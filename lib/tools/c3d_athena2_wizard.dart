/*
* Orion - Athena 2 Leveling Wizard
* Copyright (C) 2026 Open Resin Alliance
*
* Licensed under the Apache License, Version 2.0 (the "License");
* you may not use this file except in compliance with the License.
* You may obtain a copy of the License at
*
*     http://www.apache.org/licenses/LICENSE-2.0
*
* Unless required by applicable law or agreed to in writing, software
* distributed under the License is distributed on an "AS IS" BASIS,
* WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
* See the License for the specific language governing permissions and
* limitations under the License.
*/

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_i18n/flutter_i18n.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:orion/backend_service/athena_iot/models/force_leveling_workflow.dart';
import 'package:orion/backend_service/backend_service.dart';
import 'package:orion/backend_service/providers/analytics_provider.dart';
import 'package:orion/backend_service/providers/manual_provider.dart';
import 'package:orion/backend_service/providers/status_provider.dart';
import 'package:orion/glasser/glasser.dart';
import 'package:orion/tools/leveling_configs.dart';
import 'package:orion/tools/leveling_log_entry.dart';
import 'package:orion/tools/leveling_log_service.dart';
import 'package:orion/tools/leveling_workflow_engine.dart';
import 'package:orion/util/orion_spacing.dart';
import 'package:orion/util/providers/theme_provider.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';

enum _WizardPhase {
  variant,
  introAndChecklist,
  workflow,
  adjustment,
}

enum _AdjustmentStep {
  preparing,
  puckPlacement,
  probing,
  feedback,
}

class Athena2LevelingWizard extends StatefulWidget {
  const Athena2LevelingWizard({super.key, required this.config});

  final LevelingConfig config;

  @override
  State<Athena2LevelingWizard> createState() => _Athena2LevelingWizardState();
}

class _Athena2LevelingWizardState extends State<Athena2LevelingWizard> {
  late final LevelingWorkflowEngine _engine;
  _WizardPhase _phase = _WizardPhase.variant;
  bool _busyStop = false;
  static const _minRunningDuration = Duration(milliseconds: 1500);

  // Pre-flight step-through: -1 = intro view, 0..N-1 = individual steps
  int _preFlightIndex = -1;

  // Minimum running display duration
  DateTime? _runningSince;
  bool _holdingRunning = false;

  // Suppresses the brief idle-step flash between auto-advance and auto-run
  bool _autoAdvancing = false;

  // Intermediate screen flags
  bool _loosenScrewsDone = false;
  bool _alignDone = false;

  // Prevents the home-after-leveling command from firing more than once
  bool _homeAfterCompleteFired = false;

  // Leveling log session tracking
  String? _levelingSessionId;
  int _recheckNumber = 0;
  bool _probeConfigCaptured = false;

  // Adaptive force→Z coupling for back-screw adjustments.
  // Stored before the user turns the screw so we can measure what was
  // actually achieved when the recheck comes back.
  int? _lastAdjustedCorner;
  double? _lastBackForce; // probed force at the corner before adjustment (gf)
  double? _lastBackZ; // probed Z at the corner before adjustment (mm)
  double? _lastTargetForce; // what the gauge told the user to reach (gf)
  double? _estimatedCoupling; // mm / gf, computed from previous cycle

  // Corner measurements from probe steps.
  // Indexed by cornerLabel, not probe order — slots are:
  // 0=Front Left, 1=Front Right, 2=Back Right, 3=Back Left.
  final List<ForceLevelingWorkflowResponse?> _cornerResults =
      List.filled(4, null);

  static const _cornerLabelToIndex = {
    'Front Left': 0,
    'Front Right': 1,
    'Back Right': 2,
    'Back Left': 3,
  };

  // Adjustment mode state
  int? _adjustingCornerIndex;
  bool _adjustmentBusy = false;
  String? _adjustmentError;
  bool _wizardDisposed = false;
  _AdjustmentStep _adjustmentStep = _AdjustmentStep.preparing;
  static const _cornerLocations = [
    'front-left',
    'front-right',
    'back-right',
    'back-left',
  ];

  @override
  void initState() {
    super.initState();
    _engine = LevelingWorkflowEngine()..addListener(_handleEngineUpdate);

    // Prevent standby from activating while the leveling wizard is open
    Provider.of<StatusProvider>(context, listen: false)
        .setLevelingWorkflowActive(true);
  }

  @override
  void dispose() {
    _wizardDisposed = true;
    _engine.removeListener(_handleEngineUpdate);
    _engine.dispose();
    // Re-allow standby now that the wizard is closed
    if (context.mounted) {
      Provider.of<StatusProvider>(context, listen: false)
          .setLevelingWorkflowActive(false);
    }
    super.dispose();
  }

  void _handleEngineUpdate() {
    if (!mounted || _wizardDisposed) return;
    if (_engine.isRunning) {
      _autoAdvancing = false;
      _runningSince ??= DateTime.now();
      _holdingRunning = false;
      _loosenScrewsDone = false;
      _alignDone = false;
    } else if (_engine.status == LevelingWorkflowStatus.stepComplete) {
      final step = _engine.currentStep;
      if (step != null) {
        // Save measurements from probe steps, keyed by cornerLabel so
        // retries and back-navigation can't misalign the slot mapping.
        if (step.cornerLabel != null && _engine.lastResponse != null) {
          final idx = _cornerLabelToIndex[step.cornerLabel!];
          if (idx != null && idx >= 0 && idx < 4) {
            _cornerResults[idx] = _engine.lastResponse;
            // Capture probe config from the first corner response that has it
            if (!_probeConfigCaptured &&
                _engine.lastResponse!.measurements != null) {
              _probeConfigCaptured = true;
            }
          }
        }

        // Fire special screens
        if (step.specialScreen != null) {
          if (step.specialScreen == 'center') {
            BackendService()
                .showSpecialScreenCenter()
                .then((_) {})
                .catchError((_) {});
          } else if (step.specialScreen!.startsWith('corner-')) {
            final cornerIdx =
                int.tryParse(step.specialScreen!.split('-')[1]) ?? 0;
            if (cornerIdx >= 0 && cornerIdx < 4) {
              BackendService()
                  .showSpecialScreenCorner(_cornerLocations[cornerIdx])
                  .then((_) {})
                  .catchError((_) {});
            }
          }
        }

        // While showing the remove-puck prompt, run the prepare endpoint
        // in the background so the plate moves up for easy puck removal.
        if (step.intermediateScreen == 'removePuck') {
          BackendService()
              .runForceLevelingWorkflow('probe_corner_prepare',
                  requestTimeout: const Duration(seconds: 90))
              .then((_) {})
              .catchError((_) {});
        }

        // Log corner check results when all 4 corners are measured.
        if (step.intermediateScreen == 'allCorners' &&
            _levelingSessionId != null) {
          _logCornerCheck();
        }

        // Auto-advance through steps that don't need user interaction
        if (step.autoAdvance) {
          _engine.advanceAfterSuccessfulStep();
          // Also auto-run the next step if it's a prepare move, final offset,
          // or a skipBackend/intermediate step (e.g. corner results).
          // (but only if the workflow isn't complete)
          if (!_engine.isComplete) {
            final nextStep = _engine.currentStep;
            if (nextStep != null &&
                (nextStep.kind == LevelingWorkflowStepKind.finalOffset ||
                    nextStep.kind == LevelingWorkflowStepKind.prepare ||
                    nextStep.skipBackend)) {
              _autoAdvancing = true;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) _engine.runCurrentStep();
              });
            }
          }
        }
      }
    }

    // Home the machine once when the leveling workflow completes
    if (_engine.status == LevelingWorkflowStatus.complete &&
        !_homeAfterCompleteFired) {
      _homeAfterCompleteFired = true;
      Provider.of<ManualProvider>(context, listen: false)
          .moveToTop()
          .then((_) {})
          .catchError((_) {});
    }

    // Minimum running duration â€” always checked, independent of status
    if (!_engine.isRunning && _runningSince != null && !_holdingRunning) {
      final elapsed = DateTime.now().difference(_runningSince!);
      if (elapsed < _minRunningDuration) {
        _holdingRunning = true;
        Future.delayed(_minRunningDuration - elapsed, () {
          if (mounted) setState(() => _holdingRunning = false);
        });
      }
      _runningSince = null;
    }
    if (mounted) setState(() {});
  }

  bool get _effectivelyRunning =>
      _engine.isRunning || _holdingRunning || _autoAdvancing;

  void _goBack() {
    switch (_phase) {
      case _WizardPhase.variant:
        Navigator.of(context).pop();
        return;
      case _WizardPhase.introAndChecklist:
        if (_preFlightIndex >= 0) {
          setState(() => _preFlightIndex -= 1);
        } else {
          setState(() {
            _phase = _WizardPhase.variant;
            _preFlightIndex = -1;
          });
        }
        return;
      case _WizardPhase.workflow:
        if (_engine.canGoBack) {
          _engine.previousStep();
        } else {
          setState(() {
            _phase = _WizardPhase.introAndChecklist;
            _preFlightIndex = -1;
          });
          _resetCornerResults();
        }
        return;
      case _WizardPhase.adjustment:
        // Back from adjustment â†’ cancel
        _cancelLeveling();
        return;
    }
  }

  /// Generate a simple UUID v4 string without depending on the `uuid` package.
  static String _uuid4() {
    final r = Random();
    final hex = List.generate(32, (_) => r.nextInt(16).toRadixString(16));
    // Insert dashes at positions 8, 13, 18, 23 and set version/variant bits
    hex[12] = '4'; // version 4
    hex[16] = (8 + r.nextInt(4)).toRadixString(16); // variant 8–b
    return '${hex.sublist(0, 8).join()}-${hex.sublist(8, 12).join()}-${hex.sublist(12, 16).join()}-${hex.sublist(16, 20).join()}-${hex.sublist(20).join()}';
  }

  void _resetCornerResults() {
    for (int i = 0; i < _cornerResults.length; i++) {
      _cornerResults[i] = null;
    }
    _homeAfterCompleteFired = false;
  }

  // Cantilever compensation constants (currently disabled).
  // Geometry: plate 234×134mm, corners at (±117,±67) from center.
  // Cantilever attaches at rear linear rail 160mm behind center → Y=−160.
  // A simple cantilever beam model gives stiffness ∝ 1/d² at each corner,
  // so Z (probe deflection at trigger) ∝ d².  Back corners serve as the
  // stiff reference row.
  //
  //   FL/FR d² = 117² + (67+160)² = 65218
  //   BL/BR d² = 117² + (160−67)² = 22338
  //   front compensation factor = 22338 / 65218 ≈ 0.34244
  // static const _kCantileverD2Front = 65218.0;
  // static const _kCantileverD2Back = 22338.0;
  // static const _kCantileverFrontComp = _kCantileverD2Back / _kCantileverD2Front;

  /// Return the 4 raw Z values (cantilever compensation disabled).
  /// Corner order: 0=FL, 1=FR, 2=BR, 3=BL.
  List<double> _compensatedCorners(List<double?> rawZ) {
    if (rawZ.length < 4) return [];
    return [
      if (rawZ[0] != null) rawZ[0]!,
      if (rawZ[1] != null) rawZ[1]!,
      if (rawZ[2] != null) rawZ[2]!,
      if (rawZ[3] != null) rawZ[3]!,
    ];
  }

  double get _cornerDeviation {
    final rawZ = _cornerResults
        .map((r) => r?.measurements?.secondStageTriggerZ)
        .toList();
    final zValues = _compensatedCorners(rawZ);
    if (zValues.isEmpty) return 0.0;
    final min = zValues.reduce((a, b) => a < b ? a : b);
    final max = zValues.reduce((a, b) => a > b ? a : b);
    return max - min;
  }

  bool get _isCornerCheckPassed => _cornerDeviation <= 0.100;

  void _enterAdjustmentMode() {
    // The build arm has 3 screws (2 front, 1 back) defining a plane.
    // With all screws already snug, we need PAIRED adjustments
    // (loosen one, tighten another) to maintain torque balance.
    //
    // Two independent axes:
    //   Front-to-back: both front screws vs back screw
    //   Left-to-right: FL screw vs FR screw
    //
    // Corner indexing: 0=FL, 1=FR, 2=BR, 3=BL
    // Screw mapping:   corners 0-1 → respective front screw
    //                  corners 2-3 → center back screw
    final rawZ = _cornerResults
        .map((r) => r?.measurements?.secondStageTriggerZ)
        .toList();
    final zValues = _compensatedCorners(rawZ);
    if (zValues.length < 4) return;

    final z0 = zValues[0]; // FL
    final z1 = zValues[1]; // FR
    final z2 = zValues[2]; // BR
    final z3 = zValues[3]; // BL

    int probeCorner;

    // Detect front-to-back tilt: both front corners are on one side of
    // both back corners.  In that case the back screw (which controls
    // BR and BL together) is the right target — tightening or loosening
    // it pivots the plate around the front edge.  The target force
    // will be (FL+FR)/2, a clean front-only reference, instead of a
    // contaminated cross-average from the diagonal analysis.
    final frontAvg = (z0 + z1) / 2;
    final bool allFrontHigher = z0 > z2 && z0 > z3 && z1 > z2 && z1 > z3;
    final bool allBackHigher = z2 > z0 && z2 > z1 && z3 > z0 && z3 > z1;

    if (allFrontHigher || allBackHigher) {
      // Front-to-back tilt: pick the back corner furthest from the
      // front-plane average so the feedback shows the worst outlier.
      probeCorner = (z2 - frontAvg).abs() >= (z3 - frontAvg).abs() ? 2 : 3;
    } else {
      // Diagonal-pair analysis: tightening a front corner raises both
      // front corners (plate flexes as a whole) and lowers the diagonal
      // opposite rear corner via the cantilever pivot.  Pick the pair
      // with the greatest height difference and tighten the lower corner.
      final diagFLBR = (z0 - z2).abs(); // FL ↔ BR
      final diagFRBL = (z1 - z3).abs(); // FR ↔ BL

      if (diagFLBR >= diagFRBL) {
        probeCorner = z0 < z2 ? 0 : 2; // tighten the lower corner
      } else {
        probeCorner = z1 < z3 ? 1 : 3; // tighten the lower corner
      }
    }

    _adjustingCornerIndex = probeCorner;
    _adjustmentError = null;
    _adjustmentBusy = true;

    // Snapshot pre-adjustment state for back-screw coupling estimation.
    if (probeCorner >= 2) {
      _lastAdjustedCorner = probeCorner;
      _lastBackForce = _cornerResults[probeCorner]
          ?.measurements?.firstStagePeakForce;
      _lastBackZ = _cornerResults[probeCorner]
          ?.measurements?.secondStageTriggerZ;
    }

    setState(() {
      _phase = _WizardPhase.adjustment;
      _adjustmentStep = _AdjustmentStep.preparing;
    });

    _runAdjustmentPrepare();
  }

  Future<void> _runAdjustmentPrepare() async {
    if (_adjustingCornerIndex == null) return;
    _adjustmentBusy = true;
    if (mounted) setState(() {});

    try {
      await BackendService().runForceLevelingWorkflow(
        'probe_corner_prepare',
        requestTimeout: const Duration(seconds: 90),
      );
      if (!mounted) return;

      // Fire the special screen for this corner so the projector shows the position
      final cornerIdx = _adjustingCornerIndex!;
      if (cornerIdx >= 0 && cornerIdx < 4) {
        BackendService()
            .showSpecialScreenCorner(_cornerLocations[cornerIdx])
            .then((_) {})
            .catchError((_) {});
      }
    } catch (e) {
      _adjustmentError = e.toString();
      _adjustmentBusy = false;
      if (mounted) setState(() {});
      return;
    }

    _adjustmentBusy = false;
    _adjustmentStep = _AdjustmentStep.puckPlacement;
    if (mounted) setState(() {});
  }

  Future<void> _runAdjustmentProbe() async {
    if (_adjustingCornerIndex == null) return;
    _adjustmentBusy = true;
    _adjustmentStep = _AdjustmentStep.probing;
    if (mounted) setState(() {});

    try {
      final response = await BackendService().runForceLevelingWorkflow(
        'probe_corner',
        requestTimeout: const Duration(seconds: 90),
      );
      if (!mounted) return;

      if (!response.result) {
        _adjustmentError = response.error.isNotEmpty
            ? response.error
            : FlutterI18n.translate(context, 'leveling.wizardProbeFailed');
        _adjustmentBusy = false;
        if (mounted) setState(() {});
        return;
      }

      _cornerResults[_adjustingCornerIndex!] = response;
    } catch (e) {
      _adjustmentError = e.toString();
      _adjustmentBusy = false;
      if (mounted) setState(() {});
      return;
    }

    _adjustmentBusy = false;
    _adjustmentStep = _AdjustmentStep.feedback;
    if (mounted) setState(() {});
  }

  void _logCornerCheck() {
    if (_levelingSessionId == null) return;

    // ── Update adaptive coupling estimate from the recheck results ──
    if (_lastAdjustedCorner != null &&
        _lastBackForce != null &&
        _lastBackZ != null &&
        _lastTargetForce != null) {
      final newBackZ = _cornerResults[_lastAdjustedCorner!]
          ?.measurements?.secondStageTriggerZ;
      if (newBackZ != null) {
        final actualZMm = newBackZ - _lastBackZ!;
        final appliedForceGf = _lastTargetForce! - _lastBackForce!;
        if (appliedForceGf.abs() > 10 && actualZMm.abs() > 0.001) {
          final newCoupling = actualZMm / appliedForceGf; // mm / gf
          // EMA-smooth the estimate so noise from a single cycle
          // doesn't cause wild swings.
          if (_estimatedCoupling != null) {
            _estimatedCoupling =
                _estimatedCoupling! * 0.5 + newCoupling * 0.5;
          } else {
            _estimatedCoupling = newCoupling;
          }
        }
      }
      // Clear the snapshot so stale values don't feed the next estimate
      _lastAdjustedCorner = null;
      _lastBackForce = null;
      _lastBackZ = null;
      _lastTargetForce = null;
    }

    final variant = _engine.variant?.id ?? 'unknown';
    final cornerLabels = ['FL', 'FR', 'BR', 'BL'];
    final corners = <String, CornerLogData>{};
    for (int i = 0; i < 4; i++) {
      corners[cornerLabels[i]] =
          CornerLogData.fromMeasurements(_cornerResults[i]?.measurements);
    }
    // Snapshot probe config from the first corner that has it
    ProbeConfigSnapshot? probeConfig;
    for (final r in _cornerResults) {
      if (r?.measurements != null) {
        final c = ProbeConfigSnapshot.fromMeasurements(r!.measurements);
        // Only include if at least one config field is present
        if (c.firstStageSpeed != null ||
            c.secondStageSpeed != null ||
            c.firstStageLiftHeight != null ||
            c.secondStageLiftHeight != null ||
            c.firstStageThreshold != null ||
            c.secondStageThreshold != null ||
            c.probeStartDistance != null ||
            c.probeRetractDistance != null) {
          probeConfig = c;
          break;
        }
      }
    }
    final entry = LevelingLogEntry(
      sessionId: _levelingSessionId!,
      timestamp: DateTime.now().toUtc().toIso8601String(),
      variant: variant,
      recheckNumber: _recheckNumber,
      corners: corners,
      totalDeviationMm: _cornerDeviation,
      passed: _isCornerCheckPassed,
      probeConfig: probeConfig,
      estimatedCoupling: _estimatedCoupling,
    );
    LevelingLogService.logCornerCheck(entry);
  }

  void _runRecheckCorners() {
    _recheckNumber++;
    _resetCornerResults();
    _probeConfigCaptured = false;
    _engine.jumpToFirstStepId('fine_prepare_');
    setState(() => _phase = _WizardPhase.workflow);
    // Auto-run the corner prepare step so the probe positions itself before
    // showing the puck placement screen.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _engine.canRunCurrentStep) {
        _engine.runCurrentStep();
      }
    });
  }

  void _advancePreFlight() {
    final keys = widget.config.checklistKeys;
    if (_preFlightIndex < keys.length - 1) {
      setState(() => _preFlightIndex += 1);
    } else {
      // All pre-flight steps done â†’ start workflow (variant already selected)
      setState(() {
        _phase = _WizardPhase.workflow;
        _preFlightIndex = -1;
      });
      // Auto-run the first workflow step (Prepare Printer)
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _engine.canRunCurrentStep) {
          _engine.runCurrentStep();
        }
      });
    }
  }

  Future<void> _emergencyStop() async {
    if (_busyStop) return;
    setState(() => _busyStop = true);
    try {
      final manual = Provider.of<ManualProvider>(context, listen: false);
      await manual.emergencyStop();
      if (!mounted) return;
      final status = Provider.of<StatusProvider>(context, listen: false);
      status.clearHomedStatus();
      await status.refreshKinematicStatus();
      // Exit the wizard after emergency stop
      if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
    } finally {
      if (mounted) setState(() => _busyStop = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isGlass =
        Provider.of<ThemeProvider>(context, listen: false).isGlassTheme;
    final primary = Theme.of(context).colorScheme.primary;

    return GlassApp(
      child: Scaffold(
        backgroundColor: isGlass
            ? Colors.transparent
            : Theme.of(context).colorScheme.surface,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.only(
              left: OrionSpacing.screenHorizontal,
              right: OrionSpacing.screenHorizontal,
              top: 24,
              bottom: 24,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ====== Phase content (header + body, animated) ======
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 350),
                    switchInCurve: Curves.easeInOut,
                    switchOutCurve: Curves.easeInOut,
                    transitionBuilder: (child, animation) {
                      return FadeTransition(opacity: animation, child: child);
                    },
                    child: _buildPhaseContent(context, primary),
                  ),
                ),
                const SizedBox(height: 16),
                // ====== Actions ======
                _buildActions(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPhaseContent(BuildContext context, Color primary) {
    // Each phase returns its full layout (header + body) as one widget
    // so AnimatedSwitcher can cross-fade the entire transition.
    switch (_phase) {
      case _WizardPhase.variant:
        return Column(
          key: const ValueKey('variant-phase'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(PhosphorIcons.swap(), size: 24, color: primary),
                const SizedBox(width: OrionSpacing.listGap),
                Text(
                  FlutterI18n.translate(context, 'leveling.selectBuildArm'),
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: OrionSpacing.controlGap),
            Expanded(child: _buildPhaseBody(context)),
          ],
        );
      case _WizardPhase.adjustment:
        return _buildAdjustmentPhase(context, primary);
      default:
        // introAndChecklist and workflow have no header
        return _buildPhaseBody(context);
    }
  }

  Widget _buildPhaseBody(BuildContext context) {
    switch (_phase) {
      case _WizardPhase.introAndChecklist:
        if (_preFlightIndex < 0) {
          return const _PreLevelingPane(key: ValueKey('intro'));
        }
        return _PreFlightGuidePane(
          key: ValueKey('preflight-$_preFlightIndex'),
          config: widget.config,
          stepIndex: _preFlightIndex,
        );
      case _WizardPhase.variant:
        return _VariantSelectionPane(
          key: const ValueKey('variant'),
          config: widget.config,
          onVariantSelected: (variant) {
            _engine.selectVariant(variant);
            _resetCornerResults();
            // Generate a new session ID for each leveling attempt
            _levelingSessionId = _uuid4();
            _recheckNumber = 0;
            _probeConfigCaptured = false;
            setState(() {
              _phase = _WizardPhase.introAndChecklist;
              _preFlightIndex = -1;
            });
          },
        );
      case _WizardPhase.workflow:
        return _WorkflowPane(
          key: const ValueKey('workflow'),
          engine: _engine,
          effectivelyRunning: _effectivelyRunning,
          loosenScrewsDone: _loosenScrewsDone,
          alignDone: _alignDone,
          cornerResults: _cornerResults,
        );
      case _WizardPhase.adjustment:
        // Handled in _buildPhaseContent
        return const SizedBox.shrink();
    }
  }

  Widget _buildActions(BuildContext context) {
    if (_phase == _WizardPhase.workflow) {
      return _buildWorkflowActions(context);
    }

    if (_phase == _WizardPhase.adjustment) {
      return _buildAdjustmentActions(context);
    }

    if (_phase == _WizardPhase.introAndChecklist && _preFlightIndex >= 0) {
      // Pre-flight step: Back | Done
      final isLast = _preFlightIndex >= widget.config.checklistKeys.length - 1;
      return Row(
        children: [
          Expanded(
            child: GlassButton(
              tint: GlassButtonTint.neutral,
              onPressed: _goBack,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 65),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(PhosphorIcons.arrowLeft(), size: 20),
                  const SizedBox(width: 8),
                  Text(
                    FlutterI18n.translate(context, 'common.back'),
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: OrionSpacing.controlGap),
          Expanded(
            child: GlassButton(
              tint: GlassButtonTint.positive,
              onPressed: _advancePreFlight,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 65),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    isLast
                        ? FlutterI18n.translate(context, 'common.done')
                        : FlutterI18n.translate(context, 'leveling.next'),
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    isLast ? PhosphorIcons.check() : PhosphorIcons.arrowRight(),
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    // Variant selection (first step): Cancel only
    if (_phase == _WizardPhase.variant) {
      return Center(
        child: SizedBox(
          width: 260,
          child: GlassButton(
            tint: GlassButtonTint.negative,
            onPressed: _cancelLeveling,
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 65),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(PhosphorIcons.x(), size: 20),
                const SizedBox(width: 8),
                Text(
                  FlutterI18n.translate(context, 'common.cancel'),
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Intro view: Cancel | Start Pre-Flight
    return Row(
      children: [
        Expanded(
          child: GlassButton(
            tint: GlassButtonTint.negative,
            onPressed: _goBack,
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 65),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(PhosphorIcons.x(), size: 20),
                const SizedBox(width: 10),
                Text(
                  FlutterI18n.translate(context, 'common.cancel'),
                  style: const TextStyle(fontSize: 20),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: OrionSpacing.controlGap),
        Expanded(
          child: GlassButton(
            tint: GlassButtonTint.positive,
            onPressed: () => setState(() => _preFlightIndex = 0),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 65),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  FlutterI18n.translate(
                      context, 'leveling.wizardStartPreFlight'),
                  style: const TextStyle(fontSize: 20),
                ),
                const SizedBox(width: 10),
                Icon(PhosphorIcons.arrowRight(), size: 20),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWorkflowActions(BuildContext context) {
    final status = _engine.status;
    final isLast = _engine.currentStepIndex >= _engine.steps.length - 1;
    final isAllCornersMeasured =
        status == LevelingWorkflowStatus.stepComplete &&
            _engine.currentStep?.intermediateScreen == 'allCorners';

    // Completion: single Done button
    if (status == LevelingWorkflowStatus.complete) {
      return Center(
        child: SizedBox(
          width: 320,
          child: GlassButton(
            tint: GlassButtonTint.positive,
            onPressed: () =>
                Navigator.of(context).popUntil((route) => route.isFirst),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 65),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(PhosphorIcons.check(), size: 20),
                const SizedBox(width: 10),
                Text(
                  FlutterI18n.translate(context, 'common.done'),
                  style: const TextStyle(fontSize: 20),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Running: Emergency Stop only
    if (_effectivelyRunning || _busyStop) {
      return Center(
        child: SizedBox(
          width: 320,
          child: GlassButton(
            tint: GlassButtonTint.negative,
            onPressed: _busyStop ? null : _emergencyStop,
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 65),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _busyStop
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(PhosphorIconsFill.stop, size: 20),
                const SizedBox(width: 8),
                Text(
                  FlutterI18n.translate(context, 'moveZ.emergencyStop'),
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Loosen-screws prompt: Cancel | Done
    if (status == LevelingWorkflowStatus.stepComplete &&
        _engine.currentStep?.intermediateScreen == 'loosen' &&
        !_loosenScrewsDone) {
      return Row(
        children: [
          Expanded(
            child: GlassButton(
              tint: GlassButtonTint.negative,
              onPressed: _cancelLeveling,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 65),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(PhosphorIcons.x(), size: 20),
                  const SizedBox(width: 8),
                  Text(
                    FlutterI18n.translate(context, 'common.cancel'),
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: OrionSpacing.controlGap),
          Expanded(
            child: GlassButton(
              tint: GlassButtonTint.positive,
              onPressed: () {
                _loosenScrewsDone = true;
                _engine.advanceAfterSuccessfulStep();
                // Auto-run the initial leveling step
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted && _engine.canRunCurrentStep) {
                    _engine.runCurrentStep();
                  }
                });
              },
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 65),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(PhosphorIcons.check(), size: 20),
                  const SizedBox(width: 8),
                  Text(
                    FlutterI18n.translate(context, 'common.done'),
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    // Align-plate prompt (shown before tighten): Cancel | Done
    if (status == LevelingWorkflowStatus.stepComplete &&
        _engine.currentStep?.intermediateScreen == 'tighten' &&
        !_alignDone) {
      return Row(
        children: [
          Expanded(
            child: GlassButton(
              tint: GlassButtonTint.negative,
              onPressed: _cancelLeveling,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 65),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(PhosphorIcons.x(), size: 20),
                  const SizedBox(width: 8),
                  Text(
                    FlutterI18n.translate(context, 'common.cancel'),
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: OrionSpacing.controlGap),
          Expanded(
            child: GlassButton(
              tint: GlassButtonTint.positive,
              onPressed: () => setState(() => _alignDone = true),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 65),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(PhosphorIcons.check(), size: 20),
                  const SizedBox(width: 8),
                  Text(
                    FlutterI18n.translate(context, 'common.done'),
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    // Tighten-screws prompt (after alignment): Cancel | Done â†’ auto-run offset
    if (status == LevelingWorkflowStatus.stepComplete &&
        _engine.currentStep?.intermediateScreen == 'tighten' &&
        _alignDone) {
      return Row(
        children: [
          Expanded(
            child: GlassButton(
              tint: GlassButtonTint.negative,
              onPressed: _cancelLeveling,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 65),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(PhosphorIcons.x(), size: 20),
                  const SizedBox(width: 8),
                  Text(
                    FlutterI18n.translate(context, 'common.cancel'),
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: OrionSpacing.controlGap),
          Expanded(
            child: GlassButton(
              tint: GlassButtonTint.positive,
              onPressed: () {
                _engine.advanceAfterSuccessfulStep();
                // Auto-run the calibrating offset step
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted && _engine.canRunCurrentStep) {
                    _engine.runCurrentStep();
                  }
                });
              },
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 65),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(PhosphorIcons.check(), size: 20),
                  const SizedBox(width: 8),
                  Text(
                    FlutterI18n.translate(context, 'common.done'),
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    // Remove puck prompt: Cancel | Done â†’ advance + auto-run final prepare
    if (status == LevelingWorkflowStatus.stepComplete &&
        _engine.currentStep?.intermediateScreen == 'removePuck') {
      return Row(
        children: [
          Expanded(
            child: GlassButton(
              tint: GlassButtonTint.negative,
              onPressed: _cancelLeveling,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 65),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(PhosphorIcons.x(), size: 20),
                  const SizedBox(width: 8),
                  Text(
                    FlutterI18n.translate(context, 'common.cancel'),
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: OrionSpacing.controlGap),
          Expanded(
            child: GlassButton(
              tint: GlassButtonTint.positive,
              onPressed: () {
                // Arm is already up from background probe_corner_prepare.
                // Skip final_prepare — jump straight to final calibration.
                final finalIdx = _engine.steps.lastIndexWhere(
                  (s) => s.kind == LevelingWorkflowStepKind.finalOffset,
                );
                if (finalIdx >= 0) {
                  _engine.jumpToStep(finalIdx);
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted && _engine.canRunCurrentStep) {
                      _engine.runCurrentStep();
                    }
                  });
                }
              },
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 65),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(PhosphorIcons.check(), size: 20),
                  const SizedBox(width: 8),
                  Text(
                    FlutterI18n.translate(context, 'common.done'),
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    // Not running, not complete: Cancel + action button
    final bool needsAdjustment = isAllCornersMeasured && !_isCornerCheckPassed;
    final bool isCornerPrepare =
        status == LevelingWorkflowStatus.stepComplete &&
            _engine.currentStep?.kind == LevelingWorkflowStepKind.prepare &&
            (_engine.currentStep?.id.startsWith('fine_prepare_') ?? false);
    final primaryLabel = switch (status) {
      LevelingWorkflowStatus.idle =>
        FlutterI18n.translate(context, 'leveling.wizardProceed'),
      LevelingWorkflowStatus.stepComplete => isAllCornersMeasured
          ? (needsAdjustment
              ? FlutterI18n.translate(context, 'leveling.wizardAdjust')
              : FlutterI18n.translate(context, 'leveling.wizardContinue'))
          : isCornerPrepare
              ? FlutterI18n.translate(context, 'leveling.next')
              : isLast
                  ? FlutterI18n.translate(context, 'common.done')
                  : FlutterI18n.translate(context, 'leveling.next'),
      LevelingWorkflowStatus.failed =>
        FlutterI18n.translate(context, 'common.retry'),
      _ => '',
    };

    final primaryIcon = switch (status) {
      LevelingWorkflowStatus.idle => PhosphorIcons.arrowRight(),
      LevelingWorkflowStatus.stepComplete => isAllCornersMeasured
          ? (needsAdjustment
              ? PhosphorIcons.wrench()
              : PhosphorIcons.arrowRight())
          : PhosphorIcons.arrowRight(),
      LevelingWorkflowStatus.failed => PhosphorIcons.arrowRight(),
      _ => PhosphorIcons.arrowRight(),
    };

    final primaryTint = needsAdjustment
        ? GlassButtonTint.warn
        : status == LevelingWorkflowStatus.failed
            ? GlassButtonTint.warn
            : GlassButtonTint.positive;

    VoidCallback? onPrimary() {
      if (_engine.isRunning) return null;
      if (isAllCornersMeasured && needsAdjustment) {
        return () => _enterAdjustmentMode();
      }
      return switch (status) {
        LevelingWorkflowStatus.idle => () => _engine.runCurrentStep(),
        LevelingWorkflowStatus.failed => () => _engine.runCurrentStep(),
        LevelingWorkflowStatus.stepComplete => () {
            _engine.advanceAfterSuccessfulStep();
            // Auto-run the next step if advancing from a corner prepare,
            // or if it's a skipBackend intermediate screen (e.g. remove
            // puck) so the user sees the real view immediately.
            if (isCornerPrepare) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted && _engine.canRunCurrentStep) {
                  _engine.runCurrentStep();
                }
              });
            }
            final next = _engine.currentStep;
            if (next?.skipBackend == true && next?.intermediateScreen != null) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted && _engine.canRunCurrentStep) {
                  _engine.runCurrentStep();
                }
              });
            }
          },
        LevelingWorkflowStatus.complete => () =>
            Navigator.of(context).popUntil((route) => route.isFirst),
        LevelingWorkflowStatus.running => null,
      };
    }

    return Row(
      children: [
        Expanded(
          child: GlassButton(
            tint: GlassButtonTint.negative,
            onPressed: _cancelLeveling,
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 65),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(PhosphorIcons.x(), size: 20),
                const SizedBox(width: 8),
                Text(
                  FlutterI18n.translate(context, 'common.cancel'),
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: OrionSpacing.controlGap),
        Expanded(
          child: GlassButton(
            tint: primaryTint,
            onPressed: onPrimary(),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 65),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(primaryIcon, size: 20),
                const SizedBox(width: 8),
                Text(
                  primaryLabel,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _cancelLeveling() async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => GlassAlertDialog(
        title: Row(
          children: [
            Icon(PhosphorIcons.warning(), size: 26, color: Colors.orangeAccent),
            const SizedBox(width: 14),
            Text(
              FlutterI18n.translate(context, 'leveling.wizardCancelTitle'),
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.orangeAccent,
              ),
            ),
          ],
        ),
        content: Text(
          FlutterI18n.translate(context, 'leveling.wizardCancelMsg'),
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
        ),
        actions: [
          GlassButton(
            tint: GlassButtonTint.negative,
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(0, 60),
            ),
            child: Text(
              FlutterI18n.translate(context, 'levelingWorkflow.yes'),
              style: const TextStyle(fontSize: 18),
            ),
          ),
          GlassButton(
            tint: GlassButtonTint.neutral,
            onPressed: () => Navigator.of(ctx).pop(false),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(0, 60),
            ),
            child: Text(
              FlutterI18n.translate(context, 'levelingWorkflow.no'),
              style: const TextStyle(fontSize: 18),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      // Move to top before cancelling so the arm is in a safe position
      Provider.of<ManualProvider>(context, listen: false)
          .moveToTop()
          .then((_) {})
          .catchError((_) {});
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  Widget _buildAdjustmentActions(BuildContext context) {
    final isPuckStep = _adjustmentStep == _AdjustmentStep.puckPlacement;

    // Busy (preparing / probing): emergency stop with status label
    if (_adjustmentBusy) {
      return Center(
        child: SizedBox(
          width: 320,
          child: GlassButton(
            tint: GlassButtonTint.negative,
            onPressed: _busyStop ? null : _emergencyStop,
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 65),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(PhosphorIconsFill.stop, size: 20),
                const SizedBox(width: 8),
                Text(
                  _adjustmentStep == _AdjustmentStep.probing
                      ? FlutterI18n.translate(
                          context, 'leveling.wizardProbingBtn')
                      : FlutterI18n.translate(
                          context, 'leveling.wizardPreparingBtn'),
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Puck placement: Cancel | Proceed
    if (isPuckStep) {
      return Row(
        children: [
          Expanded(
            child: GlassButton(
              tint: GlassButtonTint.negative,
              onPressed: _cancelLeveling,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 65),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(PhosphorIcons.x(), size: 20),
                  const SizedBox(width: 8),
                  Text(
                    FlutterI18n.translate(context, 'common.cancel'),
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: OrionSpacing.controlGap),
          Expanded(
            child: GlassButton(
              tint: GlassButtonTint.positive,
              onPressed: _runAdjustmentProbe,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 65),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(PhosphorIcons.arrowRight(), size: 20),
                  const SizedBox(width: 8),
                  Text(
                    FlutterI18n.translate(context, 'leveling.next'),
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    // Feedback / error: Cancel | Re-check
    return Row(
      children: [
        Expanded(
          child: GlassButton(
            tint: GlassButtonTint.negative,
            onPressed: _cancelLeveling,
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 65),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(PhosphorIcons.x(), size: 20),
                const SizedBox(width: 8),
                Text(
                  FlutterI18n.translate(context, 'common.cancel'),
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: OrionSpacing.controlGap),
        Expanded(
          child: GlassButton(
            tint: GlassButtonTint.positive,
            onPressed: _runRecheckCorners,
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 65),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(PhosphorIcons.arrowClockwise(), size: 20),
                const SizedBox(width: 8),
                Text(
                  FlutterI18n.translate(context, 'leveling.wizardRecheckAll'),
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAdjustmentPhase(BuildContext context, Color primary) {
    if (_adjustmentError != null) {
      return _buildAdjustmentError(context, primary);
    }
    if (_adjustingCornerIndex == null) {
      return const SizedBox.shrink();
    }

    switch (_adjustmentStep) {
      case _AdjustmentStep.preparing:
      case _AdjustmentStep.probing:
        return _buildAdjustmentWarning(context, primary);
      case _AdjustmentStep.puckPlacement:
        return _buildPuckPlacementView(context, primary);
      case _AdjustmentStep.feedback:
        // Diagonal-average force target.
        // The two corners NOT on the adjusting corner's diagonal
        // sit on the pivot axis and define the reference plane.
        // Target = average of those two reference corners' forces.
        // Uses first-stage peak force — varies with corner height,
        // unlike the constant second-stage trigger force.
        //
        // Corner indexing: 0=FL, 1=FR, 2=BR, 3=BL
        //   FL screw → diagonal FL↔BR, reference = FR + BL
        //   FR screw → diagonal FR↔BL, reference = FL + BR
        //   Back screw → reference = FL + FR (front edge)
        final allForces = _cornerResults
            .map((r) => r?.measurements?.firstStagePeakForce)
            .toList();
        final idx = _adjustingCornerIndex!;

        if (allForces.length < 4 ||
            allForces[0] == null || allForces[1] == null ||
            allForces[2] == null || allForces[3] == null) {
          return const SizedBox.shrink();
        }

        final double targetForce;
        if (idx == 0) {
          targetForce = (allForces[1]! + allForces[3]!) / 2; // FR + BL
        } else if (idx == 1) {
          targetForce = (allForces[0]! + allForces[2]!) / 2; // FL + BR
        } else {
          // ── Back screw (shared between BR and BL, idx 2 or 3) ──
          //
          // Goal: raise the back edge until it is 0.1 mm *above* the
          // front-plane average in a single adjustment cycle.  The
          // force→Z coupling is estimated from the previous cycle (if
          // available) so the target adapts to the actual machine.
          final rawZ = _cornerResults
              .map((r) => r?.measurements?.secondStageTriggerZ)
              .toList();
          final zValues = _compensatedCorners(rawZ);
          final frontAvgZ = zValues.length >= 4
              ? (zValues[0] + zValues[1]) / 2
              : 0.0;
          final backZ = zValues.length >= 4 ? zValues[idx] : 0.0;
          final zGapMm = frontAvgZ - backZ; // positive → back too low
          const targetOvershootMm = 0.1;
          final neededZMm = zGapMm + targetOvershootMm;

          final double forceDelta;
          if (_estimatedCoupling != null && _estimatedCoupling! > 0) {
            // Adaptive: use the coupling measured from the last cycle.
            // Clamp to ±3000 gf — the sensor can handle it.
            forceDelta = (neededZMm / _estimatedCoupling!)
                .clamp(-3000.0, 3000.0);
          } else {
            // First cycle — no coupling estimate yet.  Use a force-based
            // heuristic: drive the lower back corner to match the higher
            // front corner, with a 2× gain because the coupling is weak.
            final frontMax =
                (allForces[0]! > allForces[1]! ? allForces[0]! : allForces[1]!);
            final backMin =
                (allForces[2]! < allForces[3]! ? allForces[2]! : allForces[3]!);
            forceDelta = (frontMax - backMin) * 2.0;
          }
          targetForce = allForces[idx]! + forceDelta;
          _lastTargetForce = targetForce;
        }

        final double cornerForce = allForces[idx]!;
        final double forceDeltaGf = cornerForce - targetForce;
        // Positive → corner more compressed than reference → TIGHTEN.
        // Negative → corner less compressed than reference → LOOSEN.
        final bool needsTighten = forceDeltaGf > 20;
        final bool needsLoosen = forceDeltaGf < -20;

        return _AdjustmentFeedbackScreen(
          key: const ValueKey('adjustment-feedback'),
          cornerIndex: _adjustingCornerIndex!,
          cornerForce: cornerForce,
          targetForce: targetForce,
          allCornerForces: allForces.whereType<double>().toList(),
          forceDelta: forceDeltaGf,
          needsTighten: needsTighten,
          needsLoosen: needsLoosen,
        );
    }
  }

  Widget _buildAdjustmentWarning(BuildContext context, Color primary) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 100,
            height: 100,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.redAccent.withValues(alpha: 0.20),
                  ),
                ),
                const Icon(
                  PhosphorIconsFill.hand,
                  size: 56,
                  color: Colors.redAccent,
                ),
                SizedBox(
                  width: 100,
                  height: 100,
                  child: CircularProgressIndicator(
                    strokeWidth: 4,
                    color: Colors.redAccent.withValues(alpha: 0.50),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text(
            FlutterI18n.translate(context, 'leveling.wizardKeepHandsClear'),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.redAccent,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              FlutterI18n.translate(context, 'leveling.wizardMovingToProbe'),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                height: 1.4,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.72),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPuckPlacementView(BuildContext context, Color primary) {
    final labels = ['Front Left', 'Front Right', 'Back Right', 'Back Left'];
    final screwHints = ['', '', ' (center screw)', ' (center screw)'];
    final cornerIcons = [
      PhosphorIcons.arrowDownLeft(),
      PhosphorIcons.arrowDownRight(),
      PhosphorIcons.arrowUpRight(),
      PhosphorIcons.arrowUpLeft(),
    ];
    final idx = _adjustingCornerIndex ?? 0;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: primary.withValues(alpha: 0.12),
            ),
            child: Icon(
              cornerIcons[idx],
              size: 52,
              color: primary,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            FlutterI18n.translate(context, 'leveling.wizardPlacePuck'),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: primary,
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              FlutterI18n.translate(context, 'leveling.wizardPuckInstruction',
                  translationParams: {
                    'corner': labels[idx],
                    'hint': screwHints[idx],
                  }),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                height: 1.4,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.72),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdjustmentError(BuildContext context, Color primary) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(PhosphorIcons.warning(), size: 64, color: Colors.orangeAccent),
          const SizedBox(height: 20),
          Text(
            FlutterI18n.translate(context, 'leveling.wizardAdjustFailed'),
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.orangeAccent,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              _adjustmentError ??
                  FlutterI18n.translate(context, 'leveling.wizardUnknownError'),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.72),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ================================================================================================================================================================================================
// Phase: Intro (simplified â€” calibration-overlay style)
// ================================================================================================================================================================================================

class _PreLevelingPane extends StatelessWidget {
  const _PreLevelingPane({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    return Center(
      key: const ValueKey('intro'),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: primary.withValues(alpha: 0.12),
            ),
            child: Icon(
              PhosphorIcons.magicWand(),
              size: 52,
              color: primary,
            ),
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              FlutterI18n.translate(context, 'leveling.wizardIntroMsg'),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: primary,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              FlutterI18n.translate(context, 'leveling.wizardIntroDetail'),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                height: 1.4,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.72),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ================================================================================================================================================================================================
// Pre-Flight Step-through Guide
// ================================================================================================================================================================================================

class _PreFlightGuidePane extends StatelessWidget {
  const _PreFlightGuidePane({
    super.key,
    required this.config,
    required this.stepIndex,
  });

  final LevelingConfig config;
  final int stepIndex;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final keys = config.checklistKeys;
    final label = FlutterI18n.translate(context, keys[stepIndex]);
    final total = keys.length;

    return Center(
      key: ValueKey('preflight-$stepIndex'),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: primary.withValues(alpha: 0.12),
            ),
            child: Icon(
              PhosphorIcons.listChecks(),
              size: 52,
              color: primary,
            ),
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: primary,
              ),
            ),
          ),
          const SizedBox(height: 20),
          // Progress dots
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(total, (i) {
              final isActive = i <= stepIndex;
              return Container(
                width: 10,
                height: 10,
                margin: const EdgeInsets.symmetric(horizontal: 5),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isActive
                      ? primary
                      : theme.colorScheme.onSurface.withValues(alpha: 0.15),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

// ================================================================================================================================================================================================
// Phase: Variant Selection (kept similar but updated styling)
// ================================================================================================================================================================================================

class _VariantSelectionPane extends StatelessWidget {
  const _VariantSelectionPane({
    super.key,
    required this.config,
    required this.onVariantSelected,
  });

  final LevelingConfig config;
  final ValueChanged<LevelingVariant> onVariantSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const ValueKey('variant'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (int i = 0; i < config.variants.length; i++) ...[
                if (i > 0) const SizedBox(width: OrionSpacing.controlGap),
                Expanded(
                  child: _VariantCard(
                    variant: config.variants[i],
                    onPressed: () => onVariantSelected(config.variants[i]),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _VariantCard extends StatelessWidget {
  const _VariantCard({
    required this.variant,
    required this.onPressed,
  });

  final LevelingVariant variant;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GlassCard(
      outlined: true,
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(glassCornerRadius),
        onTap: onPressed,
        child: Padding(
          padding: OrionSpacing.cardPadding,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Expanded(child: _VariantAsset(variant: variant)),
              const SizedBox(height: OrionSpacing.listGap),
              Text(
                variant.label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: OrionSpacing.compactListGap),
              Text(
                variant.description,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.2,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.64),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VariantAsset extends StatelessWidget {
  const _VariantAsset({required this.variant});

  final LevelingVariant variant;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final asset = variant.assetPath;
    if (asset == null) {
      return Icon(
        variant.icon ?? PhosphorIconsFill.cube,
        size: 64,
        color: accent,
      );
    }

    return SizedBox(
      height: 120,
      child: asset.endsWith('.svg')
          ? SvgPicture.asset(
              asset,
              fit: BoxFit.contain,
              colorFilter: ColorFilter.mode(accent, BlendMode.srcIn),
            )
          : Image.asset(asset, fit: BoxFit.contain),
    );
  }
}

// ================================================================================================================================================================================================
// Phase: Workflow Execution (calibration progress overlay style)
// ================================================================================================================================================================================================

class _WorkflowPane extends StatelessWidget {
  static const _cornerLabels = [
    'Front Left',
    'Front Right',
    'Back Right',
    'Back Left',
  ];

  /// Pass through raw corner Z values (cantilever compensation disabled).
  static List<double?> _compensatedZ(List<double?> raw) {
    return raw;
  }

  const _WorkflowPane({
    super.key,
    required this.engine,
    required this.effectivelyRunning,
    required this.loosenScrewsDone,
    required this.alignDone,
    required this.cornerResults,
  });

  final LevelingWorkflowEngine engine;
  final bool effectivelyRunning;
  final bool loosenScrewsDone;
  final bool alignDone;
  final List<ForceLevelingWorkflowResponse?> cornerResults;

  @override
  Widget build(BuildContext context) {
    if (engine.isComplete) {
      return _CompletionPane(engine: engine);
    }

    final step = engine.currentStep;
    if (step == null) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    // Intermediate screens from step metadata (only on stepComplete)
    final isComplete = engine.status == LevelingWorkflowStatus.stepComplete;
    final String? intermediate = step.intermediateScreen;
    final isLoosenScrews =
        isComplete && intermediate == 'loosen' && !loosenScrewsDone;
    final isAlignPlate = isComplete && intermediate == 'tighten' && !alignDone;
    final isTightenScrews =
        isComplete && intermediate == 'tighten' && alignDone;
    final isAllCornersMeasured = isComplete && intermediate == 'allCorners';
    final isRemovePuck = isComplete && intermediate == 'removePuck';

    return Center(
      key: ValueKey(
        'workflow-${engine.currentStepIndex}-${engine.status.name}',
      ),
      child: effectivelyRunning
          ? _buildRunningView(context, primary, step)
          : isLoosenScrews
              ? _buildLoosenScrewsView(context, primary)
              : isAlignPlate
                  ? _buildAlignPlateView(context, primary)
                  : isTightenScrews
                      ? _buildTightenScrewsView(context, primary)
                      : isAllCornersMeasured
                          ? _buildAllCornersMeasuredView(context, primary)
                          : isRemovePuck
                              ? _buildRemovePuckView(context, primary)
                              : _buildStepView(context, theme, primary, step),
    );
  }

  Widget _buildLoosenScrewsView(BuildContext context, Color primary) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: primary.withValues(alpha: 0.12),
          ),
          child: Icon(
            PhosphorIcons.wrench(),
            size: 52,
            color: primary,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          FlutterI18n.translate(context, 'leveling.loosenTitle'),
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            FlutterI18n.translate(context, 'leveling.loosenInstruction'),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 20,
              height: 1.4,
              color: onSurface.withValues(alpha: 0.72),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRunningView(
    BuildContext context,
    Color primary,
    LevelingWorkflowStep step,
  ) {
    final title = step.runningTitle ??
        switch (step.kind) {
          LevelingWorkflowStepKind.prepare =>
            FlutterI18n.translate(context, 'leveling.wizardPreparingMachine'),
          LevelingWorkflowStepKind.finalOffset =>
            FlutterI18n.translate(context, 'leveling.wizardSavingOffset'),
          _ => FlutterI18n.translate(context, 'leveling.wizardMovingToScreen'),
        };
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 100,
          height: 100,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.redAccent.withValues(alpha: 0.20),
                ),
              ),
              const Icon(
                PhosphorIconsFill.hand,
                size: 56,
                color: Colors.redAccent,
              ),
              SizedBox(
                width: 100,
                height: 100,
                child: CircularProgressIndicator(
                  strokeWidth: 4,
                  color: Colors.redAccent.withValues(alpha: 0.50),
                  backgroundColor: Colors.redAccent.withValues(alpha: 0.20),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Text(
          FlutterI18n.translate(context, 'leveling.wizardKeepHandsClear'),
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.redAccent,
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 20,
              height: 1.4,
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.72),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAlignPlateView(BuildContext context, Color primary) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: primary.withValues(alpha: 0.12),
          ),
          child: Icon(
            PhosphorIcons.compass(),
            size: 52,
            color: primary,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          FlutterI18n.translate(context, 'leveling.wizardAlignTitle'),
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            FlutterI18n.translate(context, 'leveling.wizardAlignInstr'),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 20,
              height: 1.4,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.72),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTightenScrewsView(BuildContext context, Color primary) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: primary.withValues(alpha: 0.12),
          ),
          child: Icon(
            PhosphorIcons.clockClockwise(),
            size: 52,
            color: primary,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          FlutterI18n.translate(context, 'leveling.tightenTitle'),
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            engine.variant?.id == 'pro'
                ? FlutterI18n.translate(
                    context, 'leveling.tightenInstructionPro')
                : FlutterI18n.translate(
                    context, 'leveling.tightenInstructionStandard'),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 20,
              height: 1.4,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.72),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRemovePuckView(BuildContext context, Color primary) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: primary.withValues(alpha: 0.12),
          ),
          child: Icon(
            PhosphorIconsFill.hand,
            size: 52,
            color: primary,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          FlutterI18n.translate(context, 'leveling.wizardRemovePuck'),
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            FlutterI18n.translate(context, 'leveling.wizardRemovePuckInstr'),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 20,
              height: 1.4,
              color: onSurface.withValues(alpha: 0.72),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAllCornersMeasuredView(BuildContext context, Color primary) {
    final theme = Theme.of(context);
    final rawZ = cornerResults.map((r) {
      return r?.measurements?.secondStageTriggerZ;
    }).toList();

    // Front-corner Z values are displayed raw (cantilever compensation disabled).
    final compZ = _compensatedZ(rawZ);
    final validZ = compZ.whereType<double>().toList();
    final minZ = validZ.isEmpty ? 0.0 : validZ.reduce((a, b) => a < b ? a : b);
    final maxZ = validZ.isEmpty ? 0.0 : validZ.reduce((a, b) => a > b ? a : b);
    final deviation = maxZ - minZ;
    final withinTolerance = deviation <= 0.100;
    final statusColor = withinTolerance ? Colors.greenAccent : Colors.redAccent;

    // Use raw values for display (cantilever compensation disabled).
    final dispZ = compZ;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(
              withinTolerance
                  ? PhosphorIconsFill.checkCircle
                  : PhosphorIcons.warning(),
              size: 24,
              color: statusColor,
            ),
            const SizedBox(width: 10),
            Text(
              FlutterI18n.translate(context, 'leveling.wizardCornerResults'),
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: statusColor,
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                color: statusColor.withValues(alpha: 0.15),
              ),
              child: Text(
                withinTolerance
                    ? FlutterI18n.translate(context, 'leveling.wizardPass')
                    : FlutterI18n.translate(context, 'leveling.wizardFail'),
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: statusColor,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        // Corner measurements - fill remaining space
        Expanded(
          child: GlassCard(
            outlined: true,
            margin: EdgeInsets.zero,
            child: Stack(
              children: [
                // Back Left â€” top-left (back of printer, facing away)
                Positioned(
                  top: OrionSpacing.cardPadding.top,
                  left: OrionSpacing.cardPadding.left,
                  child: _cornerValueCard(
                    theme,
                    _cornerLabels[3],
                    dispZ[3],
                    validZ,
                    minZ,
                    maxZ,
                  ),
                ),
                // Back Right â€” top-right
                Positioned(
                  top: OrionSpacing.cardPadding.top,
                  right: OrionSpacing.cardPadding.right,
                  child: _cornerValueCard(
                    theme,
                    _cornerLabels[2],
                    dispZ[2],
                    validZ,
                    minZ,
                    maxZ,
                  ),
                ),
                // Front Right â€” bottom-right (front of printer, facing us)
                Positioned(
                  bottom: OrionSpacing.cardPadding.bottom,
                  right: OrionSpacing.cardPadding.right,
                  child: _cornerValueCard(
                    theme,
                    _cornerLabels[1],
                    dispZ[1],
                    validZ,
                    minZ,
                    maxZ,
                  ),
                ),
                // Front Left â€” bottom-left
                Positioned(
                  bottom: OrionSpacing.cardPadding.bottom,
                  left: OrionSpacing.cardPadding.left,
                  child: _cornerValueCard(
                    theme,
                    _cornerLabels[0],
                    dispZ[0],
                    validZ,
                    minZ,
                    maxZ,
                  ),
                ),
                // Total deviation â€” dead center
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        FlutterI18n.translate(
                            context, 'leveling.wizardTotalDeviation'),
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.5),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            deviation.toStringAsFixed(2),
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: statusColor,
                              height: 1,
                            ),
                          ),
                          Text(
                            FlutterI18n.translate(
                                context, 'leveling.wizardDeviationLimit'),
                            style: TextStyle(
                              fontSize: 14,
                              color: theme.colorScheme.onSurface
                                  .withValues(alpha: 0.4),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: statusColor.withValues(alpha: 0.12),
                        ),
                        child: Text(
                          withinTolerance
                              ? FlutterI18n.translate(
                                  context, 'leveling.wizardWithinTolerance')
                              : FlutterI18n.translate(
                                  context, 'leveling.wizardNeedsAdjust'),
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: statusColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _cornerValueCard(
    ThemeData theme,
    String label,
    double? z,
    List<double> validZ,
    double minZ,
    double maxZ,
  ) {
    final isLowest = validZ.isNotEmpty && z == minZ;
    final isHighest = validZ.isNotEmpty && z == maxZ;
    final dotColor = isLowest
        ? Colors.greenAccent
        : isHighest
            ? Colors.orangeAccent
            : theme.colorScheme.primary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color:
            theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.15),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isHighest)
                Icon(PhosphorIcons.caretDoubleUp(), size: 14, color: dotColor),
              if (isLowest)
                Icon(PhosphorIcons.caretDoubleDown(),
                    size: 14, color: dotColor),
              if (!isHighest && !isLowest)
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: dotColor,
                  ),
                ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            z != null ? '${z.toStringAsFixed(2)} mm' : '--',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: dotColor,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepView(
    BuildContext context,
    ThemeData theme,
    Color primary,
    LevelingWorkflowStep step,
  ) {
    final title =
        step.stepTitle ?? FlutterI18n.translate(context, step.titleKey);
    final instruction = step.stepInstruction ??
        FlutterI18n.translate(context, step.instructionKey);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ====== Icon ======
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: primary.withValues(alpha: 0.10),
          ),
          child: Icon(
            step.icon,
            key: const ValueKey('icon'),
            size: 52,
            color: primary,
          ),
        ),
        const SizedBox(height: 20),
        // ====== Title ======
        Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: primary,
          ),
        ),
        const SizedBox(height: 8),
        // ====== Instruction ======
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Text(
            instruction,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 20,
              height: 1.4,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.72),
            ),
          ),
        ),
      ],
    );
  }
}

// ================================================================================================================================================================================================
// Adjustment Feedback â€” live force gauge
// ================================================================================================================================================================================================

class _AdjustmentFeedbackScreen extends StatefulWidget {
  const _AdjustmentFeedbackScreen({
    super.key,
    required this.cornerIndex,
    this.cornerForce,
    this.targetForce,
    this.allCornerForces = const [],
    this.forceDelta,
    this.needsTighten = false,
    this.needsLoosen = false,
  });

  final int cornerIndex;
  final double? cornerForce;
  final double? targetForce;
  final List<double> allCornerForces;
  final double? forceDelta;
  final bool needsTighten;
  final bool needsLoosen;

  @override
  State<_AdjustmentFeedbackScreen> createState() =>
      _AdjustmentFeedbackScreenState();
}

class _AdjustmentFeedbackScreenState extends State<_AdjustmentFeedbackScreen>
    with TickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final AnimationController _rotationController;
  AnalyticsProvider? _analytics;
  VoidCallback? _analyticsListener;
  bool _analyticsDisposed = false;

  // Live force EMA — everything in gram-force.
  double? _emaForce;
  static const double _emaAlpha = 0.25;
  double? _liveOffset;

  double? get _smoothedForce => _emaForce;

  @override
  void initState() {
    super.initState();
    _emaForce = widget.cornerForce;
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_analytics != null) return;
    _analytics = Provider.of<AnalyticsProvider>(context, listen: false);
    _analyticsListener = () {
      if (_analyticsDisposed) return;
      final series = _analytics!.pressureSeries;
      if (series.isEmpty) return;
      final raw = (series.last['v'] as num?)?.toDouble();
      if (raw == null) return;
      // Capture live-vs-probe offset once.
      if (_liveOffset == null && _emaForce != null && widget.cornerForce != null) {
        _liveOffset = _emaForce! - widget.cornerForce!;
      }
      if (_emaForce == null) {
        _emaForce = raw;
      } else {
        _emaForce = _emaAlpha * raw + (1.0 - _emaAlpha) * _emaForce!;
      }
      setState(() {});
    };
    _analytics!.addListener(_analyticsListener!);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _rotationController.dispose();
    _analyticsDisposed = true;
    if (_analytics != null && _analyticsListener != null) {
      _analytics!.removeListener(_analyticsListener!);
    }
    super.dispose();
  }

  String get _adjustmentTitle {
    if (widget.cornerIndex <= 1) {
      return widget.cornerIndex == 0
          ? FlutterI18n.translate(context, 'leveling.wizardAdjustFL')
          : FlutterI18n.translate(context, 'leveling.wizardAdjustFR');
    }
    return FlutterI18n.translate(context, 'leveling.wizardAdjustRear');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;

    // Live force vs target, both in the live-analytics reference frame.
    // The Jacobian target is shifted by the probe→live offset captured
    // when the first analytics reading arrives after probing.
    //
    // live − target: positive → corner lower than target → TIGHTEN.
    // live − target: negative → corner higher than target → LOOSEN.
    // Live delta: anchor the diagonal-average target into the live
    // force reference frame via the probe→live offset.
    final double? forceDelta;
    if (_smoothedForce != null && widget.targetForce != null) {
      final liveTarget = widget.targetForce! + (_liveOffset ?? 0.0);
      forceDelta = _smoothedForce! - liveTarget;
    } else {
      forceDelta = widget.forceDelta; // fallback to static value
    }

    // Gauge scale: ±2000 gf maps to the full range (~ ±20 N).
    const forceScale = 2000.0;
    final position =
        forceDelta != null ? (forceDelta / forceScale).clamp(-1.0, 1.0) : 0.0;
    // Live direction from actual force delta with ±20 gf green zone.
    // Uses the live force delta so the label, accent, and rotation
    // update in real time as the user tightens or loosens the screw.
    final liveNeedsTighten = forceDelta != null && forceDelta > 20;
    final liveNeedsLoosen = forceDelta != null && forceDelta < -20;
    final directionLabel = liveNeedsTighten
        ? FlutterI18n.translate(context, 'leveling.wizardTighten')
        : liveNeedsLoosen
            ? FlutterI18n.translate(context, 'leveling.wizardLoosen')
            : FlutterI18n.translate(context, 'leveling.wizardAtTarget');
    final bool anyDirection = liveNeedsTighten || liveNeedsLoosen;
    final accent = anyDirection
        ? const Color(0xFFFFC16D)
        : const Color(0xFF57F0A4);
    // Rotation direction: -1 = CCW (loosen), 1 = CW (tighten), 0 = at target
    final rotationDirection = liveNeedsTighten
        ? 1
        : liveNeedsLoosen
            ? -1
            : 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.center,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 18),
            child: Text(
              _adjustmentTitle,
              style: TextStyle(
                color: accent,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 24),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // ====== Left: screw diagram + title ======
                        Expanded(
                          flex: 1,
                          child: Container(
                            height: 240,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 18,
                            ),
                            decoration: BoxDecoration(
                              color: onSurface.withValues(alpha: 0.035),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: onSurface.withValues(alpha: 0.10),
                              ),
                            ),
                            child: Stack(
                              children: [
                                Align(
                                  alignment: Alignment.topCenter,
                                  child: Text(
                                    FlutterI18n.translate(
                                        context, 'leveling.wizardAdjustScrew'),
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 1.2,
                                      color: onSurface.withValues(alpha: 0.45),
                                    ),
                                  ),
                                ),
                                Positioned.fill(
                                  child: Center(
                                    child: Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        Positioned(
                                          left: 0,
                                          right: 0,
                                          top: 13,
                                          bottom: 24,
                                          child: Center(
                                            child: SizedBox(
                                              width: 150,
                                              height: 105,
                                              child: AnimatedBuilder(
                                                animation: _rotationController,
                                                builder: (context, _) =>
                                                    CustomPaint(
                                                  size: const Size(150, 105),
                                                  painter: _TrianglePainter(
                                                    accent: accent,
                                                    onSurface: onSurface,
                                                    fillBack:
                                                        widget.cornerIndex >= 2,
                                                    fillFl:
                                                        widget.cornerIndex == 0,
                                                    fillFr:
                                                        widget.cornerIndex == 1,
                                                    pulse:
                                                        _pulseController.value,
                                                    rotationValue:
                                                        _rotationController
                                                            .value,
                                                    rotationDirection:
                                                        rotationDirection,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                        Align(
                                          alignment: Alignment.bottomCenter,
                                          child: Text(
                                            directionLabel,
                                            style: TextStyle(
                                              color: accent,
                                              fontSize: 20,
                                              fontWeight: FontWeight.w900,
                                              letterSpacing: 0.8,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 24),
                        // ====== Right: force readout + gauge ======
                        Expanded(
                          flex: 1,
                          child: Container(
                            height: 240,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 18,
                            ),
                            decoration: BoxDecoration(
                              color: onSurface.withValues(alpha: 0.035),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: onSurface.withValues(alpha: 0.10),
                              ),
                            ),
                            child: Stack(
                              children: [
                                Align(
                                  alignment: Alignment.topCenter,
                                  child: Text(
                                    FlutterI18n.translate(
                                        context, 'leveling.wizardZDeviation'),
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 1.2,
                                      color: onSurface.withValues(alpha: 0.45),
                                    ),
                                  ),
                                ),
                                Positioned.fill(
                                  child: Center(
                                    child: Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        // Force value
                                        Positioned(
                                          left: 0,
                                          right: 0,
                                          top: 13,
                                          bottom: 47,
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              SizedBox(
                                                width: 220,
                                                child: Text(
                                                  forceDelta != null
                                                      ? forceDelta
                                                          .toStringAsFixed(3)
                                                      : '--',
                                                  textAlign: TextAlign.right,
                                                  style: TextStyle(
                                                    fontSize: 38,
                                                    fontWeight: FontWeight.w800,
                                                    fontFeatures: const [
                                                      FontFeature
                                                          .tabularFigures(),
                                                    ],
                                                    height: 1,
                                                    color: accent,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 7),
                                              Text(
                                                'gf',
                                                style: TextStyle(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.w600,
                                                  color: accent,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        // Gauge
                                        Align(
                                          alignment: Alignment.bottomCenter,
                                          child: ConstrainedBox(
                                            constraints: const BoxConstraints(
                                              maxWidth: 260,
                                            ),
                                            child: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                SizedBox(
                                                  height: 28,
                                                  child: LayoutBuilder(
                                                    builder: (_, trackBox) {
                                                      final w =
                                                          trackBox.maxWidth;
                                                      // Dot moves toward the direction to turn:
                                                      // right → tighten (CW), left → loosen (CCW).
                                                      // position > 0 → tighten → dot goes right
                                                      // position < 0 → loosen → dot goes left
                                                      final dotFrac =
                                                          ((1.0 + position) / 2.0)
                                                              .clamp(0.0, 1.0);
                                                      final centerX = w / 2;
                                                      final dotCenter =
                                                          dotFrac * w;
                                                      final fillLeft =
                                                          dotCenter < centerX
                                                              ? dotCenter
                                                              : centerX;
                                                      final fillWidth =
                                                          (dotCenter - centerX)
                                                              .abs();
                                                      return Stack(
                                                        clipBehavior: Clip.none,
                                                        children: [
                                                          ClipRRect(
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        14),
                                                            child: Container(
                                                              color: onSurface
                                                                  .withValues(
                                                                      alpha:
                                                                          0.08),
                                                            ),
                                                          ),
                                                          Positioned(
                                                            left: centerX - 1,
                                                            top: 0,
                                                            bottom: 0,
                                                            child: Container(
                                                              width: 2,
                                                              color: onSurface
                                                                  .withValues(
                                                                      alpha:
                                                                          0.15),
                                                            ),
                                                          ),
                                                          if (fillWidth > 0)
                                                            Positioned(
                                                              left: fillLeft,
                                                              top: 0,
                                                              bottom: 0,
                                                              width: fillWidth,
                                                              child: ClipRRect(
                                                                borderRadius:
                                                                    BorderRadius
                                                                        .circular(
                                                                            14),
                                                                child:
                                                                    Container(
                                                                  color: accent
                                                                      .withValues(
                                                                          alpha:
                                                                              0.50),
                                                                ),
                                                              ),
                                                            ),
                                                          Positioned(
                                                            left:
                                                                dotCenter - 14,
                                                            top: 0,
                                                            child: Container(
                                                              width: 28,
                                                              height: 28,
                                                              decoration:
                                                                  BoxDecoration(
                                                                shape: BoxShape
                                                                    .circle,
                                                                color: accent,
                                                                border: Border.all(
                                                                    color: Colors
                                                                        .white,
                                                                    width: 3),
                                                                boxShadow: [
                                                                  BoxShadow(
                                                                    color: accent
                                                                        .withValues(
                                                                            alpha:
                                                                                0.35),
                                                                    blurRadius:
                                                                        6,
                                                                  ),
                                                                ],
                                                              ),
                                                            ),
                                                          ),
                                                        ],
                                                      );
                                                    },
                                                  ),
                                                ),
                                                const SizedBox(height: 6),
                                                Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment
                                                          .spaceBetween,
                                                  children: [
                                                    Text(
                                                      FlutterI18n.translate(
                                                          context,
                                                          'leveling.wizardLooser'),
                                                      style: TextStyle(
                                                          fontSize: 11,
                                                          fontWeight:
                                                              FontWeight.w500,
                                                          color: onSurface
                                                              .withValues(
                                                                  alpha: 0.3)),
                                                    ),
                                                    Text(
                                                      FlutterI18n.translate(
                                                          context,
                                                          'leveling.wizardTighter'),
                                                      style: TextStyle(
                                                          fontSize: 11,
                                                          fontWeight:
                                                              FontWeight.w500,
                                                          color: onSurface
                                                              .withValues(
                                                                  alpha: 0.3)),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ================================================================================================================================================================================================
// Equilateral Screw Triangle
// ================================================================================================================================================================================================

class _TrianglePainter extends CustomPainter {
  _TrianglePainter({
    required this.accent,
    required this.onSurface,
    required this.fillBack,
    required this.fillFl,
    required this.fillFr,
    this.pulse = 0.0,
    this.rotationValue = 0.0,
    this.rotationDirection = 0,
  });

  final Color accent;
  final Color onSurface;
  final bool fillBack;
  final bool fillFl;
  final bool fillFr;
  final double pulse;
  final double rotationValue;
  final int rotationDirection;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    // Equilateral triangle arrangement (just the dots, no lines).
    const spacing = 62.0;
    final triH = spacing * 0.866; // spacing * sqrt(3)/2

    final backX = cx;
    final backY = cy - triH / 2;
    final flX = cx - spacing / 2;
    final flY = cy + triH / 2;
    final frX = cx + spacing / 2;
    final frY = cy + triH / 2;

    const r = 13.0;
    _drawDot(canvas, backX, backY, r, fillBack);
    _drawDot(canvas, flX, flY, r, fillFl);
    _drawDot(canvas, frX, frY, r, fillFr);

    // Rotating arc around the highlighted dot
    if (fillFl || fillFr || fillBack) {
      final dotX = fillBack ? backX : (fillFl ? flX : frX);
      final dotY = fillBack ? backY : (fillFl ? flY : frY);
      _drawRotatingArc(canvas, dotX, dotY, r + 10);
    }
  }

  void _drawRotatingArc(Canvas canvas, double cx, double cy, double radius) {
    final arcPaint = Paint()
      ..color = accent.withValues(alpha: 0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    // Continuously rotate: CW for tighten (direction=1), CCW for loosen (direction=-1)
    final angle = rotationValue * 2 * 3.14159265 * rotationDirection;
    const arcSpan = 3.0;

    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: radius),
      angle - arcSpan / 2,
      arcSpan,
      false,
      arcPaint,
    );

    // Bold dot at the leading tip (opposite end for CCW)
    final tipAngle =
        angle + (rotationDirection >= 0 ? arcSpan / 2 : -arcSpan / 2);
    final tipX = cx + radius * cos(tipAngle);
    final tipY = cy + radius * sin(tipAngle);

    canvas.drawCircle(
        Offset(tipX, tipY),
        4.0,
        Paint()
          ..color = accent.withValues(alpha: 0.9)
          ..style = PaintingStyle.fill);
  }

  void _drawDot(Canvas canvas, double cx, double cy, double r, bool filled) {
    final paint = Paint()
      ..style = filled ? PaintingStyle.fill : PaintingStyle.stroke
      ..strokeWidth = 2.5;
    if (filled) {
      // Pulse opacity: 0.5 \u2192 1.0 \u2192 0.5
      paint.color = accent.withValues(alpha: 0.5 + pulse * 0.5);
      // Bump radius so filled dot visually matches the outlined one
      canvas.drawCircle(Offset(cx, cy), r + 1.5, paint);
    } else {
      paint.color = accent;
      canvas.drawCircle(Offset(cx, cy), r, paint);
    }
  }

  @override
  bool shouldRepaint(_TrianglePainter oldDelegate) =>
      oldDelegate.fillBack != fillBack ||
      oldDelegate.fillFl != fillFl ||
      oldDelegate.fillFr != fillFr ||
      oldDelegate.pulse != pulse ||
      oldDelegate.rotationValue != rotationValue ||
      oldDelegate.rotationDirection != rotationDirection;
}

// ================================================================================================================================================================================================
// Completion Pane (calibration-overlay style)
// ================================================================================================================================================================================================

class _CompletionPane extends StatelessWidget {
  const _CompletionPane({required this.engine});

  final LevelingWorkflowEngine engine;

  @override
  Widget build(BuildContext context) {
    final variant = engine.variant;
    final theme = Theme.of(context);

    return Center(
      key: const ValueKey('complete'),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.green.withValues(alpha: 0.15),
            ),
            child: const Icon(
              PhosphorIconsFill.checkCircle,
              size: 56,
              color: Colors.greenAccent,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            FlutterI18n.translate(context, 'levelingWorkflow.complete'),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: Colors.greenAccent,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              FlutterI18n.translate(
                context,
                variant?.successKey ?? 'levelingWorkflow.offsetSuccess',
              ),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 17,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.72),
                height: 1.35,
              ),
            ),
          ),
          if (engine.zOffsetApplied != null) ...[
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 14,
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: Colors.green.withValues(alpha: 0.10),
                border: Border.all(
                  color: Colors.greenAccent.withValues(alpha: 0.35),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    PhosphorIcons.ruler(),
                    size: 20,
                    color: Colors.greenAccent,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    FlutterI18n.translate(
                      context,
                      'levelingWorkflow.appliedOffset',
                    ),
                    style: TextStyle(
                      fontSize: 15,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '${engine.zOffsetApplied!.toStringAsFixed(2)} mm',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.greenAccent,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

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
import 'package:orion/tools/athena/screw_calibration_store.dart';
import 'package:orion/tools/athena/screw_controller.dart';
import 'package:orion/tools/athena/leveling_configs.dart';
import 'package:orion/tools/athena/leveling_log_entry.dart';
import 'package:orion/tools/athena/leveling_log_service.dart';
import 'package:orion/tools/athena/leveling_workflow_engine.dart';
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
  intro,
  preparing,
  puckPlacement,
  probing,
  feedback,
  belowResolution,
}

/// A screw command anchored into the gauge's force frame: the
/// controller's command plus the re-probed corner force it was anchored
/// to and the resulting absolute force target shown to the user.
class _PendingScrewCommand {
  const _PendingScrewCommand(
    this.cmd, {
    required this.anchorForceGf,
    required this.targetForceGf,
  });

  final ScrewCommand cmd;
  final double anchorForceGf;
  final double targetForceGf;
}

class Athena2LevelingWizard extends StatefulWidget {
  const Athena2LevelingWizard({
    super.key,
    required this.config,
    this.recheck = false,
  });

  final LevelingConfig config;
  final bool recheck;

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

  // Adaptive force→Z coupling, one controller per physical screw
  // (0=FL, 1=FR, 2=shared back).  Coupling is a property of each
  // screw's lever geometry and must not cross-mix.  Each controller
  // snapshots its commanded force delta so the recheck can measure
  // what was actually achieved.  See ScrewController for the sign
  // conventions and the estimator design.
  //
  // Baseline seeds are field-derived: the first instrumented printer
  // measured back −1.37e-4 / fronts −2.0e-4, with ~1.5× sensitivity
  // margin so a softer unit undershoots one cycle rather than
  // oscillating.  The per-machine calibration file and/or the first
  // measured sample replace these outright.
  static const double _frontBaselineSeed = -3.0e-4;
  static const double _backBaselineSeed = -2.0e-4;

  static Map<int, ScrewController> _freshControllers() => {
        0: ScrewController(seedCouplingMmPerGf: _frontBaselineSeed),
        1: ScrewController(seedCouplingMmPerGf: _frontBaselineSeed),
        2: ScrewController(
          seedCouplingMmPerGf: _backBaselineSeed,
          targetBiasMm: ScrewController.backLeapfrogBiasMm,
        ),
      };

  Map<int, ScrewController> _screwControllers = _freshControllers();
  int? _lastAdjustedCorner;
  int? _puckPlacedCorner; // corner that still has the puck from adjustment
  bool _adjustmentIntroShown = false;
  _PendingScrewCommand? _pendingCommand;
  double? _lastAchievedForceGf; // what the live gauge read when the user stopped
  double? _preAdjustmentDeviation; // snapshot before adjustment for divergence detection
  int _consecutiveBackAdjustments = 0; // detect maxed-out back screw

  // Persisted per-screw coupling calibration — coupling is a physical
  // property of the plate, so sessions start from the previous
  // session's measurements instead of the generic seed.
  final ScrewCalibrationStore _calibrationStore = ScrewCalibrationStore();
  static const _screwStoreKeys = {0: 'fl', 1: 'fr', 2: 'back'};

  /// Seed the (fresh) controllers from the stored calibration.
  Future<void> _loadScrewCalibration() async {
    final stored = await _calibrationStore.load();
    if (!mounted) return;
    for (final entry in _screwStoreKeys.entries) {
      final coupling = stored[entry.value];
      if (coupling != null) {
        _screwControllers[entry.key]!.adoptSeed(coupling);
      }
    }
  }

  /// The controller for the screw that drives [cornerIndex]
  /// (both back corners share one screw).  Cross-seeds an unmeasured
  /// controller from a sibling with a measured coupling — the screws
  /// on one plate share similar geometry, and this saves the
  /// half-effective relearning cycle each screw otherwise pays on its
  /// first adjustment (session 27e976fe: FR and FL first commands
  /// moved only 46% / 35% of target from the generic seed while the
  /// back screw already knew the plate's coupling).
  ScrewController _controllerForCorner(int cornerIndex) {
    final controller = _screwControllers[cornerIndex >= 2 ? 2 : cornerIndex]!;
    if (!controller.hasMeasuredSample) {
      for (final sibling in _screwControllers.values) {
        if (sibling.hasMeasuredSample) {
          controller.adoptSeed(sibling.coupling);
          break;
        }
      }
    }
    return controller;
  }

  // Prediction summary — shown to the user before they turn the screw
  String? _predictionDirection; // e.g. "Tighten"
  String? _predictionScrew; // e.g. "Back Screw"
  double? _predictionZMm; // expected Z change magnitude
  int? _predictionRechecks; // estimated rechecks remaining to pass

  // Corner measurements from probe steps.
  // Indexed by cornerLabel, not probe order — slots are:
  // 0=Front Left, 1=Front Right, 2=Back Right, 3=Back Left.
  final List<ForceLevelingWorkflowResponse?> _cornerResults =
      List.filled(4, null);

  // Per-corner Z samples keyed by the step id that produced them.
  // Keying by step id keeps retries idempotent, and [_cornerZ]
  // averages the values — so a future multi-probe check is a
  // config-only change.
  final List<Map<String, double>> _cornerZByStep =
      List.generate(4, (_) => <String, double>{});

  /// Averaged probed Z for a corner (mm), or null if never probed.
  double? _cornerZ(int i) {
    final samples = _cornerZByStep[i].values;
    if (samples.isEmpty) {
      return _cornerResults[i]?.measurements?.secondStageTriggerZ;
    }
    return samples.reduce((a, b) => a + b) / samples.length;
  }

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

    if (widget.recheck) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _startRecheckMode();
      });
    }
  }

  void _startRecheckMode() {
    // Auto-select the Pro variant, skip loosen/tighten screens, but
    // still show the pre-flight checklist before probing begins.
    final proVariant = widget.config.variants.firstWhere(
      (v) => v.id == 'pro',
      orElse: () => widget.config.variants.first,
    );
    _engine.selectVariant(proVariant);
    _loosenScrewsDone = true;
    _alignDone = true;
    _levelingSessionId = _uuid4();
    _recheckNumber = 0;
    _probeConfigCaptured = false;
    _screwControllers = _freshControllers();
    _pendingCommand = null;
    _lastAchievedForceGf = null;
    _lastAdjustedCorner = null;
    _resetCornerResults();
    _loadScrewCalibration();

    // Start at pre-flight so the user sees the safety checklist first.
    setState(() {
      _phase = _WizardPhase.introAndChecklist;
      _preFlightIndex = 0;
    });
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
            // Record the corner's Z sample keyed by step id (a retried
            // step overwrites its own sample instead of duplicating it).
            final z = _engine.lastResponse!.measurements?.secondStageTriggerZ;
            if (z != null) {
              _cornerZByStep[idx][step.id] = z;
            }
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
          // Puck is at the last probed corner (BL, index 3) after a full sweep.
          _puckPlacedCorner = 3;
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

    // ── Puck-location skip ──
    // If the puck is already at this corner from a prior adjustment,
    // auto-advance past the placement screen straight to probing.
    if (_puckPlacedCorner != null &&
        _engine.status == LevelingWorkflowStatus.stepComplete) {
      final step = _engine.currentStep;
      if (step != null &&
          step.kind == LevelingWorkflowStepKind.prepare &&
          step.id.startsWith('fine_prepare_')) {
        final cornerNum =
            int.tryParse(step.id.replaceFirst('fine_prepare_', '')) ?? 0;
        final cornerIndex = cornerNum - 1; // fine_prepare_1 → corner 0
        if (cornerIndex == _puckPlacedCorner) {
          _puckPlacedCorner = null; // only skip once
          _engine.advanceAfterSuccessfulStep();
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _engine.canRunCurrentStep) {
              _engine.runCurrentStep();
            }
          });
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
      _cornerZByStep[i].clear();
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

  /// The four averaged corner Z values in corner order (0=FL, 1=FR,
  /// 2=BR, 3=BL), for [_compensatedCorners].
  List<double?> get _rawCornerZs =>
      [_cornerZ(0), _cornerZ(1), _cornerZ(2), _cornerZ(3)];

  double get _cornerDeviation {
    final zValues = _compensatedCorners(_rawCornerZs);
    if (zValues.isEmpty) return 0.0;
    final min = zValues.reduce((a, b) => a < b ? a : b);
    final max = zValues.reduce((a, b) => a > b ? a : b);
    return max - min;
  }

  bool get _isCornerCheckPassed => _cornerDeviation <= 0.100;
  bool get _isBorderline =>
      _cornerDeviation > 0.100 && _cornerDeviation <= 0.200;

  Future<void> _skipAdjustment() async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => GlassAlertDialog(
        title: Row(
          children: [
            Icon(PhosphorIcons.warning(),
                size: 26, color: Colors.orangeAccent),
            const SizedBox(width: 14),
            Text(
              FlutterI18n.translate(
                  context, 'leveling.wizardSkipTitle'),
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.orangeAccent,
              ),
            ),
          ],
        ),
        content: Text(
          FlutterI18n.translate(
              context, 'leveling.wizardSkipMsg'),
          style: const TextStyle(
              fontSize: 17, fontWeight: FontWeight.w500),
        ),
        actions: [
          GlassButton(
            tint: GlassButtonTint.neutral,
            onPressed: () => Navigator.of(ctx).pop(false),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(0, 55),
            ),
            child: Text(FlutterI18n.translate(
                context, 'leveling.cancel')),
          ),
          GlassButton(
            tint: GlassButtonTint.warn,
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(0, 55),
            ),
            child: Text(FlutterI18n.translate(
                context, 'leveling.wizardSkip')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    // Jump to final offset calibration, skipping remove-puck and
    // final_prepare — same as the PASS flow.
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
  }

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
    final zValues = _compensatedCorners(_rawCornerZs);
    if (zValues.length < 4) return;

    // Legacy leapfrog pick order (see rankAdjustmentCandidates):
    // front-back tilt → back screw (worst outlier), else the lower
    // corner of the worst diagonal.  Take the first candidate whose
    // command is an executable TIGHTEN: at least the 150 gf execution
    // floor (below it the ±20 gf green zone plus live-force noise make
    // a human turn uncontrolled — field session f2c9f74d recheck #2),
    // and never a loosen (preload policy).
    int? probeCorner;
    for (final corner in rankAdjustmentCandidates(zValues)) {
      final cmd = _controllerForCorner(corner)
          .command(zGapMm: adjustmentGapMm(corner, zValues));
      if (cmd.forceDeltaGf <= -ScrewController.minCommandDeltaGf) {
        probeCorner = corner;
        break;
      }
    }

    if (probeCorner == null) {
      // Every candidate is below the execution floor: the remaining
      // deviation is within measurement/adjustment resolution.  Don't
      // send the user to a screw — offer a recheck instead.
      _adjustingCornerIndex = null;
      _adjustmentError = null;
      _adjustmentBusy = false;
      // No adjustment will happen, so the next recheck must not run
      // divergence detection against a stale baseline.
      _preAdjustmentDeviation = null;
      setState(() {
        _phase = _WizardPhase.adjustment;
        _adjustmentStep = _AdjustmentStep.belowResolution;
      });
      return;
    }

    _adjustingCornerIndex = probeCorner;
    _adjustmentError = null;
    _preAdjustmentDeviation = _cornerDeviation;

    // Track consecutive back-screw picks to detect mechanical limits.
    if (probeCorner >= 2) {
      _consecutiveBackAdjustments++;
    } else {
      _consecutiveBackAdjustments = 0;
    }

    if (!_adjustmentIntroShown) {
      _adjustmentIntroShown = true;
      setState(() {
        _phase = _WizardPhase.adjustment;
        _adjustmentStep = _AdjustmentStep.intro;
      });
      return;
    }

    _adjustmentBusy = true;
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
    // If the puck is already at this corner from the last probe, skip the
    // placement screen and go straight to probing.
    if (_puckPlacedCorner == _adjustingCornerIndex) {
      _puckPlacedCorner = null;
      _adjustmentStep = _AdjustmentStep.probing;
      if (mounted) setState(() {});
      _runAdjustmentProbe();
      return;
    }
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

      final probedIdx = _adjustingCornerIndex!;
      // The re-probe supersedes this corner's check sample.
      _cornerZByStep[probedIdx].clear();
      final z = response.measurements?.secondStageTriggerZ;
      if (z != null) _cornerZByStep[probedIdx]['adjust_probe'] = z;
      _cornerResults[probedIdx] = response;
    } catch (e) {
      _adjustmentError = e.toString();
      _adjustmentBusy = false;
      if (mounted) setState(() {});
      return;
    }

    // ── Compute the screw command once, anchored to this re-probe ──
    // Done here (not in build) so the target is deterministic across
    // rebuilds and the gauge, the command, and the coupling estimator
    // all share the same force reference frame.
    final idx = _adjustingCornerIndex!;
    _pendingCommand = null;
    _lastAchievedForceGf = null; // fresh adjustment → fresh gauge snapshot
    {
      final zValues = _compensatedCorners(_rawCornerZs);
      final anchorForce =
          _cornerResults[idx]?.measurements?.firstStagePeakForce;
      if (zValues.length >= 4 && anchorForce != null) {
        // Positive gap → adjusted corner too low → tighten.  The
        // adjusted corner's Z comes from the fresh re-probe (its
        // sample was just replaced); the reference corners keep
        // their corner-check values.
        final zGapMm = adjustmentGapMm(idx, zValues);
        final controller = _controllerForCorner(idx);
        final cmd = controller.command(zGapMm: zGapMm);
        // The re-probe may have shrunk the gap below the execution
        // floor — or flipped its sign, which under the tighten-only
        // policy must never turn into a loosen command.
        if (cmd.forceDeltaGf > -ScrewController.minCommandDeltaGf) {
          _adjustmentBusy = false;
          _adjustmentStep = _AdjustmentStep.belowResolution;
          // No adjustment will happen — see _enterAdjustmentMode.
          _preAdjustmentDeviation = null;
          if (mounted) setState(() {});
          return;
        }
        controller.recordCommand(cmd);
        _lastAdjustedCorner = idx;
        _pendingCommand = _PendingScrewCommand(
          cmd,
          anchorForceGf: anchorForce,
          targetForceGf: anchorForce + cmd.forceDeltaGf,
        );
      }
    }

    _adjustmentBusy = false;
    _adjustmentStep = _AdjustmentStep.feedback;
    if (mounted) setState(() {});
  }

  void _logCornerCheck() {
    if (_levelingSessionId == null) return;

    // ── Update the adaptive coupling estimate from the recheck ──
    // Routed to the controller of whichever screw was adjusted; if no
    // adjustment preceded this check there is no pending command and
    // nothing updates.
    CouplingUpdateResult? update;
    ScrewController? adjusted;
    if (_lastAdjustedCorner != null) {
      adjusted = _controllerForCorner(_lastAdjustedCorner!);
      final zValues = _compensatedCorners(_rawCornerZs);
      if (zValues.length >= 4) {
        // Give the estimator the force delta the user ACTUALLY applied
        // (live gauge reading minus the anchor) so a user who ignores
        // the gauge cannot corrupt the learned coupling; null when no
        // live reading was captured (falls back to the commanded
        // delta).
        final anchor = _pendingCommand?.anchorForceGf;
        final achieved = _lastAchievedForceGf;
        final achievedDelta =
            (anchor != null && achieved != null) ? achieved - anchor : null;
        update = adjusted.onRecheck(
          newGapMm: adjustmentGapMm(_lastAdjustedCorner!, zValues),
          achievedDeltaGf: achievedDelta,
        );
      } else {
        // Missing data — never let a stale command pair with a later,
        // unrelated recheck.
        adjusted.abandonPending();
      }
    }
    // Snapshot before clearing the per-adjustment state.
    final savedAdjustedCorner = _lastAdjustedCorner;
    final targetForceGf = _pendingCommand?.targetForceGf;
    final anchorForceGf = _pendingCommand?.anchorForceGf;
    final achievedGf = _lastAchievedForceGf;
    final telemetrySource = adjusted ?? _controllerForCorner(2);
    _lastAdjustedCorner = null;
    _lastAchievedForceGf = null;
    _pendingCommand = null;

    // Persist the updated coupling — a physical plate property that
    // survives session restarts — so the next session starts
    // calibrated instead of relearning from the seed.
    if (update?.accepted == true && savedAdjustedCorner != null) {
      final storeKey =
          _screwStoreKeys[savedAdjustedCorner >= 2 ? 2 : savedAdjustedCorner];
      if (storeKey != null) {
        // Best-effort — the coupling is saved again on the next
        // accepted sample.
        _calibrationStore.save(storeKey, adjusted!.coupling);
      }
    }

    // Which screw the telemetry below refers to.  Fall back to the
    // back controller for checks with no preceding adjustment.
    final screwLabels = ['FL', 'FR', 'BACK', 'BACK'];
    final adjustedScrew =
        savedAdjustedCorner != null ? screwLabels[savedAdjustedCorner] : null;

    final variant = _engine.variant?.id ?? 'unknown';
    final cornerLabels = ['FL', 'FR', 'BR', 'BL'];
    final corners = <String, CornerLogData>{};
    for (int i = 0; i < 4; i++) {
      final m = _cornerResults[i]?.measurements;
      // finalZ comes from the sample accumulator — the value the
      // wizard actually leveled with.
      corners[cornerLabels[i]] = CornerLogData(
        finalZ: _cornerZ(i),
        firstStagePeakForce: m?.firstStagePeakForce,
        secondStagePeakForce: m?.secondStagePeakForce,
        firstStageOvershoot: m?.firstStageOvershoot,
        secondStageOvershoot: m?.secondStageOvershoot,
      );
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
      estimatedCoupling: telemetrySource.coupling,
      couplingIsSeed: !telemetrySource.hasMeasuredSample,
      preAdjustmentDeviation: _preAdjustmentDeviation,
      adjustedScrew: adjustedScrew,
      commandedDeltaGf: update?.commandedDeltaGf,
      gapAtCommandMm: update?.gapAtCommandMm,
      measuredGapMoveMm: update?.measuredGapMoveMm,
      couplingSample: update?.sample,
      sampleOutcome: update?.outcome.name,
      stictionEscalations: telemetrySource.stictionEscalations,
      anchorForceGf: anchorForceGf,
      targetForceGf: targetForceGf,
      achievedForceGf: achievedGf,
    );
    LevelingLogService.logCornerCheck(entry);
  }

  void _runRecheckCorners() {
    _recheckNumber++;
    _resetCornerResults();
    _probeConfigCaptured = false;
    // If the user just adjusted a screw, the puck is still at that corner.
    // Skip the "place puck" prompt for the first corner of the re-check.
    _puckPlacedCorner = _lastAdjustedCorner;
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
      // All pre-flight steps done → start workflow
      setState(() {
        _phase = _WizardPhase.workflow;
        _preFlightIndex = -1;
      });
      // In recheck mode, skip the initial probe_prepare / probe_screen
      // (Stage 1) and jump straight to corner probing.  Home first so
      // the machine knows its position before moving to the corners.
      if (widget.recheck) {
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          if (!mounted) return;
          final manual =
              Provider.of<ManualProvider>(context, listen: false);
          await manual.manualHome();
          if (!mounted) return;
          _engine.jumpToFirstStepId('fine_prepare_');
          if (_engine.canRunCurrentStep) {
            _engine.runCurrentStep();
          }
        });
        return; // skip the non-recheck auto-run below
      }
      // Auto-run the current step
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

    final showAppBar = _phase == _WizardPhase.adjustment &&
        _adjustmentStep == _AdjustmentStep.intro;

    return GlassApp(
      child: Scaffold(
        backgroundColor: isGlass
            ? Colors.transparent
            : Theme.of(context).colorScheme.surface,
        appBar: showAppBar
            ? AppBar(
                backgroundColor: isGlass
                    ? Colors.transparent
                    : Theme.of(context).colorScheme.surface,
                elevation: 0,
                automaticallyImplyLeading: false,
                centerTitle: true,
                title: Text(
                  FlutterI18n.translate(
                      context, 'leveling.adjustmentIntroTitle'),
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                    color: primary,
                  ),
                ),
              )
            : null,
        body: SafeArea(
          child: Padding(
            padding: OrionSpacing.screenPaddingWithBottomNav,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
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
                _buildActions(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPhaseContent(BuildContext context, Color primary) {
    switch (_phase) {
      case _WizardPhase.variant:
        return Column(
          key: const ValueKey('variant-phase'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  PhosphorIcon(PhosphorIcons.magicWand(), color: primary),
                  const SizedBox(width: 8),
                  Text(
                    FlutterI18n.translate(context, 'leveling.assisted'),
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                      color: primary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: OrionSpacing.listGap),
            Expanded(child: _buildPhaseBody(context)),
          ],
        );
      case _WizardPhase.adjustment:
        return _buildAdjustmentPhase(context, primary);
      default:
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
            // Fresh coupling state — the estimates are per-printer
            // properties but must not leak across re-selected sessions.
            _screwControllers = _freshControllers();
            _pendingCommand = null;
            _lastAchievedForceGf = null;
            _lastAdjustedCorner = null;
            // Pre-seed the fresh controllers from the persisted
            // per-screw calibration (fire-and-forget; adjustments
            // happen much later in the flow).
            _loadScrewCalibration();
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
          cornerZs: _rawCornerZs,
          preAdjustmentDeviation: _preAdjustmentDeviation,
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
      // Pre-flight step: (Back or Cancel) | Next/Done
      final isLast = _preFlightIndex >= widget.config.checklistKeys.length - 1;
      final isFirstRecheck = widget.recheck && _preFlightIndex == 0;
      return Row(
        children: [
          Expanded(
            child: GlassButton(
              tint: isFirstRecheck
                  ? GlassButtonTint.negative
                  : GlassButtonTint.neutral,
              onPressed: isFirstRecheck ? _cancelLeveling : _goBack,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 65),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    isFirstRecheck
                        ? PhosphorIcons.x()
                        : PhosphorIcons.arrowLeft(),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isFirstRecheck
                        ? FlutterI18n.translate(context, 'leveling.cancel')
                        : FlutterI18n.translate(context, 'common.back'),
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
            onPressed: () => widget.recheck
                ? Navigator.of(context).pop()
                : Navigator.of(context).popUntil((route) => route.isFirst),
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
    final bool canSkip = isAllCornersMeasured && _isBorderline;
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
        if (canSkip) ...[
          const SizedBox(width: OrionSpacing.controlGap),
          Expanded(
            child: GlassButton(
              tint: GlassButtonTint.neutral,
              onPressed: _skipAdjustment,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 65),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(PhosphorIcons.fastForward(), size: 20),
                  const SizedBox(width: 8),
                  Text(
                    FlutterI18n.translate(context, 'leveling.wizardSkip'),
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ),
        ],
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
      Navigator.of(context).pop();
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

    // Adjustment intro: single "Start" button
    if (_adjustmentStep == _AdjustmentStep.intro) {
      return Center(
        child: SizedBox(
          width: 320,
          child: GlassButton(
            tint: GlassButtonTint.positive,
            onPressed: () {
              setState(() => _adjustmentStep = _AdjustmentStep.preparing);
              _runAdjustmentPrepare();
            },
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 65),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(PhosphorIcons.arrowRight(), size: 20),
                const SizedBox(width: 8),
                Text(
                  FlutterI18n.translate(context, 'leveling.startLeveling'),
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
    // Below-resolution has no adjusting corner — handle it before the
    // corner guard.
    if (_adjustmentStep == _AdjustmentStep.belowResolution) {
      return _buildBelowResolutionView(context, primary);
    }
    if (_adjustingCornerIndex == null) {
      return const SizedBox.shrink();
    }

    switch (_adjustmentStep) {
      case _AdjustmentStep.intro:
        return _buildAdjustmentIntroView(context, primary);
      case _AdjustmentStep.preparing:
      case _AdjustmentStep.probing:
        return _buildAdjustmentWarning(context, primary);
      case _AdjustmentStep.puckPlacement:
        return _buildPuckPlacementView(context, primary);
      case _AdjustmentStep.belowResolution:
        return _buildBelowResolutionView(context, primary);
      case _AdjustmentStep.feedback:
        // Corner indexing: 0=FL, 1=FR, 2=BR, 3=BL
        // The gauge target is anchored to the adjusted corner's
        // re-probed first-stage peak force plus the controller's
        // commanded delta (see _runAdjustmentProbe).
        final allForces = _cornerResults
            .map((r) => r?.measurements?.firstStagePeakForce)
            .toList();
        final idx = _adjustingCornerIndex!;

        if (allForces.length < 4 ||
            allForces[0] == null || allForces[1] == null ||
            allForces[2] == null || allForces[3] == null) {
          return const SizedBox.shrink();
        }

        // ── Unified screw command (front and back) ──
        // The command was computed once when the re-probe completed
        // (see _runAdjustmentProbe) and is only rendered here, so
        // rebuilds can't shift the target.  Direction comes from the
        // Z gap, magnitude from the per-screw learned coupling —
        // never from raw force differences, whose ±300–500 gf noise
        // can point the gauge the wrong way (e.g. session b9ef2b8f
        // recheck #1: FR's force sat ABOVE its diagonal reference
        // even though FR was the highest corner).
        if (_pendingCommand == null) {
          return const SizedBox.shrink();
        }
        final double targetForce = _pendingCommand!.targetForceGf;

        final double cornerForce = allForces[idx]!;
        final double forceDeltaGf = cornerForce - targetForce;
        // Positive → corner more compressed than reference → TIGHTEN.
        // Negative → corner less compressed than reference → LOOSEN.
        final bool needsTighten = forceDeltaGf > 20;
        final bool needsLoosen = forceDeltaGf < -20;

        // ── Prediction summary ──
        // Compute what the user should expect from this adjustment so
        // they can see whether they're on track.
        {
          final screwNames = [
            FlutterI18n.translate(context, 'leveling.wizardScrewFL'),
            FlutterI18n.translate(context, 'leveling.wizardScrewFR'),
            FlutterI18n.translate(context, 'leveling.wizardScrewBack'),
            FlutterI18n.translate(context, 'leveling.wizardScrewBack'),
          ];
          _predictionScrew = screwNames[idx];
          _predictionDirection = needsTighten
              ? FlutterI18n.translate(context, 'leveling.wizardTighten')
              : needsLoosen
                  ? FlutterI18n.translate(context, 'leveling.wizardLoosen')
                  : FlutterI18n.translate(context, 'leveling.wizardAtTarget');

          // The command carries its own damped target and a
          // clamp-aware recheck estimate.
          _predictionZMm = _pendingCommand!.cmd.targetZMm.abs();
          _predictionRechecks = _pendingCommand!.cmd.predictedRechecks;
        }

        return _AdjustmentFeedbackScreen(
          key: const ValueKey('adjustment-feedback'),
          cornerIndex: _adjustingCornerIndex!,
          cornerForce: cornerForce,
          targetForce: targetForce,
          allCornerForces: allForces.whereType<double>().toList(),
          forceDelta: forceDeltaGf,
          needsTighten: needsTighten,
          needsLoosen: needsLoosen,
          predictionDirection: _predictionDirection,
          predictionScrew: _predictionScrew,
          predictionZMm: _predictionZMm,
          predictionRechecks: _predictionRechecks,
          consecutiveBackAdjustments: _consecutiveBackAdjustments,
          // Track where the user actually leaves the gauge so the
          // recheck log can compare it against the suggested target.
          onAchievedForce: (force) => _lastAchievedForceGf = force,
        );
    }
  }

  Widget _buildAdjustmentIntroView(BuildContext context, Color primary) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              FlutterI18n.translate(
                  context, 'leveling.adjustmentIntroBody'),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                height: 1.4,
                color: theme.colorScheme.onSurface
                    .withValues(alpha: 0.75),
              ),
            ),
            const SizedBox(height: 28),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: Colors.orangeAccent.withValues(alpha: 0.08),
                border: Border.all(
                  color: Colors.orangeAccent.withValues(alpha: 0.25),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(PhosphorIcons.warning(),
                      size: 22, color: Colors.orangeAccent),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      FlutterI18n.translate(
                          context, 'leveling.adjustmentIntroCaveat'),
                      style: TextStyle(
                        fontSize: 18,
                        height: 1.4,
                        color: theme.colorScheme.onSurface
                            .withValues(alpha: 0.7),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
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

  /// Shown when the corner check failed but every screw's correction
  /// would be below the execution floor — the remaining deviation is
  /// within measurement/adjustment resolution, so turning a screw
  /// against the gauge would be noise-driven.  Footer offers
  /// Cancel | Re-check (same as feedback).
  Widget _buildBelowResolutionView(BuildContext context, Color primary) {
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
                    color: primary.withValues(alpha: 0.15),
                  ),
                ),
                Icon(
                  PhosphorIcons.equals(),
                  size: 56,
                  color: primary,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text(
            FlutterI18n.translate(
                context, 'leveling.wizardBelowResolutionTitle'),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              FlutterI18n.translate(
                  context, 'leveling.wizardBelowResolutionBody'),
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
    required this.cornerZs,
    this.preAdjustmentDeviation,
  });

  final LevelingWorkflowEngine engine;
  final bool effectivelyRunning;
  final bool loosenScrewsDone;
  final bool alignDone;
  final List<ForceLevelingWorkflowResponse?> cornerResults;

  /// Averaged per-corner Z values from the sample accumulator — the
  /// values the wizard actually levels with; the results view must
  /// display the same numbers.
  final List<double?> cornerZs;
  final double? preAdjustmentDeviation;

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
    final rawZ = cornerZs;

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
        const SizedBox(height: 12),
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
        const SizedBox(height: 12),
        // Divergence warning: recheck is worse than the pre-adjustment check.
        // Gate 0.15 mm — leapfrog overshoot plus probe noise is expected
        // growth, not divergence.
        if (preAdjustmentDeviation != null &&
            deviation > preAdjustmentDeviation! + 0.15)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: Colors.orangeAccent.withValues(alpha: 0.15),
              border: Border.all(
                color: Colors.orangeAccent.withValues(alpha: 0.4),
              ),
            ),
            child: Row(
              children: [
                Icon(PhosphorIcons.warningOctagon(),
                    size: 20, color: Colors.orangeAccent),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    FlutterI18n.translate(
                        context, 'leveling.wizardDivergedWarning'),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.orangeAccent,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 8),
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
    this.predictionDirection,
    this.predictionScrew,
    this.predictionZMm,
    this.predictionRechecks,
    this.consecutiveBackAdjustments = 0,
    this.onAchievedForce,
  });

  final int cornerIndex;
  final double? cornerForce;
  final double? targetForce;
  final List<double> allCornerForces;
  final double? forceDelta;
  final bool needsTighten;
  final bool needsLoosen;
  final String? predictionDirection;
  final String? predictionScrew;
  final double? predictionZMm;
  final int? predictionRechecks;
  final int consecutiveBackAdjustments;

  /// Reports the smoothed live force mapped back into the PROBE frame
  /// (live EMA minus the probe→live offset) on every gauge tick.  The
  /// wizard keeps the last value so the recheck log can record where
  /// the user actually stopped relative to the suggested target.
  final ValueChanged<double>? onAchievedForce;

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

  // Probe→live frame anchor.  The gauge target is expressed in the
  // probe's force frame (first-stage peak); live analytics readings sit
  // in a different frame.  The offset is the mean of the first few RAW
  // live samples minus the probe force, captured before the user starts
  // turning.  (An earlier revision computed the offset from the EMA —
  // which was still initialized to the probe force at that moment — so
  // the offset was always 0 and the needle slowly drifted from the
  // probe frame into the live frame while the user was chasing it.)
  static const int _anchorSampleCount = 5;
  final List<double> _anchorSamples = [];
  double? _liveOffset;

  double? get _smoothedForce => _emaForce;

  @override
  void initState() {
    super.initState();
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
      // Anchor the probe→live offset on the first few raw samples.
      if (_anchorSamples.length < _anchorSampleCount &&
          widget.cornerForce != null) {
        _anchorSamples.add(raw);
        final mean =
            _anchorSamples.reduce((a, b) => a + b) / _anchorSamples.length;
        _liveOffset = mean - widget.cornerForce!;
      }
      // EMA runs purely in the live frame; until the first sample
      // arrives the gauge falls back to the static probe-frame delta.
      if (_emaForce == null) {
        _emaForce = raw;
      } else {
        _emaForce = _emaAlpha * raw + (1.0 - _emaAlpha) * _emaForce!;
      }
      // Report the achieved force in the probe frame so the wizard can
      // log where the user actually stopped vs the suggested target.
      if (_liveOffset != null && _emaForce != null) {
        widget.onAchievedForce?.call(_emaForce! - _liveOffset!);
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
    // The controller's target is shifted into the live frame via the
    // probe→live offset anchored on the first raw analytics samples.
    //
    // live − target: positive → corner lower than target → TIGHTEN.
    // live − target: negative → corner higher than target → LOOSEN.
    final double? forceDelta;
    if (_smoothedForce != null &&
        widget.targetForce != null &&
        _liveOffset != null) {
      final liveTarget = widget.targetForce! + _liveOffset!;
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
            padding: const EdgeInsets.symmetric(vertical: 12),
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
        ],
      ),
    );
  }
}

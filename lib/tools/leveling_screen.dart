/*
* Orion - Leveling Screen
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

import 'package:flutter/material.dart';
import 'package:flutter_i18n/flutter_i18n.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:orion/backend_service/backend_registry.dart';
import 'package:orion/backend_service/backend_service.dart';
import 'package:orion/backend_service/providers/analytics_provider.dart';
import 'package:orion/backend_service/providers/manual_provider.dart';
import 'package:orion/backend_service/providers/status_provider.dart';
import 'package:orion/glasser/glasser.dart';
import 'package:orion/tools/leveling_configs.dart';
import 'package:orion/backend_service/athena_iot/models/force_leveling_workflow.dart';
import 'package:orion/tools/leveling_workflow_engine.dart';
import 'package:orion/tools/manual_leveling_screen.dart';
import 'package:orion/util/orion_config.dart';
import 'package:orion/util/orion_spacing.dart';
import 'package:orion/util/providers/theme_provider.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';

class LevelingScreen extends StatelessWidget {
  const LevelingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final config = OrionConfig();
    final levelingConfig = getLevelingConfigForMachine(
      config.getMachineModelName(),
    );
    final backend = BackendService();
    final assistedEnabled = levelingConfig != null &&
        config.hasForceSensor() &&
        backend.supportsCapability(BackendCapabilities.supportsForceLeveling);

    return SafeArea(
      child: Padding(
        padding: OrionSpacing.screenPaddingWithBottomNav,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: _buildModeCard(
                context,
                title: FlutterI18n.translate(context, 'leveling.assisted'),
                description:
                    FlutterI18n.translate(context, 'leveling.assistedDesc'),
                icon: PhosphorIcons.magicWand(),
                accentColor: accent,
                accentCard: assistedEnabled,
                heroTag: 'start-assisted',
                actionLabel: assistedEnabled
                    ? FlutterI18n.translate(context, 'leveling.startLeveling')
                    : FlutterI18n.translate(context, 'leveling.notAvailable'),
                actionTint: assistedEnabled
                    ? GlassButtonTint.positive
                    : GlassButtonTint.none,
                actionEnabled: assistedEnabled,
                actionIcon: assistedEnabled
                    ? PhosphorIcon(PhosphorIcons.magicWand())
                    : PhosphorIcon(PhosphorIcons.warning()),
                onPressed: assistedEnabled
                    ? () => Navigator.of(context).push(
                          _buildOverlayRoute(
                            _AssistedLevelingWizard(config: levelingConfig),
                          ),
                        )
                    : null,
              ),
            ),
            const SizedBox(width: OrionSpacing.controlGap),
            Expanded(
              child: _buildModeCard(
                context,
                title: FlutterI18n.translate(context, 'leveling.manual'),
                description:
                    FlutterI18n.translate(context, 'leveling.manualDesc'),
                icon: PhosphorIconsFill.wrench,
                accentColor: accent,
                accentCard: true,
                heroTag: 'start-manual',
                actionLabel:
                    FlutterI18n.translate(context, 'leveling.manualMode'),
                actionTint: GlassButtonTint.positive,
                actionEnabled: true,
                actionIcon: const Icon(PhosphorIconsFill.wrench),
                onPressed: () {
                  Navigator.of(context).push(
                    _buildOverlayRoute(const ManualLevelingScreen()),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModeCard(
    BuildContext context, {
    required String title,
    required String description,
    required IconData icon,
    required Color accentColor,
    required bool accentCard,
    required String heroTag,
    required String actionLabel,
    required GlassButtonTint actionTint,
    required bool actionEnabled,
    required Widget actionIcon,
    VoidCallback? onPressed,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return GlassCard(
      margin: EdgeInsets.zero,
      accentColor: accentCard ? accentColor : null,
      child: Padding(
        padding: OrionSpacing.cardPadding.copyWith(top: 16, bottom: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: accentColor.withValues(alpha: isDark ? 0.14 : 0.10),
                    border: Border.all(
                      color:
                          accentColor.withValues(alpha: isDark ? 0.35 : 0.24),
                    ),
                  ),
                  child: Icon(icon, color: accentColor, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      fontSize: 24,
                      height: 1.15,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Expanded(
              child: Center(
                child: Text(
                  description,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    height: 1.35,
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: GlassFloatingActionButton.extended(
                heroTag: heroTag,
                scale: 1.2,
                icon: actionIcon,
                label: actionLabel,
                tint: actionTint,
                onPressed: actionEnabled ? onPressed : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

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

class _AssistedLevelingWizard extends StatefulWidget {
  const _AssistedLevelingWizard({required this.config});

  final LevelingConfig config;

  @override
  State<_AssistedLevelingWizard> createState() =>
      _AssistedLevelingWizardState();
}

class _AssistedLevelingWizardState extends State<_AssistedLevelingWizard> {
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

  // Corner measurements from probe steps
  final List<ForceLevelingWorkflowResponse?> _cornerResults =
      List.filled(4, null);

  // Adjustment mode state
  int? _adjustingCornerIndex;
  bool _adjustmentIsCw = true;
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
  }

  @override
  void dispose() {
    _wizardDisposed = true;
    _engine.removeListener(_handleEngineUpdate);
    _engine.dispose();
    super.dispose();
  }

  void _handleEngineUpdate() {
    if (!mounted || _wizardDisposed) return;
    if (_engine.isRunning) {
      _autoAdvancing = false;
      _runningSince ??= DateTime.now();
      _holdingRunning = false;
      _loosenScrewsDone = false;
    } else if (_engine.status == LevelingWorkflowStatus.stepComplete) {
      final step = _engine.currentStep;
      if (step != null) {
        // Save measurements from probe steps (any step with a cornerLabel)
        if (step.cornerLabel != null && _engine.lastResponse != null) {
          final idx = _cornerResults.indexWhere((r) => r == null);
          if (idx >= 0 && idx < 4) {
            _cornerResults[idx] = _engine.lastResponse;
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

        // Auto-advance through steps that don't need user interaction
        if (step.autoAdvance) {
          _autoAdvancing = true;
          _engine.advanceAfterSuccessfulStep();
          // Also auto-run the next step if it's a prepare move or final offset
          final nextStep = _engine.currentStep;
          if (nextStep != null &&
              (nextStep.kind == LevelingWorkflowStepKind.finalOffset ||
                  nextStep.kind == LevelingWorkflowStepKind.prepare)) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _engine.runCurrentStep();
            });
          }
        }
      }
    }

    // Minimum running duration — always checked, independent of status
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
        }
        return;
      case _WizardPhase.adjustment:
        // Back from adjustment → cancel
        _cancelLeveling();
        return;
    }
  }

  /// Compute deviation from corner measurements.
  double get _cornerDeviation {
    final zValues = _cornerResults
        .map((r) => r?.measurements?.secondStageTriggerZ)
        .whereType<double>()
        .toList();
    if (zValues.isEmpty) return 0.0;
    final min = zValues.reduce((a, b) => a < b ? a : b);
    final max = zValues.reduce((a, b) => a > b ? a : b);
    return max - min;
  }

  bool get _isCornerCheckPassed => _cornerDeviation <= 0.100;

  void _enterAdjustmentMode() {
    // Find the corner furthest from average
    final zValues = _cornerResults
        .map((r) => r?.measurements?.secondStageTriggerZ)
        .toList();
    final validZ = zValues.whereType<double>().toList();
    if (validZ.isEmpty) return;
    final avg = validZ.reduce((a, b) => a + b) / validZ.length;

    double maxDelta = 0;
    int worstIdx = 0;
    for (int i = 0; i < zValues.length; i++) {
      if (zValues[i] == null) continue;
      final delta = (zValues[i]! - avg).abs();
      if (delta > maxDelta) {
        maxDelta = delta;
        worstIdx = i;
      }
    }

    // LOW (below avg) → tighten (CW pulls up)
    // HIGH (above avg) → loosen (CCW pushes down)
    _adjustingCornerIndex = worstIdx;
    _adjustmentIsCw = zValues[worstIdx]! < avg;
    _adjustmentError = null;
    // Must be set before setState so the rebuild sees the busy state
    // and shows the spinner, not the feedback screen
    _adjustmentBusy = true;

    setState(() {
      _phase = _WizardPhase.adjustment;
      _adjustmentStep = _AdjustmentStep.preparing;
    });

    // Start the prepare cycle
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
            : 'Probe failed. Please try again.';
        if (mounted) setState(() {});
        return;
      }

      _cornerResults[_adjustingCornerIndex!] = response;
    } catch (e) {
      _adjustmentError = e.toString();
      if (mounted) setState(() {});
      return;
    }

    _adjustmentBusy = false;
    _adjustmentStep = _AdjustmentStep.feedback;
    if (mounted) setState(() {});
  }

  void _runRecheckCorners() {
    for (int i = 0; i < _cornerResults.length; i++) {
      _cornerResults[i] = null;
    }
    _engine.jumpToStep(3);
    setState(() => _phase = _WizardPhase.workflow);
  }

  void _advancePreFlight() {
    final keys = widget.config.checklistKeys;
    if (_preFlightIndex < keys.length - 1) {
      setState(() => _preFlightIndex += 1);
    } else {
      // All pre-flight steps done → start workflow (variant already selected)
      setState(() {
        _phase = _WizardPhase.workflow;
        _preFlightIndex = -1;
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
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Phase content (header + body, animated) ──
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
                // ── Actions ──
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
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(PhosphorIcons.swap(), size: 24, color: primary),
                const SizedBox(width: 10),
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
            const SizedBox(height: 20),
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
                  'Start Pre-Flight',
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

    // Running: only Emergency Stop, centered
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

    // Not running, not complete: Cancel + action button
    final bool needsAdjustment = isAllCornersMeasured && !_isCornerCheckPassed;
    final primaryLabel = switch (status) {
      LevelingWorkflowStatus.idle => 'Proceed',
      LevelingWorkflowStatus.stepComplete => isAllCornersMeasured
          ? (needsAdjustment ? 'Adjust' : 'Continue')
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
          : isLast
              ? PhosphorIcons.check()
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
        LevelingWorkflowStatus.stepComplete => () =>
            _engine.advanceAfterSuccessfulStep(),
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
              'Cancel Leveling',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.orangeAccent,
              ),
            ),
          ],
        ),
        content: const Text(
          'Are you sure you want to cancel?\n\n'
          'Progress will be lost and you will return to the leveling menu.',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
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
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }



  Widget _buildAdjustmentActions(BuildContext context) {
    final isPuckStep = _adjustmentStep == _AdjustmentStep.puckPlacement;

    // Busy (preparing / probing): single disabled spinner
    if (_adjustmentBusy) {
      return Center(
        child: SizedBox(
          width: 320,
          child: GlassButton(
            tint: GlassButtonTint.negative,
            onPressed: null,
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 65),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(
                  width: 20, height: 20,
                  child: CircularProgressIndicator(strokeWidth: 3),
                ),
                const SizedBox(width: 8),
                Text(
                  _adjustmentStep == _AdjustmentStep.probing
                      ? 'Probing…'
                      : 'Preparing…',
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
                  'Re-check All',
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
        return _buildAdjustmentRunning(context, primary);
      case _AdjustmentStep.puckPlacement:
        return _buildPuckPlacementView(context, primary);
      case _AdjustmentStep.feedback:
        final adjMeasurements =
            _cornerResults[_adjustingCornerIndex!]?.measurements;
        return _AdjustmentFeedbackScreen(
          key: const ValueKey('adjustment-feedback'),
          cornerIndex: _adjustingCornerIndex!,
          isCw: _adjustmentIsCw,
          zValue: adjMeasurements?.secondStageTriggerZ,
        );
    }
  }

  Widget _buildAdjustmentRunning(BuildContext context, Color primary) {
    final idx = _adjustingCornerIndex ?? 0;
    final isProbing = _adjustmentStep == _AdjustmentStep.probing;
    final labels = ['Front Left', 'Front Right', 'Back Right', 'Back Left'];
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 100, height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: primary.withValues(alpha: 0.10),
            ),
            child: const Center(
              child: CircularProgressIndicator(strokeWidth: 4),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            isProbing ? 'Probing Corner' : 'Preparing Corner',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: primary),
          ),
          const SizedBox(height: 8),
          Text(
            isProbing
                ? 'Measuring at ${labels[idx]}'
                : 'Positioning at ${labels[idx]}',
            style: TextStyle(
              fontSize: 16,
              color: Theme.of(context)
                  .colorScheme.onSurface.withValues(alpha: 0.72),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPuckPlacementView(BuildContext context, Color primary) {
    final labels = ['Front Left', 'Front Right', 'Back Right', 'Back Left'];
    final idx = _adjustingCornerIndex ?? 0;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 100, height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: primary.withValues(alpha: 0.12),
            ),
            child: Icon(
              PhosphorIcons.crosshair(),
              size: 52,
              color: primary,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Place the Leveling Puck',
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
              'Put the Leveling Puck under the\n'
              '${labels[idx]} corner, then press Proceed\n'
              'to measure the current force.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                height: 1.4,
                color: Theme.of(context)
                    .colorScheme.onSurface.withValues(alpha: 0.72),
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
            'Adjustment Failed',
            style: TextStyle(
              fontSize: 22, fontWeight: FontWeight.bold,
              color: Colors.orangeAccent,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              _adjustmentError ?? 'Unknown error',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Theme.of(context)
                    .colorScheme.onSurface.withValues(alpha: 0.72),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────
// Phase: Intro (simplified — calibration-overlay style)
// ────────────────────────────────────────────────────────────────

class _PreLevelingPane extends StatelessWidget {
  const _PreLevelingPane({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    return Center(
      key: const ValueKey('intro'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              PhosphorIcons.magicWand(),
              size: 80,
              color: primary,
            ),
            const SizedBox(height: 20),
            Text(
              'This wizard will guide you through assisted leveling.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: primary,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Your printer will utilize the force-sensor to help with '
              'ensuring good leveling results.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                height: 1.5,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.72),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────
// Pre-Flight Step-through Guide
// ────────────────────────────────────────────────────────────────

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
          // Large icon
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
          const SizedBox(height: 24),
          // Step label
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
                height: 1.3,
              ),
            ),
          ),
          const SizedBox(height: 28),
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

// ────────────────────────────────────────────────────────────────
// Phase: Variant Selection (kept similar but updated styling)
// ────────────────────────────────────────────────────────────────

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
                if (i > 0) const SizedBox(width: 16),
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
      child: InkWell(
        borderRadius: BorderRadius.circular(glassCornerRadius),
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Expanded(child: _VariantAsset(variant: variant)),
              const SizedBox(height: 12),
              Text(
                variant.label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 6),
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

// ────────────────────────────────────────────────────────────────
// Phase: Workflow Execution (calibration progress overlay style)
// ────────────────────────────────────────────────────────────────

class _WorkflowPane extends StatelessWidget {
  static const _cornerLabels = [
    'Front Left',
    'Front Right',
    'Back Right',
    'Back Left',
  ];

  const _WorkflowPane({
    super.key,
    required this.engine,
    required this.effectivelyRunning,
    required this.loosenScrewsDone,
    required this.cornerResults,
  });

  final LevelingWorkflowEngine engine;
  final bool effectivelyRunning;
  final bool loosenScrewsDone;
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
    final isTightenScrews = isComplete && intermediate == 'tighten';
    final isAllCornersMeasured = isComplete && intermediate == 'allCorners';

    return Center(
      key: ValueKey(
        'workflow-${engine.currentStepIndex}-${engine.status.name}',
      ),
      child: effectivelyRunning
          ? _buildRunningView(context, primary, step)
          : isLoosenScrews
              ? _buildLoosenScrewsView(context, primary)
              : isTightenScrews
                  ? _buildTightenScrewsView(context, primary)
                  : isAllCornersMeasured
                      ? _buildAllCornersMeasuredView(context, primary)
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
          'Loosen Plate Screws',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            'Please loosen the screws once the printer\n'
            'has stopped moving.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
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
    final onSurface =
        Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.72);
    final title = step.runningTitle ??
        switch (step.kind) {
          LevelingWorkflowStepKind.prepare => 'Preparing Machine',
          LevelingWorkflowStepKind.finalOffset => 'Saving Offset',
          _ => 'Moving towards plate',
        };
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: primary.withValues(alpha: 0.10),
          ),
          child: const SizedBox(
            width: 48,
            height: 48,
            child: Center(
              child: CircularProgressIndicator(strokeWidth: 4),
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: primary,
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Text(
            'Please do not touch the printer',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              height: 1.4,
              color: onSurface,
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
          'Tighten the Leveling Screws',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            'Please press down on the screen firmly and go\n'
            'in a clockwise motion as you increasingly\n'
            'tighten each screw.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              height: 1.4,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.72),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAllCornersMeasuredView(BuildContext context, Color primary) {
    final theme = Theme.of(context);
    final zValues = cornerResults.map((r) {
      return r?.measurements?.secondStageTriggerZ;
    }).toList();

    final validZ = zValues.whereType<double>().toList();
    final minZ = validZ.isEmpty ? 0.0 : validZ.reduce((a, b) => a < b ? a : b);
    final maxZ = validZ.isEmpty ? 0.0 : validZ.reduce((a, b) => a > b ? a : b);
    final deviation = maxZ - minZ;
    final withinTolerance = deviation < 0.100;
    final statusColor = withinTolerance ? Colors.greenAccent : Colors.redAccent;

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
              'Corner Check Results',
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
                withinTolerance ? 'PASS' : 'FAIL',
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
                // Back Left — top-left (back of printer, facing away)
                Positioned(
                  top: OrionSpacing.cardPadding.top,
                  left: OrionSpacing.cardPadding.left,
                  child: _cornerValueCard(
                    theme,
                    _cornerLabels[3],
                    zValues[3],
                    validZ,
                    minZ,
                    maxZ,
                  ),
                ),
                // Back Right — top-right
                Positioned(
                  top: OrionSpacing.cardPadding.top,
                  right: OrionSpacing.cardPadding.right,
                  child: _cornerValueCard(
                    theme,
                    _cornerLabels[2],
                    zValues[2],
                    validZ,
                    minZ,
                    maxZ,
                  ),
                ),
                // Front Right — bottom-right (front of printer, facing us)
                Positioned(
                  bottom: OrionSpacing.cardPadding.bottom,
                  right: OrionSpacing.cardPadding.right,
                  child: _cornerValueCard(
                    theme,
                    _cornerLabels[1],
                    zValues[1],
                    validZ,
                    minZ,
                    maxZ,
                  ),
                ),
                // Front Left — bottom-left
                Positioned(
                  bottom: OrionSpacing.cardPadding.bottom,
                  left: OrionSpacing.cardPadding.left,
                  child: _cornerValueCard(
                    theme,
                    _cornerLabels[0],
                    zValues[0],
                    validZ,
                    minZ,
                    maxZ,
                  ),
                ),
                // Total deviation — dead center
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Total Deviation',
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
                            '${deviation.toStringAsFixed(3)}',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: statusColor,
                              height: 1,
                            ),
                          ),
                          Text(
                            ' / 0.100 mm',
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
                              ? '✓ Within Tolerance'
                              : '⚠ Needs Adjustment',
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
            z != null ? '${z.toStringAsFixed(3)} mm' : '--',
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
        // ── Icon ──
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
        // ── Title ──
        Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: primary,
          ),
        ),
        const SizedBox(height: 8),
        // ── Instruction ──
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Text(
            instruction,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              height: 1.4,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.72),
            ),
          ),
        ),
      ],
    );
  }
}

// ────────────────────────────────────────────────────────────────
// Adjustment Feedback — live force gauge
// ────────────────────────────────────────────────────────────────

class _AdjustmentFeedbackScreen extends StatefulWidget {
  const _AdjustmentFeedbackScreen({
    super.key,
    required this.cornerIndex,
    required this.isCw,
    this.zValue,
  });

  final int cornerIndex;
  final bool isCw;
  final double? zValue;

  @override
  State<_AdjustmentFeedbackScreen> createState() =>
      _AdjustmentFeedbackScreenState();
}

class _AdjustmentFeedbackScreenState
    extends State<_AdjustmentFeedbackScreen> {
  static const _cornerNames = [
    'Front Left',
    'Front Right',
    'Back Right',
    'Back Left',
  ];

  AnalyticsProvider? _analytics;
  VoidCallback? _analyticsListener;
  bool _listenerRegistered = false;
  bool _analyticsDisposed = false;

  double? _baselineForce;
  final List<double> _forceHistory = [];
  static const int _smoothingWindow = 30; // ~2 seconds at 15Hz

  double? get _smoothedForce {
    if (_forceHistory.isEmpty) return null;
    return _forceHistory.reduce((a, b) => a + b) / _forceHistory.length;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_listenerRegistered) return;
    _analytics = Provider.of<AnalyticsProvider>(context, listen: false);
    _analyticsListener = () {
      if (!_analyticsDisposed) {
        final series = _analytics!.pressureSeries;
        if (series.isNotEmpty) {
          final raw = (series.last['v'] as num?)?.toDouble();
          if (raw != null) {
            _forceHistory.add(raw);
            if (_forceHistory.length > _smoothingWindow) {
              _forceHistory.removeAt(0);
            }
          }
        }
        // Capture baseline from the first smoothed value
        if (_baselineForce == null) {
          _baselineForce = _smoothedForce;
        }
        setState(() {});
      }
    };
    _analytics!.addListener(_analyticsListener!);
    _listenerRegistered = true;
  }

  @override
  void dispose() {
    _analyticsDisposed = true;
    if (_analytics != null && _analyticsListener != null) {
      _analytics!.removeListener(_analyticsListener!);
    }
    super.dispose();
  }

  String get _screwLabel {
    if (widget.cornerIndex <= 1) {
      return widget.cornerIndex == 0
          ? 'Front Left screw'
          : 'Front Right screw';
    }
    return 'Back screw';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;

    final currentForce = _smoothedForce;

    // Center the gauge on the force reading when the screen first appeared.
    // As you turn the screw, the dot moves relative to this baseline:
    //   tightening (CW) → force ↑ → dot moves right
    //   loosening  (CCW) → force ↓ → dot moves left
    final baseline = _baselineForce ?? currentForce ?? 0.0;
    const halfScale = 3.0;
    final position = currentForce != null
        ? ((currentForce - baseline) / halfScale).clamp(-1.0, 1.0)
        : 0.0;
    final gap = currentForce != null ? (currentForce - baseline).abs() : 0.0;

    // 10% deadzone (±0.1 position) so small fluctuations don't flip labels
    const deadzone = 0.10;
    final directionLabel = position < -deadzone
        ? '⟳ TIGHTEN'
        : position > deadzone
            ? '⟲ LOOSEN'
            : '✓ AT TARGET';
    final accent = position < -deadzone
        ? const Color(0xFF57F0A4)
        : position > deadzone
            ? const Color(0xFFFFC16D)
            : const Color(0xFF57F0A4);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 4),
        Row(
          children: [
            Icon(PhosphorIcons.wrench(), size: 24, color: accent),
            const SizedBox(width: 10),
            Text(
              'Adjust: ${_cornerNames[widget.cornerIndex]}',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: accent,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Expanded(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Direction + screw label
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: accent.withValues(alpha: 0.12),
                  ),
                  child: Text(
                    '$directionLabel — $_screwLabel',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: accent,
                    ),
                  ),
                ),
                if (widget.zValue != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Probed Z: ${widget.zValue!.toStringAsFixed(3)} mm',
                    style: TextStyle(
                      fontSize: 13,
                      color: onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                ],
                const SizedBox(height: 32),
                // Gauge
                SizedBox(
                  width: 320,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Labels above gauge
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '← Looser',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFFFFC16D),
                            ),
                          ),
                          Text(
                            'Start',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF57F0A4),
                            ),
                          ),
                          Text(
                            'Tighter →',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.orangeAccent,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Gauge track
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          height: 32,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            gradient: const LinearGradient(
                              colors: [
                                Color(0xFFFFC16D),
                                Color(0xFF57F0A4),
                                Colors.orangeAccent,
                              ],
                            ),
                          ),
                          child: Stack(
                            children: [
                              // Center target marker
                              Center(
                                child: Container(
                                  width: 4,
                                  height: 32,
                                  color: Colors.white.withValues(alpha: 0.7),
                                ),
                              ),
                              // Moving dot
                              Center(
                                child: FractionallySizedBox(
                                  widthFactor: 1,
                                  child: Padding(
                                    padding: EdgeInsetsDirectional.only(
                                      start: (position + 1) / 2 * (320 - 32),
                                    ),
                                    child: Container(
                                      width: 32,
                                      height: 32,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Colors.white,
                                        boxShadow: [
                                          BoxShadow(
                                            color: position.abs() > 0.3
                                                ? Colors.white
                                                    .withValues(alpha: 0.4)
                                                : const Color(0xFF57F0A4)
                                                    .withValues(alpha: 0.4),
                                            blurRadius: 12,
                                            spreadRadius: 2,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      // Force value below gauge
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            PhosphorIcons.gauge(),
                            size: 16,
                            color: onSurface.withValues(alpha: 0.5),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Force: ',
                            style: TextStyle(
                              fontSize: 15,
                              color: onSurface.withValues(alpha: 0.6),
                            ),
                          ),
                          Text(
                            currentForce != null
                                ? '${currentForce.toStringAsFixed(2)} N'
                                : '--',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: position.abs() < 0.15
                                  ? const Color(0xFF57F0A4)
                                  : position > 0
                                      ? Colors.orangeAccent
                                      : const Color(0xFFFFC16D),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'baseline ${baseline.toStringAsFixed(1)} N',
                            style: TextStyle(
                              fontSize: 12,
                              color: onSurface.withValues(alpha: 0.4),
                            ),
                          ),
                        ],
                      ),
                      if (gap > 0.2) ...[
                        const SizedBox(height: 8),
                        Text(
                          gap > 0.5
                              ? '${gap.toStringAsFixed(2)} N change'
                              : '${gap.toStringAsFixed(2)} N change — small adjustments now',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: onSurface.withValues(alpha: 0.5),
                          ),
                        ),
                      ],
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
}

// ────────────────────────────────────────────────────────────────
// Completion Pane (calibration-overlay style)
// ────────────────────────────────────────────────────────────────

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

PageRouteBuilder<T> _buildOverlayRoute<T>(Widget child) {
  return PageRouteBuilder<T>(
    opaque: false,
    barrierDismissible: false,
    barrierColor: Colors.black.withValues(alpha: 0.35),
    transitionDuration: const Duration(milliseconds: 300),
    reverseTransitionDuration: const Duration(milliseconds: 250),
    pageBuilder: (_, __, ___) => child,
    transitionsBuilder: (_, animation, __, child) {
      return FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
        child: child,
      );
    },
  );
}

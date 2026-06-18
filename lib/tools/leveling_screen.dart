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
import 'package:orion/backend_service/providers/manual_provider.dart';
import 'package:orion/backend_service/providers/status_provider.dart';
import 'package:orion/glasser/glasser.dart';
import 'package:orion/tools/leveling_configs.dart';
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

  @override
  void initState() {
    super.initState();
    _engine = LevelingWorkflowEngine()..addListener(_handleEngineUpdate);
  }

  @override
  void dispose() {
    _engine.removeListener(_handleEngineUpdate);
    _engine.dispose();
    super.dispose();
  }

  void _handleEngineUpdate() {
    if (!mounted) return;
    if (_engine.isRunning) {
      _runningSince ??= DateTime.now();
      _holdingRunning = false;
    } else if (_runningSince != null && !_holdingRunning) {
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

  bool get _effectivelyRunning => _engine.isRunning || _holdingRunning;

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
    }
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
        );
    }
  }

  Widget _buildActions(BuildContext context) {
    if (_phase == _WizardPhase.workflow) {
      return _buildWorkflowActions(context);
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

    // Completion: single Done button
    if (status == LevelingWorkflowStatus.complete) {
      return SizedBox(
        width: double.infinity,
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

    // Not running, not complete: Cancel + action button
    final primaryLabel = switch (status) {
      LevelingWorkflowStatus.idle => 'Proceed',
      LevelingWorkflowStatus.stepComplete => isLast
          ? FlutterI18n.translate(context, 'common.done')
          : FlutterI18n.translate(context, 'leveling.next'),
      LevelingWorkflowStatus.failed =>
        FlutterI18n.translate(context, 'common.retry'),
      _ => '',
    };

    final primaryIcon = switch (status) {
      LevelingWorkflowStatus.idle => PhosphorIcons.arrowRight(),
      LevelingWorkflowStatus.stepComplete =>
        isLast ? PhosphorIcons.check() : PhosphorIcons.arrowRight(),
      LevelingWorkflowStatus.failed => PhosphorIcons.arrowRight(),
      _ => PhosphorIcons.arrowRight(),
    };

    final primaryTint = status == LevelingWorkflowStatus.failed
        ? GlassButtonTint.warn
        : GlassButtonTint.positive;

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
            onPressed: _primaryWorkflowAction(status),
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

  VoidCallback? _primaryWorkflowAction(LevelingWorkflowStatus status) {
    if (_engine.isRunning) return null;
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
  const _WorkflowPane({
    super.key,
    required this.engine,
    required this.effectivelyRunning,
  });

  final LevelingWorkflowEngine engine;
  final bool effectivelyRunning;

  @override
  Widget build(BuildContext context) {
    if (engine.isComplete) {
      return _CompletionPane(engine: engine);
    }

    final step = engine.currentStep;
    if (step == null) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    // After the first (prepare) step completes → show "Ready for Leveling"
    final isReadyForLeveling = !effectivelyRunning &&
        engine.currentStepIndex == 0 &&
        engine.status == LevelingWorkflowStatus.stepComplete;

    return Center(
      key: ValueKey(
        'workflow-${engine.currentStepIndex}-${engine.status.name}',
      ),
      child: isReadyForLeveling
          ? _buildReadyForLeveling(context, primary)
          : effectivelyRunning
              ? _buildRunningView(context, primary, step)
              : _buildStepView(context, theme, primary, step),
    );
  }

  Widget _buildReadyForLeveling(BuildContext context, Color primary) {
    return Column(
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
            size: 52,
            color: Colors.greenAccent,
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'Ready for Leveling',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.greenAccent,
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Text(
            'The printer is ready to start leveling.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              height: 1.4,
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
    final title = step.kind == LevelingWorkflowStepKind.prepare
        ? 'Preparing Machine'
        : 'Moving towards plate';
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

  Widget _buildStepView(
    BuildContext context,
    ThemeData theme,
    Color primary,
    LevelingWorkflowStep step,
  ) {
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
          FlutterI18n.translate(context, step.titleKey),
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
            FlutterI18n.translate(context, step.instructionKey),
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
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: GlassCard(
          outlined: true,
          accentColor: Colors.greenAccent,
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  PhosphorIconsFill.checkCircle,
                  size: 64,
                  color: Colors.greenAccent,
                ),
                const SizedBox(height: 14),
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
                Text(
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
                if (engine.zOffsetApplied != null) ...[
                  const SizedBox(height: 20),
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
                      children: [
                        Icon(
                          PhosphorIcons.ruler(),
                          size: 20,
                          color: Colors.greenAccent,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            FlutterI18n.translate(
                              context,
                              'levelingWorkflow.appliedOffset',
                            ),
                            style: TextStyle(
                              fontSize: 15,
                              color: theme.colorScheme.onSurface
                                  .withValues(alpha: 0.7),
                            ),
                          ),
                        ),
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
          ),
        ),
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

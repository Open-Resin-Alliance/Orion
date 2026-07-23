/*
* Orion - Leveling Screen
* Copyright (C) 2025 Open Resin Alliance
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
import 'package:orion/backend_service/providers/status_provider.dart';
import 'package:orion/glasser/glasser.dart';
import 'package:orion/util/orion_config.dart';
import 'package:orion/util/orion_spacing.dart';
import 'package:orion/util/providers/theme_provider.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'package:orion/backend_service/providers/manual_provider.dart';
import 'package:logging/logging.dart';
import 'package:orion/tools/leveling_configs.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:video_player/video_player.dart';
import 'package:orion/tools/manual_leveling_screen.dart';

class LevelingScreen extends StatelessWidget {
  const LevelingScreen({super.key});

  // ignore: unused_element
  Future<void> _showLevelingDialog(BuildContext context) async {
    final config = OrionConfig();
    final navigator = Navigator.of(context);
    final homeIsUp = config.isHomePositionUp();

    // Step 4: Guide
    void showGuide(LevelingVariant variant) {
      if (variant.guide != null) {
        navigator.push(
          _buildOverlayRoute(
            _LevelingGuideScreen(
              guide: variant.guide!,
              onComplete: () {
                Navigator.of(context).popUntil((route) => route.isFirst);
              },
            ),
          ),
        );
      } else {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    }

    // Step 3: Checklist
    void showChecklist(LevelingVariant variant) {
      navigator.push(
        _buildOverlayRoute(
          _LevelingOverlay(
            onBegin: (overlayContext) async {
              showGuide(variant);
            },
          ),
        ),
      );
    }

    // Step 2: Homing
    Future<void> startHomingSequence(LevelingVariant variant) async {
      // Define the smart homing check as a closure
      Future<bool> checkSmartHoming() async {
        try {
          final statusProvider =
              Provider.of<StatusProvider>(context, listen: false);
          // Force a refresh to ensure we have the latest kinematic status
          await statusProvider.refresh(force: true);
          final kin = statusProvider.kinematicStatus;

          const skipPositionThreshold = 20.0;
          if (kin != null &&
              kin.homed == true &&
              kin.position > skipPositionThreshold) {
            return true;
          }
        } catch (_) {}
        return false;
      }

      Future<void> startHoming() {
        return navigator.push(
          _buildOverlayRoute(
            _LevelingHomingScreen(
              homeIsUp: homeIsUp,
              skipHome: false,
              shouldSkipHome: checkSmartHoming,
              onComplete: () {
                showChecklist(variant);
              },
            ),
          ),
        );
      }

      if (homeIsUp) {
        await startHoming();
      } else {
        final result = await navigator.push<bool>(
          _buildOverlayRoute(
            _DownwardHomingWarningScreen(
              onCancel: () => navigator.pop(false),
              onContinue: () => navigator.pop(true),
            ),
          ),
        );
        if (result == true) {
          await startHoming();
        }
      }
    }

    // Step 1: Build Arm Selection
    Future<void> showBuildArmSelection() async {
      final machineName = config.getMachineModelName();
      final levelingConfig = getLevelingConfigForMachine(machineName);

      if (levelingConfig != null) {
        // Do not await here, so Intro stops loading immediately
        navigator.push(
          _buildOverlayRoute(
            _BuildArmSelectionScreen(
              config: levelingConfig,
              onVariantSelected: (variant) {
                startHomingSequence(variant);
              },
            ),
          ),
        );
      } else {
        // No specific config, just close for now
        if (navigator.canPop()) {
          navigator.pop();
        }
      }
    }

    // Step 0: Intro
    navigator.push(
      _buildOverlayRoute(
        _LevelingIntroScreen(
          onContinue: () async {
            await showBuildArmSelection();
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;

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
                accentCard: false,
                heroTag: 'start-assisted',
                actionLabel:
                    FlutterI18n.translate(context, 'leveling.comingSoon'),
                actionTint: GlassButtonTint.none,
                actionEnabled: false,
                actionIcon: PhosphorIcon(PhosphorIcons.clockClockwise()),
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          fontSize: 24,
                          height: 1.15,
                        ),
                      ),
                    ],
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
            Center(
              child: SizedBox(
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
            ),
          ],
        ),
      ),
    );
  }
}

class _LevelingOverlay extends StatefulWidget {
  const _LevelingOverlay({required this.onBegin});

  final Future<void> Function(BuildContext) onBegin;

  @override
  State<_LevelingOverlay> createState() => _LevelingOverlayState();
}

class _LevelingOverlayState extends State<_LevelingOverlay> {
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final isGlass =
        Provider.of<ThemeProvider>(context, listen: false).isGlassTheme;
    final accent = Theme.of(context).colorScheme.primary;

    return GlassApp(
      child: Scaffold(
        backgroundColor: isGlass
            ? Colors.transparent
            : Theme.of(context).colorScheme.surface,
        appBar: AppBar(
          backgroundColor: isGlass
              ? Colors.transparent
              : Theme.of(context).colorScheme.surface,
          elevation: 0,
          automaticallyImplyLeading: false,
          title: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                PhosphorIconsFill.screwdriver,
                size: 32,
                color: accent,
              ),
              const SizedBox(width: 12),
              Text(
                FlutterI18n.translate(context, 'leveling.preparation'),
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
          centerTitle: true,
        ),
        body: SafeArea(
          child: LayoutBuilder(builder: (context, constraints) {
            return SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Padding(
                  padding: OrionSpacing.screenPaddingNoTop,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _PreFlightChecklist(),
                      const SizedBox(height: 85),
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
        floatingActionButton: Padding(
          padding: OrionSpacing.screenPaddingNoTop,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              GlassFloatingActionButton.extended(
                heroTag: 'cancel-leveling',
                tint: GlassButtonTint.negative,
                icon: Icon(PhosphorIcons.x()),
                iconAfterLabel: false,
                scale: 1.3,
                label: FlutterI18n.translate(context, 'common.cancel'),
                onPressed:
                    _isLoading ? null : () => Navigator.of(context).pop(false),
              ),
              GlassFloatingActionButton.extended(
                heroTag: 'start-leveling',
                tint: GlassButtonTint.positive,
                scale: 1.3,
                icon: _isLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          color: Colors.white,
                        ),
                      )
                    : PhosphorIcon(PhosphorIcons.arrowRight()),
                iconAfterLabel: !_isLoading,
                label: _isLoading
                    ? FlutterI18n.translate(context, 'leveling.loading')
                    : FlutterI18n.translate(context, 'leveling.next'),
                onPressed: _isLoading
                    ? null
                    : () async {
                        setState(() => _isLoading = true);
                        await widget.onBegin(context);
                        if (mounted) {
                          setState(() => _isLoading = false);
                        }
                      },
              ),
            ],
          ),
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      ),
    );
  }
}

class _LevelingHomingScreen extends StatefulWidget {
  const _LevelingHomingScreen({
    required this.homeIsUp,
    required this.onComplete,
    this.skipHome = false,
    this.shouldSkipHome,
  });

  final bool homeIsUp;
  final VoidCallback onComplete;

  /// When true, do not issue a homing command. This is used when the
  /// backend reports the device is already homed and we only need to
  /// move to the safe top position â€” but we still show this screen while
  /// motion completes and Z stabilizes.
  final bool skipHome;

  /// Optional callback to check if homing should be skipped.
  /// This allows the screen to be shown immediately while the check runs.
  final Future<bool> Function()? shouldSkipHome;

  @override
  State<_LevelingHomingScreen> createState() => _LevelingHomingScreenState();
}

class _PreFlightChecklist extends StatefulWidget {
  const _PreFlightChecklist();

  @override
  State<_PreFlightChecklist> createState() => _PreFlightChecklistState();
}

class _PreFlightChecklistState extends State<_PreFlightChecklist> {
  bool _haveRemovedResin = false;
  bool _haveHexKeys = false;
  bool _havePlate = false;
  bool _haveClean = false;

  @override
  Widget build(BuildContext context) {
    final textStyle = TextStyle(fontSize: 22);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GlassCard(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: OrionSpacing.compactCardPadding,
            child: CheckboxListTile(
              activeColor: Colors.greenAccent,
              value: _haveRemovedResin,
              onChanged: (v) => setState(() => _haveRemovedResin = v ?? false),
              title: Text(FlutterI18n.translate(context, 'leveling.removeVat'),
                  style: textStyle),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ),
        const SizedBox(height: 8),
        GlassCard(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: OrionSpacing.compactCardPadding,
            child: CheckboxListTile(
              activeColor: Colors.greenAccent,
              value: _haveHexKeys,
              onChanged: (v) => setState(() => _haveHexKeys = v ?? false),
              title: Text(
                  FlutterI18n.translate(context, 'leveling.checkHexKeys'),
                  style: textStyle),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ),
        const SizedBox(height: 8),
        GlassCard(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: OrionSpacing.compactCardPadding,
            child: CheckboxListTile(
              activeColor: Colors.greenAccent,
              value: _havePlate,
              onChanged: (v) => setState(() => _havePlate = v ?? false),
              title: Text(
                  FlutterI18n.translate(context, 'leveling.checkInstallPlate'),
                  style: textStyle),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ),
        const SizedBox(height: 8),
        GlassCard(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: OrionSpacing.compactCardPadding,
            child: CheckboxListTile(
              activeColor: Colors.greenAccent,
              value: _haveClean,
              onChanged: (v) => setState(() => _haveClean = v ?? false),
              title: Text(
                  FlutterI18n.translate(context, 'leveling.checkLcdClean'),
                  style: textStyle),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ),
      ],
    );
  }
}

class _LevelingHomingScreenState extends State<_LevelingHomingScreen>
    with SingleTickerProviderStateMixin {
  static const _stabilityThreshold = 0.02;
  static const _stabilityDuration = Duration(seconds: 2);
  static const _noUpdateTimeout = Duration(seconds: 3);

  late final AnimationController _pulseController;
  double? _lastZ;
  DateTime? _stableSince;
  Timer? _stabilityTimer;
  Timer? _noUpdateTimer;
  bool _moveInitiated = false;
  bool _completed = false;
  final _log = Logger('_LevelingHomingScreen');

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);

    // Enable continuous kinematic polling so we can detect when homing/moving
    // completes. This will be disabled in dispose().
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final statusProvider =
          Provider.of<StatusProvider>(context, listen: false);
      statusProvider.setContinuousKinematicPolling(true);
    });

    // Start the homing command when this screen is presented. Use a
    // post-frame callback so the widget tree is fully built and providers
    // can be read from the context safely.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;

      bool doSkip = widget.skipHome;
      if (!doSkip && widget.shouldSkipHome != null) {
        doSkip = await widget.shouldSkipHome!();
      }

      if (doSkip) {
        _log.info(
            'Homing screen shown; skipping homing command and moving to top');
        if (!mounted) return;
        final messenger = ScaffoldMessenger.of(context);
        final manual = Provider.of<ManualProvider>(context, listen: false);
        try {
          // If we're already very high (>=50mm) move down a little first to
          // ensure the subsequent moveToTop has a reliable travel start.
          final statusProvider =
              Provider.of<StatusProvider>(context, listen: false);
          final currentZ = statusProvider.status?.physicalState.z;
          if (currentZ != null && currentZ >= 50.0) {
            final preZ = currentZ;
            _log.info('Z is $preZ >=50; moving down 2mm before top');
            try {
              // Set _lastZ so the next differing reading will be detected as a
              // change. Then attempt to capture an updated Z after the small
              // downward move so we can reliably detect the subsequent move-to-top.
              _lastZ = preZ;
              final ok = await manual.moveDelta(-2.0);
              _log.info('moveDelta(-2) returned: $ok');
              // Try to capture the new Z value within a short window.
              Duration waited = Duration.zero;
              const step = Duration(milliseconds: 200);
              const maxWait = Duration(seconds: 2);
              var newZ = statusProvider.status?.physicalState.z;
              while ((newZ == null || (newZ - preZ).abs() < 0.0001) &&
                  waited < maxWait) {
                await Future.delayed(step);
                waited += step;
                newZ = statusProvider.status?.physicalState.z;
              }
              if (newZ != null) {
                _log.info('Captured Z after moveDown: $newZ');
                _lastZ = newZ;
              } else {
                _log.fine(
                    'Did not capture new Z after moveDown; relying on watchdog');
              }
            } catch (e, st) {
              _log.warning('moveDelta(-2) failed', e, st);
            }
          }
          final started = await manual.moveToTop();
          _log.info('moveToTop returned: $started');
          _moveInitiated = true;
          if (!started) {
            _log.warning('moveToTop() returned false');
            if (!mounted) return;
            messenger.showSnackBar(
              SnackBar(
                  content: Text(FlutterI18n.translate(
                      context, 'leveling.failedMoveToTop'))),
            );
          }
        } catch (e) {
          _log.severe('moveToTop() threw', e);
          if (!mounted) return;
          messenger.showSnackBar(
            SnackBar(
                content: Text(FlutterI18n.translate(
                    context, 'leveling.moveFailed',
                    translationParams: {'error': e.toString()}))),
          );
        }
      } else {
        _log.info('Homing screen shown; issuing manualHome()');
        if (!mounted) return;
        final messenger = ScaffoldMessenger.of(context);
        try {
          if (!mounted) return;
          final manual = Provider.of<ManualProvider>(context, listen: false);
          final started = await manual.manualHome();
          _log.info('manualHome returned: $started');
          if (!started) {
            _log.warning('manualHome() returned false');
            if (!mounted) return;
            messenger.showSnackBar(
              SnackBar(
                  content: Text(
                      FlutterI18n.translate(context, 'leveling.failedHoming'))),
            );
          }
        } catch (e) {
          _log.severe('manualHome() threw', e);
          if (!mounted) return;
          messenger.showSnackBar(
            SnackBar(
                content: Text(FlutterI18n.translate(
                    context, 'leveling.homingFailed',
                    translationParams: {'error': e.toString()}))),
          );
        }
      }
    });
  }

  @override
  void dispose() {
    _stabilityTimer?.cancel();
    _noUpdateTimer?.cancel();
    _pulseController.dispose();
    // Disable continuous kinematic polling when leaving this screen
    try {
      final statusProvider =
          Provider.of<StatusProvider>(context, listen: false);
      statusProvider.setContinuousKinematicPolling(false);
    } catch (_) {
      // Context may not be valid during dispose
    }
    super.dispose();
  }

  void _handleZ(double? z) {
    if (_completed) return;
    _log.fine(
        'handleZ called z=$z lastZ=$_lastZ stableSince=$_stableSince completed=$_completed');

    if (z == null) {
      _log.fine('z is null');
      // If we're skipping homing and have initiated a move, don't clear
      // _lastZ here â€” the status stream can be sparse during motion.
      if (!widget.skipHome) {
        _log.fine('clearing stability state (non-skipHome)');
        _stableSince = null;
        _lastZ = null;
        _stabilityTimer?.cancel();
        _stabilityTimer = null;
      } else {
        // When skipping homing, treat null as "no update" and let the
        // no-update watchdog handle completion if updates stop.
        if (_moveInitiated && _lastZ != null) {
          _noUpdateTimer?.cancel();
          _noUpdateTimer = Timer(_noUpdateTimeout, () async {
            _noUpdateTimer = null;
            if (_completed) return;
            _log.info(
                'no-update watchdog fired (z==null); confirming before completing');
            await _confirmAndComplete();
          });
        }
      }
      return;
    }

    final changed = _lastZ == null || (z - _lastZ!).abs() > _stabilityThreshold;

    if (changed) {
      _log.fine('z changed (last=$_lastZ -> now=$z); resetting stableSince');
      // Z moved beyond threshold â€” reset stability tracking and cancel any
      // pending timer.
      _stableSince = DateTime.now();
      if (widget.skipHome && _moveInitiated) {
        // Reset the no-update watchdog: if updates stop arriving for a
        // short interval after a change, assume motion completed.
        _noUpdateTimer?.cancel();
        _noUpdateTimer = Timer(_noUpdateTimeout, () async {
          _noUpdateTimer = null;
          if (_completed) return;
          _log.info(
              'no-update watchdog fired after change; confirming before completing');
          await _confirmAndComplete();
        });
      }
      if (_stabilityTimer != null) {
        _log.fine('cancelling existing stability timer');
        _stabilityTimer?.cancel();
        _stabilityTimer = null;
      }
    } else {
      _log.fine('z within threshold (last=$_lastZ now=$z)');
    }

    // Always ensure a stability timer is running. If Z changed, we cancelled
    // the old one above and will schedule a new one here. If Z didn't change,
    // we keep the existing timer running. This ensures that if the Z value
    // stabilizes and stops updating (causing Selector to stop firing), the
    // timer from the last change will still eventually fire and complete.
    _stableSince ??= DateTime.now();
    if (_stabilityTimer == null) {
      _log.fine('scheduling stability timer for $_stabilityDuration');
      _stabilityTimer = Timer(_stabilityDuration, () {
        _stabilityTimer = null;
        if (_completed) return;
        final since = _stableSince;
        if (since == null) return;
        final stableFor = DateTime.now().difference(since);
        _log.fine('stability timer fired; stableFor=$stableFor');
        if (stableFor >= _stabilityDuration) {
          _log.info('Z stable long enough; completing homing');
          _completed = true;
          if (!mounted) return;
          Navigator.of(context).pop();
          widget.onComplete();
        } else {
          _log.fine('stability timer fired but stableFor < required; ignoring');
        }
      });
    }

    _lastZ = z;
  }

  Future<void> _confirmAndComplete() async {
    if (_completed) return;
    try {
      final statusProvider =
          Provider.of<StatusProvider>(context, listen: false);
      // Force an immediate refresh to try to get a final kinematic update.
      await statusProvider.refresh(force: true);
      final latestZ = statusProvider.status?.physicalState.z;
      if (latestZ != null &&
          _lastZ != null &&
          (latestZ - _lastZ!).abs() <= _stabilityThreshold) {
        _log.info('confirmation poll: Z settled at $latestZ; completing');
        _complete();
        return;
      } else {
        _log.fine(
            'confirmation poll: Z not settled (latest=$latestZ last=$_lastZ); not completing yet');
        // Let normal polling or subsequent updates handle completion.
        return;
      }
    } catch (e, st) {
      _log.fine('confirmation poll failed; completing as fallback', e, st);
      _complete();
    }
  }

  void _complete() {
    if (_completed) return;
    _completed = true;
    if (!mounted) return;
    Navigator.of(context).pop();
    widget.onComplete();
  }

  @override
  Widget build(BuildContext context) {
    final isGlass =
        Provider.of<ThemeProvider>(context, listen: false).isGlassTheme;
    final accent = Theme.of(context).colorScheme.primary;

    return GlassApp(
      child: Scaffold(
        backgroundColor: isGlass
            ? Colors.transparent
            : Theme.of(context).colorScheme.surface,
        appBar: AppBar(
          backgroundColor: isGlass
              ? Colors.transparent
              : Theme.of(context).colorScheme.surface,
          elevation: 0,
          automaticallyImplyLeading: false,
          title: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              PhosphorIcon(PhosphorIcons.house(), color: accent),
              const SizedBox(width: 8),
              Text(
                FlutterI18n.translate(context, 'levelingGuide.homingZ'),
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
          centerTitle: true,
        ),
        body: SafeArea(
          child: Padding(
            padding: OrionSpacing.screenPaddingNoTop,
            child: Column(
              children: [
                Selector<StatusProvider, double?>(
                  selector: (_, provider) => provider.status?.physicalState.z,
                  builder: (_, z, __) {
                    WidgetsBinding.instance
                        .addPostFrameCallback((_) => _handleZ(z));
                    return const SizedBox.shrink();
                  },
                ),
                Expanded(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 100),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          AnimatedBuilder(
                            animation: _pulseController,
                            builder: (context, child) {
                              final scale =
                                  0.9 + (_pulseController.value * 0.15);
                              final opacity =
                                  0.5 + (_pulseController.value * 0.5);
                              return Opacity(
                                opacity: opacity,
                                child: Transform.scale(
                                  scale: scale,
                                  child: child,
                                ),
                              );
                            },
                            child: Icon(
                              widget.homeIsUp
                                  ? PhosphorIcons.caretDoubleUp()
                                  : PhosphorIcons.caretDoubleDown(),
                              size: 150,
                              color: accent,
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            widget.skipHome
                                ? (widget.homeIsUp
                                    ? FlutterI18n.translate(
                                        context, 'levelingGuide.movingUp')
                                    : FlutterI18n.translate(
                                        context, 'levelingGuide.movingDown'))
                                : (widget.homeIsUp
                                    ? FlutterI18n.translate(
                                        context, 'levelingGuide.homingUp')
                                    : FlutterI18n.translate(
                                        context, 'levelingGuide.homingDown')),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w200,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            widget.homeIsUp
                                ? FlutterI18n.translate(
                                    context, 'levelingGuide.movingAway')
                                : FlutterI18n.translate(
                                    context, 'levelingGuide.ensureClear'),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.white.withValues(alpha: 0.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        floatingActionButton: GlassFloatingActionButton.extended(
          heroTag: 'homing-estop',
          tint: GlassButtonTint.negative,
          icon: Icon(PhosphorIcons.stop()),
          scale: 1.3,
          label: FlutterI18n.translate(context, 'levelingGuide.emergencyStop'),
          onPressed: () {
            final manual = Provider.of<ManualProvider>(context, listen: false);
            manual.emergencyStop();
            Navigator.of(context).popUntil((route) => route.isFirst);
          },
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      ),
    );
  }
}

class _DownwardHomingWarningScreen extends StatelessWidget {
  const _DownwardHomingWarningScreen({
    required this.onCancel,
    required this.onContinue,
  });

  final VoidCallback onCancel;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final isGlass =
        Provider.of<ThemeProvider>(context, listen: false).isGlassTheme;
    final accent = Theme.of(context).colorScheme.primary;

    return GlassApp(
      child: Scaffold(
        backgroundColor: isGlass
            ? Colors.transparent
            : Theme.of(context).colorScheme.surface,
        appBar: AppBar(
          backgroundColor: isGlass
              ? Colors.transparent
              : Theme.of(context).colorScheme.surface,
          elevation: 0,
          automaticallyImplyLeading: false,
          title: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                PhosphorIconsFill.warning,
                color: accent,
              ),
              const SizedBox(width: 8),
              Text(
                FlutterI18n.translate(context, 'levelingGuide.clearPath'),
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
          centerTitle: true,
        ),
        body: SafeArea(
          child: Padding(
            padding: OrionSpacing.screenPaddingNoTop,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                GlassCard(
                  margin: EdgeInsets.zero,
                  outlined: true,
                  child: Padding(
                    padding: OrionSpacing.cardPadding,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              PhosphorIconsFill.arrowFatLinesDown,
                              color: accent,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                FlutterI18n.translate(
                                    context, 'leveling.downwardWarning'),
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey.shade200,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _levelingChecklistRow(
                          context,
                          FlutterI18n.translate(
                              context, 'leveling.downwardStep1'),
                        ),
                        const SizedBox(height: 12),
                        _levelingChecklistRow(
                          context,
                          FlutterI18n.translate(
                              context, 'leveling.downwardStep2'),
                        ),
                        const SizedBox(height: 12),
                        _levelingChecklistRow(
                          context,
                          FlutterI18n.translate(
                              context, 'leveling.downwardStep3'),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 85),
              ],
            ),
          ),
        ),
        floatingActionButton: Padding(
          padding: OrionSpacing.screenPaddingNoTop,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              GlassFloatingActionButton.extended(
                heroTag: 'downward-cancel',
                tint: GlassButtonTint.negative,
                icon: Icon(PhosphorIcons.arrowLeft()),
                iconAfterLabel: false,
                scale: 1.3,
                label: FlutterI18n.translate(context, 'common.back'),
                onPressed: onCancel,
              ),
              GlassFloatingActionButton.extended(
                heroTag: 'downward-continue',
                tint: GlassButtonTint.positive,
                icon: PhosphorIcon(PhosphorIcons.check()),
                iconAfterLabel: true,
                scale: 1.3,
                label: FlutterI18n.translate(context, 'leveling.allClear'),
                onPressed: onContinue,
              ),
            ],
          ),
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      ),
    );
  }
}

class _BuildArmSelectionScreen extends StatelessWidget {
  const _BuildArmSelectionScreen({
    required this.config,
    required this.onVariantSelected,
  });

  final LevelingConfig config;
  final ValueChanged<LevelingVariant> onVariantSelected;

  @override
  Widget build(BuildContext context) {
    final isGlass =
        Provider.of<ThemeProvider>(context, listen: false).isGlassTheme;
    final accent = Theme.of(context).colorScheme.primary;

    return GlassApp(
      child: Scaffold(
        backgroundColor: isGlass
            ? Colors.transparent
            : Theme.of(context).colorScheme.surface,
        appBar: AppBar(
          backgroundColor: isGlass
              ? Colors.transparent
              : Theme.of(context).colorScheme.surface,
          elevation: 0,
          automaticallyImplyLeading: false,
          title: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                PhosphorIconsFill.gear,
                color: accent,
              ),
              const SizedBox(width: 8),
              Text(
                FlutterI18n.translate(context, 'leveling.selectBuildArm'),
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
          centerTitle: true,
        ),
        body: SafeArea(
          child: Padding(
            padding: OrionSpacing.screenPaddingNoTop,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 24),
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (int i = 0; i < config.variants.length; i++) ...[
                        if (i > 0) const SizedBox(width: 16),
                        Expanded(
                          child: GlassButton(
                            onPressed: () =>
                                onVariantSelected(config.variants[i]),
                            tint: GlassButtonTint.neutral,
                            style: ElevatedButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(glassCornerRadius),
                              ),
                              minimumSize:
                                  const Size(double.infinity, double.infinity),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                if (config.variants[i].assetPath != null)
                                  SizedBox(
                                    height: 160,
                                    child: config.variants[i].assetPath!
                                            .endsWith('.svg')
                                        ? SvgPicture.asset(
                                            config.variants[i].assetPath!,
                                            fit: BoxFit.contain,
                                            colorFilter: ColorFilter.mode(
                                                accent, BlendMode.srcIn),
                                          )
                                        : Image.asset(
                                            config.variants[i].assetPath!,
                                            fit: BoxFit.contain,
                                          ),
                                  )
                                else
                                  Icon(
                                    config.variants[i].icon ??
                                        PhosphorIconsFill.cube,
                                    size: 80,
                                    color: accent,
                                  ),
                                const SizedBox(height: 24),
                                Text(
                                  config.variants[i].label,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface, // Force white/text color
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  config.variants[i].description,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey.shade400,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const Spacer(),
                const SizedBox(height: 85),
              ],
            ),
          ),
        ),
        floatingActionButton: Padding(
          padding: OrionSpacing.screenPaddingNoTop,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              GlassFloatingActionButton.extended(
                heroTag: 'selection-back',
                tint: GlassButtonTint.neutral,
                icon: Icon(PhosphorIcons.arrowLeft()),
                iconAfterLabel: false,
                scale: 1.3,
                label: FlutterI18n.translate(context, 'common.back'),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
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

Widget _levelingChecklistRow(BuildContext context, String label) {
  return Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(
        PhosphorIconsFill.checkCircle,
        size: 20,
        color: Colors.green.shade400,
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Text(
          label,
          style: TextStyle(
            fontSize: 17,
            color: Colors.grey.shade300,
            height: 1.3,
          ),
        ),
      ),
    ],
  );
}

class _LevelingIntroScreen extends StatefulWidget {
  const _LevelingIntroScreen({required this.onContinue});

  final Future<void> Function() onContinue;

  @override
  State<_LevelingIntroScreen> createState() => _LevelingIntroScreenState();
}

class _LevelingIntroScreenState extends State<_LevelingIntroScreen> {
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final isGlass =
        Provider.of<ThemeProvider>(context, listen: false).isGlassTheme;
    final accent = Theme.of(context).colorScheme.primary;

    return GlassApp(
      child: Scaffold(
        backgroundColor: isGlass
            ? Colors.transparent
            : Theme.of(context).colorScheme.surface,
        appBar: AppBar(
          backgroundColor: isGlass
              ? Colors.transparent
              : Theme.of(context).colorScheme.surface,
          elevation: 0,
          automaticallyImplyLeading: false,
          title: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                PhosphorIcons.magicWand(),
                color: accent,
              ),
              const SizedBox(width: 8),
              Text(
                FlutterI18n.translate(context, 'leveling.assisted'),
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
          centerTitle: true,
        ),
        body: SafeArea(
          child: Padding(
            padding: OrionSpacing.screenPaddingNoTop,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                GlassCard(
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: OrionSpacing.cardPadding,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          FlutterI18n.translate(
                              context, 'leveling.introMessage'),
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          FlutterI18n.translate(
                              context, 'leveling.introDetail'),
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey.shade300,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 85),
              ],
            ),
          ),
        ),
        floatingActionButton: Padding(
          padding: OrionSpacing.screenPaddingNoTop,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              GlassFloatingActionButton.extended(
                heroTag: 'intro-cancel',
                tint: GlassButtonTint.negative,
                icon: Icon(PhosphorIcons.x()),
                iconAfterLabel: false,
                scale: 1.3,
                label: FlutterI18n.translate(context, 'common.cancel'),
                onPressed:
                    _isLoading ? null : () => Navigator.of(context).pop(),
              ),
              GlassFloatingActionButton.extended(
                heroTag: 'intro-continue',
                tint: GlassButtonTint.positive,
                icon: _isLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          color: Colors.white,
                        ),
                      )
                    : PhosphorIcon(PhosphorIcons.arrowRight()),
                iconAfterLabel: !_isLoading,
                scale: 1.3,
                label: _isLoading
                    ? FlutterI18n.translate(context, 'leveling.starting')
                    : FlutterI18n.translate(context, 'leveling.startLeveling'),
                onPressed: _isLoading
                    ? null
                    : () async {
                        setState(() => _isLoading = true);
                        await widget.onContinue();
                        if (mounted) {
                          setState(() => _isLoading = false);
                        }
                      },
              ),
            ],
          ),
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      ),
    );
  }
}

class _LevelingGuideScreen extends StatefulWidget {
  const _LevelingGuideScreen({
    required this.guide,
    required this.onComplete,
  });

  final LevelingGuide guide;
  final VoidCallback onComplete;

  @override
  State<_LevelingGuideScreen> createState() => _LevelingGuideScreenState();
}

class _LevelingGuideScreenState extends State<_LevelingGuideScreen> {
  int _currentStep = 0;
  VideoPlayerController? _videoController;
  bool _videoInitialized = false;
  bool _isRestarting = false;

  @override
  void initState() {
    super.initState();
    _loadStep(_currentStep);
  }

  @override
  void dispose() {
    _videoController?.removeListener(_videoListener);
    _videoController?.dispose();
    super.dispose();
  }

  void _videoListener() {
    final controller = _videoController;
    if (controller == null || !controller.value.isInitialized) return;

    if (controller.value.position >= controller.value.duration &&
        !controller.value.isPlaying &&
        !_isRestarting) {
      _isRestarting = true;
      Future.delayed(const Duration(seconds: 3), () async {
        if (!mounted || _videoController != controller) return;
        await controller.seekTo(Duration.zero);
        await controller.play();
        _isRestarting = false;
      });
    }
  }

  Future<void> _loadStep(int stepIndex) async {
    final oldController = _videoController;
    if (oldController != null) {
      oldController.removeListener(_videoListener);
      await oldController.dispose();
    }

    if (stepIndex < 0 || stepIndex >= widget.guide.steps.length) return;

    final step = widget.guide.steps[stepIndex];
    final controller = VideoPlayerController.asset(step.videoPath);

    setState(() {
      _videoController = controller;
      _videoInitialized = false;
      _isRestarting = false;
    });

    try {
      await controller.initialize();
      controller.addListener(_videoListener);

      if (mounted) {
        setState(() {
          _videoInitialized = true;
        });
      }

      await Future.delayed(const Duration(seconds: 2));
      if (mounted && _videoController == controller) {
        await controller.play();
      }
    } catch (e) {
      debugPrint('Error loading video ${step.videoPath}: $e');
    }
  }

  void _nextStep() {
    if (_currentStep < widget.guide.steps.length - 1) {
      setState(() {
        _currentStep++;
      });
      _loadStep(_currentStep);
    } else {
      widget.onComplete();
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
      });
      _loadStep(_currentStep);
    } else {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isGlass =
        Provider.of<ThemeProvider>(context, listen: false).isGlassTheme;
    final accent = Theme.of(context).colorScheme.primary;
    final step = widget.guide.steps[_currentStep];

    return GlassApp(
      child: Scaffold(
        backgroundColor: isGlass
            ? Colors.transparent
            : Theme.of(context).colorScheme.surface,
        appBar: AppBar(
          backgroundColor: isGlass
              ? Colors.transparent
              : Theme.of(context).colorScheme.surface,
          elevation: 0,
          automaticallyImplyLeading: false,
          title: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                PhosphorIcons.magicWand(),
                color: accent,
              ),
              const SizedBox(width: 8),
              Text(
                FlutterI18n.translate(context, 'leveling.guideProgress',
                    translationParams: {
                      'step': (_currentStep + 1).toString(),
                      'total': widget.guide.steps.length.toString()
                    }),
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
          centerTitle: true,
        ),
        body: SafeArea(
          child: Padding(
            padding: OrionSpacing.screenPaddingNoTop,
            child: Column(
              children: [
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Left: Video
                      Expanded(
                        flex: 1,
                        child: GlassCard(
                          margin: EdgeInsets.zero,
                          child: ClipRRect(
                            borderRadius:
                                BorderRadius.circular(glassCornerRadius),
                            child: Container(
                              color: Colors.black,
                              child: _videoInitialized &&
                                      _videoController != null
                                  ? SizedBox.expand(
                                      child: FittedBox(
                                        fit: BoxFit.cover,
                                        child: SizedBox(
                                          width: _videoController!
                                              .value.size.width,
                                          height: _videoController!
                                              .value.size.height,
                                          child: VideoPlayer(_videoController!),
                                        ),
                                      ),
                                    )
                                  : const Center(
                                      child: CircularProgressIndicator(),
                                    ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Right: Text
                      Expanded(
                        flex: 1,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              child: GlassCard(
                                margin: EdgeInsets.zero,
                                child: Padding(
                                  padding: OrionSpacing.cardPadding,
                                  child: Center(
                                    child: SingleChildScrollView(
                                      child: Text(
                                        step.text,
                                        style: const TextStyle(
                                          fontSize: 24,
                                          height: 1.5,
                                          color: Colors.white,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 85),
              ],
            ),
          ),
        ),
        floatingActionButton: Padding(
          padding: OrionSpacing.screenPaddingNoTop,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              GlassFloatingActionButton.extended(
                heroTag: 'guide-back',
                tint: GlassButtonTint.neutral,
                icon: Icon(PhosphorIcons.arrowLeft()),
                iconAfterLabel: false,
                scale: 1.3,
                label: FlutterI18n.translate(context, 'common.back'),
                onPressed: _prevStep,
              ),
              GlassFloatingActionButton.extended(
                heroTag: 'guide-next',
                tint: GlassButtonTint.positive,
                icon: Icon(
                  _currentStep == widget.guide.steps.length - 1
                      ? PhosphorIcons.check()
                      : PhosphorIcons.arrowRight(),
                ),
                iconAfterLabel: true,
                scale: 1.3,
                label: _currentStep == widget.guide.steps.length - 1
                    ? FlutterI18n.translate(context, 'common.done')
                    : FlutterI18n.translate(context, 'leveling.next'),
                onPressed: _nextStep,
              ),
            ],
          ),
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      ),
    );
  }
}

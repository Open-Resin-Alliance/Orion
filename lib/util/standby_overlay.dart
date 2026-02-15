/*
* Orion - Standby Overlay
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

import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:orion/backend_service/providers/status_provider.dart';
import 'package:orion/backend_service/providers/standby_settings_provider.dart';
import 'package:orion/util/orion_config.dart';
import 'dart:ui' as ui;

/// A fullscreen standby overlay that appears after a period of inactivity.
/// Shows a bold clock in the accent color on a black background.
class StandbyOverlay extends StatefulWidget {
  final Widget child;
  final bool enabled;
  final Duration inactivityDuration;

  const StandbyOverlay({
    super.key,
    required this.child,
    this.enabled = true,
    this.inactivityDuration = const Duration(minutes: 2, seconds: 30),
  });

  @override
  State<StandbyOverlay> createState() => _StandbyOverlayState();
}

class _StandbyOverlayState extends State<StandbyOverlay>
    with TickerProviderStateMixin {
  Timer? _inactivityTimer;
  bool _isStandbyActive = false;
  bool _standbyThrottled = false;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  Timer? _clockUpdateTimer;
  String _currentTime = '';

  // DVD-logo bounce state
  Ticker? _bounceTicker;
  double _logoX = 0;
  double _logoY = 0;
  double _logoDx = 0.6; // pixels per frame at ~60fps
  double _logoDy = 0.45;
  bool _bounceInitialized = false;
  static const double _logoSize = 180;
  Color _logoTint = Colors.white;
  late String _logoAssetPath;

  // Dimming variables
  late AnimationController _dimmingController;
  late Animation<double> _dimmingAnimation;
  int _originalBrightness = 255;
  int _dimmingStartBrightness = 255;
  bool _capturedOriginalBrightness = false;
  static const int _minBrightness = 13; // 5% of 255

  // Finished celebration state
  bool _celebrationActive = false;
  bool _celebrationCompleted = false;
  bool _wasPrinting = false;
  bool _wasPrintingOrPaused = false;
  bool _celebrationStartScheduled = false;
  Timer? _celebrationTimer;
  late AnimationController _fireworksController;
  late AnimationController _checkmarkController;
  late Animation<double> _checkmarkScale;
  late Animation<double> _checkmarkFade;
  final List<_FireworkBurst> _fireworkBursts = [];

  // Canceled state
  bool _canceledActive = false;
  bool _canceledCompleted = false;
  bool _canceledStartScheduled = false;
  Timer? _canceledTimer;
  late AnimationController _cancelIconController;
  late Animation<double> _cancelIconScale;
  late Animation<double> _cancelIconFade;
  late AnimationController _cancelShakeController;
  late AnimationController _cancelLayersController;
  final List<_CancelLayerSlice> _cancelLayerSlices = [];

  // Paused pulse
  late AnimationController _pausePulseController;

  // Track previous settings to detect changes
  bool? _prevStandbyEnabled;
  int? _prevDurationSeconds;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    );

    // Dimming animation controller (3 seconds for smooth dim)
    _dimmingController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    );
    _dimmingAnimation = CurvedAnimation(
      parent: _dimmingController,
      curve: Curves.easeInOut,
    );
    _dimmingAnimation.addListener(_handleDimmingTick);

    _fireworksController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _checkmarkController = AnimationController(
      duration: const Duration(milliseconds: 900),
      vsync: this,
    );
    _checkmarkScale = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _checkmarkController, curve: Curves.elasticOut),
    );
    _checkmarkFade = CurvedAnimation(
      parent: _checkmarkController,
      curve: const Interval(0.0, 0.7, curve: Curves.easeOut),
    );
    _initFireworks();

    // Canceled icon entrance
    _cancelIconController = AnimationController(
      duration: const Duration(milliseconds: 700),
      vsync: this,
    );
    _cancelIconScale = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _cancelIconController, curve: Curves.elasticOut),
    );
    _cancelIconFade = CurvedAnimation(
      parent: _cancelIconController,
      curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
    );
    // Subtle shake
    _cancelShakeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    // Falling cancel layers animation (loops for duration of cancel display)
    _cancelLayersController = AnimationController(
      duration: const Duration(seconds: 4),
      vsync: this,
    );
    _initCancelLayers();

    // Pause pulse
    _pausePulseController = AnimationController(
      duration: const Duration(milliseconds: 1400),
      vsync: this,
    );

    _updateTime();
    _resetInactivityTimer();
    _resolveLogoAsset();
  }

  @override
  void dispose() {
    _inactivityTimer?.cancel();
    _clockUpdateTimer?.cancel();
    _bounceTicker?.dispose();
    _celebrationTimer?.cancel();
    _canceledTimer?.cancel();
    _fadeController.dispose();
    _dimmingController.dispose();
    _fireworksController.dispose();
    _checkmarkController.dispose();
    _cancelIconController.dispose();
    _cancelShakeController.dispose();
    _cancelLayersController.dispose();
    _pausePulseController.dispose();
    super.dispose();
  }

  void _resetInactivityTimer() {
    _inactivityTimer?.cancel();
    // Get current settings from provider if available
    if (context.mounted) {
      final standbySettings =
          Provider.of<StandbySettingsProvider>(context, listen: false);
      if (standbySettings.standbyEnabled) {
        _inactivityTimer = Timer(
            Duration(seconds: standbySettings.durationSeconds),
            _activateStandby);
      }
    }
  }

  void _activateStandby() {
    if (!context.mounted) return;

    final standbySettings =
        Provider.of<StandbySettingsProvider>(context, listen: false);

    if (!_isStandbyActive && widget.enabled && standbySettings.standbyEnabled) {
      setState(() {
        _isStandbyActive = true;
      });
      _fadeController.forward();
      _startClockUpdate();
      _startBounce();
      _startDimming(); // Will check dimming config internally
      // Throttle background status polling while in standby if not printing.
      final statusProvider =
          Provider.of<StatusProvider>(context, listen: false);
      final isPrinting = statusProvider.status?.isPrinting ?? false;
      _syncStandbyThrottling(statusProvider, isPrinting);
    }
  }

  void _deactivateStandby() {
    if (_isStandbyActive) {
      // Speed up the fade-out (return to app) significantly
      _fadeController
          .animateTo(
        0.0,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      )
          .then((_) {
        if (mounted) {
          setState(() {
            _isStandbyActive = false;
          });
        }
        _resetCelebrationState(resetCompleted: true);
        _resetCanceledState(resetCompleted: true);
        _stopDimming();
      });
      _stopClockUpdate();
      _stopBounce();
      // Resume status polling when leaving standby.
      final statusProvider =
          Provider.of<StatusProvider>(context, listen: false);
      _syncStandbyThrottling(statusProvider, false, forceResume: true);
      _resetInactivityTimer();
    }
  }

  void _syncStandbyThrottling(StatusProvider statusProvider, bool isActiveJob,
      {bool forceResume = false}) {
    if (!_isStandbyActive || forceResume) {
      if (_standbyThrottled) {
        statusProvider.exitStandbyMode();
        _standbyThrottled = false;
      }
      return;
    }

    // When idle in standby, switch to slow polling so we still detect
    // remotely-started prints.
    if (!isActiveJob && !_standbyThrottled) {
      statusProvider.enterStandbyMode();
      _standbyThrottled = true;
    } else if (isActiveJob && _standbyThrottled) {
      // Active job detected — restore full-speed polling / SSE.
      statusProvider.exitStandbyMode();
      _standbyThrottled = false;
    }
  }

  void _handleUserInteraction() {
    if (_isStandbyActive) {
      _deactivateStandby();
    } else {
      _resetInactivityTimer();
    }
  }

  void _startClockUpdate() {
    _updateTime();
    // Update once per second to flip immediately at minute boundaries
    _clockUpdateTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _updateTime();
    });
  }

  void _stopClockUpdate() {
    _clockUpdateTimer?.cancel();
    _clockUpdateTimer = null;
  }

  void _updateTime() {
    if (mounted) {
      setState(() {
        // Show hours and minutes only
        _currentTime = DateFormat('HH:mm').format(DateTime.now());
      });
    }
  }

  void _handleDimmingTick() {
    final progress = _dimmingAnimation.value;
    final currentBrightness =
        (_dimmingStartBrightness * (1 - progress) + _minBrightness * progress)
            .toInt();
    _writeBrightness(currentBrightness);
  }

  String _getBacklightDevice() {
    if (context.mounted) {
      final standbySettings =
          Provider.of<StandbySettingsProvider>(context, listen: false);
      return standbySettings.backlightDevice;
    }
    return '';
  }

  String _getBrightnessPath() {
    final device = _getBacklightDevice();
    if (device.isEmpty) return '';
    return '/sys/class/backlight/$device/brightness';
  }

  Future<int> _readBrightness() async {
    try {
      final path = _getBrightnessPath();
      if (path.isEmpty) return 255;

      final file = File(path);
      if (!await file.exists()) return 255;

      final contents = await file.readAsString();
      return int.tryParse(contents.trim()) ?? 255;
    } catch (e) {
      print('Error reading brightness: $e');
      return 255;
    }
  }

  Future<void> _writeBrightness(int level) async {
    try {
      final path = _getBrightnessPath();
      if (path.isEmpty) return;

      // Try writing directly first (in case permissions are already set)
      try {
        final file = File(path);
        await file.writeAsString(level.toString());
        return;
      } catch (_) {
        // Direct write failed, try with sudo
      }

      // Fall back to sudo method
      try {
        final process = await Process.start('sudo', ['tee', path]);
        process.stdin.writeln(level.toString());
        await process.stdin.close();
        await process.exitCode;
        // Don't treat non-zero exit code as error - some systems may have issues
        // but we still want to continue dimming
      } catch (e) {
        print('Brightness write skipped: $e');
      }
    } catch (e) {
      print('Error writing brightness: $e');
    }
  }

  Future<void> _startDimming() async {
    try {
      if (!context.mounted) return;

      final standbySettings =
          Provider.of<StandbySettingsProvider>(context, listen: false);
      if (!standbySettings.dimmingEnabled) return; // Dimming not enabled, skip

      // Read current brightness for this dimming pass
      _dimmingStartBrightness = await _readBrightness();
      if (!_capturedOriginalBrightness) {
        _originalBrightness = _dimmingStartBrightness;
        _capturedOriginalBrightness = true;
      }

      // Start the dimming animation
      await _dimmingController.forward(from: 0.0);
    } catch (e) {
      print('Error starting dimming: $e');
    }
  }

  Future<void> _stopDimming() async {
    try {
      // Stop animation
      _dimmingController.stop();
      _dimmingController.reset();

      // Instantly restore brightness
      await _writeBrightness(_originalBrightness);
      _capturedOriginalBrightness = false;
    } catch (e) {
      print('Error stopping dimming: $e');
    }
  }

  void _pauseDimmingForCelebration() {
    _dimmingController.stop();
    _dimmingController.reset();
  }

  Future<void> _boostBrightnessForCelebration() async {
    try {
      _pauseDimmingForCelebration();
      await _writeBrightness(255);
    } catch (e) {
      print('Error boosting brightness: $e');
    }
  }

  void _initFireworks() {
    _fireworkBursts.clear();
    final rand = math.Random();

    // Rich palette — warm golds, cool cyans, greens, pinks, with varied
    // saturation so it doesn't look flat.
    final palettes = <List<Color>>[
      [const Color(0xFF00E676), const Color(0xFF69F0AE), const Color(0xFFB9F6CA)],
      [const Color(0xFF00BCD4), const Color(0xFF84FFFF), const Color(0xFFE0F7FA)],
      [const Color(0xFFFFD740), const Color(0xFFFFAB40), const Color(0xFFFFF8E1)],
      [const Color(0xFFFF4081), const Color(0xFFFF80AB), const Color(0xFFFCE4EC)],
      [const Color(0xFF7C4DFF), const Color(0xFFB388FF), const Color(0xFFEDE7F6)],
      [const Color(0xFF00E5FF), const Color(0xFF18FFFF), const Color(0xFFE0F7FA)],
    ];

    // 10 bursts spread across the full screen, with staggered delays
    for (var i = 0; i < 10; i++) {
      // Place bursts using a scattered grid so they cover the display
      // fractional x: 0.1..0.9, fractional y: 0.15..0.85
      final fx = 0.1 + rand.nextDouble() * 0.8;
      final fy = 0.15 + rand.nextDouble() * 0.7;
      final palette = palettes[rand.nextInt(palettes.length)];

      // Stagger burst timing across the 0..1 animation cycle
      final delay = (i / 10) * 0.55 + rand.nextDouble() * 0.15;

      // 28-40 particles per burst for density
      final count = 28 + rand.nextInt(13);
      final particles = List.generate(count, (_) {
        final angle = rand.nextDouble() * 2 * math.pi;
        final speed = 0.6 + rand.nextDouble() * 0.8; // varied speeds
        final radius = 80.0 + rand.nextDouble() * 140.0;
        final size = 2.0 + rand.nextDouble() * 5.0;
        final color = palette[rand.nextInt(palette.length)];
        // Individual fade jitter so particles don't all vanish at once
        final fadeStart = 0.3 + rand.nextDouble() * 0.35;
        return _FireworkParticle(
          angle: angle,
          radius: radius,
          color: color,
          speed: speed,
          size: size,
          fadeStart: fadeStart,
          gravity: 40.0 + rand.nextDouble() * 60.0,
        );
      });

      _fireworkBursts.add(_FireworkBurst(
        fractionalX: fx,
        fractionalY: fy,
        particles: particles,
        delay: delay,
      ));
    }
  }

  void _scheduleCelebrationStart() {
    if (_celebrationStartScheduled || _celebrationActive) return;
    _celebrationStartScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _celebrationStartScheduled = false;
      if (!_celebrationActive) _startCelebration();
    });
  }

  void _startCelebration() {
    if (!mounted) return;
    _initFireworks(); // re-randomise each time
    setState(() {
      _celebrationActive = true;
      _celebrationCompleted = false;
    });
    _celebrationTimer?.cancel();
    _checkmarkController.forward(from: 0.0);
    _fireworksController.repeat(period: const Duration(seconds: 3));
    _boostBrightnessForCelebration();
    _celebrationTimer = Timer(const Duration(seconds: 20), _endCelebration);
  }

  void _endCelebration() {
    if (!mounted) return;
    _fireworksController.stop();
    setState(() {
      _celebrationActive = false;
      _celebrationCompleted = true;
    });

    if (context.mounted) {
      final standbySettings =
          Provider.of<StandbySettingsProvider>(context, listen: false);
      if (_isStandbyActive && standbySettings.dimmingEnabled) {
        _startDimming();
      }
    }
  }

  void _resetCelebrationState({bool resetCompleted = false}) {
    _celebrationTimer?.cancel();
    _fireworksController.stop();
    _checkmarkController.reset();
    _celebrationStartScheduled = false;
    if (!mounted) return;
    setState(() {
      _celebrationActive = false;
      if (resetCompleted) {
        _celebrationCompleted = false;
      }
    });
  }

  // --- Canceled state helpers ---

  void _scheduleCanceledStart() {
    if (_canceledStartScheduled || _canceledActive) return;
    _canceledStartScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _canceledStartScheduled = false;
      if (!_canceledActive) _startCanceled();
    });
  }

  void _startCanceled() {
    if (!mounted) return;
    _initCancelLayers(); // re-randomise each time
    setState(() {
      _canceledActive = true;
      _canceledCompleted = false;
    });
    _canceledTimer?.cancel();
    _cancelIconController.forward(from: 0.0);
    _cancelShakeController.forward(from: 0.0);
    _cancelLayersController.repeat();
    // Show for 10 seconds then crossfade to clock
    _canceledTimer = Timer(const Duration(seconds: 10), _endCanceled);
  }

  void _endCanceled() {
    if (!mounted) return;
    setState(() {
      _canceledActive = false;
      _canceledCompleted = true;
    });

    if (context.mounted) {
      final standbySettings =
          Provider.of<StandbySettingsProvider>(context, listen: false);
      if (_isStandbyActive && standbySettings.dimmingEnabled) {
        _startDimming();
      }
    }
  }

  void _resetCanceledState({bool resetCompleted = false}) {
    _canceledTimer?.cancel();
    _cancelIconController.reset();
    _cancelShakeController.reset();
    _cancelLayersController.stop();
    _cancelLayersController.reset();
    _canceledStartScheduled = false;
    if (!mounted) return;
    setState(() {
      _canceledActive = false;
      if (resetCompleted) {
        _canceledCompleted = false;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Consume StatusProvider to check if a print is active
    // Also consume StandbySettingsProvider to react to setting changes
    return Consumer2<StatusProvider, StandbySettingsProvider>(
      builder: (ctx, statusProvider, standbySettings, child) {
        // Check if standby settings have changed, and only reset timer if so
        if (_prevStandbyEnabled != standbySettings.standbyEnabled ||
            _prevDurationSeconds != standbySettings.durationSeconds) {
          _prevStandbyEnabled = standbySettings.standbyEnabled;
          _prevDurationSeconds = standbySettings.durationSeconds;

          // Reset timer on next frame when settings change
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _resetInactivityTimer();
          });
        }

        final isPrinting = statusProvider.status?.isPrinting ?? false;
        final isPaused = statusProvider.status?.isPaused ?? false;
        final isPausing = statusProvider.isPausing;
        final isCancelingTransition = statusProvider.isCanceling;
        final status = statusProvider.status;
        // A print was canceled if either the model's isCanceled flag is set
        // (layer == null after a job) OR the cancel_latched hint from the
        // state handler is present (cancel mid-print where layer data remains).
        final isCanceled = (status?.isCanceled ?? false) ||
            (status?.cancelLatched == true);
        final isFinished = status != null &&
            status.isIdle &&
            status.layer != null &&
            !isCanceled;
        final progress = statusProvider.status?.progress ?? 0.0;
        // Treat transitional states as active for throttling purposes.
        final isActiveJob =
            isPrinting || isPaused || isPausing || isCancelingTransition;
        _syncStandbyThrottling(statusProvider, isActiveJob);

        // Manage pause pulse animation
        if ((isPaused || isPausing) && _isStandbyActive) {
          if (!_pausePulseController.isAnimating) {
            _pausePulseController.repeat(reverse: true);
          }
        } else {
          if (_pausePulseController.isAnimating) {
            _pausePulseController.stop();
            _pausePulseController.reset();
          }
        }

        if (_isStandbyActive) {
          // A new print started — reset any celebration/canceled overlays.
          if (isPrinting &&
              (_celebrationActive ||
                  _celebrationCompleted ||
                  _canceledActive ||
                  _canceledCompleted)) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                _resetCelebrationState(resetCompleted: true);
                _resetCanceledState(resetCompleted: true);
              }
            });
          }
          // Detect print finished (was printing → now finished).
          else if (!_celebrationActive &&
              !_celebrationCompleted &&
              _wasPrinting &&
              isFinished) {
            _scheduleCelebrationStart();
          }
          // Detect canceled (was printing/paused → now canceled).
          else if (!_canceledActive &&
              !_canceledCompleted &&
              !_celebrationActive &&
              _wasPrintingOrPaused &&
              isCanceled) {
            _scheduleCanceledStart();
          }
        }
        _wasPrinting = isPrinting;
        _wasPrintingOrPaused =
            isPrinting || isPaused || isPausing || isCancelingTransition;

        final Widget standbyContent;
        if (_celebrationActive) {
          standbyContent = _buildFinishedCelebration(ctx);
        } else if (_canceledActive) {
          standbyContent = _buildCanceledDisplay(ctx);
        } else if (_celebrationCompleted || _canceledCompleted) {
          standbyContent = Center(child: _buildClockDisplay(ctx));
        } else if (isPaused || isPausing) {
          standbyContent =
              Center(child: _buildPausedIndicator(ctx, progress));
        } else if (isPrinting) {
          standbyContent =
              Center(child: _buildProgressIndicator(ctx, progress));
        } else if (isCancelingTransition) {
          // During cancel transition, keep showing the progress ring
          // so the UI doesn't flash the clock before the canceled overlay.
          standbyContent =
              Center(child: _buildProgressIndicator(ctx, progress));
        } else {
          standbyContent = standbySettings.standbyMode == 'logo'
              ? _buildLogoDisplay(ctx)
              : Center(child: _buildClockDisplay(ctx));
        }

        return Listener(
          onPointerDown: (_) => _handleUserInteraction(),
          onPointerMove: (_) => _handleUserInteraction(),
          onPointerUp: (_) => _handleUserInteraction(),
          child: Stack(
            children: [
              widget.child,
              if (_isStandbyActive)
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: GestureDetector(
                    onTap: _deactivateStandby,
                    child: Container(
                      color: Colors.black,
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 600),
                        switchInCurve: Curves.easeOut,
                        switchOutCurve: Curves.easeIn,
                        child: KeyedSubtree(
                          key: ValueKey<String>(
                            _celebrationActive
                                ? 'celebration'
                                : _canceledActive
                                    ? 'canceled'
                                    : (_celebrationCompleted ||
                                            _canceledCompleted)
                                        ? 'state-complete'
                                        : (isPaused || isPausing)
                                            ? 'paused'
                                            : (isPrinting ||
                                                    isCancelingTransition)
                                                ? 'printing'
                                                : standbySettings
                                                    .standbyMode,
                          ),
                          child: standbyContent,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  void _resolveLogoAsset() {
    try {
      final config = OrionConfig();
      final vendorLogo =
          config.getString('vendorLogo', category: 'vendor').toLowerCase().trim();
      switch (vendorLogo) {
        case 'c3d':
          _logoAssetPath = 'assets/images/concepts_3d/c3d.svg';
          break;
        case 'athena':
          _logoAssetPath = 'assets/images/concepts_3d/athena_logo.svg';
          break;
        case 'ora':
        default:
          _logoAssetPath = 'assets/images/ora/open_resin_alliance_logo_darkmode.png';
      }
    } catch (_) {
      _logoAssetPath = 'assets/images/ora/open_resin_alliance_logo_darkmode.png';
    }
  }

  void _startBounce() {
    _bounceInitialized = false;
    _bounceTicker?.dispose();
    _bounceTicker = createTicker(_onBounceTick)..start();
  }

  void _stopBounce() {
    _bounceTicker?.stop();
    _bounceTicker?.dispose();
    _bounceTicker = null;
    _bounceInitialized = false;
  }

  Color _randomAccentColor() {
    final rand = math.Random();
    // Softer pastel colors: lower saturation, higher lightness
    final hue = rand.nextDouble() * 360;
    return HSLColor.fromAHSL(1.0, hue, 0.45, 0.78).toColor();
  }

  void _onBounceTick(Duration elapsed) {
    if (!mounted) return;

    final size = MediaQuery.of(context).size;
    final maxX = size.width - _logoSize;
    final maxY = size.height - _logoSize;

    if (!_bounceInitialized) {
      // Start from a random position
      final rand = math.Random();
      _logoX = rand.nextDouble() * maxX.clamp(0, double.infinity);
      _logoY = rand.nextDouble() * maxY.clamp(0, double.infinity);
      _logoTint = _randomAccentColor();
      _bounceInitialized = true;
    }

    _logoX += _logoDx;
    _logoY += _logoDy;

    bool bounced = false;
    if (_logoX <= 0) {
      _logoX = 0;
      _logoDx = _logoDx.abs();
      bounced = true;
    } else if (_logoX >= maxX) {
      _logoX = maxX;
      _logoDx = -_logoDx.abs();
      bounced = true;
    }

    if (_logoY <= 0) {
      _logoY = 0;
      _logoDy = _logoDy.abs();
      bounced = true;
    } else if (_logoY >= maxY) {
      _logoY = maxY;
      _logoDy = -_logoDy.abs();
      bounced = true;
    }

    if (bounced) {
      _logoTint = _randomAccentColor();
    }

    setState(() {});
  }

  Widget _buildLogoDisplay(BuildContext context) {
    final logoWidget = _logoAssetPath.endsWith('.svg')
        ? SvgPicture.asset(
            _logoAssetPath,
            width: _logoSize,
            height: _logoSize,
            colorFilter: ColorFilter.mode(_logoTint, BlendMode.srcIn),
          )
        : Image.asset(
            _logoAssetPath,
            width: _logoSize,
            height: _logoSize,
            color: _logoTint,
          );

    return Stack(
      children: [
        Positioned(
          left: _logoX,
          top: _logoY,
          child: SizedBox(
            width: _logoSize,
            height: _logoSize,
            child: logoWidget,
          ),
        ),
      ],
    );
  }

  Widget _buildClockDisplay(BuildContext context) {
    final accentColor = Theme.of(context).colorScheme.primary;

    return Transform(
      alignment: Alignment.center,
      // Barlow Condensed is already tall; add a gentle extra vertical stretch
      transform: Matrix4.diagonal3Values(1.0, 1.25, 1.0),
      child: ShaderMask(
        blendMode: BlendMode.srcIn,
        shaderCallback: (bounds) {
          return LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color.lerp(accentColor, Colors.white, 0.35)!,
              accentColor,
              Color.lerp(accentColor, Colors.black, 0.4)!,
            ],
            stops: const [0.0, 0.45, 1.0],
          ).createShader(bounds);
        },
        child: Text(
          _currentTime,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'AtkinsonHyperlegible',
            fontSize: 150,
            fontWeight: FontWeight.w500,
            color: Colors.white,
            letterSpacing: 2,
            decoration: TextDecoration.none,
            // Use tabular figures so digits/colon align nicely
            fontFeatures: const [ui.FontFeature.tabularFigures()],
            // Subtle glow/shadow for readability on pure black
            shadows: [
              Shadow(
                blurRadius: 8,
                color: Colors.black.withAlpha((0.5 * 255).toInt()),
                offset: const Offset(0, 2),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProgressIndicator(BuildContext context, double progress) {
    final percentage = (progress * 100).toStringAsFixed(0);
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Stack(
      alignment: Alignment.center,
      children: [
        SizedBox(
          width: 340,
          height: 340,
          child: CircularProgressIndicator(
            value: progress,
            strokeWidth: 14,
            strokeCap: StrokeCap.round,
            valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
            backgroundColor: Color.lerp(primaryColor, Colors.black, 0.9)!,
          ),
        ),
        Text(
          '$percentage%',
          style: TextStyle(
            fontFamily: 'AtkinsonHyperlegible',
            fontSize: 100,
            fontWeight: FontWeight.w500,
            color: primaryColor,
            decoration: TextDecoration.none,
            fontFeatures: const [ui.FontFeature.tabularFigures()],
            shadows: [
              Shadow(
                blurRadius: 8,
                color: Colors.black.withAlpha((0.5 * 255).toInt()),
                offset: const Offset(0, 2),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPausedIndicator(BuildContext context, double progress) {
    final percentage = (progress * 100).toStringAsFixed(0);
    const pauseColor = Colors.orange;

    return AnimatedBuilder(
      animation: _pausePulseController,
      builder: (context, child) {
        // Gentle pulse: icon opacity oscillates 0.55 ↔ 1.0
        final pulse =
            0.55 + 0.45 * _pausePulseController.value;

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Pulsing pause icon
            Opacity(
              opacity: pulse,
              child: const Icon(
                Icons.pause_circle_filled,
                size: 160,
                color: pauseColor,
              ),
            ),
            const SizedBox(height: 28),
            // Percentage below the icon
            Text(
              '$percentage%',
              style: TextStyle(
                fontFamily: 'AtkinsonHyperlegible',
                fontSize: 48,
                fontWeight: FontWeight.w500,
                color: pauseColor.withValues(alpha: 0.7),
                decoration: TextDecoration.none,
                fontFeatures: const [ui.FontFeature.tabularFigures()],
              ),
            ),
          ],
        );
      },
    );
  }

  void _initCancelLayers() {
    _cancelLayerSlices.clear();
    final rand = math.Random();

    // Colour palette: reds, dark greys, and dull oranges — like charred layers
    final colors = <Color>[
      const Color(0xFFD32F2F),
      const Color(0xFFB71C1C),
      const Color(0xFFFF5252),
      const Color(0xFF424242),
      const Color(0xFF616161),
      const Color(0xFFBF360C),
      const Color(0xFF8D6E63),
      const Color(0xFF455A64),
    ];

    // Generate 35-45 layer slices that originate near the top
    final count = 35 + rand.nextInt(11);
    for (var i = 0; i < count; i++) {
      // Horizontal spread across the screen
      final fx = 0.05 + rand.nextDouble() * 0.9;
      // Originate in the upper 15% of the screen
      final fy = 0.02 + rand.nextDouble() * 0.13;

      // Horizontal velocity: gentle drift left or right
      final vx = (rand.nextDouble() - 0.5) * 120.0;
      // Downward velocity: varied so slices spread out vertically
      final vy = 60.0 + rand.nextDouble() * 200.0;

      // Rotation speed (radians/sec equivalent across 0..1 anim)
      final rotSpeed = (rand.nextDouble() - 0.5) * 8.0;

      // Slice dimensions: thin rectangles of varied width
      final width = 18.0 + rand.nextDouble() * 50.0;
      final height = 3.0 + rand.nextDouble() * 8.0;

      // Stagger: delay before this slice starts falling (0..0.35)
      final delay = rand.nextDouble() * 0.35;

      // Individual fade-out start: 0.45..0.75 through the cycle
      final fadeStart = 0.45 + rand.nextDouble() * 0.3;

      _cancelLayerSlices.add(_CancelLayerSlice(
        fractionalX: fx,
        fractionalY: fy,
        velocityX: vx,
        velocityY: vy,
        rotationSpeed: rotSpeed,
        width: width,
        height: height,
        color: colors[rand.nextInt(colors.length)],
        delay: delay,
        fadeStart: fadeStart,
      ));
    }
  }

  Widget _buildCanceledDisplay(BuildContext context) {
    return Stack(
      children: [
        // Falling layer slices behind everything
        Positioned.fill(
          child: AnimatedBuilder(
            animation: _cancelLayersController,
            builder: (context, child) {
              return CustomPaint(
                painter: _CancelLayersPainter(
                  animation: _cancelLayersController,
                  slices: _cancelLayerSlices,
                ),
                size: Size.infinite,
              );
            },
          ),
        ),
        // Subtle dark vignette behind the icon
        Center(
          child: Container(
            width: 260,
            height: 260,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  Colors.black,
                  Colors.black.withValues(alpha: 0.85),
                  Colors.black.withValues(alpha: 0.0),
                ],
                stops: const [0.0, 0.55, 1.0],
              ),
            ),
          ),
        ),
        // Cancel icon with shake
        AnimatedBuilder(
          animation: _cancelShakeController,
          builder: (context, child) {
            final shakeT = _cancelShakeController.value;
            final shake =
                math.sin(shakeT * math.pi * 6) * 12.0 * (1.0 - shakeT);

            return Center(
              child: Transform.translate(
                offset: Offset(shake, 0),
                child: FadeTransition(
                  opacity: _cancelIconFade,
                  child: ScaleTransition(
                    scale: _cancelIconScale,
                    child: Container(
                      width: 200,
                      height: 200,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.redAccent.withValues(alpha: 0.15),
                            blurRadius: 30,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.cancel,
                        size: 180,
                        color: Colors.redAccent,
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildFinishedCelebration(BuildContext context) {
    // Fireworks behind, then checkmark, then a second fireworks layer clipped
    // to avoid the centre so particles never render on top of the icon.
    return Stack(
      children: [
        // Background fireworks layer
        Positioned.fill(
          child: AnimatedBuilder(
            animation: _fireworksController,
            builder: (context, child) {
              return CustomPaint(
                painter: _FireworksPainter(
                  animation: _fireworksController,
                  bursts: _fireworkBursts,
                ),
                size: Size.infinite,
              );
            },
          ),
        ),
        // Black vignette behind the checkmark so nearby particles fade out
        // rather than abruptly clipping.
        Center(
          child: Container(
            width: 260,
            height: 260,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  Colors.black,
                  Colors.black.withValues(alpha: 0.85),
                  Colors.black.withValues(alpha: 0.0),
                ],
                stops: const [0.0, 0.55, 1.0],
              ),
            ),
          ),
        ),
        // Checkmark icon
        Center(
          child: FadeTransition(
            opacity: _checkmarkFade,
            child: ScaleTransition(
              scale: _checkmarkScale,
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.greenAccent.withValues(alpha: 0.2),
                      blurRadius: 30,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.check_circle,
                  size: 180,
                  color: Colors.greenAccent,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _FireworkParticle {
  final double angle;
  final double radius;
  final Color color;
  final double speed;
  final double size;
  final double fadeStart;
  final double gravity;

  const _FireworkParticle({
    required this.angle,
    required this.radius,
    required this.color,
    this.speed = 1.0,
    this.size = 4.0,
    this.fadeStart = 0.5,
    this.gravity = 50.0,
  });
}

class _FireworkBurst {
  /// Position as a fraction of screen size (0..1).
  final double fractionalX;
  final double fractionalY;
  final List<_FireworkParticle> particles;
  /// Delay (0..1) within a single animation cycle before the burst fires.
  final double delay;

  const _FireworkBurst({
    required this.fractionalX,
    required this.fractionalY,
    required this.particles,
    this.delay = 0.0,
  });
}

class _CancelLayerSlice {
  final double fractionalX;
  final double fractionalY;
  final double velocityX;
  final double velocityY;
  final double rotationSpeed;
  final double width;
  final double height;
  final Color color;
  final double delay;
  final double fadeStart;

  const _CancelLayerSlice({
    required this.fractionalX,
    required this.fractionalY,
    required this.velocityX,
    required this.velocityY,
    required this.rotationSpeed,
    required this.width,
    required this.height,
    required this.color,
    this.delay = 0.0,
    this.fadeStart = 0.6,
  });
}

class _CancelLayersPainter extends CustomPainter {
  final Animation<double> animation;
  final List<_CancelLayerSlice> slices;

  _CancelLayersPainter({required this.animation, required this.slices})
      : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    final t = animation.value;
    final center = size.center(Offset.zero);
    const exclusionRadius = 130.0;

    for (final s in slices) {
      // Each slice has a staggered delay
      final localT = ((t - s.delay) % 1.0).clamp(0.0, 1.0);
      if (t < s.delay && t + 1.0 - s.delay > 1.0) continue;

      // Starting position
      final originX = size.width * s.fractionalX;
      final originY = size.height * s.fractionalY;

      // Apply velocity + gravity (accelerating downward)
      final gravity = 350.0; // pixels/sec² equivalent
      final posX = originX + s.velocityX * localT;
      final posY = originY + s.velocityY * localT + gravity * localT * localT;

      // Skip if off-screen
      if (posY > size.height + 50 || posX < -80 || posX > size.width + 80) {
        continue;
      }

      // Skip slices inside the icon exclusion zone
      final pos = Offset(posX, posY);
      if ((pos - center).distance < exclusionRadius) continue;

      // Rotation
      final rotation = s.rotationSpeed * localT;

      // Fade: fully visible until fadeStart, then fade out
      final fadeProgress = localT < s.fadeStart
          ? 1.0
          : 1.0 - ((localT - s.fadeStart) / (1.0 - s.fadeStart));
      final alpha = fadeProgress.clamp(0.0, 1.0);
      if (alpha <= 0.01) continue;

      canvas.save();
      canvas.translate(posX, posY);
      canvas.rotate(rotation);

      // Glow/shadow beneath the slice
      final glowPaint = Paint()
        ..color = s.color.withValues(alpha: 0.15 * alpha)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
      canvas.drawRect(
        Rect.fromCenter(center: Offset.zero, width: s.width + 4, height: s.height + 4),
        glowPaint,
      );

      // Core slice rectangle
      final slicePaint = Paint()
        ..color = s.color.withValues(alpha: 0.85 * alpha)
        ..style = PaintingStyle.fill;
      final rect = Rect.fromCenter(
        center: Offset.zero,
        width: s.width,
        height: s.height,
      );
      // Rounded corners to look like resin layers
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(1.5)),
        slicePaint,
      );

      // Subtle lighter edge highlight on top
      final highlightPaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.12 * alpha)
        ..style = PaintingStyle.fill;
      canvas.drawRect(
        Rect.fromLTWH(-s.width / 2, -s.height / 2, s.width, s.height * 0.3),
        highlightPaint,
      );

      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _CancelLayersPainter oldDelegate) => true;
}

class _FireworksPainter extends CustomPainter {
  final Animation<double> animation;
  final List<_FireworkBurst> bursts;

  _FireworksPainter({required this.animation, required this.bursts})
      : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    final t = animation.value;
    final center = size.center(Offset.zero);
    // Exclusion zone around the checkmark so particles never overlap it.
    const exclusionRadius = 130.0;

    for (final burst in bursts) {
      // Each burst has a staggered delay within the cycle.
      final localT = ((t - burst.delay) % 1.0).clamp(0.0, 1.0);
      // Burst is invisible before its delay fires within the cycle.
      if (t < burst.delay && t + 1.0 - burst.delay > 1.0) continue;

      final origin = Offset(
        size.width * burst.fractionalX,
        size.height * burst.fractionalY,
      );

      for (final p in burst.particles) {
        final pt = (localT * p.speed).clamp(0.0, 1.0);
        // Ease-out so particles decelerate naturally
        final eased = 1.0 - math.pow(1.0 - pt, 2.5);

        final distance = p.radius * eased;
        final dx = math.cos(p.angle) * distance;
        // Gravity pulls particles down over time
        final dy = math.sin(p.angle) * distance + p.gravity * pt * pt;

        final pos = origin + Offset(dx, dy);

        // Skip particles that would land inside the checkmark exclusion zone.
        if ((pos - center).distance < exclusionRadius) continue;

        // Per-particle fade: fully visible until fadeStart, then fade out
        final fadeProgress =
            pt < p.fadeStart ? 1.0 : 1.0 - ((pt - p.fadeStart) / (1.0 - p.fadeStart));
        final alpha = fadeProgress.clamp(0.0, 1.0);
        if (alpha <= 0.01) continue;

        // --- Glow layer (large, soft, translucent) ---
        final glowPaint = Paint()
          ..color = p.color.withValues(alpha: 0.18 * alpha)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
        canvas.drawCircle(pos, p.size * 3.0, glowPaint);

        // --- Core particle ---
        final corePaint = Paint()
          ..color = Color.lerp(Colors.white, p.color, 0.4 + 0.6 * pt)!
              .withValues(alpha: alpha)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(pos, p.size * (1.0 - 0.3 * pt), corePaint);

        // --- Sparkle trail (fading dots along the path) ---
        const trailSteps = 5;
        for (var s = 1; s <= trailSteps; s++) {
          final trailT = (pt - s * 0.04).clamp(0.0, 1.0);
          if (trailT <= 0.0) continue;
          final trailEased = 1.0 - math.pow(1.0 - trailT, 2.5);
          final td = p.radius * trailEased;
          final tdx = math.cos(p.angle) * td;
          final tdy = math.sin(p.angle) * td + p.gravity * trailT * trailT;
          final tpos = origin + Offset(tdx, tdy);
          final trailAlpha = alpha * (1.0 - s / (trailSteps + 1));
          final trailPaint = Paint()
            ..color = p.color.withValues(alpha: 0.45 * trailAlpha)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
          canvas.drawCircle(tpos, p.size * 0.5, trailPaint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _FireworksPainter oldDelegate) => true;
}

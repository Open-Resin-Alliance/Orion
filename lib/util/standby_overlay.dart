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
  static const int _minBrightness = 13; // 5% of 255

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

    _updateTime();
    _resetInactivityTimer();
    _resolveLogoAsset();
  }

  @override
  void dispose() {
    _inactivityTimer?.cancel();
    _clockUpdateTimer?.cancel();
    _bounceTicker?.dispose();
    _fadeController.dispose();
    _dimmingController.dispose();
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

  void _syncStandbyThrottling(StatusProvider statusProvider, bool isPrinting,
      {bool forceResume = false}) {
    if (!_isStandbyActive || forceResume) {
      if (_standbyThrottled) {
        statusProvider.resumePolling();
        _standbyThrottled = false;
      }
      return;
    }

    // Only pause polling in standby when not printing.
    if (!isPrinting && !_standbyThrottled) {
      statusProvider.pausePolling();
      _standbyThrottled = true;
    } else if (isPrinting && _standbyThrottled) {
      // If a print starts while in standby, resume polling so progress updates.
      statusProvider.resumePolling();
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

      // Read current brightness first
      _originalBrightness = await _readBrightness();

      // Listen to animation and update brightness
      _dimmingAnimation.addListener(() {
        final progress = _dimmingAnimation.value;
        final currentBrightness =
            (_originalBrightness * (1 - progress) + _minBrightness * progress)
                .toInt();
        _writeBrightness(currentBrightness);
      });

      // Start the dimming animation
      await _dimmingController.forward();
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
    } catch (e) {
      print('Error stopping dimming: $e');
    }
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
        final progress = statusProvider.status?.progress ?? 0.0;
        _syncStandbyThrottling(statusProvider, isPrinting);

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
                      child: isPrinting
                          ? Center(
                              child:
                                  _buildProgressIndicator(ctx, progress),
                            )
                          : standbySettings.standbyMode == 'logo'
                              ? _buildLogoDisplay(ctx)
                              : Center(child: _buildClockDisplay(ctx)),
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
}

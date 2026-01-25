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
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:orion/backend_service/providers/status_provider.dart';
import 'dart:ui' as ui;

/// A fullscreen standby overlay that appears after a period of inactivity.
/// Shows a bold clock in the accent color on a black background.
class StandbyOverlay extends StatefulWidget {
  final Widget child;
  final Duration inactivityDuration;

  const StandbyOverlay({
    super.key,
    required this.child,
    this.inactivityDuration = const Duration(minutes: 2, seconds: 30),
  });

  @override
  State<StandbyOverlay> createState() => _StandbyOverlayState();
}

class _StandbyOverlayState extends State<StandbyOverlay>
    with SingleTickerProviderStateMixin {
  Timer? _inactivityTimer;
  bool _isStandbyActive = false;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  Timer? _clockUpdateTimer;
  String _currentTime = '';

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
    _updateTime();
    _resetInactivityTimer();
  }

  @override
  void dispose() {
    _inactivityTimer?.cancel();
    _clockUpdateTimer?.cancel();
    _fadeController.dispose();
    super.dispose();
  }

  void _resetInactivityTimer() {
    _inactivityTimer?.cancel();
    _inactivityTimer = Timer(widget.inactivityDuration, _activateStandby);
  }

  void _activateStandby() {
    if (!_isStandbyActive) {
      setState(() {
        _isStandbyActive = true;
      });
      _fadeController.forward();
      _startClockUpdate();
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
      });
      _stopClockUpdate();
      _resetInactivityTimer();
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

  @override
  Widget build(BuildContext context) {
    // Consume StatusProvider to check if a print is active
    return Consumer<StatusProvider>(
      builder: (ctx, statusProvider, child) {
        final isPrinting = statusProvider.status?.isPrinting ?? false;
        final progress = statusProvider.status?.progress ?? 0.0;
        
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
                      child: Center(
                        child: isPrinting
                            ? _buildProgressIndicator(ctx, progress)
                            : _buildClockDisplay(ctx),
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

  Widget _buildClockDisplay(BuildContext context) {
    final primaryFamily = defaultTargetPlatform == TargetPlatform.linux
        ? 'AtkinsonHyperlegible'
        : 'AtkinsonHyperlegibleNext';
    const cjkFallback = ['AtkinsonHyperlegible', 'NotoSansSC', 'NotoSansJP', 'NotoSansKR'];
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
            fontFamily: primaryFamily,
            fontFamilyFallback: cjkFallback,
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
    final primaryFamily = defaultTargetPlatform == TargetPlatform.linux
        ? 'AtkinsonHyperlegible'
        : 'AtkinsonHyperlegibleNext';
    const cjkFallback = ['AtkinsonHyperlegible', 'NotoSansSC', 'NotoSansJP', 'NotoSansKR'];
    
    return Stack(
      alignment: Alignment.center,
      children: [
        SizedBox(
          width: 340,
          height: 340,
          child: CircularProgressIndicator(
            value: progress,
            strokeWidth: 14,
            valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
            backgroundColor: Color.lerp(primaryColor, Colors.black, 0.6)!,
          ),
        ),
        Text(
          '$percentage%',
          style: TextStyle(
            fontFamily: primaryFamily,
            fontFamilyFallback: cjkFallback,
            fontSize: 100,
            fontWeight: FontWeight.w500,
            color: primaryColor,
            letterSpacing: 2,
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

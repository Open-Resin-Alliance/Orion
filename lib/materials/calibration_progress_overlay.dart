/*
* Orion - Calibration Progress Overlay
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
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:orion/glasser/glasser.dart';
import 'package:provider/provider.dart';
import 'package:orion/util/providers/theme_provider.dart';

/// A full-screen modal overlay that displays calibration progress and messages.
/// Designed to be shown during calibration print preparation to inform the user of progress.

class CalibrationProgressOverlay extends StatefulWidget {
  /// Context of the active overlay for forced dismissal
  static BuildContext? _overlayContext;
  static final Logger _log = Logger('CalibrationProgressOverlay');
  static bool _shouldHide = false;

  /// Reset the overlay state when starting a new calibration
  static void reset() {
    _shouldHide = false;
    _overlayContext = null;
    _log.info('Overlay reset for new calibration');
  }

  /// Mark the overlay as hidden when StatusScreen opens
  static void markAsHidden() {
    _shouldHide = true;
    _log.info('Overlay marked as hidden');
  }

  /// Force dismiss any active calibration progress overlay
  /// Call this when StatusScreen opens to prevent overlay from reappearing
  /// Also pops the CalibrationScreen underneath so StatusScreen is over home
  static void forceDismiss(BuildContext statusScreenContext) {
    final overlayCtx = _overlayContext;
    _log.info(
        'forceDismiss called - overlayContext exists: ${overlayCtx != null}');
    if (overlayCtx != null) {
      try {
        // Check if the context is still mounted before trying to use it
        if (overlayCtx.mounted) {
          _log.info(
              'Overlay context is mounted, popping overlay and CalibrationScreen...');
          final navigator = Navigator.of(overlayCtx, rootNavigator: false);

          // Pop the overlay (this route)
          if (navigator.canPop()) {
            _log.info('Popping overlay...');
            navigator.pop();
          }

          // Then pop CalibrationScreen
          Future.delayed(const Duration(milliseconds: 100), () {
            try {
              if (overlayCtx.mounted && navigator.canPop()) {
                _log.info('Popping CalibrationScreen...');
                navigator.pop();
              } else {
                _log.info('CalibrationScreen already gone');
              }
            } catch (e) {
              _log.warning('Error popping CalibrationScreen: $e');
            }
          });
        } else {
          _log.info('Overlay context not mounted');
        }
      } catch (e) {
        _log.warning('Error in forceDismiss: $e');
      } finally {
        _overlayContext = null;
      }
    } else {
      _log.info('No overlay context to dismiss');
    }
  }

  final ValueListenable<double> progress;
  final ValueListenable<String> message;
  final IconData icon;
  final ValueListenable<bool>? showReady;

  const CalibrationProgressOverlay({
    super.key,
    required this.progress,
    required this.message,
    this.icon = PhosphorIconsFill.flask,
    this.showReady,
  });

  @override
  State<CalibrationProgressOverlay> createState() =>
      _CalibrationProgressOverlayState();
}

class _CalibrationProgressOverlayState extends State<CalibrationProgressOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    // Store context for forced dismissal
    CalibrationProgressOverlay._overlayContext = context;
    // Don't reset _shouldHide here - it should persist across rebuilds

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.99, end: 1.03).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    // Clear stored context when overlay is disposed
    if (CalibrationProgressOverlay._overlayContext == context) {
      CalibrationProgressOverlay._overlayContext = null;
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // If marked as hidden, always return invisible container to prevent reappearing
    if (CalibrationProgressOverlay._shouldHide) {
      // Return completely invisible widget that doesn't intercept any interactions
      return const IgnorePointer(
        child: SizedBox.shrink(),
      );
    }

    final isGlass =
        Provider.of<ThemeProvider>(context, listen: false).isGlassTheme;

    return GlassApp(
      child: Scaffold(
        backgroundColor: isGlass
            ? Colors.transparent
            : Theme.of(context).colorScheme.surface,
        body: SafeArea(
          child: ValueListenableBuilder<bool>(
            valueListenable: widget.showReady ?? ValueNotifier(false),
            builder: (context, showReady, _) {
              // Check again inside builder in case it changed during rebuild
              if (CalibrationProgressOverlay._shouldHide) {
                return const IgnorePointer(
                  child: SizedBox.shrink(),
                );
              }

              return AnimatedSwitcher(
                duration: const Duration(milliseconds: 600),
                switchInCurve: Curves.easeInOut,
                switchOutCurve: Curves.easeInOut,
                transitionBuilder: (child, animation) {
                  return FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, 0.1),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    ),
                  );
                },
                child: showReady
                    ? _buildReadyView(context)
                    : _buildProgressView(context),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildProgressView(BuildContext context) {
    return Stack(
      key: const ValueKey('progress'),
      fit: StackFit.expand,
      children: [
        // Centered icon with halo
        Center(
          child: Transform.translate(
            offset: const Offset(0, -30),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Pulsing icon
                ScaleTransition(
                  scale: _pulseAnim,
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Icon(
                      widget.icon,
                      size: 120,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'CALIBRATION PREPARATION',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 30,
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'Processing calibration print job',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 24,
                    color: Theme.of(context).colorScheme.secondary,
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
        // Bottom message
        Positioned(
          left: 20,
          right: 20,
          bottom: 30,
          child: ValueListenableBuilder<String>(
            valueListenable: widget.message,
            builder: (context, msg, _) => Text(
              msg,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'AtkinsonHyperlegible',
                fontSize: 24,
                color: Theme.of(context).colorScheme.secondary,
              ),
            ),
          ),
        ),
        // Progress bar
        Positioned(
          left: 40,
          right: 40,
          bottom: 90,
          child: ValueListenableBuilder<double>(
            valueListenable: widget.progress,
            builder: (context, p, _) => SizedBox(
              height: 14,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(7),
                child: TweenAnimationBuilder<double>(
                  tween: Tween<double>(end: p.clamp(0.0, 1.0)),
                  duration: const Duration(milliseconds: 600),
                  curve: Curves.easeInOut,
                  builder: (context, animatedP, _) => LinearProgressIndicator(
                    value: animatedP,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Theme.of(context).colorScheme.primary,
                    ),
                    backgroundColor: Colors.black.withValues(
                      alpha: 0.3,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildReadyView(BuildContext context) {
    return Center(
      key: const ValueKey('ready'),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Non-pulsing green flask icon
          Padding(
            padding: const EdgeInsets.all(8),
            child: Icon(
              widget.icon,
              size: 120,
              color: Colors.green,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'PREPARATION COMPLETE',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 30,
              color: Colors.green,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            'Calibration job ready',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 24,
              color: Theme.of(context).colorScheme.secondary,
            ),
          ),
        ],
      ),
    );
  }
}

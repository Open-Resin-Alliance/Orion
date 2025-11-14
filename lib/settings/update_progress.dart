/*
* Orion - Update Progress Overlay
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
import 'package:orion/glasser/glasser.dart';

/// A full-screen modal overlay that displays update progress and messages.
/// Designed to be shown during system updates to inform the user of progress
/// and to discourage turning off the machine during critical operations.
/// Implements [UpdateProgressOverlay].

class UpdateProgressOverlay extends StatefulWidget {
  final ValueListenable<double> progress;
  final ValueListenable<String> message;
  final IconData icon;

  const UpdateProgressOverlay({
    super.key,
    required this.progress,
    required this.message,
    this.icon = PhosphorIconsFill.warning,
  });

  @override
  State<UpdateProgressOverlay> createState() => _UpdateProgressOverlayState();
}

class _UpdateProgressOverlayState extends State<UpdateProgressOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GlassApp(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Centered icon with halo (matches startup screen logo treatment)
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
                            color: Colors.redAccent,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'UPDATE IN PROGRESS',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 30,
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        'Please do not turn off the machine.',
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

              // Bottom message (matches positioning in startup_screen)
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

              // Progress bar positioned above the message (smoothly animated)
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
                      child: p < 0
                          ? LinearProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(
                                  Theme.of(context).colorScheme.primary),
                              backgroundColor:
                                  Colors.black.withValues(alpha: 0.3),
                            )
                          : TweenAnimationBuilder<double>(
                              tween: Tween<double>(end: p.clamp(0.0, 1.0)),
                              duration: const Duration(milliseconds: 600),
                              curve: Curves.easeInOut,
                              builder: (context, animatedP, _) =>
                                  LinearProgressIndicator(
                                value: animatedP,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                    Theme.of(context).colorScheme.primary),
                                backgroundColor:
                                    Colors.black.withValues(alpha: 0.3),
                              ),
                            ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

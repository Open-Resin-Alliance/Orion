/*
* Orion - Import Progress Overlay
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
import 'package:flutter/foundation.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';
import 'dart:math' as math;

import 'package:orion/glasser/glasser.dart';
import 'package:orion/util/providers/theme_provider.dart';

/// A full-screen modal overlay that displays import progress and messages.
/// Designed to be shown during file import to inform the user of progress.
class ImportProgressOverlay extends StatefulWidget {
  final ValueListenable<double> progress;
  final ValueListenable<String> message;
  final IconData icon;
  final ValueListenable<IconData>? iconListenable;
  final ValueListenable<String>? title;

  const ImportProgressOverlay({
    super.key,
    required this.progress,
    required this.message,
    this.icon = PhosphorIconsFill.package,
    this.iconListenable,
    this.title,
  });

  @override
  State<ImportProgressOverlay> createState() => _ImportProgressOverlayState();
}

class _ImportProgressOverlayState extends State<ImportProgressOverlay>
    with TickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnim;
  late final AnimationController _sliceController;

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

    _sliceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    )..repeat();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _sliceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isGlass =
        Provider.of<ThemeProvider>(context, listen: false).isGlassTheme;

    return GlassApp(
      child: Scaffold(
        backgroundColor: isGlass
            ? Colors.transparent
            : Theme.of(context).colorScheme.surface,
        body: SafeArea(
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Centered icon with pulsing animation
              Center(
                child: Transform.translate(
                  offset: const Offset(0, -30),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Pulsing icon or animated slicing block
                      ScaleTransition(
                        scale: _pulseAnim,
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: widget.title == null
                              ? (widget.iconListenable == null
                                  ? Icon(
                                      widget.icon,
                                      size: 120,
                                      color:
                                          Theme.of(context).colorScheme.primary,
                                    )
                                  : ValueListenableBuilder<IconData>(
                                      valueListenable: widget.iconListenable!,
                                      builder: (context, icon, _) => Icon(
                                        icon,
                                        size: 120,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary,
                                      ),
                                    ))
                              : ValueListenableBuilder<String>(
                                  valueListenable: widget.title!,
                                  builder: (context, title, _) =>
                                      title == 'SLICING JOB'
                                          ? _AnimatedSlicingBlock(
                                              controller: _sliceController,
                                              primaryColor: Theme.of(context)
                                                  .colorScheme
                                                  .primary,
                                            )
                                          : Icon(
                                              widget.icon,
                                              size: 120,
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .primary,
                                            ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      widget.title == null
                          ? Text(
                              'IMPORTING FILE',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 30,
                                color: Theme.of(context).colorScheme.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            )
                          : ValueListenableBuilder<String>(
                              valueListenable: widget.title!,
                              builder: (context, title, _) => Text(
                                title,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 30,
                                  color: Theme.of(context).colorScheme.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                      const SizedBox(height: 5),
                      widget.title == null
                          ? Text(
                              'Please wait while your file is being imported.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 24,
                                color: Theme.of(context).colorScheme.secondary,
                              ),
                            )
                          : ValueListenableBuilder<String>(
                              valueListenable: widget.title!,
                              builder: (context, title, _) => Text(
                                title == 'SLICING JOB'
                                    ? 'Please wait while your job is being sliced.'
                                    : 'Please wait while your file is being imported.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 24,
                                  color:
                                      Theme.of(context).colorScheme.secondary,
                                ),
                              ),
                            ),
                      const SizedBox(height: 18),
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

/// Custom animated widget showing a cube being sliced horizontally.
/// Used as the icon during slicing operations.
class _AnimatedSlicingBlock extends StatelessWidget {
  final AnimationController controller;
  final Color primaryColor;

  const _AnimatedSlicingBlock({
    required this.controller,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 120,
      height: 120,
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          final progress = controller.value;
          // Smooth easing for slice count, with a pop-out separation
          final countT = Curves.easeInOut.transform(progress);
          final popT = Curves.easeOutBack.transform(progress);
          final numSlices = (countT * 6).toInt() + 1;
          final separation = popT * 18;

          return CustomPaint(
            painter: _CubeSlicePainter(
              primaryColor: primaryColor,
              sliceCount: numSlices,
              separation: separation,
            ),
            size: const Size(120, 120),
          );
        },
      ),
    );
  }
}

class _CubeSlicePainter extends CustomPainter {
  final Color primaryColor;
  final int sliceCount;
  final double separation;

  _CubeSlicePainter({
    required this.primaryColor,
    required this.sliceCount,
    required this.separation,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final outlineStroke = Paint()
      ..color = primaryColor.withValues(alpha: 0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final centerX = size.width / 2;
    final centerY = size.height / 2;

    const double cubeSize = 85;
    const double depth = 20;
    const double cornerRadius = 4;

    final baseRect = Rect.fromCenter(
      center: Offset(centerX, centerY),
      width: cubeSize,
      height: cubeSize,
    );

    final sliceHeight = cubeSize / sliceCount;

    // Draw slices from back to front for proper 3D occlusion
    for (int i = 0; i < sliceCount; i++) {
      // Calculate offset from center for peeling effect
      final centerIndex = sliceCount / 2.0;
      final distanceFromCenter = (i - centerIndex).abs();

      // Add wavy motion with sine for peeling effect
      final waveAmount =
          math.sin((i / sliceCount) * math.pi) * separation * 0.3;
      final sliceVerticalOffset =
          distanceFromCenter * separation * (i < centerIndex ? -0.5 : 0.5);
      final sliceHorizontalOffset = waveAmount;

      final sliceTop = baseRect.top + (sliceHeight * i) + sliceVerticalOffset;
      final sliceLeft = baseRect.left + sliceHorizontalOffset;

      final sliceRect = Rect.fromLTWH(
        sliceLeft,
        sliceTop,
        cubeSize,
        sliceHeight - 1,
      );

      // Create gradient fill for bubbly gel effect
      final gradientFill = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            primaryColor.withValues(alpha: 0.25),
            primaryColor.withValues(alpha: 0.1),
          ],
        ).createShader(sliceRect)
        ..style = PaintingStyle.fill;

      // Draw front face with rounded corners for bubble effect
      final frontRRect =
          RRect.fromRectAndRadius(sliceRect, Radius.circular(cornerRadius));
      canvas.drawRRect(frontRRect, gradientFill);
      canvas.drawRRect(frontRRect, outlineStroke);

      // Draw 3D depth faces
      final topRight = Offset(
        sliceRect.right + depth / 3,
        sliceRect.top - depth / 3,
      );
      final bottomRight = Offset(
        sliceRect.right + depth / 3,
        sliceRect.bottom - depth / 3,
      );
      final topLeft = Offset(
        sliceRect.left + depth / 4,
        sliceRect.top - depth / 4,
      );

      // Right face - slightly darker for depth
      final rightFill = Paint()
        ..color = primaryColor.withValues(alpha: 0.08)
        ..style = PaintingStyle.fill;
      final rightPath = Path()
        ..moveTo(sliceRect.right, sliceRect.top)
        ..lineTo(topRight.dx, topRight.dy)
        ..lineTo(bottomRight.dx, bottomRight.dy)
        ..lineTo(sliceRect.right, sliceRect.bottom)
        ..close();
      canvas.drawPath(rightPath, rightFill);
      canvas.drawPath(rightPath, outlineStroke);

      // Top face - lighter for gel bubble effect
      final topFill = Paint()
        ..color = primaryColor.withValues(alpha: 0.12)
        ..style = PaintingStyle.fill;
      final topPath = Path()
        ..moveTo(sliceRect.left, sliceRect.top)
        ..lineTo(topLeft.dx, topLeft.dy)
        ..lineTo(topRight.dx, topRight.dy)
        ..lineTo(sliceRect.right, sliceRect.top)
        ..close();
      canvas.drawPath(topPath, topFill);
      canvas.drawPath(topPath, outlineStroke);
    }
  }

  @override
  bool shouldRepaint(_CubeSlicePainter oldDelegate) {
    return oldDelegate.sliceCount != sliceCount ||
        oldDelegate.separation != separation ||
        oldDelegate.primaryColor != primaryColor;
  }
}

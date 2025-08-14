/*
* Orion - Orion HoldButton
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
import 'package:provider/provider.dart';

import 'package:orion/glasser/glasser.dart';
import 'package:orion/util/providers/theme_provider.dart';

class HoldButton extends StatefulWidget {
  final VoidCallback onPressed;
  final Widget child;
  final ButtonStyle? style;
  final Duration duration;

  const HoldButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.style,
    this.duration = const Duration(seconds: 3),
  });

  @override
  HoldButtonState createState() => HoldButtonState();
}

class HoldButtonState extends State<HoldButton> with TickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onPressed();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    _controller.forward();
  }

  void _onTapUp(TapUpDetails details) {
    _controller.reverse();
  }

  void _onTapCancel() {
    _controller.fling(velocity: -1);
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    BorderRadius borderRadius =
        BorderRadius.circular(15); // Match our standard radius

    if (widget.style?.shape?.resolve({}) is RoundedRectangleBorder) {
      final shape = widget.style?.shape?.resolve({}) as RoundedRectangleBorder;
      if (shape.borderRadius is BorderRadius) {
        borderRadius = shape.borderRadius as BorderRadius;
      }
    }

    Widget buttonChild = SizedBox(
      width: double.infinity,
      height: double.infinity,
      child: GlassButton(
        // Intentionally left empty: HoldButton manages tap events via GestureDetector.
        onPressed: () {},
        style: widget.style,
        child: Center(
          child: widget.child,
        ),
      ),
    );

    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return IntrinsicWidth(
            child: IntrinsicHeight(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  buttonChild,
                  // Show the animated hold icon only when the button is idle (not being pressed or held).
                  // The condition ensures the icon appears only when the animation is not running and the progress is at the start.
                  if (!_controller.isAnimating && _controller.value == 0)
                    Align(
                      alignment: Alignment.centerRight,
                      child: Padding(
                        padding: const EdgeInsets.only(right: 16.0),
                        child: _AnimatedHoldIcon(),
                      ),
                    ),
                  Positioned.fill(
                    child: IgnorePointer(
                      child: ClipRRect(
                        borderRadius: borderRadius,
                        child: LinearProgressIndicator(
                          value: _controller.value,
                          backgroundColor: Colors.transparent,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            themeProvider.isGlassTheme
                                ? Colors.white.withValues(alpha: 0.5)
                                : Theme.of(context)
                                    .colorScheme
                                    .primary
                                    .withValues(alpha: 0.5),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Animated hold icon overlay for HoldButton
class _AnimatedHoldIcon extends StatefulWidget {
  @override
  State<_AnimatedHoldIcon> createState() => _AnimatedHoldIconState();
}

class _AnimatedHoldIconState extends State<_AnimatedHoldIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _scale = Tween<double>(begin: 1.0, end: 1.18).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _scale,
      builder: (context, child) {
        return Transform.scale(
          scale: _scale.value,
          child: Icon(
            Icons.touch_app,
            size: 28,
            color: Colors.white.withValues(alpha: 0.38),
            shadows: [
              Shadow(
                color: Colors.black.withValues(alpha: 0.10),
                blurRadius: 6,
              ),
            ],
          ),
        );
      },
    );
  }
}

/*
* Glasser - Glass Card Widget
* Copyright (C) 2024 Open Resin Alliance
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

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:orion/util/providers/theme_provider.dart';
import '../constants.dart';

/// A card that automatically becomes glassmorphic when the glass theme is active.
///
/// This widget is a drop-in replacement for [Card]. When the glass theme is enabled,
/// it renders with a glassmorphic effect for visual consistency. Otherwise, it falls back to a normal card.
///
/// Example usage:
/// ```dart
/// GlassCard(
///   child: Text('Hello'),
/// )
/// ```
///
/// See also:
///
///  * [GlassScaffold], for glass-aware scaffolds.
///  * [Card], the standard Flutter card.
class GlassCard extends StatelessWidget {
  /// A card that automatically becomes glassmorphic when the glass theme is active.
  final Widget child;
  final EdgeInsetsGeometry? margin;
  final Color? color;
  final double? elevation;
  final ShapeBorder? shape;
  final bool outlined;

  const GlassCard({
    super.key,
    required this.child,
    this.margin,
    this.color,
    this.elevation,
    this.shape,
    this.outlined = false,
  });

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    if (!themeProvider.isGlassTheme) {
      return outlined
          ? Card.outlined(
              margin: margin,
              color: color,
              elevation: elevation,
              shape: shape,
              child: child,
            )
          : Card(
              margin: margin,
              color: color,
              elevation: elevation,
              shape: shape,
              child: child,
            );
    }

    return Container(
      margin: margin ?? const EdgeInsets.all(4.0), // Default Card margin
      child: ClipRRect(
        borderRadius: BorderRadius.circular(glassCornerRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(glassCornerRadius),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.2),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 15,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

// Backwards compatibility alias
typedef GlassAwareCard = GlassCard;

/*
* Glasser - Glass Card Widget
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
import 'package:orion/util/providers/theme_provider.dart';
import '../constants.dart';
import '../glass_effect.dart';
import '../platform_config.dart';

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

    // Extract borderRadius from shape if possible
    BorderRadius borderRadius = BorderRadius.circular(glassCornerRadius);
    if (shape is RoundedRectangleBorder) {
      final rrb = shape as RoundedRectangleBorder;
      if (rrb.borderRadius is BorderRadius) {
        borderRadius = rrb.borderRadius as BorderRadius;
      }
    }

    return Container(
      margin: margin ?? const EdgeInsets.all(4.0), // Default Card margin
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: GlassPlatformConfig.surfaceShadow(
          blurRadius: outlined ? 14 : 16,
          yOffset: outlined ? 3 : 4,
          alpha: outlined ? 0.14 : 0.12,
        ),
      ),
      child: GlassEffect(
        borderRadius: borderRadius,
        opacity: GlassPlatformConfig.surfaceOpacity(0.12, emphasize: outlined),
        sigma: glassBlurSigma,
        borderWidth: outlined ? 1.4 : 1.0,
        child: Material(
          type: MaterialType.transparency,
          shape: RoundedRectangleBorder(borderRadius: borderRadius),
          clipBehavior: Clip.antiAlias,
          child: child,
        ),
      ),
    );
  }
}

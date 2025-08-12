/*
* Glasser - Glass App Widget
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

/// A wrapper that automatically applies a glassmorphic background when the glass theme is active.
///
/// This widget should wrap your app's root or major sections to provide a consistent
/// glassmorphic gradient background. It automatically adapts to the current glass theme,
/// using the gradient from the [ThemeProvider], a custom [gradientColors], or a generated gradient.
///
/// If the glass theme is not active, [child] is rendered as-is with no background effect.
///
/// Example usage:
/// ```dart
/// GlassApp(
///   child: MyHomePage(),
/// )
/// ```
///
/// See also:
///
///  * [GlassScaffold], for a glass-aware scaffold.
///  * [ThemeProvider], for theme and gradient management.
class GlassApp extends StatelessWidget {
  /// A wrapper that automatically applies a glassmorphic background when the glass theme is active.
  final Widget child;
  final List<Color>? gradientColors;
  final AlignmentGeometry gradientBegin;
  final AlignmentGeometry gradientEnd;

  const GlassApp({
    super.key,
    required this.child,
    this.gradientColors,
    this.gradientBegin = Alignment.topLeft,
    this.gradientEnd = Alignment.bottomRight,
  });

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    if (!themeProvider.isGlassTheme) {
      return child;
    }

    // Use gradient from provider, fall back to custom gradientColors, then auto-generate
    List<Color> finalGradient;

    if (gradientColors != null) {
      // Custom gradient override provided
      finalGradient = gradientColors!;
    } else if (themeProvider.currentThemeGradient.isNotEmpty) {
      // Use saved/vendor gradient from provider
      finalGradient = themeProvider.currentThemeGradient;
    } else {
      // Auto-generate gradient from theme color
      finalGradient = _generateThemeGradient(themeProvider.currentColorSeed);
    }

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: gradientBegin,
          end: gradientEnd,
          colors: finalGradient,
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.5),
        ),
        child: child,
      ),
    );
  }

  /// Generate beautiful gradients based on the theme color
  List<Color> _generateThemeGradient(Color baseColor) {
    final hsl = HSLColor.fromColor(baseColor);

    // Create a sophisticated 4-color gradient that stays within the color family
    if (_isWarmColor(baseColor)) {
      return _generateWarmGradient(hsl);
    } else {
      return _generateCoolGradient(hsl);
    }
  }

  /// Generate warm color gradients (reds, oranges, purples, magentas)
  List<Color> _generateWarmGradient(HSLColor baseHsl) {
    final hue = baseHsl.hue;

    // For warm colors, create depth by varying saturation and lightness
    // while keeping hue shifts minimal and natural
    return [
      // Deep, rich version - darkest
      baseHsl
          .withLightness(0.15)
          .withSaturation((baseHsl.saturation * 1.3).clamp(0.0, 1.0))
          .withHue((hue - 5) % 360) // Slight hue shift for depth
          .toColor(),

      // Medium-dark version
      baseHsl
          .withLightness(0.25)
          .withSaturation((baseHsl.saturation * 1.2).clamp(0.0, 1.0))
          .toColor(),

      // Medium version - closer to original
      baseHsl
          .withLightness(0.4)
          .withSaturation((baseHsl.saturation * 1.1).clamp(0.0, 1.0))
          .toColor(),

      // Bright accent - adds energy without changing color family
      baseHsl
          .withLightness(0.6)
          .withSaturation((baseHsl.saturation * 0.9).clamp(0.0, 1.0))
          .withHue((hue + 10) % 360) // Small complementary shift
          .toColor(),
    ];
  }

  /// Generate cool color gradients (blues, greens, teals)
  List<Color> _generateCoolGradient(HSLColor baseHsl) {
    final hue = baseHsl.hue;

    // For cool colors, create oceanic/nature-inspired gradients
    return [
      // Deep ocean/forest - darkest
      baseHsl
          .withLightness(0.12)
          .withSaturation((baseHsl.saturation * 1.4).clamp(0.0, 1.0))
          .withHue((hue + 8) % 360) // Slight shift toward teal/navy
          .toColor(),

      // Medium depth
      baseHsl
          .withLightness(0.22)
          .withSaturation((baseHsl.saturation * 1.25).clamp(0.0, 1.0))
          .toColor(),

      // Medium - main color
      baseHsl
          .withLightness(0.35)
          .withSaturation((baseHsl.saturation * 1.15).clamp(0.0, 1.0))
          .toColor(),

      // Bright cool accent
      baseHsl
          .withLightness(0.55)
          .withSaturation((baseHsl.saturation * 0.85).clamp(0.0, 1.0))
          .withHue((hue - 12) % 360) // Shift toward cyan/mint
          .toColor(),
    ];
  }

  /// Determine if a color is warm (red/orange/yellow family) or cool (blue/green family)
  bool _isWarmColor(Color color) {
    final hsl = HSLColor.fromColor(color);
    final hue = hsl.hue;

    // Warm colors: Red (0-60), Orange (30-90), Yellow (60-120), Purple/Magenta (270-330)
    return (hue >= 0 && hue <= 120) || (hue >= 270 && hue <= 360);
  }
}

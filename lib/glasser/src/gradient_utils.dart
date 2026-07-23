/*
* Glasser - Gradient Utilities
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

import 'package:orion/util/providers/theme_provider.dart';

/// Utility helpers for working with glassmorphic gradients.
class GlassGradientUtils {
  const GlassGradientUtils._();

  /// Resolves the gradient for the current glass theme, preferring
  /// explicit overrides and saved gradients before falling back to a
  /// generated palette derived from the active seed color.
  static List<Color> resolveGradient({
    required ThemeProvider themeProvider,
    List<Color>? override,
  }) {
    if (override != null) {
      return override;
    }

    final storedGradient = themeProvider.currentThemeGradient;
    if (storedGradient.isNotEmpty) {
      return storedGradient;
    }

    return generateFromSeed(themeProvider.currentColorSeed);
  }

  /// Generates a four-stop gradient based on the provided seed color.
  static List<Color> generateFromSeed(Color baseColor) {
    final hsl = HSLColor.fromColor(baseColor);
    return _isWarmColor(baseColor)
        ? _generateWarmGradient(hsl)
        : _generateCoolGradient(hsl);
  }

  /// Darkens each color in the gradient by blending toward black.
  static List<Color> darkenGradient(List<Color> colors,
      {double amount = 0.25}) {
    final factor = amount.clamp(0.0, 1.0);
    return colors
        .map((color) => Color.lerp(color, Colors.black, factor) ?? color)
        .toList(growable: false);
  }

  static List<Color> _generateWarmGradient(HSLColor baseHsl) {
    final hue = baseHsl.hue;

    return [
      baseHsl
          .withLightness(0.15)
          .withSaturation((baseHsl.saturation * 1.3).clamp(0.0, 1.0))
          .withHue((hue - 5) % 360)
          .toColor(),
      baseHsl
          .withLightness(0.25)
          .withSaturation((baseHsl.saturation * 1.2).clamp(0.0, 1.0))
          .toColor(),
      baseHsl
          .withLightness(0.4)
          .withSaturation((baseHsl.saturation * 1.1).clamp(0.0, 1.0))
          .toColor(),
      baseHsl
          .withLightness(0.6)
          .withSaturation((baseHsl.saturation * 0.9).clamp(0.0, 1.0))
          .withHue((hue + 10) % 360)
          .toColor(),
    ];
  }

  static List<Color> _generateCoolGradient(HSLColor baseHsl) {
    final hue = baseHsl.hue;

    return [
      baseHsl
          .withLightness(0.12)
          .withSaturation((baseHsl.saturation * 1.4).clamp(0.0, 1.0))
          .withHue((hue + 8) % 360)
          .toColor(),
      baseHsl
          .withLightness(0.22)
          .withSaturation((baseHsl.saturation * 1.25).clamp(0.0, 1.0))
          .toColor(),
      baseHsl
          .withLightness(0.35)
          .withSaturation((baseHsl.saturation * 1.15).clamp(0.0, 1.0))
          .toColor(),
      baseHsl
          .withLightness(0.55)
          .withSaturation((baseHsl.saturation * 0.85).clamp(0.0, 1.0))
          .withHue((hue - 12) % 360)
          .toColor(),
    ];
  }

  static bool _isWarmColor(Color color) {
    final hue = HSLColor.fromColor(color).hue;
    return (hue >= 0 && hue <= 120) || (hue >= 270 && hue <= 360);
  }
}

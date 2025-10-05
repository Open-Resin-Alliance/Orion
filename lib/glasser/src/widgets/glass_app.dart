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

import '../gradient_utils.dart';

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
    final List<Color> finalGradient = GlassGradientUtils.resolveGradient(
      themeProvider: themeProvider,
      override: gradientColors,
    );

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
}

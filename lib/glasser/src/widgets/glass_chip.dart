/*
* Glasser - Glass Chip Widget
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
import '../../../util/providers/theme_provider.dart';

/// A chip that automatically becomes glassmorphic when the glass theme is active.
///
/// This widget is a drop-in replacement for [Chip]. When the glass theme is enabled,
/// it renders with a glassmorphic effect for visual consistency. Otherwise, it falls back to a normal chip.
///
/// Example usage:
/// ```dart
/// GlassChip(
///   label: Text('Chip'),
/// )
/// ```
///
/// See also:
///
///  * [GlassScaffold], for glass-aware scaffolds.
///  * [Chip], the standard Flutter chip.
class GlassChip extends StatelessWidget {
  /// A chip that automatically becomes glassmorphic when the glass theme is active.
  final Widget label;
  final Color? backgroundColor;
  final Color? borderColor;

  const GlassChip({
    super.key,
    required this.label,
    this.backgroundColor,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    if (!themeProvider.isGlassTheme) {
      return Chip(
        label: label,
        backgroundColor: backgroundColor?.withValues(alpha: 0.35),
      );
    }

    // Glass theme - enhanced visibility for chips
    final baseColor = backgroundColor ?? Theme.of(context).colorScheme.primary;
    final border = borderColor ?? baseColor;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        color: baseColor.withValues(alpha: 0.4),
        border: Border.all(
          color: border.withValues(alpha: 0.8),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: baseColor.withValues(alpha: 0.3),
            blurRadius: 4,
            spreadRadius: 0,
          ),
        ],
      ),
      child: DefaultTextStyle(
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
          fontSize: 12,
          shadows: [
            Shadow(
              color: Colors.black38,
              blurRadius: 2,
            ),
          ],
        ),
        child: label,
      ),
    );
  }
}

// Backwards compatibility alias
typedef GlassAwareChip = GlassChip;

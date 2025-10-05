/*
* Glasser - Glass Choice Chip Widget
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

/// A choice chip that automatically becomes glassmorphic when the glass theme is active.
///
/// This widget is a drop-in replacement for [ChoiceChip]. When the glass theme is enabled,
/// it renders with a glassmorphic effect for visual consistency. Otherwise, it falls back to a normal choice chip.
///
/// Example usage:
/// ```dart
/// GlassChoiceChip(
///   label: Text('Choice'),
///   selected: true,
///   onSelected: (v) {},
/// )
/// ```
///
/// See also:
///
///  * [GlassScaffold], for glass-aware scaffolds.
///  * [ChoiceChip], the standard Flutter choice chip.
class GlassChoiceChip extends StatelessWidget {
  /// A choice chip that automatically becomes glassmorphic when the glass theme is active.
  final Widget label;
  final bool selected;
  final ValueChanged<bool>? onSelected;

  const GlassChoiceChip({
    super.key,
    required this.label,
    this.selected = false,
    this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    if (!themeProvider.isGlassTheme) {
      return ChoiceChip.elevated(
        label: SizedBox(
          width: double.infinity,
          child: label,
        ),
        selected: selected,
        onSelected: onSelected,
      );
    }

    // Glass theme - create glassmorphic choice chip
    final borderRadius = BorderRadius.circular(glassSmallCornerRadius);
    final fillOpacity = GlassPlatformConfig.surfaceOpacity(
      selected ? 0.28 : 0.12,
      emphasize: selected,
    );
    final borderWidth = selected ? 2.2 : 1.2;
    final glow = selected
        ? GlassPlatformConfig.selectionGlow(blurRadius: 10, alpha: 0.24)
        : null;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: double.infinity,
      height: 48,
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: glow,
      ),
      child: GlassEffect(
        borderRadius: borderRadius,
        sigma: glassBlurSigma,
        opacity: fillOpacity,
        borderWidth: borderWidth,
        emphasizeBorder: selected,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onSelected != null ? () => onSelected!(!selected) : null,
            borderRadius: borderRadius,
            child: Center(
              child: DefaultTextStyle(
                style: TextStyle(
                  fontFamily: 'AtkinsonHyperlegible',
                  color: selected
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.85),
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  fontSize: 22,
                ),
                child: label,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

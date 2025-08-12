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

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:orion/util/providers/theme_provider.dart';
import '../constants.dart';

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
    return ClipRRect(
      borderRadius: BorderRadius.circular(glassSmallCornerRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: double.infinity,
          height: 48, // Fixed height to prevent layout issues
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(glassSmallCornerRadius),
            color: selected
                ? Colors.white.withValues(alpha: 0.35)
                : Colors.white.withValues(alpha: 0.1),
            border: Border.all(
              color: selected
                  ? Colors.white.withValues(alpha: 0.8)
                  : Colors.white.withValues(alpha: 0.25),
              width: selected ? 2.5 : 1,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: Colors.white.withValues(alpha: 0.2),
                      blurRadius: 8,
                      spreadRadius: 0,
                    ),
                  ]
                : null,
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onSelected != null ? () => onSelected!(!selected) : null,
              borderRadius: BorderRadius.circular(glassSmallCornerRadius),
              child: Center(
                child: DefaultTextStyle(
                  style: TextStyle(
                    fontFamily: 'AtkinsonHyperlegible',
                    color: selected
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.8),
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    fontSize: 22,
                  ),
                  child: label,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

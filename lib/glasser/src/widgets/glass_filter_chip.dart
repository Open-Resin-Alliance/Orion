/*
* Glasser - Glass Filter Chip Widget
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

/// A filter chip that automatically becomes glassmorphic when the glass theme is active.
///
/// This widget is a drop-in replacement for [FilterChip]. When the glass theme is enabled,
/// it renders with a glassmorphic effect for visual consistency. Otherwise, it falls back to a normal filter chip.
///
/// Example usage:
/// ```dart
/// GlassFilterChip(
///   label: Text('Filter'),
///   selected: true,
///   onSelected: (v) {},
/// )
/// ```
///
/// See also:
///
///  * [GlassScaffold], for glass-aware scaffolds.
///  * [FilterChip], the standard Flutter filter chip.
class GlassFilterChip extends StatelessWidget {
  /// A filter chip that automatically becomes glassmorphic when the glass theme is active.
  final Widget label;
  final bool selected;
  final ValueChanged<bool>? onSelected;

  const GlassFilterChip({
    super.key,
    required this.label,
    required this.selected,
    this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    if (!themeProvider.isGlassTheme) {
      return FilterChip(
        label: label,
        selected: selected,
        onSelected: onSelected,
      );
    }

    // Glass theme - create glassmorphic filter chip
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onSelected != null ? () => onSelected!(!selected) : null,
        borderRadius: BorderRadius.circular(glassSmallCornerRadius),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
          child: Row(
            mainAxisSize: MainAxisSize.max,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (selected)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Icon(
                    Icons.check,
                    size: 16,
                    color: Colors.white,
                  ),
                ),
              DefaultTextStyle(
                style: TextStyle(
                  fontFamily: 'AtkinsonHyperlegible',
                  color: selected
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.8),
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  fontSize: selected ? 16 : 15,
                ),
                child: label,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Backwards compatibility alias
typedef GlassAwareFilterChip = GlassFilterChip;

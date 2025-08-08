/*
* Glasser - Glass Bottom Navigation Bar Widget
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

/// A bottom navigation bar that automatically becomes glassmorphic when the glass theme is active.
///
/// This widget is a drop-in replacement for [BottomNavigationBar]. When the glass theme is enabled,
/// it renders with a glassmorphic effect for visual consistency. Otherwise, it falls back to a normal bottom navigation bar.
///
/// Example usage:
/// ```dart
/// GlassBottomNavigationBar(
///   items: [...],
///   currentIndex: 0,
///   onTap: (i) {},
/// )
/// ```
///
/// See also:
///
///  * [GlassScaffold], for glass-aware scaffolds.
///  * [BottomNavigationBar], the standard Flutter bottom navigation bar.
class GlassBottomNavigationBar extends StatelessWidget {
  /// A bottom navigation bar that automatically becomes glassmorphic when the glass theme is active.
  final List<BottomNavigationBarItem> items;
  final ValueChanged<int>? onTap;
  final int currentIndex;
  final BottomNavigationBarType? type;
  final Color? selectedItemColor;
  final Color? unselectedItemColor;

  const GlassBottomNavigationBar({
    super.key,
    required this.items,
    this.onTap,
    this.currentIndex = 0,
    this.type,
    this.selectedItemColor,
    this.unselectedItemColor,
  });

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    if (themeProvider.isGlassTheme) {
      return BottomNavigationBar(
        items: items,
        currentIndex: currentIndex,
        onTap: onTap,
        type: type ?? BottomNavigationBarType.fixed,
        backgroundColor: Colors.transparent,
        elevation: 0,
        selectedItemColor: selectedItemColor ?? Colors.white,
        unselectedItemColor: unselectedItemColor ?? Colors.white70,
        selectedLabelStyle:
            Theme.of(context).bottomNavigationBarTheme.selectedLabelStyle,
        unselectedLabelStyle:
            Theme.of(context).bottomNavigationBarTheme.unselectedLabelStyle,
        selectedIconTheme:
            Theme.of(context).bottomNavigationBarTheme.selectedIconTheme,
        unselectedIconTheme:
            Theme.of(context).bottomNavigationBarTheme.unselectedIconTheme,
      );
    }

    return BottomNavigationBar(
      items: items,
      currentIndex: currentIndex,
      onTap: onTap,
      type: type ?? BottomNavigationBarType.fixed,
      selectedItemColor: selectedItemColor,
      unselectedItemColor: unselectedItemColor,
    );
  }
}

// Backwards compatibility alias
typedef GlassAwareBottomNavigationBar = GlassBottomNavigationBar;

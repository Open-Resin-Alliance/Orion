/*
* Glasser - Glass Switch Widget
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

/// A switch that automatically becomes glassmorphic when the glass theme is active.
///
/// This widget is a drop-in replacement for [Switch]. When the glass theme is enabled,
/// it renders with a glassmorphic effect for visual consistency. Otherwise, it falls back to a normal switch.
///
/// Example usage:
/// ```dart
/// GlassSwitch(
///   value: true,
///   onChanged: (v) {},
/// )
/// ```
///
/// See also:
///
///  * [GlassScaffold], for glass-aware scaffolds.
///  * [Switch], the standard Flutter switch.
class GlassSwitch extends StatelessWidget {
  /// A switch that automatically becomes glassmorphic when the glass theme is active.
  final bool value;
  final ValueChanged<bool>? onChanged;
  final Color? activeColor;
  final Color? inactiveTrackColor;
  final Color? inactiveThumbColor;

  const GlassSwitch({
    super.key,
    required this.value,
    this.onChanged,
    this.activeColor,
    this.inactiveTrackColor,
    this.inactiveThumbColor,
  });

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    if (!themeProvider.isGlassTheme) {
      return Switch(
        value: value,
        onChanged: onChanged,
        activeColor: activeColor,
        inactiveTrackColor: inactiveTrackColor,
        inactiveThumbColor: inactiveThumbColor,
      );
    }

    // Glass theme: create a custom glassmorphic switch
    return Switch(
      value: value,
      onChanged: onChanged,
      activeColor: Colors.white,
      activeTrackColor: Colors.white.withValues(alpha: 0.3),
      inactiveTrackColor: Colors.white.withValues(alpha: 0.1),
      inactiveThumbColor: Colors.white.withValues(alpha: 0.7),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}

// Backwards compatibility alias
typedef GlassAwareSwitch = GlassSwitch;

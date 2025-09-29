/*
* Glasser - Glass Dialog Widget
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
import '../glass_effect.dart';

/// A dialog that automatically becomes glassmorphic when the glass theme is active.
///
/// This widget is a drop-in replacement for [Dialog]. When the glass theme is enabled,
/// it renders with a glassmorphic effect for visual consistency. Otherwise, it falls back to a normal dialog.
///
/// Example usage:
/// ```dart
/// GlassDialog(
///   child: Text('Dialog content'),
/// )
/// ```
///
/// See also:
///
///  * [GlassScaffold], for glass-aware scaffolds.
///  * [Dialog], the standard Flutter dialog.
class GlassDialog extends StatelessWidget {
  /// A dialog that automatically becomes glassmorphic when the glass theme is active.
  final Widget child;
  final EdgeInsetsGeometry padding;

  const GlassDialog({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(24),
  });

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    if (!themeProvider.isGlassTheme) {
      return Dialog(
        child: Padding(
          padding: padding,
          child: child,
        ),
      );
    }

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: GlassEffect(
        opacity: 0.1, // Use dialog-specific opacity
        child: Padding(
          padding: padding,
          child: child,
        ),
      ),
    );
  }
}

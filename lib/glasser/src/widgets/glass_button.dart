/*
* Glasser - Glass Button Widget
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

/// A button that automatically becomes glassmorphic when the glass theme is active.
///
/// This widget is a drop-in replacement for [ElevatedButton]. When the glass theme is enabled,
/// it renders with a glassmorphic effect for visual consistency. Otherwise, it falls back to a normal button.
///
/// Example usage:
/// ```dart
/// GlassButton(
///   onPressed: () {},
///   child: Text('OK'),
/// )
/// ```
///
/// See also:
///
///  * [GlassScaffold], for glass-aware scaffolds.
///  * [ElevatedButton], the standard Flutter button.
class GlassButton extends StatelessWidget {
  /// A button that automatically becomes glassmorphic when the glass theme is active.
  final Widget child;
  final VoidCallback? onPressed;
  final ButtonStyle? style;
  final bool wantIcon;

  const GlassButton({
    super.key,
    required this.child,
    required this.onPressed,
    this.style,
    this.wantIcon = false,
  });

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    if (!themeProvider.isGlassTheme) {
      return ElevatedButton(
        onPressed: onPressed,
        style: style,
        child: child,
      );
    }

    return _GlassmorphicButton(
      onPressed: onPressed,
      style: style,
      wantIcon: wantIcon,
      child: child, // Pass the wantIcon parameter
    );
  }
}

/// Internal glassmorphic button implementation
class _GlassmorphicButton extends StatelessWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final ButtonStyle? style;
  final bool wantIcon;

  const _GlassmorphicButton({
    required this.child,
    required this.onPressed,
    this.style,
    this.wantIcon = true,
  });

  @override
  Widget build(BuildContext context) {
    // Extract size constraints from style if provided
    Size? minimumSize;
    Size? maximumSize;

    if (style != null) {
      minimumSize = style!.minimumSize?.resolve({});
      maximumSize = style!.maximumSize?.resolve({});
    }

    final isEnabled = onPressed != null;

    Widget buttonChild = ClipRRect(
      borderRadius: BorderRadius.circular(glassCornerRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: isEnabled
                ? Colors.white.withValues(alpha: 0.1)
                : Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(glassCornerRadius),
            border: Border.all(
              color: isEnabled
                  ? Colors.white.withValues(alpha: 0.2)
                  : Colors.white.withValues(alpha: 0.1),
              width: 1.5,
            ),
            boxShadow: isEnabled
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 20,
                      offset: const Offset(0, 2), // Reduced from 8 to 2
                    ),
                  ]
                : null,
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(glassCornerRadius),
              onTap: onPressed,
              splashColor:
                  isEnabled ? Colors.white.withValues(alpha: 0.2) : null,
              highlightColor:
                  isEnabled ? Colors.white.withValues(alpha: 0.1) : null,
              child: Opacity(
                opacity: isEnabled ? 1.0 : 0.5,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24.0,
                      vertical: 8.0), // Match ElevatedButton default padding
                  child: Center(
                    child:
                        _buildButtonContentWithIcon(child, wantIcon: wantIcon),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    // Apply size constraints if specified, or use default
    return ConstrainedBox(
      constraints: BoxConstraints(
        minWidth: ((minimumSize?.width ?? 20) - 5).clamp(0.0, double.infinity),
        minHeight: ((minimumSize?.height ?? 5) - 5).clamp(0.0, double.infinity),
        maxWidth: (maximumSize?.width ?? double.infinity) - 5,
        maxHeight: (maximumSize?.height ?? double.infinity) - 5,
      ),
      child: buttonChild,
    );
  }
}

/// Helper function to add icons to button content based on text
Widget _buildButtonContentWithIcon(Widget originalChild,
    {required bool wantIcon}) {
  if (originalChild is Text) {
    final text = originalChild.data?.toLowerCase() ?? '';

    IconData? icon;

    // Map common button text to icons
    if (text.contains('cancel') ||
        text.contains('close') ||
        text.contains('later')) {
      icon = Icons.close;
    } else if (text.contains('confirm') ||
        text.contains('ok') ||
        text.contains('set') ||
        text.contains('save') ||
        text.contains('now')) {
      icon = Icons.check;
    } else if (text.contains('delete')) {
      icon = Icons.delete_outline;
    } else if (text.contains('disconnect')) {
      icon = Icons.wifi_off;
    } else if (text.contains('connect')) {
      icon = Icons.wifi;
    } else if (text.contains('skip')) {
      icon = Icons.skip_next;
    } else if (text.contains('stay')) {
      icon = Icons.stay_current_portrait;
    }

    if (!wantIcon) {
      // If we don't want an icon, just return the original text
      return originalChild;
    }

    if (icon != null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 18,
            color: Colors.white,
          ),
          const SizedBox(width: 8),
          Text(originalChild.data ?? ''),
        ],
      );
    }
  }

  return originalChild;
}

// Backwards compatibility alias
typedef GlassAwareButton = GlassButton;

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

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:orion/util/providers/theme_provider.dart';
import '../constants.dart';
import '../glass_effect.dart';
import '../platform_config.dart';

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

    // Detect if the button is a circle (CircleBorder)
    final isCircle = style?.shape?.resolve({}) is CircleBorder;
    final borderRadius =
        BorderRadius.circular(isCircle ? 30 : glassCornerRadius);
    final fillOpacity = GlassPlatformConfig.surfaceOpacity(
      isEnabled ? 0.14 : 0.1,
      emphasize: isEnabled,
    );
    final shadow = GlassPlatformConfig.interactiveShadow(
      enabled: isEnabled,
      blurRadius: isCircle ? 18 : 16,
      yOffset: isCircle ? 4 : 3,
      alpha: 0.14,
    );

    Widget buttonChild = Container(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: shadow,
      ),
      child: GlassEffect(
        borderRadius: borderRadius,
        sigma: glassBlurSigma,
        opacity: fillOpacity,
        borderWidth: 1.5,
        emphasizeBorder: isEnabled,
        interactiveSurface: true,
        child: Material(
          color: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: borderRadius),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            borderRadius: borderRadius,
            onTap: onPressed,
            splashColor: isEnabled ? Colors.white.withValues(alpha: 0.2) : null,
            highlightColor:
                isEnabled ? Colors.white.withValues(alpha: 0.1) : null,
            child: Opacity(
              opacity: isEnabled ? 1.0 : 0.6,
              child: Padding(
                padding: isCircle
                    ? const EdgeInsets.all(0)
                    : const EdgeInsets.symmetric(
                        horizontal: 24.0, vertical: 8.0),
                child: Center(
                  child: _buildButtonContentWithIcon(child, wantIcon: wantIcon),
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

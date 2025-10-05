/*
* Glasser - Glass Theme Selector Widget
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
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../util/providers/theme_provider.dart';
import '../constants.dart';
import '../glass_effect.dart';
import '../platform_config.dart';

/// A theme selector that automatically becomes glassmorphic when the glass theme is active.
///
/// This widget provides a UI for selecting between different glassmorphic themes or modes.
/// It adapts its appearance to the current glass theme for visual consistency.
///
/// Example usage:
/// ```dart
/// GlassThemeSelector(
///   selectedTheme: OrionThemeMode.light,
///   onThemeChanged: (mode) {},
/// )
/// ```
///
/// See also:
///
///  * [GlassApp], for a glassmorphic background at the app level.
class GlassThemeSelector extends StatelessWidget {
  /// A theme selector that automatically becomes glassmorphic when the glass theme is active.
  final OrionThemeMode selectedTheme;
  final Function(OrionThemeMode) onThemeChanged;
  final EdgeInsetsGeometry padding;

  const GlassThemeSelector({
    super.key,
    required this.selectedTheme,
    required this.onThemeChanged,
    this.padding = const EdgeInsets.all(16.0),
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _ThemeCard(
                  mode: OrionThemeMode.light,
                  isSelected: selectedTheme == OrionThemeMode.light,
                  onTap: () => onThemeChanged(OrionThemeMode.light),
                  icon: PhosphorIcons.sun(),
                  label: 'Light',
                  primaryColor: Colors.blue,
                  backgroundColor: Colors.white,
                  textColor: Colors.black87,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ThemeCard(
                  mode: OrionThemeMode.dark,
                  isSelected: selectedTheme == OrionThemeMode.dark,
                  onTap: () => onThemeChanged(OrionThemeMode.dark),
                  icon: PhosphorIcons.moonStars(),
                  label: 'Dark',
                  primaryColor: Colors.blue,
                  backgroundColor: const Color(0xFF1E1E1E),
                  textColor: Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ThemeCard(
                  mode: OrionThemeMode.glass,
                  isSelected: selectedTheme == OrionThemeMode.glass,
                  onTap: () => onThemeChanged(OrionThemeMode.glass),
                  icon: PhosphorIcons.drop(),
                  label: 'Glass',
                  primaryColor: Colors.white,
                  backgroundColor: Colors.transparent,
                  textColor: Colors.white,
                  isGlass: true,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Individual theme preview card
class _ThemeCard extends StatelessWidget {
  final OrionThemeMode mode;
  final bool isSelected;
  final VoidCallback onTap;
  final IconData icon;
  final String label;
  final Color primaryColor;
  final Color backgroundColor;
  final Color textColor;
  final bool isGlass;

  const _ThemeCard({
    required this.mode,
    required this.isSelected,
    required this.onTap,
    required this.icon,
    required this.label,
    required this.primaryColor,
    required this.backgroundColor,
    required this.textColor,
    this.isGlass = false,
  });

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    Widget cardContent = Container(
      height: 110,
      decoration: BoxDecoration(
        color: isGlass ? null : backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected
              ? primaryColor.withValues(alpha: 0.8)
              : (themeProvider.isGlassTheme
                  ? Colors.white.withValues(alpha: 0.3)
                  : Colors.grey.withValues(alpha: 0.3)),
          width: isSelected ? 2.5 : 1,
        ),
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: primaryColor.withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Mini preview of the theme
                Container(
                  width: 32,
                  height: 20,
                  decoration: BoxDecoration(
                    color: isGlass
                        ? Colors.white.withValues(alpha: 0.2)
                        : backgroundColor == Colors.white
                            ? Colors.grey.shade200
                            : backgroundColor.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(4),
                    border: isGlass
                        ? Border.all(color: Colors.white.withValues(alpha: 0.3))
                        : null,
                  ),
                  child: Center(
                    child: Container(
                      width: 20,
                      height: 2,
                      decoration: BoxDecoration(
                        color: primaryColor.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Icon(
                  icon,
                  size: 20,
                  color: _getIconColor(themeProvider, isSelected),
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'AtkinsonHyperlegible',
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    color: _getTextColor(themeProvider, isSelected),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    // Add glassmorphic effect for glass theme preview
    if (isGlass) {
      final borderRadius = BorderRadius.circular(12);
      final fillOpacity = GlassPlatformConfig.surfaceOpacity(
        isSelected ? 0.2 : 0.12,
        emphasize: isSelected,
      );
      final boxShadow = isSelected
          ? GlassPlatformConfig.selectionGlow(blurRadius: 12, alpha: 0.28)
          : GlassPlatformConfig.surfaceShadow(
              blurRadius: 10,
              yOffset: 3,
              alpha: 0.12,
            );

      return Container(
        height: 110,
        decoration: BoxDecoration(
          borderRadius: borderRadius,
          boxShadow: boxShadow,
        ),
        child: GlassEffect(
          borderRadius: borderRadius,
          sigma: glassBlurSigma,
          opacity: fillOpacity,
          borderWidth: isSelected ? 2.2 : 1.2,
          emphasizeBorder: isSelected,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: borderRadius,
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 32,
                      height: 20,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Center(
                        child: Container(
                          width: 20,
                          height: 2,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.7),
                            borderRadius: BorderRadius.circular(1),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Icon(
                      icon,
                      size: 20,
                      color: _getIconColor(themeProvider, isSelected),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'AtkinsonHyperlegible',
                        fontSize: 14,
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.w500,
                        color: _getTextColor(themeProvider, isSelected),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return cardContent;
  }

  Color _getTextColor(ThemeProvider themeProvider, bool isSelected) {
    if (themeProvider.isGlassTheme) {
      // Glass theme viewing mode
      if (mode == OrionThemeMode.light) {
        return Colors.black87; // Light card = dark text
      } else if (mode == OrionThemeMode.dark) {
        return Colors.white; // Dark card = light text
      } else {
        return Colors.white; // Glass card = light text
      }
    } else if (themeProvider.orionThemeMode == OrionThemeMode.light) {
      // Light theme viewing mode
      if (mode == OrionThemeMode.dark) {
        return Colors.white; // Dark card = light text
      } else if (mode == OrionThemeMode.glass) {
        return Colors.black87; // Glass card = dark text
      } else {
        return isSelected ? Colors.blue : Colors.black87; // Light card
      }
    } else {
      // Dark theme viewing mode
      if (mode == OrionThemeMode.light) {
        return Colors.black87; // Light card = dark text
      } else if (mode == OrionThemeMode.glass) {
        return Colors.white; // Glass card = light text
      } else {
        return isSelected ? Colors.blue : Colors.white; // Dark card
      }
    }
  }

  Color _getIconColor(ThemeProvider themeProvider, bool isSelected) {
    // Same logic as text color
    if (themeProvider.isGlassTheme) {
      // Glass theme viewing mode
      if (mode == OrionThemeMode.light) {
        return Colors.black87; // Light card = dark icon
      } else if (mode == OrionThemeMode.dark) {
        return Colors.white; // Dark card = light icon
      } else {
        return Colors.white; // Glass card = light icon
      }
    } else if (themeProvider.orionThemeMode == OrionThemeMode.light) {
      // Light theme viewing mode
      if (mode == OrionThemeMode.dark) {
        return Colors.white; // Dark card = light icon
      } else if (mode == OrionThemeMode.glass) {
        return Colors.black87; // Glass card = dark icon
      } else {
        return isSelected ? Colors.blue : Colors.black87; // Light card
      }
    } else {
      // Dark theme viewing mode
      if (mode == OrionThemeMode.light) {
        return Colors.black87; // Light card = dark icon
      } else if (mode == OrionThemeMode.glass) {
        return Colors.white; // Glass card = light icon
      } else {
        return isSelected ? Colors.blue : Colors.white; // Dark card
      }
    }
  }
}

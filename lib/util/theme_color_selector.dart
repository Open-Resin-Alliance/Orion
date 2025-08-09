/*
* Orion - Theme Color Selector
* Copyright (C) 2024 Open Resin Alliance
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

import 'package:orion/l10n/generated/app_localizations.dart';
import 'package:orion/util/orion_config.dart';
import 'package:orion/util/providers/theme_provider.dart';

class ThemeColorSelector extends StatelessWidget {
  final OrionConfig config;

  const ThemeColorSelector({
    super.key,
    required this.config,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final themeProvider = Provider.of<ThemeProvider>(context);

    var themeOptions = [
      ThemeOption(
        name: l10n.themePurple,
        colorSeed: Colors.deepPurple,
        optionKey: 'purple',
      ),
      ThemeOption(
        name: l10n.themeBlue,
        colorSeed: Colors.blue,
        optionKey: 'blue',
      ),
      ThemeOption(
        name: l10n.themeGreen,
        colorSeed: Colors.green,
        optionKey: 'green',
      ),
      ThemeOption(
        name: l10n.themeRed,
        colorSeed: Colors.red,
        optionKey: 'red',
      ),
      ThemeOption(
        name: l10n.themeOrange,
        colorSeed: Colors.orange,
        optionKey: 'orange',
      ),
    ];

    // Add vendor theme if present
    Color vendorTheme = config.getThemeSeed('vendor');
    if (vendorTheme.r != 0 || vendorTheme.g != 0 || vendorTheme.b != 0) {
      themeOptions.insert(
          0,
          ThemeOption(
            name: config.getString('vendorName', category: 'vendor'),
            colorSeed: vendorTheme,
            optionKey: 'vendor',
          ));
    }

    final bool isThemeMandated =
        config.getFlag('mandateTheme', category: 'vendor');

    // Remove the filtering of theme options
    // Now we'll handle disabled state in the UI instead

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Use 2x3 grid layout when we have exactly 6 theme options
        if (themeOptions.length == 6)
          _build2x3Grid(context, themeOptions, themeProvider, isThemeMandated)
        else
          // Responsive grid layout that fills width for other cases
          LayoutBuilder(
            builder: (context, constraints) {
              // Calculate how many items can fit per row
              const itemWidth = 120.0;
              const spacing = 12.0;
              final availableWidth = constraints.maxWidth;
              final itemsPerRow =
                  ((availableWidth + spacing) / (itemWidth + spacing)).floor();
              final actualItemWidth =
                  (availableWidth - (spacing * (itemsPerRow - 1))) /
                      itemsPerRow;

              return Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: themeOptions.map((option) {
                  final bool isSelected =
                      themeProvider.currentColorSeed == option.colorSeed;
                  final bool isDisabled =
                      isThemeMandated && option.optionKey != 'vendor';
                  return SizedBox(
                    width: actualItemWidth,
                    child: _buildModernThemeOption(
                      context,
                      option,
                      isSelected,
                      themeProvider,
                      isDisabled: isDisabled,
                    ),
                  );
                }).toList(),
              );
            },
          ),
      ],
    );
  }

  Widget _build2x3Grid(BuildContext context, List<ThemeOption> themeOptions,
      ThemeProvider themeProvider, bool isThemeMandated) {
    const spacing = 12.0;

    return Column(
      children: [
        // First row (3 items)
        Row(
          children: [
            for (int i = 0; i < 3 && i < themeOptions.length; i++) ...[
              Expanded(
                child: _buildThemeOptionForGrid(
                  context,
                  themeOptions[i],
                  themeProvider,
                  isThemeMandated,
                ),
              ),
              if (i < 2) const SizedBox(width: spacing),
            ],
          ],
        ),
        const SizedBox(height: spacing),
        // Second row (3 items)
        Row(
          children: [
            for (int i = 3; i < 6 && i < themeOptions.length; i++) ...[
              Expanded(
                child: _buildThemeOptionForGrid(
                  context,
                  themeOptions[i],
                  themeProvider,
                  isThemeMandated,
                ),
              ),
              if (i < 5) const SizedBox(width: spacing),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildThemeOptionForGrid(BuildContext context, ThemeOption option,
      ThemeProvider themeProvider, bool isThemeMandated) {
    final bool isSelected = themeProvider.currentColorSeed == option.colorSeed;
    final bool isDisabled = isThemeMandated && option.optionKey != 'vendor';

    return _buildModernThemeOption(
      context,
      option,
      isSelected,
      themeProvider,
      isDisabled: isDisabled,
    );
  }

  Widget _buildModernThemeOption(
    BuildContext context,
    ThemeOption option,
    bool isSelected,
    ThemeProvider themeProvider, {
    bool isDisabled = false,
  }) {
    final colorToUse =
        isDisabled ? ColorFilters.dull(option.colorSeed) : option.colorSeed;

    return GestureDetector(
      onTap: isDisabled
          ? null
          : () {
              config.setString('colorSeed', option.optionKey,
                  category: 'general');
              themeProvider.setColorSeed(option.colorSeed);
            },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        height: 90,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? colorToUse.withValues(alpha: 0.8)
                : colorToUse.withValues(alpha: 0.3),
            width: isSelected ? 2.5 : 1.5,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            children: [
              // Conditional background styling
              if (themeProvider.isGlassTheme)
                // Glassmorphic background with gradient preview
                BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: _getGradientPreview(colorToUse),
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                )
              else
                // Regular dark/light mode background with subtle color tint
                Container(
                  decoration: BoxDecoration(
                    color: Color.alphaBlend(
                      colorToUse.withValues(
                          alpha: 0.08), // Very subtle color tint
                      Theme.of(context).colorScheme.surface,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),

              // Content overlay
              Container(
                padding: const EdgeInsets.all(12),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Color indicator dot
                    Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: colorToUse,
                        borderRadius: BorderRadius.circular(4),
                        boxShadow: themeProvider.isGlassTheme
                            ? [
                                BoxShadow(
                                  color: colorToUse.withValues(alpha: 0.5),
                                  blurRadius: 8,
                                  spreadRadius: 2,
                                ),
                              ]
                            : null,
                      ),
                    ),

                    // Theme name and selection indicator
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            option.name,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: themeProvider.isGlassTheme
                                  ? Colors.white.withValues(alpha: 0.9)
                                  : Theme.of(context).colorScheme.onSurface,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isSelected)
                          Container(
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              color: colorToUse,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.check,
                              size: 16,
                              color: colorToUse.computeLuminance() > 0.5
                                  ? Colors.black
                                  : Colors.white,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),

              // Disabled overlay
              if (isDisabled)
                Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .surface
                        .withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Center(
                    child: Icon(
                      Icons.lock_outline,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.5),
                      size: 20,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Generate gradient preview for glass mode color selector
  List<Color> _getGradientPreview(Color baseColor) {
    final hsl = HSLColor.fromColor(baseColor);

    // Create a simplified 3-color gradient for preview
    final darkVariant = hsl
        .withLightness((hsl.lightness * 0.4).clamp(0.0, 1.0))
        .withSaturation((hsl.saturation * 1.1).clamp(0.0, 1.0))
        .toColor();

    final midVariant =
        hsl.withLightness((hsl.lightness * 0.6).clamp(0.0, 1.0)).toColor();

    final lightVariant =
        hsl.withLightness((hsl.lightness * 0.8).clamp(0.0, 1.0)).toColor();

    return [
      darkVariant.withValues(alpha: 0.6),
      midVariant.withValues(alpha: 0.4),
      lightVariant.withValues(alpha: 0.3),
    ];
  }
}

class ThemeOption {
  final String name;
  final Color colorSeed;
  final String optionKey;

  const ThemeOption({
    required this.name,
    required this.colorSeed,
    required this.optionKey,
  });
}

class ColorFilters {
  static Color dull(Color color) {
    final hslColor = HSLColor.fromColor(color);
    return hslColor
        .withSaturation(hslColor.saturation * 0.6) // Reduce saturation
        .withLightness(hslColor.lightness * 0.8 + 0.2) // Slightly lighter
        .toColor();
  }
}

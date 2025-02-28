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

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:orion/util/orion_config.dart';
import 'package:orion/util/providers/theme_provider.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class ThemeColorSelector extends StatelessWidget {
  final OrionConfig config;
  final Function(ThemeMode) changeThemeMode;

  const ThemeColorSelector({
    super.key,
    required this.config,
    required this.changeThemeMode,
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
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: themeOptions.map((option) {
            final bool isSelected =
                themeProvider.currentColorSeed == option.colorSeed;
            final bool isDisabled =
                isThemeMandated && option.optionKey != 'vendor';
            return Expanded(
              child: Center(
                child: _buildThemeOption(
                  context,
                  option,
                  isSelected,
                  themeProvider,
                  isDisabled: isDisabled,
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildThemeOption(
    BuildContext context,
    ThemeOption option,
    bool isSelected,
    ThemeProvider themeProvider, {
    bool isDisabled = false,
  }) {
    return InkWell(
      onTap: isDisabled
          ? null
          : () {
              config.setString('colorSeed', option.optionKey,
                  category: 'general');
              themeProvider.setColorSeed(option.colorSeed);
            },
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: isDisabled
                  ? ColorFilters.dull(option.colorSeed)
                  : option.colorSeed,
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : Colors.transparent,
                width: 3,
              ),
            ),
            child: isSelected
                ? Icon(
                    Icons.check,
                    color: option.colorSeed.computeLuminance() > 0.5
                        ? Colors.black
                        : Colors.white,
                  )
                : null,
          ),
          if (isDisabled)
            ClipOval(
              child: SizedBox(
                width: 64,
                height: 64,
                child: CustomPaint(
                  painter: CrossOutPainter(
                    color: Theme.of(context).colorScheme.surface,
                    strokeWidth: 4.0,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
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

class CrossOutPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;

  CrossOutPainter({
    required this.color,
    this.strokeWidth = 4.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    // Calculate the diagonal length inside the circle
    final radius = size.width / 2;
    final diagonal = radius * 1.414; // sqrt(2)

    // Calculate start and end points to stay within circle
    final offset = (size.width - diagonal) / 2;
    canvas.drawLine(
      Offset(offset, offset),
      Offset(size.width - offset, size.height - offset),
      paint,
    );
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
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

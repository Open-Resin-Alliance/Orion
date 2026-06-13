/*
* Orion - Theme Provider
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

import 'package:orion/themes/themes.dart';
import 'package:orion/util/orion_config.dart';

enum OrionThemeMode {
  light,
  dark,
  glass, // New glassmorphic theme
}

class ThemeProvider with ChangeNotifier {
  final OrionConfig _config = OrionConfig();
  late OrionThemeMode _orionThemeMode;
  late Color _colorSeed;
  late List<Color> _themeGradient;

  ThemeProvider() {
    // Initialize theme mode from config
    final savedThemeMode = _config.getString('themeMode', category: 'general');
    _orionThemeMode = OrionThemeMode.values.firstWhere(
      (mode) => mode.name == savedThemeMode,
      orElse: () => OrionThemeMode.dark,
    );

    // Initialize color seed from config
    _colorSeed = _determineThemeColor();

    // Initialize gradient from config
    _themeGradient = _determineThemeGradient();
  }

  OrionThemeMode get orionThemeMode => _orionThemeMode;
  Color get currentColorSeed => _colorSeed;
  List<Color> get currentThemeGradient => _themeGradient;

  // For backwards compatibility with Material ThemeMode
  ThemeMode get themeMode {
    switch (_orionThemeMode) {
      case OrionThemeMode.light:
        return ThemeMode.light;
      case OrionThemeMode.dark:
      case OrionThemeMode.glass:
        return ThemeMode.dark; // Glass theme uses dark as base
    }
  }

  ThemeData get lightTheme => createLightTheme(_colorSeed);
  ThemeData get darkTheme => _orionThemeMode == OrionThemeMode.glass
      ? createGlassTheme(_colorSeed)
      : createDarkTheme(_colorSeed);

  bool get isGlassTheme => _orionThemeMode == OrionThemeMode.glass;

  void setThemeMode(OrionThemeMode mode) {
    _orionThemeMode = mode;
    _config.setString('themeMode', mode.name, category: 'general');
    notifyListeners();
  }

  // Backwards compatibility method
  void setMaterialThemeMode(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        setThemeMode(OrionThemeMode.light);
        break;
      case ThemeMode.dark:
        setThemeMode(OrionThemeMode.dark);
        break;
      case ThemeMode.system:
        // For now, map system to dark - could be enhanced later
        setThemeMode(OrionThemeMode.dark);
        break;
    }
  }

  void setColorSeed(Color color) {
    // Only allow changing color if vendor theme is not mandated
    if (!_config.getFlag('mandateTheme', category: 'vendor')) {
      _colorSeed = color;
      // Clear saved gradient when color changes to auto-generate new one
      _config.setThemeGradient([]);
      // Re-evaluate the gradient after clearing
      _themeGradient = _determineThemeGradient();
      notifyListeners();
    } else {}
  }

  void setThemeGradient(List<Color> gradient) {
    // Only allow changing gradient if vendor theme is not mandated
    if (!_config.getFlag('mandateTheme', category: 'vendor')) {
      _themeGradient = gradient;
      _config.setThemeGradient(gradient);
      notifyListeners();
    }
  }

  Color _determineThemeColor() {
    // Check for vendor theme first
    final vendorTheme = _config.getThemeSeed('vendor');
    final isVendorMandated =
        _config.getFlag('mandateTheme', category: 'vendor');

    if ((vendorTheme.r != 0 ||
            vendorTheme.g != 0 ||
            vendorTheme.b != 0 ||
            vendorTheme.a != 0) &&
        isVendorMandated) {
      return vendorTheme;
    }

    // Check for user-selected theme
    final savedColorSeed = _config.getString('colorSeed', category: 'general');
    if (savedColorSeed != 'vendor') {
      return _getColorFromKey(savedColorSeed);
    }

    // If vendor theme exists but not mandated, it's still a valid fallback
    if (vendorTheme.r != 0 ||
        vendorTheme.g != 0 ||
        vendorTheme.b != 0 ||
        vendorTheme.a != 0) {
      return vendorTheme;
    }

    // Default to blue if no other theme is set
    return Colors.purple;
  }

  List<Color> _determineThemeGradient() {
    // Check for vendor gradient first
    final vendorGradient = _config.getThemeGradient('vendor');
    final isVendorMandated =
        _config.getFlag('mandateTheme', category: 'vendor');

    if (vendorGradient.isNotEmpty && isVendorMandated) {
      return vendorGradient;
    }

    // Check for user-selected gradient
    final savedGradient = _config.getThemeGradient('primary');
    if (savedGradient.isNotEmpty) {
      return savedGradient;
    }

    // Check if user has explicitly selected vendor theme color
    final savedColorSeed = _config.getString('colorSeed', category: 'general');
    if (savedColorSeed == 'vendor' && vendorGradient.isNotEmpty) {
      return vendorGradient;
    }

    // Return empty list to auto-generate gradient from current color
    return [];
  }

  Color _getColorFromKey(String? key) {
    switch (key) {
      case 'purple':
        return Colors.deepPurple;
      case 'blue':
        return Colors.blue;
      case 'green':
        return Colors.green;
      case 'red':
        return Colors.red;
      case 'orange':
        return Colors.orange;
      case 'vendor':
        final vendorTheme = _config.getThemeSeed('vendor');
        return (vendorTheme.r != 0x0 ||
                vendorTheme.g != 0 ||
                vendorTheme.b != 0)
            ? vendorTheme
            : Colors.blue;
      default:
        return Colors.blue;
    }
  }
}

/*
* Orion - Theme Provider
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
import 'package:orion/themes/themes.dart';
import 'package:orion/util/orion_config.dart';

class ThemeProvider with ChangeNotifier {
  final OrionConfig _config = OrionConfig();
  late ThemeMode _themeMode;
  late Color _colorSeed;

  ThemeProvider() {
    // Initialize theme mode from config
    final savedThemeMode = _config.getString('themeMode', category: 'general');
    _themeMode = ThemeMode.values.firstWhere(
      (mode) => mode.name == savedThemeMode,
      orElse: () => ThemeMode.system,
    );

    // Initialize color seed from config
    _colorSeed = _determineThemeColor();
  }

  ThemeMode get themeMode => _themeMode;
  Color get currentColorSeed => _colorSeed;

  ThemeData get lightTheme => createLightTheme(_colorSeed);
  ThemeData get darkTheme => createDarkTheme(_colorSeed);

  void setThemeMode(ThemeMode mode) {
    _themeMode = mode;
    _config.setString('themeMode', mode.name, category: 'general');
    notifyListeners();
  }

  void setColorSeed(Color color) {
    // Only allow changing color if vendor theme is not mandated
    if (!_config.getFlag('mandateTheme', category: 'vendor')) {
      _colorSeed = color;
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

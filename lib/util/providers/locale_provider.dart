/*
* Orion - Locale Provider
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
import 'package:orion/util/orion_config.dart';

class LocaleProvider with ChangeNotifier {
  Locale _locale;
  final OrionConfig _config;

  LocaleProvider()
      : _locale = const Locale('en', 'US'), // Changed to include country code
        _config = OrionConfig() {
    _initLocale();
  }

  void _initLocale() {
    try {
      final savedLocale = _config.getString('orionLocale', category: 'machine');
      final parts = savedLocale.split('_');
      if (parts.length == 2) {
        // Ensure we have both language and country codes
        _locale = Locale(parts[0], parts[1]);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error initializing locale: $e');
    }
  }

  Locale get locale => _locale;

  void setLocale(Locale newLocale) {
    if (_locale != newLocale) {
      // Ensure the new locale has a country code
      if (newLocale.countryCode == null) {
        return;
      }
      _locale = newLocale;
      _config.setString(
        'orionLocale',
        '${newLocale.languageCode}_${newLocale.countryCode}',
        category: 'machine',
      );
      notifyListeners();
    }
  }
}

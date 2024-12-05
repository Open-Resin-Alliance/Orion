/*
* Orion - Localization
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

import 'locales/en_US.orionkb.dart' show en_US_keyboardLayout;
import 'locales/de_DE.orionkb.dart' show de_DE_keyboardLayout;

class OrionLocale {
  final String locale;
  final Map<String, String> keyboardLayout;

  OrionLocale({required this.locale, required this.keyboardLayout});

  static OrionLocale getLocale(String locale) {
    switch (locale) {
      case 'en_US':
        return OrionLocale(
            locale: 'en_US', keyboardLayout: en_US_keyboardLayout);
      case 'de_DE':
        return OrionLocale(
            locale: 'de_DE', keyboardLayout: de_DE_keyboardLayout);
      default:
        return OrionLocale(
            locale: 'en_US', keyboardLayout: en_US_keyboardLayout);
    }
  }
}

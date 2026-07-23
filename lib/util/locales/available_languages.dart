/*
* Orion - Available Languages
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

const List<Map<String, String>> availableLanguages = [
  // Germanic
  {'name': 'English', 'nativeName': 'English', 'code': 'en_US', 'flag': 'GB'},
  {'name': 'German', 'nativeName': 'Deutsch', 'code': 'de_DE', 'flag': 'DE'},
  {'name': 'Dutch', 'nativeName': 'Nederlands', 'code': 'nl_NL', 'flag': 'NL'},
  // Romance
  {'name': 'French', 'nativeName': 'Français', 'code': 'fr_FR', 'flag': 'FR'},
  {'name': 'Spanish', 'nativeName': 'Español', 'code': 'es_ES', 'flag': 'ES'},
  {'name': 'Italian', 'nativeName': 'Italiano', 'code': 'it_IT', 'flag': 'IT'},
  // CJK Languages
  {'name': 'Japanese', 'nativeName': '日本語', 'code': 'ja_JP', 'flag': 'JP'},
  {
    'name': 'Chinese (Simplified)',
    'nativeName': '中文',
    'code': 'zh_CN',
    'flag': 'CN'
  },
];

const Map<String, List<Map<String, String>>> languageCountrySuggestions = {
  'en_US': [
    {'name': 'United States', 'nativeName': 'United States', 'code': 'US'},
    {'name': 'United Kingdom', 'nativeName': 'United Kingdom', 'code': 'GB'},
    {'name': 'Canada', 'nativeName': 'Canada', 'code': 'CA'},
  ],
  'de_DE': [
    {'name': 'Germany', 'nativeName': 'Deutschland', 'code': 'DE'},
    {'name': 'Austria', 'nativeName': 'Österreich', 'code': 'AT'},
    {'name': 'Switzerland', 'nativeName': 'Schweiz', 'code': 'CH'},
  ],
  'nl_NL': [
    {'name': 'Netherlands', 'nativeName': 'Nederland', 'code': 'NL'},
    {'name': 'Belgium', 'nativeName': 'België', 'code': 'BE'},
  ],
  'fr_FR': [
    {'name': 'France', 'nativeName': 'France', 'code': 'FR'},
    {'name': 'Canada', 'nativeName': 'Canada', 'code': 'CA'},
    {'name': 'Belgium', 'nativeName': 'Belgique', 'code': 'BE'},
    {'name': 'Switzerland', 'nativeName': 'Suisse', 'code': 'CH'},
  ],
  'es_ES': [
    {'name': 'Spain', 'nativeName': 'España', 'code': 'ES'},
    {'name': 'Mexico', 'nativeName': 'México', 'code': 'MX'},
    {'name': 'Colombia', 'nativeName': 'Colombia', 'code': 'CO'},
    {'name': 'Argentina', 'nativeName': 'Argentina', 'code': 'AR'},
  ],
  'it_IT': [
    {'name': 'Italy', 'nativeName': 'Italia', 'code': 'IT'},
    {'name': 'Switzerland', 'nativeName': 'Svizzera', 'code': 'CH'},
  ],
  'ja_JP': [
    {'name': 'Japan', 'nativeName': '日本', 'code': 'JP'},
  ],
  'zh_CN': [
    {'name': 'China', 'nativeName': '中国', 'code': 'CN'},
    {'name': 'Singapore', 'nativeName': '新加坡', 'code': 'SG'},
  ],
};

// Welcome messages in different languages
const Map<String, String> welcomeMessages = {
  'en': 'Welcome',
  'de': 'Willkommen',
  'nl': 'Welkom',
  'fr': 'Bienvenue',
  'es': 'Bienvenido',
  'it': 'Benvenuto',
  'ja': 'ようこそ',
  'zh_CN': '欢迎',
};

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
  // Romance
  {'name': 'Spanish', 'nativeName': 'Español', 'code': 'es_ES', 'flag': 'ES'},
  {'name': 'French', 'nativeName': 'Français', 'code': 'fr_FR', 'flag': 'FR'},
  // Slavic
  {'name': 'Polish', 'nativeName': 'Polski', 'code': 'pl_PL', 'flag': 'PL'},
  // Balkan
  {'name': 'Croatian', 'nativeName': 'Hrvatski', 'code': 'hr_HR', 'flag': 'HR'},
  // CJK Languages
  {'name': 'Japanese', 'nativeName': '日本語', 'code': 'ja_JP', 'flag': 'JP'},
  {'name': 'Korean', 'nativeName': '한국어', 'code': 'ko_KR', 'flag': 'KR'},
  /*{
    'name': 'Chinese (Simplified)',
    'nativeName': '中文 (简体)',
    'code': 'zh_CN',
    'flag': 'CN'
  },
  {
    'name': 'Chinese (Traditional)',
    'nativeName': '中文 (繁體)',
    'code': 'zh_TW',
    'flag': 'TW'
  },*/
];

const Map<String, List<Map<String, String>>> languageCountrySuggestions = {
  'en_US': [
    {'name': 'United States', 'nativeName': 'United States', 'code': 'US'},
    {'name': 'United Kingdom', 'nativeName': 'United Kingdom', 'code': 'GB'},
    {'name': 'Canada', 'nativeName': 'Canada', 'code': 'CA'},
    {'name': 'Australia', 'nativeName': 'Australia', 'code': 'AU'},
    {'name': 'Ireland', 'nativeName': 'Ireland', 'code': 'IE'},
    {'name': 'New Zealand', 'nativeName': 'New Zealand', 'code': 'NZ'},
    {'name': 'Singapore', 'nativeName': 'Singapore', 'code': 'SG'},
    {'name': 'India', 'nativeName': 'India', 'code': 'IN'},
    {'name': 'South Africa', 'nativeName': 'South Africa', 'code': 'ZA'},
  ],
  'es_ES': [
    {'name': 'Spain', 'nativeName': 'España', 'code': 'ES'},
    {'name': 'Mexico', 'nativeName': 'México', 'code': 'MX'},
    {'name': 'Colombia', 'nativeName': 'Colombia', 'code': 'CO'},
    {'name': 'Argentina', 'nativeName': 'Argentina', 'code': 'AR'},
    {'name': 'Peru', 'nativeName': 'Perú', 'code': 'PE'},
    {'name': 'United States', 'nativeName': 'Estados Unidos', 'code': 'US'},
    {'name': 'Chile', 'nativeName': 'Chile', 'code': 'CL'},
  ],
  'fr_FR': [
    {'name': 'France', 'nativeName': 'France', 'code': 'FR'},
    {'name': 'Canada', 'nativeName': 'Canada', 'code': 'CA'},
    {'name': 'Belgium', 'nativeName': 'Belgique', 'code': 'BE'},
    {'name': 'Switzerland', 'nativeName': 'Suisse', 'code': 'CH'},
    {'name': 'Luxembourg', 'nativeName': 'Luxembourg', 'code': 'LU'},
    {'name': 'Monaco', 'nativeName': 'Monaco', 'code': 'MC'},
  ],
  'de_DE': [
    {'name': 'Germany', 'nativeName': 'Deutschland', 'code': 'DE'},
    {'name': 'Austria', 'nativeName': 'Österreich', 'code': 'AT'},
    {'name': 'Switzerland', 'nativeName': 'Schweiz', 'code': 'CH'},
    {'name': 'Luxembourg', 'nativeName': 'Luxemburg', 'code': 'LU'},
    {'name': 'Belgium', 'nativeName': 'Belgien', 'code': 'BE'},
  ],
  'zh_CN': [
    {'name': 'China', 'nativeName': '中国', 'code': 'CN'},
    {'name': 'Singapore', 'nativeName': '新加坡', 'code': 'SG'},
    {'name': 'Malaysia', 'nativeName': '马来西亚', 'code': 'MY'},
    {'name': 'Taiwan', 'nativeName': '台湾', 'code': 'TW'},
  ],
  'zh_TW': [
    {'name': 'Taiwan', 'nativeName': '台灣', 'code': 'TW'},
    {'name': 'Hong Kong', 'nativeName': '香港', 'code': 'HK'},
    {'name': 'Macau', 'nativeName': '澳門', 'code': 'MO'},
  ],
  'ja_JP': [
    {'name': 'Japan', 'nativeName': '日本', 'code': 'JP'},
    {'name': 'Brazil', 'nativeName': 'ブラジル', 'code': 'BR'},
    {'name': 'United States', 'nativeName': 'アメリカ合衆国', 'code': 'US'},
  ],
  'ko_KR': [
    {'name': 'South Korea', 'nativeName': '대한민국', 'code': 'KR'},
    {'name': 'North Korea', 'nativeName': '조선민주주의인민공화국', 'code': 'KP'},
    {'name': 'United States', 'nativeName': '미국', 'code': 'US'},
    {'name': 'Japan', 'nativeName': '일본', 'code': 'JP'},
    {'name': 'China', 'nativeName': '중국', 'code': 'CN'},
  ],
  'pl_PL': [
    {'name': 'Poland', 'nativeName': 'Polska', 'code': 'PL'},
    {'name': 'Germany', 'nativeName': 'Niemcy', 'code': 'DE'},
    {'name': 'United Kingdom', 'nativeName': 'Wielka Brytania', 'code': 'GB'},
    {'name': 'Ireland', 'nativeName': 'Irlandia', 'code': 'IE'},
    {'name': 'United States', 'nativeName': 'Stany Zjednoczone', 'code': 'US'}
  ],
  'hr_HR': [
    {'name': 'Croatia', 'nativeName': 'Hrvatska', 'code': 'HR'},
    {
      'name': 'Bosnia and Herzegovina',
      'nativeName': 'Bosna i Hercegovina',
      'code': 'BA'
    },
    {'name': 'Serbia', 'nativeName': 'Srbija', 'code': 'RS'},
    {'name': 'Germany', 'nativeName': 'Njemačka', 'code': 'DE'},
    {'name': 'Austria', 'nativeName': 'Austrija', 'code': 'AT'}
  ]
};

// Welcome messages in different languages
const Map<String, String> welcomeMessages = {
  'en': 'Welcome',
  'de': 'Willkommen',
  'es': 'Bienvenido',
  'fr': 'Bienvenue',
  'ja': 'ようこそ',
  'ko': '환영합니다',
  'zh_CN': '欢迎',
  'zh_TW': '歡迎',
};

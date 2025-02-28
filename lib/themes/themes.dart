/*
* Orion - Themes
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
import 'package:flex_seed_scheme/flex_seed_scheme.dart';

ThemeData createLightTheme(Color seedColor) {
  return ThemeData(
    fontFamily: 'AtkinsonHyperlegible',
    colorScheme: SeedColorScheme.fromSeeds(
      primaryKey: seedColor,
      brightness: Brightness.light,
      variant: FlexSchemeVariant.soft,
    ),
    appBarTheme: const AppBarTheme(
      titleTextStyle: TextStyle(
        fontFamily: 'AtkinsonHyperlegible',
        fontSize: 30,
        color: Colors.black,
      ),
      centerTitle: true,
      toolbarHeight: 65,
      iconTheme: IconThemeData(size: 30),
    ),
    textTheme: const TextTheme(
      bodyMedium: TextStyle(fontFamily: 'AtkinsonHyperlegible', fontSize: 20),
      titleLarge: TextStyle(
          fontFamily: 'AtkinsonHyperlegible', fontSize: 20), // For AppBar title
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      selectedLabelStyle:
          TextStyle(fontFamily: 'AtkinsonHyperlegible', fontSize: 18),
      unselectedLabelStyle:
          TextStyle(fontFamily: 'AtkinsonHyperlegible', fontSize: 18),
      selectedIconTheme: IconThemeData(size: 30),
      unselectedIconTheme: IconThemeData(size: 30),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ButtonStyle(
        minimumSize: WidgetStateProperty.all<Size>(
            const Size(88, 50)), // Set the width and height
      ),
    ),
    useMaterial3: true,
  );
}

ThemeData createDarkTheme(Color seedColor) {
  return ThemeData(
    fontFamily: 'AtkinsonHyperlegible',
    colorScheme: SeedColorScheme.fromSeeds(
      primaryKey: seedColor,
      brightness: Brightness.dark,
      variant: FlexSchemeVariant.soft,
    ),
    appBarTheme: const AppBarTheme(
      titleTextStyle: TextStyle(
        fontFamily: 'AtkinsonHyperlegible',
        fontSize: 30,
        color: Colors.white,
      ),
      centerTitle: true,
      toolbarHeight: 65,
      iconTheme: IconThemeData(size: 30),
    ),
    textTheme: const TextTheme(
      bodyMedium: TextStyle(fontFamily: 'AtkinsonHyperlegible', fontSize: 20),
      titleLarge: TextStyle(
          fontFamily: 'AtkinsonHyperlegible', fontSize: 20), // For AppBar title
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      selectedLabelStyle:
          TextStyle(fontFamily: 'AtkinsonHyperlegible', fontSize: 18),
      unselectedLabelStyle:
          TextStyle(fontFamily: 'AtkinsonHyperlegible', fontSize: 18),
      selectedIconTheme: IconThemeData(size: 30),
      unselectedIconTheme: IconThemeData(size: 30),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ButtonStyle(
        minimumSize: WidgetStateProperty.all<Size>(
            const Size(88, 50)), // Set the width and height
      ),
    ),
    useMaterial3: true,
  );
}

extension ColorBrightness on Color {
  Color withBrightness(double factor) {
    assert(factor >= 0);

    final hsl = HSLColor.fromColor(this);
    final increasedLightness = (hsl.lightness * factor).clamp(0.0, 1.0);

    return hsl.withLightness(increasedLightness).toColor();
  }
}

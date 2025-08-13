/*
* Orion - Themes
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

ThemeData createGlassTheme(Color seedColor) {
  return ThemeData(
    fontFamily: 'AtkinsonHyperlegible',
    colorScheme: SeedColorScheme.fromSeeds(
      primaryKey: seedColor,
      brightness: Brightness.dark,
      variant: FlexSchemeVariant.soft,
    ),
    scaffoldBackgroundColor: Colors.transparent,
    // Use custom opaque transitions to prevent layering issues
    pageTransitionsTheme: PageTransitionsTheme(
      builders: {
        TargetPlatform.android: _OpaquePageTransitionsBuilder(),
        TargetPlatform.iOS: _OpaquePageTransitionsBuilder(),
        TargetPlatform.linux: _OpaquePageTransitionsBuilder(),
        TargetPlatform.macOS: _OpaquePageTransitionsBuilder(),
        TargetPlatform.windows: _OpaquePageTransitionsBuilder(),
      },
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      titleTextStyle: TextStyle(
        fontFamily: 'AtkinsonHyperlegible',
        fontSize: 30,
        color: Colors.white,
      ),
      centerTitle: true,
      toolbarHeight: 65,
      iconTheme: IconThemeData(size: 30, color: Colors.white),
      foregroundColor: Colors.white,
    ),
    textTheme: const TextTheme(
      bodyMedium: TextStyle(
        fontFamily: 'AtkinsonHyperlegible',
        fontSize: 20,
        color: Colors.white,
      ),
      titleLarge: TextStyle(
        fontFamily: 'AtkinsonHyperlegible',
        fontSize: 20,
        color: Colors.white,
      ),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: Colors.transparent,
      selectedLabelStyle: TextStyle(
        fontFamily: 'AtkinsonHyperlegible',
        fontSize: 18,
        color: Colors.white,
      ),
      unselectedLabelStyle: TextStyle(
        fontFamily: 'AtkinsonHyperlegible',
        fontSize: 18,
        color: Colors.white70,
      ),
      selectedIconTheme: IconThemeData(size: 30, color: Colors.white),
      unselectedIconTheme: IconThemeData(size: 30, color: Colors.white70),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.all(Colors.transparent),
        foregroundColor: WidgetStateProperty.all(Colors.white),
        shadowColor: WidgetStateProperty.all(Colors.transparent),
        elevation: WidgetStateProperty.all(0),
        shape: WidgetStateProperty.all(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        minimumSize: WidgetStateProperty.all(const Size(88, 50)),
      ),
    ),
    dialogTheme: const DialogThemeData(
      backgroundColor: Colors.transparent,
      elevation: 0,
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

/// Custom page transitions builder that uses an opaque background during transitions
/// to prevent the glassmorphic layering issue
class _OpaquePageTransitionsBuilder extends PageTransitionsBuilder {
  @override
  Widget buildTransitions<T extends Object?>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    // Wrap the child with an opaque background during transition
    Widget wrappedChild = Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF4A148C), // Darker deep purple
            Color(0xFF880E4F), // Darker vibrant pink
            Color(0xFFE65100), // Darker rich orange
          ],
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.5),
        ),
        child: child,
      ),
    );

    // Use a simple fade transition
    return FadeTransition(
      opacity: animation,
      child: wrappedChild,
    );
  }
}

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
import 'package:flutter/foundation.dart';

import 'package:flex_seed_scheme/flex_seed_scheme.dart';

String _primaryFontFamily() {
  // flutter-pi (and some older embedders) have limited support for
  // variable fonts. Prefer the static Atkinson family on Linux.
  return defaultTargetPlatform == TargetPlatform.linux
      ? 'AtkinsonHyperlegible'
      : 'AtkinsonHyperlegibleNext';
}

List<String> _cjkFallbackFamilies() => const [
      'AtkinsonHyperlegible',
      // Prefer explicit CJK families instead of a combined alias to
      // improve compatibility on older font engines.
      'NotoSansSC',
      'NotoSansJP',
      'NotoSansKR',
    ];

ThemeData createLightTheme(Color seedColor) {
  return ThemeData(
    fontFamily: _primaryFontFamily(),
    // Keep classic Atkinson as secondary fallback, then explicit CJK families
    fontFamilyFallback: _cjkFallbackFamilies(),
    colorScheme: SeedColorScheme.fromSeeds(
      primaryKey: seedColor,
      brightness: Brightness.light,
      variant: FlexSchemeVariant.soft,
    ),
    appBarTheme: AppBarTheme(
      titleTextStyle: TextStyle(
        fontFamily: _primaryFontFamily(),
        fontFamilyFallback: _cjkFallbackFamilies(),
        fontSize: 30,
        color: Colors.black,
      ),
      centerTitle: false,
      titleSpacing: 16.0,
      toolbarHeight: 65,
      iconTheme: IconThemeData(size: 30),
    ),
    // Ensure the TextTheme entries include the CJK fallback
    textTheme: _withCjkFallback(TextTheme(
      bodyMedium:
        TextStyle(fontFamily: _primaryFontFamily(), fontSize: 20),
      titleLarge: TextStyle(
        fontFamily: _primaryFontFamily(),
        fontSize: 20), // For AppBar title
    )),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      selectedLabelStyle: TextStyle(
        fontFamily: _primaryFontFamily(),
        fontFamilyFallback: _cjkFallbackFamilies(),
          fontSize: 18),
      unselectedLabelStyle: TextStyle(
        fontFamily: _primaryFontFamily(),
        fontFamilyFallback: _cjkFallbackFamilies(),
          fontSize: 18),
      selectedIconTheme: IconThemeData(size: 30),
      unselectedIconTheme: IconThemeData(size: 30),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ButtonStyle(
        minimumSize: WidgetStateProperty.all<Size>(
            const Size(88, 50)), // Set the width and height
        shape: WidgetStateProperty.all<RoundedRectangleBorder>(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
        ),
      ),
    ),
    useMaterial3: true,
  );
}

ThemeData createDarkTheme(Color seedColor) {
  return ThemeData(
    fontFamily: _primaryFontFamily(),
    fontFamilyFallback: _cjkFallbackFamilies(),
    colorScheme: SeedColorScheme.fromSeeds(
      primaryKey: seedColor,
      brightness: Brightness.dark,
      variant: FlexSchemeVariant.soft,
    ),
    appBarTheme: AppBarTheme(
      titleTextStyle: TextStyle(
        fontFamily: _primaryFontFamily(),
        fontFamilyFallback: _cjkFallbackFamilies(),
        fontSize: 30,
        color: Colors.white,
      ),
      centerTitle: false,
      titleSpacing: 16.0,
      toolbarHeight: 65,
      iconTheme: const IconThemeData(size: 30, color: Colors.white),
    ),
    textTheme: _withCjkFallback(TextTheme(
      bodyMedium:
        TextStyle(fontFamily: _primaryFontFamily(), fontSize: 20),
      titleLarge: TextStyle(
        fontFamily: _primaryFontFamily(),
        fontSize: 20), // For AppBar title
    )),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      selectedLabelStyle: TextStyle(
        fontFamily: _primaryFontFamily(),
        fontFamilyFallback: _cjkFallbackFamilies(),
          fontSize: 18),
      unselectedLabelStyle: TextStyle(
        fontFamily: _primaryFontFamily(),
        fontFamilyFallback: _cjkFallbackFamilies(),
          fontSize: 18),
      selectedIconTheme: const IconThemeData(size: 30),
      unselectedIconTheme: const IconThemeData(size: 30),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ButtonStyle(
        minimumSize: WidgetStateProperty.all<Size>(
            const Size(88, 50)), // Set the width and height
        shape: WidgetStateProperty.all<RoundedRectangleBorder>(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
        ),
      ),
    ),
    useMaterial3: true,
  );
}

ThemeData createGlassTheme(Color seedColor) {
  return ThemeData(
    fontFamily: _primaryFontFamily(),
    fontFamilyFallback: _cjkFallbackFamilies(),
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
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      titleTextStyle: TextStyle(
        fontFamily: _primaryFontFamily(),
        fontFamilyFallback: _cjkFallbackFamilies(),
        fontSize: 30,
        color: Colors.white,
      ),
      centerTitle: false,
      titleSpacing: 16.0,
      toolbarHeight: 65,
      iconTheme: const IconThemeData(size: 30, color: Colors.white),
      foregroundColor: Colors.white,
    ),
    textTheme: _withCjkFallback(TextTheme(
      bodyMedium: TextStyle(
        fontFamily: _primaryFontFamily(),
        fontSize: 20,
        color: Colors.white,
      ),
      titleLarge: TextStyle(
        fontFamily: _primaryFontFamily(),
        fontSize: 20,
        color: Colors.white,
      ),
    )),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: Colors.transparent,
      selectedLabelStyle: TextStyle(
        fontFamily: _primaryFontFamily(),
        fontSize: 18,
        color: Colors.white,
      ),
      unselectedLabelStyle: TextStyle(
        fontFamily: _primaryFontFamily(),
        fontSize: 18,
        color: Colors.white70,
      ),
      selectedIconTheme: const IconThemeData(size: 30, color: Colors.white),
      unselectedIconTheme: const IconThemeData(size: 30, color: Colors.white70),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.all(Colors.transparent),
        foregroundColor: WidgetStateProperty.all(Colors.white),
        shadowColor: WidgetStateProperty.all(Colors.transparent),
        elevation: WidgetStateProperty.all(0),
        shape: WidgetStateProperty.all(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
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

// Helper to inject CJK fallback into every non-null TextStyle of a TextTheme.
TextTheme _withCjkFallback(TextTheme t) {
  TextStyle? applyFallback(TextStyle? s) {
    if (s == null) return null;
    // If already has fallback, keep it; otherwise add explicit CJK families.
    final existing = s.fontFamilyFallback ?? const <String>[];
    final cjk = _cjkFallbackFamilies();
    final missing = cjk.where((f) => !existing.contains(f)).toList();
    if (missing.isEmpty) return s;
    return s.copyWith(fontFamilyFallback: [...existing, ...missing]);
  }

  return TextTheme(
    displayLarge: applyFallback(t.displayLarge),
    displayMedium: applyFallback(t.displayMedium),
    displaySmall: applyFallback(t.displaySmall),
    headlineLarge: applyFallback(t.headlineLarge),
    headlineMedium: applyFallback(t.headlineMedium),
    headlineSmall: applyFallback(t.headlineSmall),
    titleLarge: applyFallback(t.titleLarge),
    titleMedium: applyFallback(t.titleMedium),
    titleSmall: applyFallback(t.titleSmall),
    bodyLarge: applyFallback(t.bodyLarge),
    bodyMedium: applyFallback(t.bodyMedium),
    bodySmall: applyFallback(t.bodySmall),
    labelLarge: applyFallback(t.labelLarge),
    labelMedium: applyFallback(t.labelMedium),
    labelSmall: applyFallback(t.labelSmall),
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

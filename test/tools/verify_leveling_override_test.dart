/*
* Orion - Verify Leveling Debug Override Test
* Copyright (C) 2026 Open Resin Alliance
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
import 'package:flutter_i18n/flutter_i18n.dart';
import 'package:flutter_i18n/loaders/decoders/json_decode_strategy.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:orion/backend_service/backend_service.dart';
import 'package:orion/backend_service/providers/manual_provider.dart';
import 'package:orion/backend_service/providers/resins_provider.dart';
import 'package:orion/backend_service/providers/status_provider.dart';
import 'package:orion/glasser/glasser.dart';
import 'package:orion/materials/calibration_context_provider.dart';
import 'package:orion/tools/athena/verify_leveling_screen.dart';
import 'package:orion/tools/leveling_screen.dart';
import 'package:orion/util/orion_config.dart';
import 'package:orion/util/providers/locale_provider.dart';
import 'package:orion/util/providers/theme_provider.dart';
import 'package:orion/util/providers/wifi_provider.dart';

import '../fakes/fake_odyssey_client.dart';

Future<void> _pumpFor(WidgetTester tester, [int ms = 2000]) async {
  for (var t = 0; t < ms; t += 250) {
    await tester.pump(const Duration(milliseconds: 250));
  }
}

void main() {
  late FakeBackendClient backend;

  /// Pins [isLeveled] and the debug override for one test, restoring both on
  /// teardown so the shared `orion.cfg` is untouched.
  void setLeveling({required bool leveled, required bool override}) {
    final config = OrionConfig();
    final beforeLeveled = config.isLeveled();
    final beforeOverride =
        config.getFlag('alwaysAllowLevelVerification', category: 'developer');
    config.setLeveled(leveled);
    config.setFlag('alwaysAllowLevelVerification', override,
        category: 'developer');
    addTearDown(() {
      config.setLeveled(beforeLeveled);
      config.setFlag('alwaysAllowLevelVerification', beforeOverride,
          category: 'developer');
    });
  }

  Future<void> pumpScreen(WidgetTester tester, Widget widget) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    backend = FakeBackendClient();
    BackendService.debugSetSharedDelegate(backend);

    final delegate = FlutterI18nDelegate(
      translationLoader: FileTranslationLoader(
        useCountryCode: false,
        fallbackFile: 'en',
        basePath: 'assets/i18n',
        decodeStrategies: [JsonDecodeStrategy()],
      ),
    );
    await delegate.load(const Locale('en'));

    final theme = ThemeProvider();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<ThemeProvider>.value(value: theme),
          ChangeNotifierProvider(create: (_) => LocaleProvider()),
          ChangeNotifierProvider(
              create: (_) => WiFiProvider(startPolling: false)),
          ChangeNotifierProvider(create: (_) => StatusProvider(client: backend)),
          ChangeNotifierProvider(create: (_) => ManualProvider(client: backend)),
          ChangeNotifierProvider(create: (_) => ResinsProvider()),
          ChangeNotifierProvider(create: (_) => CalibrationContextProvider()),
        ],
        child: Consumer<ThemeProvider>(
          builder: (context, themeProvider, _) => MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: [delegate],
            supportedLocales: const [Locale('en')],
            theme: theme.lightTheme,
            home: Scaffold(body: widget),
          ),
        ),
      ),
    );
    await _pumpFor(tester);
  }

  String tr(WidgetTester tester, String key) =>
      FlutterI18n.translate(tester.element(find.byType(Scaffold).first), key);

  testWidgets('the override alone opens the verify entry',
      (WidgetTester tester) async {
    setLeveling(leveled: false, override: false);
    expect(canVerifyLeveling(), isFalse);

    setLeveling(leveled: false, override: true);
    expect(canVerifyLeveling(), isTrue);
  });

  testWidgets('the menu verify entry follows the override',
      (WidgetTester tester) async {
    setLeveling(leveled: false, override: false);
    await pumpScreen(tester, const LevelingScreen());

    GlassButton verifyButton() => tester.widget<GlassButton>(find
        .ancestor(
            of: find.text(tr(tester, 'leveling.verify')),
            matching: find.byType(GlassButton))
        .first);

    expect(verifyButton().onPressed, isNull);

    setLeveling(leveled: false, override: true);
    await pumpScreen(tester, const LevelingScreen());
    expect(verifyButton().onPressed, isNotNull);
  });

  testWidgets('with no data the override still offers the re-check',
      (WidgetTester tester) async {
    setLeveling(leveled: false, override: true);
    await pumpScreen(tester, const VerifyLevelingScreen());

    expect(find.text(tr(tester, 'leveling.verifyNoData')), findsOneWidget);
    expect(find.text(tr(tester, 'leveling.verifyNoDataOverrideHint')),
        findsOneWidget);
    expect(find.text(tr(tester, 'leveling.recheckLeveling')), findsOneWidget);
  });

  testWidgets('without the override no data stays a dead end',
      (WidgetTester tester) async {
    setLeveling(leveled: false, override: false);
    await pumpScreen(tester, const VerifyLevelingScreen());

    expect(find.text(tr(tester, 'leveling.verifyNoData')), findsOneWidget);
    expect(find.text(tr(tester, 'leveling.verifyNoDataHint')), findsOneWidget);
    expect(find.text(tr(tester, 'leveling.recheckLeveling')), findsNothing);
  });
}

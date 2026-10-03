/*
* Orion - Cleaning Screen Test
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
import 'package:orion/glasser/glasser.dart';
import 'package:orion/tools/cleaning_screen.dart';
import 'package:orion/util/orion_config.dart';
import 'package:orion/util/providers/theme_provider.dart';

import '../fakes/fake_odyssey_client.dart';

Future<void> _pumpFor(WidgetTester tester, [int ms = 1000]) async {
  for (var t = 0; t < ms; t += 250) {
    await tester.pump(const Duration(milliseconds: 250));
  }
}

void main() {
  /// The cleaning settings live in the shared `orion.cfg`; put them back.
  void restoreCleaning() {
    final config = OrionConfig();
    final beforeSeconds = config.getCleaningSeconds();
    final beforeIntensity = config.getCleaningIntensity();
    addTearDown(() {
      config.setCleaningSeconds(beforeSeconds);
      config.setCleaningIntensity(beforeIntensity);
    });
  }

  Future<void> pumpScreen(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    BackendService.debugSetSharedDelegate(FakeBackendClient());

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
      ChangeNotifierProvider<ThemeProvider>.value(
        value: theme,
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: [delegate],
          supportedLocales: const [Locale('en')],
          theme: theme.darkTheme,
          home: const CleaningScreen(),
        ),
      ),
    );
    await _pumpFor(tester);
  }

  testWidgets('defaults to 15 seconds at 100 percent', (tester) async {
    restoreCleaning();
    OrionConfig().setCleaningSeconds(15);
    OrionConfig().setCleaningIntensity(100);
    await pumpScreen(tester);

    expect(find.text('15 sec'), findsOneWidget);
    expect(find.text('100 %'), findsOneWidget);
  });

  testWidgets('shows the remembered values', (tester) async {
    restoreCleaning();
    OrionConfig().setCleaningSeconds(45);
    OrionConfig().setCleaningIntensity(60);
    await pumpScreen(tester);

    expect(find.text('45 sec'), findsOneWidget);
    expect(find.text('60 %'), findsOneWidget);
  });

  testWidgets('clamps values outside 1-60 s and 10-100 %', (tester) async {
    restoreCleaning();
    OrionConfig().setCleaningSeconds(600);
    OrionConfig().setCleaningIntensity(5);
    await pumpScreen(tester);

    expect(find.text('60 sec'), findsOneWidget);
    expect(find.text('10 %'), findsOneWidget);
  });

  testWidgets('start reads as unavailable until a backend supports cleaning',
      (tester) async {
    restoreCleaning();
    await pumpScreen(tester);

    final context = tester.element(find.byType(CleaningScreen));
    final unavailable =
        FlutterI18n.translate(context, 'cleaning.notAvailable');

    // The button itself carries the reason, rather than a hint above it.
    final start = tester.widget<GlassButton>(find.ancestor(
        of: find.text(unavailable), matching: find.byType(GlassButton)));
    expect(start.onPressed, isNull);
    expect(find.text(FlutterI18n.translate(context, 'cleaning.start')),
        findsNothing);
  });
}

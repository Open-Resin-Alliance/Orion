/*
* Orion - Exposure Screen Test
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
import 'package:orion/backend_service/providers/config_provider.dart';
import 'package:orion/backend_service/providers/manual_provider.dart';
import 'package:orion/tools/exposure_screen.dart';
import 'package:orion/util/hold_button.dart';
import 'package:orion/util/providers/theme_provider.dart';

import '../fakes/fake_odyssey_client.dart';

/// The exposure screen warms up from the backend config; an empty one is
/// enough for it to come up healthy.
class _ConfigFake extends FakeBackendClient {
  @override
  Future<Map<String, dynamic>> getConfig() async => <String, dynamic>{};
}

void main() {
  Future<void> pumpForLocal(WidgetTester tester, [int ms = 1500]) async {
    for (var t = 0; t < ms; t += 250) {
      await tester.pump(const Duration(milliseconds: 250));
    }
  }

  Future<void> pumpScreen(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final client = _ConfigFake();
    BackendService.debugSetSharedDelegate(client);

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
          ChangeNotifierProvider(create: (_) => ConfigProvider(client: client)),
          ChangeNotifierProvider(create: (_) => ManualProvider(client: client)),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: [delegate],
          supportedLocales: const [Locale('en')],
          theme: theme.darkTheme,
          home: const ExposureScreen(),
        ),
      ),
    );
    await pumpForLocal(tester);
  }

  testWidgets('every exposure run starts on a short, unmarked hold',
      (tester) async {
    await pumpScreen(tester);

    // Grid, Logo, Measure and White.
    final holds = tester.widgetList<HoldButton>(find.byType(HoldButton));
    expect(holds.length, 4);
    for (final hold in holds) {
      expect(hold.duration, const Duration(milliseconds: 200));
      // Secret: no hold-me finger on the edge.
      expect(hold.showHoldIcon, isFalse);
    }
  });

  testWidgets('a plain tap explains that the button must be held',
      (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.widgetWithText(HoldButton, 'Grid'));
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    final context = tester.element(find.byType(ExposureScreen));
    expect(find.text(FlutterI18n.translate(context, 'exposure.holdHint')),
        findsOneWidget);

    // Let the toast retire so no timer outlives the test.
    await tester.pump(const Duration(seconds: 3));
  });
}

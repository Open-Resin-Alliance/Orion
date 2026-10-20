/*
* Orion - Tank Clean Screen Test
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

import 'package:orion/backend_service/backend_registry.dart';
import 'package:orion/backend_service/backend_service.dart';
import 'package:orion/glasser/glasser.dart';
import 'package:orion/tools/cleaning_screen.dart';
import 'package:orion/util/hold_button.dart';
import 'package:orion/util/orion_config.dart';
import 'package:orion/util/providers/theme_provider.dart';

import '../fakes/fake_odyssey_client.dart';

Future<void> _pumpFor(WidgetTester tester, [int ms = 1000]) async {
  for (var t = 0; t < ms; t += 250) {
    await tester.pump(const Duration(milliseconds: 250));
  }
}

void main() {
  late FakeBackendClient backend;

  // Capabilities come from the registry, which the app fills at startup.
  setUpAll(() => BackendRegistry().registerBuiltInModules());

  /// The clean time lives in the shared `orion.cfg`; put it back.
  void restoreCleaning() {
    final config = OrionConfig();
    final before = config.getCleaningSeconds();
    addTearDown(() => config.setCleaningSeconds(before));
  }

  Future<void> pumpScreen(WidgetTester tester) async {
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

  testWidgets('defaults to 15 seconds', (tester) async {
    restoreCleaning();
    OrionConfig().setCleaningSeconds(15);
    await pumpScreen(tester);

    expect(find.text('15'), findsOneWidget);
  });

  testWidgets('shows the remembered time', (tester) async {
    restoreCleaning();
    OrionConfig().setCleaningSeconds(45);
    await pumpScreen(tester);

    expect(find.text('45'), findsOneWidget);
  });

  testWidgets('clamps a time outside 1-60 s', (tester) async {
    restoreCleaning();
    OrionConfig().setCleaningSeconds(600);
    await pumpScreen(tester);

    expect(find.text('60'), findsOneWidget);
  });

  testWidgets('warns about looking at the running exposure', (tester) async {
    restoreCleaning();
    await pumpScreen(tester);

    final context = tester.element(find.byType(CleaningScreen));
    expect(find.text(FlutterI18n.translate(context, 'cleaning.explainer')),
        findsOneWidget);
    expect(find.text(FlutterI18n.translate(context, 'cleaning.uvWarning')),
        findsOneWidget);
    expect(find.text(FlutterI18n.translate(context, 'cleaning.holdHint')),
        findsOneWidget);
  });

  testWidgets('holding the button runs the NanoDLP compound',
      (tester) async {
    restoreCleaning();
    await pumpScreen(tester);

    // The run only starts after the button has been held down.
    final hold = find.byType(HoldButton);
    expect(hold, findsOneWidget);

    final gesture = await tester.startGesture(tester.getCenter(hold));
    // Let the tap recogniser win (its press deadline) before the hold runs.
    await _pumpFor(tester, 2000);
    await gesture.up();
    await _pumpFor(tester, 1000);

    // Blank the frame, put the projector on, then set the LED duty at full.
    expect(backend.displayTestCalled, isTrue);
    expect(backend.commands, ['UVLED_ON PWM=1']);
    expect(backend.manualCureCalled, isTrue);

    // The run is held by the shared countdown, which can be ended early.
    expect(find.text('Tank Cleaning\u2026'), findsOneWidget);
    await tester.tap(find.widgetWithText(GlassButton, 'Stop'));
    await _pumpFor(tester, 1000);

    expect(backend.lastCommand, 'UVLED_OFF');
  });

  testWidgets('reports a backend without tank clean support', (tester) async {
    restoreCleaning();
    final config = OrionConfig();
    final beforeBackend = config.getString('backend', category: 'advanced');
    config.setString('backend', 'odyssey', category: 'advanced');
    addTearDown(
        () => config.setString('backend', beforeBackend, category: 'advanced'));

    await pumpScreen(tester);

    final context = tester.element(find.byType(CleaningScreen));
    final unavailable =
        FlutterI18n.translate(context, 'cleaning.notAvailable');
    expect(find.text(unavailable), findsOneWidget);
    expect(find.byType(HoldButton), findsNothing);
  });
}

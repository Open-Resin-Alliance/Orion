/*
* Orion - Post-Calibration Overlay Test
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
import 'package:orion/backend_service/domain/models.dart';
import 'package:orion/glasser/glasser.dart';
import 'package:orion/materials/post_calibration_overlay.dart';
import 'package:orion/util/orion_kb/orion_textfield_spawn.dart';
import 'package:orion/util/providers/theme_provider.dart';

import '../fakes/fake_odyssey_client.dart';

/// Records where a save lands, so a test can tell the template from its copy.
class _RecordingBackend extends FakeBackendClient {
  final List<Map<String, dynamic>> clones = [];
  final List<Map<String, dynamic>> saves = [];

  @override
  Future<Map<String, dynamic>> cloneProfile(
      int sourceId, Map<String, dynamic> fields) async {
    clones.add({'source': sourceId, ...fields});
    return {'ProfileID': 4242, 'Title': fields['Title']};
  }

  @override
  Future<ResinSettings?> getResinSettings(int profileId) async {
    return const ResinSettings(
      normalCureTime: 1.0,
      burnInCureTime: 8.0,
      burnInCount: 4,
      liftAfterPrint: 5.0,
      waitAfterCure: 1.0,
      waitAfterLife: 1.0,
    );
  }

  @override
  Future<void> saveResinSettings(int profileId, ResinSettings settings) async {
    saves.add({'profile': profileId, 'exposure': settings.normalCureTime});
  }

  @override
  Future<void> saveResinExposure(int profileId, double normalCureTime) async {
    saves.add({'profile': profileId, 'exposure': normalCureTime});
  }
}

Future<void> _pumpOverlay(
  WidgetTester tester,
  _RecordingBackend backend, {
  required bool isTemplate,
}) async {
  // A roomy surface: the test font is wider than the real one, and the
  // overlay's summary row is laid out for the printer's screen.
  tester.view.physicalSize = const Size(1200, 800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

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

  await tester.pumpWidget(
    MultiProvider(
      providers: [ChangeNotifierProvider(create: (_) => ThemeProvider())],
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: [delegate],
        supportedLocales: const [Locale('en')],
        home: PostCalibrationOverlay(
          calibrationModelName: 'RERF',
          resinProfileName: 'Factory Profile',
          startExposure: 1.0,
          exposureIncrement: 0.2,
          profileId: 7,
          calibrationModelId: 1,
          profileIsTemplate: isTemplate,
          onComplete: () {},
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();

  // The overlay opens on its summary; the piece picker is one step further in.
  await tester.tap(find.text('Next'));
  await tester.pumpAndSettle();
  expect(find.text('Select the piece matching the guide.'), findsOneWidget);
}

/// Pumps by hand: the Orion text field blinks, so `pumpAndSettle` never
/// returns once the naming dialog is on screen.
Future<void> _pumpFrames(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 200));
  }
}

Future<void> _saveSecondPiece(WidgetTester tester,
    {bool confirmClone = false}) async {
  await tester.tap(find.text('1.2s'));
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(GlassButton, 'Save'));
  await _pumpFrames(tester);

  if (confirmClone) {
    expect(find.text('Save to a new profile'), findsOneWidget);
    expect(find.byType(SpawnOrionTextField), findsOneWidget);

    // The field starts empty and offers the name as its hint, so there is
    // nothing to clear before typing - and typing nothing carries it over.
    final field = find.byType(SpawnOrionTextField);
    expect(tester.state<SpawnOrionTextFieldState>(field).getCurrentText(),
        isEmpty);
    expect(find.text('Factory Profile (calibrated)'), findsOneWidget);
    await tester.tap(find.descendant(
      of: find.byType(GlassAlertDialog),
      matching: find.widgetWithText(GlassButton, 'Save'),
    ));
  }
  await _pumpFrames(tester);
}

void main() {
  testWidgets('saving from a template copies it and saves to the copy',
      (WidgetTester tester) async {
    final backend = _RecordingBackend();
    await _pumpOverlay(tester, backend, isTemplate: true);

    await _saveSecondPiece(tester, confirmClone: true);

    // The template is copied under the name the dialog offered...
    expect(backend.clones, [
      {'source': 7, 'Title': 'Factory Profile (calibrated)'}
    ]);
    // ...and the exposure goes to the copy, never to the template.
    expect(backend.saves.single['profile'], 4242);
    expect(backend.saves.single['exposure'], closeTo(1.2, 0.001));
    expect(find.textContaining('Factory Profile (calibrated)'), findsWidgets);
  });

  testWidgets('saving an ordinary profile writes to it directly',
      (WidgetTester tester) async {
    final backend = _RecordingBackend();
    await _pumpOverlay(tester, backend, isTemplate: false);

    await _saveSecondPiece(tester);

    expect(backend.clones, isEmpty);
    expect(backend.saves.single['profile'], 7);
    expect(backend.saves.single['exposure'], closeTo(1.2, 0.001));
  });
}

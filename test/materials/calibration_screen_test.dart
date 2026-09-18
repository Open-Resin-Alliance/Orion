/*
* Orion - Calibration Screen Test
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
import 'package:orion/backend_service/providers/analytics_provider.dart';
import 'package:orion/backend_service/providers/resins_provider.dart';
import 'package:orion/backend_service/providers/status_provider.dart';
import 'package:orion/util/providers/wifi_provider.dart';

import '../fakes/fake_odyssey_client.dart';
import 'package:orion/materials/calibration_screen.dart';
import 'package:orion/glasser/glasser.dart';
import 'package:orion/util/orion_spacing.dart';
import 'package:orion/util/providers/theme_provider.dart';

/// Minimal backend for the status widget the resin picker's app bar carries.
class _StubBackend extends FakeBackendClient {
  @override
  Future<Map<String, dynamic>> listItems(
          String location, int pageSize, int pageIndex, String subdirectory) async =>
      {'files': <Map<String, dynamic>>[]};

  @override
  Future<List<Map<String, dynamic>>> getCalibrationModels() async => [];

  @override
  Future<int?> getDefaultProfileId() async => null;

  @override
  Future<Map<String, dynamic>> getStatus() async => {};

  @override
  Stream<Map<String, dynamic>> getStatusStream() => const Stream.empty();
}

/// The calibration screen only needs the lists and one selection, so the
/// provider's fetches are stubbed out rather than driven through a backend.
class _FakeResinsProvider extends ResinsProvider {
  static final _resins = [
    ResinProfile('Standard Resin',
        path: '/profile/edit/simple/5', meta: {'LayerHeight': 0.05}),
    ResinProfile('Thin Resin',
        path: '/profile/edit/simple/6', meta: {'LayerHeight': 0.03}),
  ];
  static final _models = [
    CalibrationModel(id: 1, name: 'RERF', models: 6, testPiecesCount: 6),
  ];

  @override
  bool get isLoading => false;

  @override
  List<ResinProfile> get userResins => _resins;

  @override
  List<CalibrationModel> get calibrationModels => _models;

  @override
  CalibrationModel? get selectedCalibrationModel => _models.first;

  @override
  String? calibrationImageUrl(int modelId) => null;

  @override
  Future<void> ensureCalibrationImage(int modelId, {bool notify = true}) async {}

  @override
  Future<void> refresh() async {}

  @override
  ResinProfile? getRecommendedResin([CalibrationModel? model]) => _resins.first;

  @override
  void setSelectedCalibrationModelId(int? id) {}
}

final _backend = _StubBackend();

/// Disposes the app-bar providers and drains their polling timers, which the
/// test binding otherwise reports as pending at teardown.
class _Harness {
  _Harness(this.status, this.analytics, this.wifi);

  final StatusProvider status;
  final AnalyticsProvider analytics;
  final WiFiProvider wifi;

  Future<void> dispose(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    status.dispose();
    analytics.dispose();
    wifi.dispose();
    await tester.pump(const Duration(milliseconds: 250));
  }
}

Future<_Harness> _pumpCalibration(WidgetTester tester) async {
  BackendService.debugSetSharedDelegate(_backend);
  final status = StatusProvider(client: _backend);
  final analytics = AnalyticsProvider(client: _backend);
  final wifi = WiFiProvider(startPolling: false);
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
      providers: [
        ChangeNotifierProvider<ResinsProvider>(
            create: (_) => _FakeResinsProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider<StatusProvider>.value(value: status),
        ChangeNotifierProvider<AnalyticsProvider>.value(value: analytics),
        ChangeNotifierProvider<WiFiProvider>.value(value: wifi),
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: [delegate],
        supportedLocales: const [Locale('en')],
        home: const Scaffold(
          body: MediaQuery(
            data: MediaQueryData(size: Size(1200, 800)),
            child: CalibrationScreen(),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return _Harness(status, analytics, wifi);
}

void main() {
  testWidgets('calibration walks resin, model, starting exposure, increment',
      (WidgetTester tester) async {
    final harness = await _pumpCalibration(tester);
    try {

    // Step 1 asks for the resin and offers the picker, without listing every
    // resin, and has nothing to go back to.
    expect(
        find.text(
            'Please select the resin profile you would like to calibrate below'),
        findsOneWidget);
    expect(find.text('Back'), findsNothing);
    // The prompt is self-explanatory, so this step carries no explainer.
    expect(
        find.text(
            'Calibration prints test pieces at increasing exposures so you can pick the best one.'),
        findsNothing);
    expect(find.text('Standard Resin'), findsOneWidget); // the suggestion
    // The profile's layer height rides along as a chip, as on the materials page.
    expect(find.text('50 µm'), findsOneWidget);
    // The prompt names the field, so the card carries the value alone.
    expect(find.text('Resin Profile'), findsNothing);
    expect(find.text('Thin Resin'), findsNothing);
    expect(find.text('Next'), findsOneWidget);
    expect(find.text('Start Calibration'), findsNothing);
    expect(find.text('Starting Exposure'), findsNothing);

    // Geometry: one guide column sized to 80% of the content width, with the
    // primary action directly below the selector.
    final screen = tester.getRect(find.byType(Scaffold).first);
    final contentWidth =
        screen.width - 2 * (OrionSpacing.screenHorizontal - 4.0);
    final column =
        tester.getRect(find.byKey(const Key('calibration-guide-column')));
    final selector =
        tester.getRect(find.widgetWithText(GlassCard, 'Standard Resin'));
    final primary = tester.getRect(find.widgetWithText(GlassButton, 'Next'));
    expect(column.width, closeTo(contentWidth * 0.80, 0.5));
    // Centred: equal margins either side of the column.
    expect(column.left - screen.left, closeTo(screen.right - column.right, 0.5));
    expect(selector.width, closeTo(column.width, 0.5));
    expect(primary.width, selector.width);
    expect(primary.top, greaterThan(selector.bottom));

    // The card opens the resin list; picking one comes back selected.
    await tester.tap(find.text('Standard Resin'));
    await tester.pumpAndSettle();
    expect(find.text('Thin Resin'), findsOneWidget);
    // Every row carries the layer height chip, as on the materials page.
    expect(find.text('50 µm'), findsOneWidget);
    expect(find.text('30 µm'), findsOneWidget);
    await tester.tap(find.text('Thin Resin'));
    await tester.pumpAndSettle();
    expect(find.text('Thin Resin'), findsOneWidget);
    expect(find.text('Standard Resin'), findsNothing);
    // And the selection carries its own layer height onto the card.
    expect(find.text('30 µm'), findsOneWidget);

    await tester.tap(find.text('Next'));
    await tester.pump(const Duration(milliseconds: 100));
    // Mid-transition both pages are on screen, cross-fading.
    expect(find.text('Please select the resin profile you would like to calibrate below'),
        findsOneWidget);
    expect(find.text('Select the calibration model you would like to print below'),
        findsOneWidget);
    await tester.pumpAndSettle();

    // Step 2 is the model: the same compact card, with the preview left to the
    // picker rather than the selector.
    expect(find.text('Select the calibration model you would like to print below'),
        findsOneWidget);
    // Only the exposure steps explain themselves.
    expect(find.text('The model sets how many test pieces the calibration prints.'),
        findsNothing);
    expect(find.text('RERF'), findsOneWidget);
    expect(find.text('Next'), findsOneWidget);
    expect(find.text('Thin Resin'), findsNothing);
    expect(find.byType(Image), findsNothing);
    final modelCard = tester.getRect(find.widgetWithText(GlassCard, 'RERF'));
    expect(modelCard.height, 88);
    expect(modelCard.width, closeTo(column.width, 0.5));

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    // Step 3 is the starting exposure: the header explains the one field, so
    // the card carries the value alone.
    expect(find.text('Please set the starting exposure'), findsOneWidget);
    expect(find.text('Exposure time for the first test piece.'), findsOneWidget);
    expect(find.text('Starting Exposure'), findsNothing);
    expect(find.text('1.00 seconds'), findsOneWidget);
    expect(find.text('Exposure Increment'), findsNothing);

    // A shorter header must not shift anything below it: the selector and the
    // actions hold the position they had on step 1.
    final shorterSelector = tester.getRect(
        find.widgetWithText(GlassCard, '1.00 seconds'));
    final shorterPrimary = tester.getRect(find.widgetWithText(GlassButton, 'Next'));
    expect(shorterSelector.top, selector.top);
    expect(shorterSelector.bottom, selector.bottom);
    expect(shorterPrimary.top, primary.top);
    expect(shorterPrimary.bottom, primary.bottom);

    // Back and the primary action split the column evenly.
    expect(
      tester.getRect(find.widgetWithText(GlassButton, 'Back')).width,
      tester.getRect(find.widgetWithText(GlassButton, 'Next')).width,
    );

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    final lastSelector = tester.getRect(find.widgetWithText(GlassCard, '0.20 seconds'));
    final lastPrimary = tester.getRect(
        find.widgetWithText(GlassButton, 'Start Calibration'));
    expect(lastSelector.top, selector.top);
    expect(lastSelector.bottom, selector.bottom);
    expect(lastPrimary.top, primary.top);
    expect(lastPrimary.bottom, primary.bottom);

    // Step 4 is the exposure increment, and it starts the print.
    expect(find.text('Please set the exposure increment'), findsOneWidget);
    expect(find.text('How much exposure increases per test piece.'),
        findsOneWidget);
    expect(find.text('0.20 seconds'), findsOneWidget);
    expect(find.text('Start Calibration'), findsOneWidget);
    expect(find.text('Next'), findsNothing);
    expect(
      tester.getRect(find.widgetWithText(GlassButton, 'Back')).width,
      tester
          .getRect(find.widgetWithText(GlassButton, 'Start Calibration'))
          .width,
    );

    // And Back walks the workflow backwards, one page at a time.
    await tester.tap(find.text('Back'));
    await tester.pumpAndSettle();
    expect(find.text('Please set the starting exposure'), findsOneWidget);
    await tester.tap(find.text('Back'));
    await tester.pumpAndSettle();
      expect(find.text('RERF'), findsWidgets);
      expect(find.text('Please set the starting exposure'), findsNothing);
    } finally {
      await harness.dispose(tester);
    }
  });
}

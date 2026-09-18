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
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:orion/glasser/glasser.dart';
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

  static final _locked = ResinProfile('Factory Profile',
      path: '/profile/edit/simple/7',
      meta: {'LayerHeight': 0.05},
      locked: true);

  @override
  List<ResinProfile> get userResins => _resins;

  @override
  List<ResinProfile> get resins => [..._resins, _locked];

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
  testWidgets('calibration walks source, resin, model, exposure, increment',
      (WidgetTester tester) async {
    final harness = await _pumpCalibration(tester);
    try {
    // The tab introduces the wizard; the setup itself opens over the shell, so
    // it is not squeezed between the app bar and the bottom navigation.
    expect(find.text('This wizard will guide you through calibration.'),
        findsOneWidget);
    // It explains what calibration does before it starts.
    expect(
      find.text(
          'Test pieces are printed at increasing exposures. You pick the best one, and its exposure time is saved to the resin profile.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Start Calibration'));
    await tester.pumpAndSettle();
    expect(find.byType(CalibrationWizardScreen), findsOneWidget);

    // The overlay leaves the tab visible behind it, so anything that appears on
    // both has to be looked for inside the wizard.
    Finder inWizard(String text) => find.descendant(
          of: find.byType(CalibrationWizardScreen),
          matching: find.text(text),
        );

    // Step 1 asks where the profile comes from, and will not move on until it
    // is answered.
    expect(find.text('Start from a template or an existing profile?'),
        findsOneWidget);
    expect(find.text('Template'), findsOneWidget);
    expect(find.text('Existing Profile'), findsOneWidget);
    expect(find.text('Back'), findsNothing);
    expect(find.text('Cancel'), findsOneWidget);
    expect(
      tester
          .widget<GlassButton>(find.widgetWithText(GlassButton, 'Next'))
          .onPressed,
      isNull,
    );

    await tester.tap(find.text('Existing Profile'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    // Step 2 asks for the profile, starting from the recommended one. The
    // header names the field, so the card carries the value alone.
    expect(
        find.text(
            'Please select the resin profile you would like to calibrate below'),
        findsOneWidget);
    expect(find.text('Standard Resin'), findsOneWidget);
    expect(find.text('50 µm'), findsOneWidget);
    expect(find.text('Resin Profile'), findsNothing);
    expect(find.text('Next'), findsOneWidget);
    expect(inWizard('Start Calibration'), findsNothing);
    expect(find.text('Starting Exposure'), findsNothing);

    // Geometry: one guide column spanning the content width, with the primary
    // action directly below the selector.
    final screen = tester.getRect(find.byType(Scaffold).first);
    // The wizard matches the pre-flight page it hands over to: 24pt gutters,
    // header and actions spanning the full width.
    final contentWidth = screen.width - 48;
    final column =
        tester.getRect(find.byKey(const Key('calibration-guide-column')));
    final selector =
        tester.getRect(find.widgetWithText(GlassCard, 'Standard Resin'));
    final primary = tester.getRect(find.widgetWithText(GlassButton, 'Next'));
    expect(column.width, closeTo(contentWidth, 0.5));
    expect(column.left - screen.left, closeTo(screen.right - column.right, 0.5));
    expect(selector.width, closeTo(column.width, 0.5));
    // Back and the action share the column evenly.
    expect(
      tester.getRect(find.widgetWithText(GlassButton, 'Back')).width,
      primary.width,
    );
    expect(primary.top, greaterThan(selector.bottom));

    // The picker offers the pool that was chosen - the user's own profiles,
    // drawn as the materials list draws them.
    await tester.tap(find.text('Standard Resin'));
    await tester.pumpAndSettle();
    expect(find.text('Thin Resin'), findsOneWidget);
    expect(find.text('Factory Profile'), findsNothing);
    expect(find.text('50 µm'), findsOneWidget);
    expect(find.text('30 µm'), findsOneWidget);
    // One selection marker: the row's own green tick, as on the materials
    // list - not the old badge plus trailing bubble pair.
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    expect(find.byIcon(Icons.check_circle), findsNothing);
    expect(find.byIcon(Icons.check), findsNothing);
    final selectedName = tester.widget<Text>(find.text('Standard Resin'));
    expect(selectedName.style?.color, Colors.green.shade400);
    await tester.tap(find.text('Thin Resin'));
    await tester.pumpAndSettle();
    expect(find.text('Thin Resin'), findsOneWidget);
    expect(find.text('30 µm'), findsOneWidget);

    // Going back and switching pools drops a profile that is no longer offered,
    // and the picker then shows the factory templates instead.
    await tester.tap(find.text('Back'));
    await tester.pumpAndSettle();
    expect(find.text('Start from a template or an existing profile?'),
        findsOneWidget);
    await tester.tap(find.text('Template'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('Select Resin'), findsOneWidget);
    await tester.tap(find.text('Select Resin'));
    await tester.pumpAndSettle();
    expect(find.text('Factory Profile'), findsOneWidget);
    expect(find.text('Standard Resin'), findsNothing);
    expect(find.text('Thin Resin'), findsNothing);
    await tester.tap(find.text('Factory Profile'));
    await tester.pumpAndSettle();
    expect(find.text('Factory Profile'), findsOneWidget);

    await tester.tap(find.text('Next'));
    await tester.pump(const Duration(milliseconds: 100));
    // Mid-transition both pages are on screen, cross-fading.
    expect(
        find.text(
            'Please select the resin profile you would like to calibrate below'),
        findsOneWidget);
    expect(
        find.text(
            'Please select the calibration model you would like to print below'),
        findsOneWidget);
    await tester.pumpAndSettle();

    // Step 3 is the model: the same compact card, with the preview left to the
    // picker rather than the selector.
    expect(
        find.text(
            'Please select the calibration model you would like to print below'),
        findsOneWidget);
    expect(
        find.text('The model sets how many test pieces the calibration prints.'),
        findsNothing);
    expect(find.text('RERF'), findsOneWidget);
    expect(find.text('Next'), findsOneWidget);
    expect(find.text('Factory Profile'), findsNothing);
    expect(find.byType(Image), findsNothing);
    final modelCard = tester.getRect(find.widgetWithText(GlassCard, 'RERF'));
    expect(modelCard.height, 88);
    expect(modelCard.width, closeTo(column.width, 0.5));

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    // Step 4 is the starting exposure: the header explains the one field, so
    // the card carries the value alone.
    expect(find.text('Please set the starting exposure'), findsOneWidget);
    expect(find.text('Exposure time for the first test piece.'), findsOneWidget);
    expect(find.text('Starting Exposure'), findsNothing);
    expect(find.text('1.00 seconds'), findsOneWidget);
    expect(find.text('Exposure Increment'), findsNothing);

    // Header and buttons follow the leveling wizard's treatment: a bold
    // primary-coloured title over a larger body line, and icon + label buttons
    // spaced by the shared control gap.
    final headerText =
        tester.widget<Text>(find.text('Please set the starting exposure'));
    expect(headerText.style?.fontSize, 24);
    expect(headerText.style?.fontWeight, FontWeight.bold);
    expect(
      headerText.style?.color,
      Theme.of(tester.element(find.byType(CalibrationWizardScreen)))
          .colorScheme
          .primary,
    );
    final hintText = tester
        .widget<Text>(find.text('Exposure time for the first test piece.'));
    expect(hintText.style?.fontSize, 20);
    final backButton = tester.getRect(find.widgetWithText(GlassButton, 'Back'));
    final nextButton = tester.getRect(find.widgetWithText(GlassButton, 'Next'));
    expect(nextButton.left - backButton.right, closeTo(16, 0.5));
    expect(
      find.descendant(
        of: find.byType(CalibrationWizardScreen),
        matching: find.byIcon(PhosphorIcons.arrowLeft()),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(CalibrationWizardScreen),
        matching: find.byIcon(PhosphorIcons.arrowRight()),
      ),
      findsOneWidget,
    );

    // The actions never move, and the control sits midway between the step's
    // header and them.
    final shorterSelector = tester.getRect(
        find.widgetWithText(GlassCard, '1.00 seconds'));
    final shorterPrimary =
        tester.getRect(find.widgetWithText(GlassButton, 'Next'));
    expect(shorterPrimary.top, primary.top);
    expect(shorterPrimary.bottom, primary.bottom);
    final body = tester.getRect(find.byType(AnimatedSwitcher));
    final headerBottom = tester
        .getRect(find.text('Exposure time for the first test piece.'))
        .bottom;
    expect(shorterSelector.top - headerBottom,
        closeTo(body.bottom - shorterSelector.bottom, 0.5));

    // Back and the primary action split the column evenly.
    expect(
      tester.getRect(find.widgetWithText(GlassButton, 'Back')).width,
      tester.getRect(find.widgetWithText(GlassButton, 'Next')).width,
    );

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    // Step 5 is the exposure increment, and it starts the print.
    expect(find.text('Please set the exposure increment'), findsOneWidget);
    expect(find.text('How much exposure increases per test piece.'),
        findsOneWidget);
    expect(find.text('0.20 seconds'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(CalibrationWizardScreen),
        matching: find.text('Start Calibration'),
      ),
      findsOneWidget,
    );
    expect(find.text('Next'), findsNothing);
    final lastSelector =
        tester.getRect(find.widgetWithText(GlassCard, '0.20 seconds'));
    final lastPrimary = tester.getRect(find.descendant(
      of: find.byType(CalibrationWizardScreen),
      matching: find.widgetWithText(GlassButton, 'Start Calibration'),
    ));
    expect(lastPrimary.top, primary.top);
    expect(lastPrimary.bottom, primary.bottom);
    final lastBody = tester.getRect(find.byType(AnimatedSwitcher));
    final lastHeaderBottom = tester
        .getRect(find.text('How much exposure increases per test piece.'))
        .bottom;
    expect(lastSelector.top - lastHeaderBottom,
        closeTo(lastBody.bottom - lastSelector.bottom, 0.5));
    expect(
      tester.getRect(find.widgetWithText(GlassButton, 'Back')).width,
      lastPrimary.width,
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

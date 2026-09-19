/*
* Orion - Onboarding Wizard Offers Test
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
import 'package:orion/backend_service/providers/manual_provider.dart';
import 'package:orion/backend_service/providers/resins_provider.dart';
import 'package:orion/backend_service/providers/status_provider.dart';
import 'package:orion/glasser/glasser.dart';
import 'package:orion/home/onboarding_screen.dart';
import 'package:orion/materials/calibration_context_provider.dart';
import 'package:orion/materials/calibration_screen.dart';
import 'package:orion/tools/athena/c3d_athena2_wizard.dart';
import 'package:orion/util/orion_config.dart';
import 'package:orion/util/providers/locale_provider.dart';
import 'package:orion/util/providers/theme_provider.dart';
import 'package:orion/util/providers/wifi_provider.dart';

import '../fakes/fake_odyssey_client.dart';

Future<void> pumpFor(WidgetTester tester, [int ms = 2000]) async {
  for (var t = 0; t < ms; t += 250) {
    await tester.pump(const Duration(milliseconds: 250));
  }
}

void main() {
  late FakeBackendClient backend;

  Future<void> pumpOnboarding(WidgetTester tester) async {
    // The printer's own surface: the walk taps the floating buttons, which the
    // default 800x600 test window pushes under the page content.
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

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => ThemeProvider()),
          ChangeNotifierProvider(create: (_) => LocaleProvider()),
          ChangeNotifierProvider(
              create: (_) => WiFiProvider(startPolling: false)),
          ChangeNotifierProvider(create: (_) => AnalyticsProvider()),
          ChangeNotifierProvider(create: (_) => StatusProvider(client: backend)),
          ChangeNotifierProvider(create: (_) => ManualProvider(client: backend)),
          ChangeNotifierProvider(create: (_) => ResinsProvider()),
          ChangeNotifierProvider(create: (_) => CalibrationContextProvider()),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: [delegate],
          supportedLocales: const [Locale('en')],
          home: const OnboardingScreen(),
        ),
      ),
    );
    await pumpFor(tester);
  }

  /// Runs the welcome hand-off and then follows whatever each step offers until
  /// the leveling step is on screen.
  Future<void> walkToLevelingStep(WidgetTester tester) async {
    String t(String key) =>
        FlutterI18n.translate(tester.element(find.byType(Scaffold).first), key);

    await tester.tap(
        find.widgetWithText(GlassFloatingActionButton, t('setup.getStarted')));
    await pumpFor(tester, 6000);

    for (var i = 0; i < 14; i++) {
      // The step's title is on the app bar whichever body it shows.
      if (find.text(t('setup.verifyLevelingTitle')).evaluate().isNotEmpty) break;
      final hasNext = find.text(t('common.next')).evaluate().isNotEmpty;
      final hasSkip = find.text(t('common.skip')).evaluate().isNotEmpty;
      // The first three steps hide their floating button, so drive them by the
      // control they do show; a hidden button still exists in the tree.
      final onLanguage =
          find.text(t('setup.languageTitle')).evaluate().isNotEmpty;
      final onCardStep =
          find.text(t('setup.regionTitle')).evaluate().isNotEmpty ||
              find.text(t('setup.timezoneTitle')).evaluate().isNotEmpty;
      if (onLanguage) {
        await tester.tap(find.text('English').first);
      } else if (onCardStep && find.byType(GlassCard).evaluate().isNotEmpty) {
        await tester.tap(find.byType(GlassCard).first);
      } else if (hasSkip) {
        await tester.tap(
            find.widgetWithText(GlassFloatingActionButton, t('common.skip')));
        await pumpFor(tester, 1000);
        if (find.text(t('wifi.skipAnyway')).evaluate().isNotEmpty) {
          await tester.tap(find.text(t('wifi.skipAnyway')));
        }
      } else if (hasNext) {
        await tester.tap(
            find.widgetWithText(GlassFloatingActionButton, t('common.next')));
      } else {
        break;
      }
      await pumpFor(tester, 2500);
    }

    expect(find.text(t('setup.verifyLevelingTitle')), findsOneWidget);
  }

  /// The leveling state the leveling menu guards Verify Leveling with, and that
  /// this step is guarded by.
  void setLeveled(bool value) {
    final config = OrionConfig();
    final before = config.isLeveled();
    config.setLeveled(value);
    addTearDown(() => config.setLeveled(before));
  }

  testWidgets('with no leveling data the step explains itself',
      (WidgetTester tester) async {
    setLeveled(false);
    await pumpOnboarding(tester);
    await walkToLevelingStep(tester);

    String t(String key) =>
        FlutterI18n.translate(tester.element(find.byType(Scaffold).first), key);

    // Nothing to check, so no offer -- the step says so instead.
    expect(find.text(t('setup.levelingNotLeveled')), findsOneWidget);
    expect(find.text(t('setup.levelingNotLeveledHint')), findsOneWidget);
    expect(find.text(t('leveling.recheckLeveling')), findsNothing);
    expect(find.text(t('common.decline')), findsNothing);

    // The step owns its button, so the floating Next is inert: the faded button
    // is still in the tree, but tapping it must change nothing.
    await tester.tap(find.text(t('common.next')).first, warnIfMissed: false);
    await pumpFor(tester, 1500);
    expect(find.text(t('setup.levelingNotLeveled')), findsOneWidget);
    expect(find.text(t('common.completeSetup')), findsNothing);

    // Continue -> the calibration offer, built the same way.
    await tester.tap(find.widgetWithText(GlassButton, t('common.continue_')));
    await pumpFor(tester, 2500);
    expect(find.text(t('setup.calibrationIntro')), findsOneWidget);
    expect(find.text(t('calibration.start')), findsOneWidget);

    // Its decline -> the completion step.
    await tester.tap(find.widgetWithText(GlassButton, t('common.decline')));
    await pumpFor(tester, 2500);
    expect(find.textContaining(t('complete.completionMessage')), findsOneWidget);
    expect(find.text(t('common.completeSetup')), findsOneWidget);
  });

  testWidgets('a leveled printer is offered the re-check',
      (WidgetTester tester) async {
    setLeveled(true);
    await pumpOnboarding(tester);
    await walkToLevelingStep(tester);

    String t(String key) =>
        FlutterI18n.translate(tester.element(find.byType(Scaffold).first), key);

    expect(find.text(t('setup.levelingIntro')), findsOneWidget);
    expect(find.text(t('setup.levelingIntroDetail')), findsOneWidget);
    expect(find.text(t('leveling.recheckLeveling')), findsWidgets);
    expect(find.text(t('common.decline')), findsOneWidget);

    await tester
        .tap(find.widgetWithText(GlassButton, t('leveling.recheckLeveling')));
    await pumpFor(tester, 2500);
    expect(find.byType(Athena2LevelingWizard), findsOneWidget);

    tester.state<NavigatorState>(find.byType(Navigator).first).pop();
    await pumpFor(tester, 3000);

    // Closing it carries onboarding on to the calibration offer.
    expect(find.text(t('setup.calibrationIntro')), findsOneWidget);
  });

  testWidgets('the calibration offer opens the calibration wizard',
      (WidgetTester tester) async {
    setLeveled(false);
    await pumpOnboarding(tester);
    await walkToLevelingStep(tester);

    String t(String key) =>
        FlutterI18n.translate(tester.element(find.byType(Scaffold).first), key);

    await tester.tap(find.widgetWithText(GlassButton, t('common.continue_')));
    await pumpFor(tester, 2500);
    expect(find.text(t('setup.calibrationIntro')), findsOneWidget);

    await tester.tap(find.widgetWithText(GlassButton, t('calibration.start')));
    await pumpFor(tester, 2500);
    expect(find.byType(CalibrationWizardScreen), findsOneWidget);

    tester.state<NavigatorState>(find.byType(Navigator).first).pop();
    await pumpFor(tester, 3000);

    // Closing it carries onboarding on to the completion step.
    expect(find.textContaining(t('complete.completionMessage')), findsOneWidget);
  });
}

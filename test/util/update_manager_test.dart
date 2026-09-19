/*
* Orion - Update Manager Test
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
import 'package:orion/backend_service/providers/status_provider.dart';
import 'package:orion/glasser/glasser.dart';
import 'package:orion/util/providers/athena_update_provider.dart';
import 'package:orion/util/providers/orion_update_provider.dart';
import 'package:orion/util/providers/theme_provider.dart';
import 'package:orion/settings/update_progress.dart';
import 'package:orion/util/update_manager.dart';

import '../fakes/fake_odyssey_client.dart';

class _StubBackend extends FakeBackendClient {
  bool updated = false;

  @override
  Future<void> updateBackend() async {
    updated = true;
  }

  @override
  Future<Map<String, dynamic>> getStatus() async => {};

  @override
  Stream<Map<String, dynamic>> getStatusStream() => const Stream.empty();
}

/// Puts the printer on the development firmware channel, which is the branch
/// that runs three confirmations in a row.
class _MasterChannelProvider extends AthenaUpdateProvider {
  _MasterChannelProvider() {
    channel = 'master';
  }
}

Future<void> _pumpFrames(WidgetTester tester, {int frames = 8}) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 250));
  }
}

void main() {
  late _StubBackend backend;
  late UpdateManager manager;
  late StatusProvider status;
  late FlutterI18nDelegate delegate;

  /// The status provider polls, so it has to be disposed inside the test body:
  /// the binding checks for pending timers before tear-downs run.
  Future<void> stopPolling(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    manager.dispose();
    status.dispose();
    await tester.pump(const Duration(milliseconds: 250));
  }

  Future<void> pumpGate(WidgetTester tester) async {
    backend = _StubBackend();
    BackendService.debugSetSharedDelegate(backend);
    manager = UpdateManager(
      OrionUpdateProvider(),
      _MasterChannelProvider(),
      enableAutoChecks: false,
    );
    status = StatusProvider(client: backend);

    delegate = FlutterI18nDelegate(
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
          ChangeNotifierProvider<StatusProvider>.value(value: status),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: [delegate],
          supportedLocales: const [Locale('en')],
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: GlassButton(
                  onPressed: () => manager.startAthenaUpdate(context),
                  child: const Text('start'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('cancelling a dev-firmware warning falls through to the offer',
      (WidgetTester tester) async {
    await pumpGate(tester);
    try {
    await tester.tap(find.text('start'));
    await _pumpFrames(tester);

    // First confirmation.
    expect(find.text(FlutterI18n.translate(tester.element(find.text('start')),
        'update.devFirmware')), findsOneWidget);

    await tester.tap(find.widgetWithText(GlassButton,
        FlutterI18n.translate(tester.element(find.text('start')), 'common.cancel')));
    await _pumpFrames(tester);

    // The awaited call after it still happens.
    expect(find.text(FlutterI18n.translate(tester.element(find.text('start')),
        'update.resetChannel')), findsOneWidget);
    } finally {
      await stopPolling(tester);
    }
  });

  testWidgets('the confirmations chain, then the update starts',
      (WidgetTester tester) async {
    await pumpGate(tester);
    try {
    await tester.tap(find.text('start'));
    await _pumpFrames(tester);

    final ctx = tester.element(find.text('start'));
    String t(String key) => FlutterI18n.translate(ctx, key);

    expect(find.text(t('update.devFirmware')), findsOneWidget);

    // Each confirmation is awaited, so every one after it is a context use
    // across an async gap.
    await tester.tap(find.widgetWithText(GlassButton, t('update.iAccept')));
    await _pumpFrames(tester);
    expect(find.text(t('update.confirmUpdate')), findsOneWidget);

    await tester.tap(find.widgetWithText(GlassButton, t('common.continue_')));
    await _pumpFrames(tester);
    expect(find.text(t('update.finalWarning')), findsOneWidget);

    await tester.tap(find.widgetWithText(GlassButton, t('update.updateNow')));
    await _pumpFrames(tester);

    // Confirmed: the progress overlay goes up, the backend update runs, and
    // the message it shows afterwards comes from the guarded code past the await.
    await _pumpFrames(tester, frames: 12);
    expect(find.byType(UpdateProgressOverlay), findsOneWidget);
    expect(find.text(t('update.athenaUpdateInitiated')), findsOneWidget);
    expect(backend.updated, isTrue);
    } finally {
      await stopPolling(tester);
    }
  });
}

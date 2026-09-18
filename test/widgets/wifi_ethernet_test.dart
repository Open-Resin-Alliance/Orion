/*
* Orion - WiFi / Ethernet Screen Test
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

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_i18n/flutter_i18n.dart';
import 'package:flutter_i18n/loaders/decoders/json_decode_strategy.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:orion/settings/wifi_screen.dart';
import 'package:orion/util/providers/wifi_provider.dart';
import 'package:orion/util/providers/theme_provider.dart';

class FakeEthernetProvider extends WiFiProvider {
  bool disconnectCalled = false;

  FakeEthernetProvider() : super(startPolling: false) {
    // no-op: override getters provide the expected state
  }

  @override
  String get connectionType => 'ethernet';

  @override
  bool get isConnected => true;

  @override
  String get platform => 'linux';

  @override
  String? get ipAddress => '192.168.1.42';

  @override
  String? get ifaceName => 'eth0';

  @override
  String? get macAddress => '02:00:00:00:00:01';

  @override
  String? get linkSpeed => '1000/1000';

  @override
  Future<bool> disconnect() async {
    disconnectCalled = true;
    return true;
  }

  @override
  Future<List<Map<String, String>>> scanNetworks() async {
    return [];
  }
}

/// Pumps the Ethernet view. The screen reads its strings through
/// [FlutterI18n], so the delegate has to be in the tree.
Future<void> _pumpEthernet(
  WidgetTester tester, {
  required FakeEthernetProvider provider,
  required Future<Map<String, String>> Function() fetcher,
}) async {
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
        ChangeNotifierProvider<WiFiProvider>.value(value: provider),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: [delegate],
        supportedLocales: const [Locale('en')],
        home: MediaQuery(
          data: const MediaQueryData(size: Size(400, 800)),
          child: WifiScreen(
            isConnected: ValueNotifier<bool>(true),
            networkDetailsFetcher: fetcher,
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('Ethernet UI shows the interface details',
      (WidgetTester tester) async {
    final fake = FakeEthernetProvider();

    await _pumpEthernet(
      tester,
      provider: fake,
      fetcher: () async => {
        'ip': '192.168.1.42',
        'mac': '02:00:00:00:00:01',
        'speed': '1000/1000',
        'iface': 'eth0',
      },
    );

    // Allow FutureBuilders and async operations to complete
    await tester.pumpAndSettle();

    expect(find.text('Connected to Ethernet'), findsOneWidget);
    expect(find.text('MAC Address'), findsOneWidget);
    expect(find.text('Link Speed'), findsOneWidget);

    // Ethernet only offers a disconnect action on macOS; on Linux the HMI
    // cannot take the interface down, so the button is deliberately absent.
    if (Platform.isMacOS) {
      expect(find.text('Disconnect'), findsWidgets);

      await tester.tap(find.text('Disconnect').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Disconnect').last);
      await tester.pumpAndSettle();

      expect(fake.disconnectCalled, isTrue);
    } else {
      expect(find.text('Disconnect'), findsNothing);
    }
  });

  testWidgets('a transient socket error retries instead of erroring out',
      (WidgetTester tester) async {
    final fake = FakeEthernetProvider();
    var attempts = 0;

    await _pumpEthernet(
      tester,
      provider: fake,
      // The platform raises a socket error while the interface is still
      // coming up, then answers normally.
      fetcher: () async {
        attempts++;
        if (attempts <= 2) {
          throw const SocketException('Network is unreachable');
        }
        return {
          'ip': '192.168.1.42',
          'mac': '02:00:00:00:00:01',
          'speed': '1000/1000',
          'iface': 'eth0',
        };
      },
    );

    // First attempt fails: the page keeps loading rather than reporting an
    // error the user would have to clear by leaving and re-entering.
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.textContaining('Error'), findsNothing);

    // Second attempt (after the retry delay) fails too.
    await tester.pump(const Duration(milliseconds: 700));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.textContaining('Error'), findsNothing);

    // Third attempt succeeds and the details render.
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();
    expect(attempts, 3);
    expect(find.text('Connected to Ethernet'), findsOneWidget);
    expect(find.text('MAC Address'), findsOneWidget);
  });
}

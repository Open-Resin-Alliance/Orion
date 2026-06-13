import 'package:flutter/material.dart';
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

void main() {
  testWidgets('Ethernet UI shows MAC, speed and disconnect button',
      (WidgetTester tester) async {
    final fake = FakeEthernetProvider();
    final isConnected = ValueNotifier<bool>(true);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<WiFiProvider>.value(value: fake),
          ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ],
        child: MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(size: Size(400, 800)),
            child: WifiScreen(
              isConnected: isConnected,
              networkDetailsFetcher: () async => {
                'ip': '192.168.1.42',
                'mac': '02:00:00:00:00:01',
                'speed': '1000/1000',
                'iface': 'eth0'
              },
            ),
          ),
        ),
      ),
    );

    // Allow FutureBuilders and async operations to complete
    await tester.pumpAndSettle();

    expect(find.text('Connected to Ethernet'), findsOneWidget);
    expect(find.text('MAC Address'), findsOneWidget);
    expect(find.text('Link Speed'), findsOneWidget);
    // The exact button widget can vary by Flutter version/theme; assert on
    // the visible label instead.
    expect(find.text('Disconnect Ethernet'), findsOneWidget);

    // Tap disconnect
    await tester.tap(find.text('Disconnect Ethernet'));
    await tester.pumpAndSettle();

    expect(fake.disconnectCalled, isTrue);
  });
}

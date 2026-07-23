import 'package:flutter_test/flutter_test.dart';
import 'package:orion/backend_service/providers/manual_provider.dart';
import 'fakes/fake_odyssey_client.dart';

void main() {
  group('ManualProvider', () {
    test('move forwards to client and toggles busy flag', () async {
      final fake = FakeBackendClient();
      final provider = ManualProvider(client: fake);

      expect(provider.busy, isFalse);
      final resFuture = provider.move(12.3);
      // busy should be true while operation in flight
      expect(provider.busy, isTrue);
      final ok = await resFuture;
      expect(ok, isTrue);
      expect(fake.moveCalled, isTrue);
      expect(fake.lastMoveHeight, equals(12.3));
      expect(provider.busy, isFalse);
    });

    test('move handles client exception gracefully', () async {
      final fake = FakeBackendClient();
      fake.throwOnMove = true;
      final provider = ManualProvider(client: fake);

      expect(provider.busy, isFalse);
      final res = await provider.move(1.0);
      expect(res, isFalse);
      expect(provider.busy, isFalse);
      expect(provider.error, isNotNull);
    });

    test('manualHome forwards correctly', () async {
      final fake = FakeBackendClient();
      final provider = ManualProvider(client: fake);
      final ok = await provider.manualHome();
      expect(ok, isTrue);
      expect(fake.manualHomeCalled, isTrue);
    });

    test('manualCommand forwards correctly', () async {
      final fake = FakeBackendClient();
      final provider = ManualProvider(client: fake);
      final ok = await provider.manualCommand('M112');
      expect(ok, isTrue);
      expect(fake.lastCommand, equals('M112'));
    });

    test('manualCure and displayTest forwards correctly', () async {
      final fake = FakeBackendClient();
      final provider = ManualProvider(client: fake);
      final ok1 = await provider.manualCure(true);
      final ok2 = await provider.displayTest('Grid');
      expect(ok1, isTrue);
      expect(ok2, isTrue);
      expect(fake.manualCureCalled, isTrue);
      expect(fake.displayTestCalled, isTrue);
    });
  });
}

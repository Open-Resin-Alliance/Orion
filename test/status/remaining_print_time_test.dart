import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:orion/backend_service/nanodlp/helpers/nano_simulated_client.dart';
import 'package:orion/backend_service/odyssey/models/status_models.dart';
import 'package:orion/backend_service/providers/status_provider.dart';

import '../fakes/fake_odyssey_client.dart';

const int _totalSeconds = 3600;
const int _totalLayers = 10;

/// Replays one status payload so the provider can be driven through its real
/// snapshot path. The status stream never emits, which keeps the provider on
/// the payload under test instead of a background poll.
class _StubStatusClient extends FakeBackendClient {
  Map<String, dynamic> payload = {};

  @override
  Future<Map<String, dynamic>> getStatus() async => payload;

  @override
  Stream<Map<String, dynamic>> getStatusStream() =>
      StreamController<Map<String, dynamic>>().stream;
}

Map<String, dynamic> _printing({
  required int layer,
  bool paused = false,
  String path = '/local/job.sl1s',
}) =>
    {
      'status': 'Printing',
      'paused': paused,
      'layer': layer,
      'physical_state': {'z': 1.0, 'curing': true},
      'print_data': {
        'layer_count': _totalLayers,
        'used_material': 1.0,
        'print_time': _totalSeconds,
        'file_data': {'name': 'job.sl1s', 'path': path},
      },
    };

const Map<String, dynamic> _idle = {
  'status': 'Idle',
  'paused': false,
  'layer': null,
  'physical_state': {'z': 0.0, 'curing': false},
  'print_data': null,
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('StatusModel.remainingPrintTime', () {
    StatusModel model(int? printTime, int layerCount, int? layer) =>
        StatusModel.fromJson({
          'status': 'Printing',
          'paused': false,
          'layer': layer,
          'physical_state': {'z': 0.0},
          'print_data': {
            'layer_count': layerCount,
            'used_material': 0.0,
            'print_time': printTime ?? 0,
          },
        });

    test('counts the layer in progress as still to come', () {
      // 10 layers over 3600 s: exposing layer 1 leaves all 3600, layer 2
      // leaves the nine layers that have not started.
      expect(model(3600, 10, 1).remainingPrintTime, const Duration(hours: 1));
      expect(
          model(3600, 10, 2).remainingPrintTime, const Duration(minutes: 54));
      expect(
          model(3600, 10, 10).remainingPrintTime, const Duration(minutes: 6));
    });

    test('never reports a layer past the last one as time left', () {
      expect(model(3600, 10, 11).remainingPrintTime, Duration.zero);
      expect(model(3600, 10, 99).remainingPrintTime, Duration.zero);
    });

    test('is unknown without an estimate or a layer', () {
      expect(model(0, 10, 1).remainingPrintTime, isNull);
      expect(model(3600, 0, 1).remainingPrintTime, isNull);
      expect(model(3600, 10, null).remainingPrintTime, isNull);
    });

    test('formats as zero padded HH:MM:SS', () {
      expect(StatusModel.formatDuration(Duration.zero), '00:00:00');
      expect(
          StatusModel.formatDuration(const Duration(minutes: 6)), '00:06:00');
      expect(
        StatusModel.formatDuration(
            const Duration(hours: 4, minutes: 5, seconds: 6)),
        '04:05:06',
      );
    });

    test('the standby ring drops the seconds', () {
      expect(StatusModel.formatHoursMinutes(Duration.zero), '00:00');
      expect(
        StatusModel.formatHoursMinutes(
            const Duration(hours: 4, minutes: 5, seconds: 6)),
        '04:05',
      );
      expect(
        StatusModel.formatHoursMinutes(
            const Duration(minutes: 59, seconds: 59)),
        '00:59',
      );
    });
  });

  group('StatusProvider.remainingPrintTime', () {
    late _StubStatusClient client;
    late StatusProvider provider;

    setUp(() {
      client = _StubStatusClient();
      provider = StatusProvider(client: client);
    });

    tearDown(() => provider.dispose());

    test('anchors to the job estimate and ticks down between snapshots',
        () async {
      client.payload = _printing(layer: 1);
      await provider.refresh();

      final anchored = provider.remainingPrintTime;
      expect(anchored, isNotNull);
      expect(anchored!.inSeconds, closeTo(_totalSeconds, 1));

      await Future.delayed(const Duration(milliseconds: 1100));

      final ticking = provider.remainingPrintTime!;
      expect(ticking.inSeconds, lessThan(anchored.inSeconds));
      expect(ticking.inSeconds, closeTo(_totalSeconds - 1, 2));
    });

    test('re-anchors to the untouched layers when the layer advances',
        () async {
      client.payload = _printing(layer: 1);
      await provider.refresh();
      expect(provider.remainingPrintTime!.inSeconds, closeTo(_totalSeconds, 1));

      client.payload = _printing(layer: 2);
      await provider.refresh();
      // Nine of ten layers left.
      expect(provider.remainingPrintTime!.inSeconds, closeTo(3240, 1));

      await Future.delayed(const Duration(milliseconds: 1100));
      expect(provider.remainingPrintTime!.inSeconds, closeTo(3239, 2));
    });

    test('a pause stops the countdown', () async {
      client.payload = _printing(layer: 3);
      await provider.refresh();
      final before = provider.remainingPrintTime!.inSeconds;

      client.payload = _printing(layer: 3, paused: true);
      await provider.refresh();
      final paused = provider.remainingPrintTime!.inSeconds;
      expect(paused, closeTo(before, 1));

      await Future.delayed(const Duration(milliseconds: 1100));
      expect(provider.remainingPrintTime!.inSeconds, paused);
    });

    test('ends with the print and restarts with the next job', () async {
      client.payload = _printing(layer: 6);
      await provider.refresh();
      expect(provider.remainingPrintTime!.inSeconds, closeTo(1800, 1));

      client.payload = _idle;
      await provider.refresh();
      expect(provider.remainingPrintTime, isNull);
      expect(provider.formattedRemainingPrintTime, isNull);

      client.payload = _printing(layer: 1, path: '/local/other.sl1s');
      await provider.refresh();
      expect(provider.remainingPrintTime!.inSeconds, closeTo(_totalSeconds, 1));
      expect(_secondsOf(provider.formattedRemainingPrintTime!),
          closeTo(_totalSeconds, 1));
    });
  });

  group('simulated backend', () {
    test('reports an estimate the countdown can anchor to', () async {
      final simulator =
          NanoDlpSimulatedClient(totalLayers: 10, layerSeconds: 2.0);
      await simulator.startPrint('Local', '/sim/demo_print.gcode');

      final status = StatusModel.fromJson(await simulator.getStatus());

      expect(status.printData!.layerCount, 10);
      expect(status.printData!.printTimeSeconds, 20);
      expect(status.remainingPrintTime, const Duration(seconds: 20));
      expect(status.printData!.usedMaterial, closeTo(0.5, 0.0001));
    });
  });
}

/// Reads back the HH:MM:SS produced by the card.
int _secondsOf(String hms) {
  final parts = hms.split(':').map(int.parse).toList();
  expect(parts, hasLength(3));
  return parts[0] * 3600 + parts[1] * 60 + parts[2];
}

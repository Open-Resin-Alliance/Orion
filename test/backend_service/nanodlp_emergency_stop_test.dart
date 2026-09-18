import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:orion/backend_service/nanodlp/nanodlp_http_client.dart';

void main() {
  /// Records every request the client makes as "METHOD path".
  NanoDlpHttpClient recordingClient(
    List<String> calls, {
    int status = 200,
    bool throwOnEveryRequest = false,
  }) =>
      NanoDlpHttpClient(
        clientFactory: () => MockClient((req) async {
          calls.add(req.url.path == '/gcode'
              ? 'gcode ${req.bodyFields['gcode']}'
              : 'GET ${req.url.path}');
          if (throwOnEveryRequest) {
            throw http.ClientException('offline');
          }
          return http.Response('{"ok":true}', status);
        }),
      );

  const expectedSequence = [
    'gcode M112',
    'GET /printer/force-stop',
    'gcode FIRMWARE_STOP',
  ];

  test('NanoDLP emergency stop issues M112, force-stop and FIRMWARE_STOP',
      () async {
    final calls = <String>[];

    await recordingClient(calls).emergencyStop();

    expect(calls, expectedSequence);
  });

  test('NanoDLP forceStop is that same sequence', () async {
    final calls = <String>[];

    await recordingClient(calls).forceStop();

    expect(calls, expectedSequence);
  });

  test('a step that fails does not abandon the ones after it', () async {
    // M112 and FIRMWARE_STOP answer 500; the force-stop endpoint answers 200.
    final calls = <String>[];

    await recordingClient(calls, status: 500).emergencyStop();

    expect(calls, expectedSequence);
  });

  test('a total failure is still reported', () async {
    // The endpoint treats a non-200 as "dispatched", so only a transport
    // failure can fail every step.
    final calls = <String>[];

    expect(
      recordingClient(calls, throwOnEveryRequest: true).emergencyStop(),
      throwsA(isA<Exception>()),
    );
  });
}

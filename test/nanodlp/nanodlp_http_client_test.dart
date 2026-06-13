/*
* Orion - NanoDLP HTTP Client Test
* Copyright (C) 2025 Open Resin Alliance
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

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image/image.dart' as img;
import 'package:orion/backend_service/nanodlp/nanodlp_http_client.dart';

void main() {
  group('NanoDlpHttpClient caching', () {
    test('reuses thumbnail bytes within cache TTL', () async {
      var plateRequests = 0;
      var thumbnailRequests = 0;

      final sampleImage = img.Image(width: 64, height: 64);
      img.fill(sampleImage, color: img.ColorRgb8(10, 20, 30));
      final sampleBytes = Uint8List.fromList(img.encodePng(sampleImage));

      http.Client mockFactory() => MockClient((request) async {
            if (request.url.path.endsWith('/plates/list/json')) {
              plateRequests++;
              return http.Response(
                  json.encode([
                    {
                      'PlateID': 123,
                      'path': 'plates/test_plate.cws',
                      'Preview': true,
                    }
                  ]),
                  200,
                  headers: {'content-type': 'application/json'});
            }
            if (request.url.path.endsWith('/static/plates/123/3d.png')) {
              thumbnailRequests++;
              return http.Response.bytes(sampleBytes, 200,
                  headers: {'content-type': 'image/png'});
            }
            return http.Response('not found', 404);
          });

      final client = NanoDlpHttpClient(clientFactory: mockFactory);

      final first = await client.getFileThumbnail(
          'local', 'plates/test_plate.cws', 'Small');
      final second = await client.getFileThumbnail(
          'local', 'plates/test_plate.cws', 'Small');

      expect(plateRequests, 1);
      expect(thumbnailRequests, 1);
      expect(second, equals(first));
    });

    test('caches placeholder after failed preview fetch for short period',
        () async {
      var plateRequests = 0;
      var thumbnailRequests = 0;

      http.Client mockFactory() => MockClient((request) async {
            if (request.url.path.endsWith('/plates/list/json')) {
              plateRequests++;
              return http.Response(
                  json.encode([
                    {
                      'PlateID': 456,
                      'path': 'plates/failed_plate.cws',
                      'Preview': true,
                    }
                  ]),
                  200,
                  headers: {'content-type': 'application/json'});
            }
            if (request.url.path.endsWith('/static/plates/456/3d.png')) {
              thumbnailRequests++;
              return http.Response('error', 500);
            }
            return http.Response('not found', 404);
          });

      final client = NanoDlpHttpClient(clientFactory: mockFactory);

      final first = await client.getFileThumbnail(
          'local', 'plates/failed_plate.cws', 'Small');
      final second = await client.getFileThumbnail(
          'local', 'plates/failed_plate.cws', 'Small');

      expect(plateRequests, 1);
      expect(thumbnailRequests, 1);
      expect(second, equals(first));
    });

    test('caches plate list responses within TTL window', () async {
      var plateRequests = 0;

      http.Client mockFactory() => MockClient((request) async {
            if (request.url.path.endsWith('/plates/list/json')) {
              plateRequests++;
              return http.Response(
                  json.encode([
                    {
                      'PlateID': 789,
                      'path': 'plates/cache_test.cws',
                      'Preview': false,
                    }
                  ]),
                  200,
                  headers: {'content-type': 'application/json'});
            }
            return http.Response('not found', 404);
          });

      final client = NanoDlpHttpClient(clientFactory: mockFactory);

      final first = await client.listItems('local', 20, 0, '/');
      final second = await client.listItems('local', 20, 0, '/');

      expect(first['files'], isNotEmpty);
      expect(second['files'], isNotEmpty);
      expect(plateRequests, 1);
    });
  });

  group('NanoDlpHttpClient timeout', () {
    test('getStatus fails fast when backend is unresponsive', () async {
      final client = NanoDlpHttpClient(
        clientFactory: () => _NeverCompletesClient(),
        requestTimeout: const Duration(milliseconds: 25),
      );

      final sw = Stopwatch()..start();
      final future = client.getStatus();
      await expectLater(future, throwsA(isA<TimeoutException>()));
      sw.stop();

      expect(sw.elapsed, lessThan(const Duration(milliseconds: 300)));
    });
  });

  group('NanoDlpHttpClient profile edits', () {
    test('editProfile accepts non-auth 302 redirect as success', () async {
      http.Client mockFactory() => MockClient((request) async {
            expect(request.method, 'POST');
            expect(request.url.path, endsWith('/profile/edit/simple/1000'));

            expect(request.bodyFields['CureTime'], '1.5');
            expect(request.bodyFields['SupportLayerNumber'], '8');

            return http.Response(
              '',
              302,
              headers: {'location': '/profile/list'},
            );
          });

      final client = NanoDlpHttpClient(clientFactory: mockFactory);
      final resp = await client.editProfile(1000, {
        'CureTime': 1.5,
        'SupportLayerNumber': 8,
      });

      expect(resp['status'], 302);
      expect(resp['location'], '/profile/list');
    });

    test('editProfile fails on login redirect', () async {
      http.Client mockFactory() => MockClient((request) async {
            return http.Response(
              '',
              302,
              headers: {'location': '/login'},
            );
          });

      final client = NanoDlpHttpClient(clientFactory: mockFactory);

      await expectLater(
        client.editProfile(1000, {'CureTime': 1.5}),
        throwsA(isA<Exception>()),
      );
    });

    test('saveResinExposure posts merged full settings payload', () async {
      var profileFetchCount = 0;
      var profileEditCount = 0;

      http.Client mockFactory() => MockClient((request) async {
            if (request.url.path.endsWith('/profile/json/1000')) {
              profileFetchCount++;
              return http.Response(
                json.encode({
                  'ProfileID': 1000,
                  'CureTime': 2.5,
                  'SupportCureTime': 10.0,
                  'WaitHeight': 1.8,
                  'SupportLayerNumber': 8,
                  'TopWait': 1.2,
                  'WaitAfterPrint': 1.2,
                }),
                200,
                headers: {'content-type': 'application/json'},
              );
            }

            if (request.url.path.endsWith('/profile/edit/simple/1000')) {
              profileEditCount++;
              expect(request.method, 'POST');

              // Updated exposure
              expect(request.bodyFields['CureTime'], '1.5');

              // Existing values preserved
              expect(request.bodyFields['SupportCureTime'], '10.0');
              expect(request.bodyFields['TopDistance'], '1.8');
              expect(request.bodyFields['WaitHeight'], '1.8');
              expect(request.bodyFields['SupportLayerNumber'], '8');
              expect(request.bodyFields['TopWait'], '1.2');
              expect(request.bodyFields['WaitAfterPrint'], '1.2');

              return http.Response('', 302,
                  headers: {'location': '/profile/list'});
            }

            return http.Response('not found', 404);
          });

      final client = NanoDlpHttpClient(clientFactory: mockFactory);
      await client.saveResinExposure(1000, 1.5);

      expect(profileFetchCount, 1);
      expect(profileEditCount, 1);
    });

    test('saveResinExposure fails safely when profile cannot be loaded',
        () async {
      var profileEditCount = 0;

      http.Client mockFactory() => MockClient((request) async {
            if (request.url.path.endsWith('/profile/edit/simple/1000')) {
              profileEditCount++;
            }
            return http.Response('not found', 404);
          });

      final client = NanoDlpHttpClient(clientFactory: mockFactory);
      await expectLater(
        client.saveResinExposure(1000, 1.5),
        throwsA(isA<StateError>()),
      );
      expect(profileEditCount, 0);
    });
  });
}

class _NeverCompletesClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    return Completer<http.StreamedResponse>().future;
  }

  @override
  void close() {}
}

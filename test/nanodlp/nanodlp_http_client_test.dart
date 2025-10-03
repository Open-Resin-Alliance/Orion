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
}

/*
* Orion - Thumbnail Utility Test
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

import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orion/util/sl1_thumbnail.dart';
import 'fakes/fake_odyssey_client_for_thumbnail_test.dart';

void main() {
  test('ThumbnailUtil.extractThumbnail writes bytes to temp file', () async {
    // Ensure binding is initialized for platform channel mocking
    TestWidgetsFlutterBinding.ensureInitialized();

    // Create a temp directory to act as the platform temp dir and mock
    final platformTemp = Directory.systemTemp.createTempSync('orion_test_tmp');
    final channel = const MethodChannel('plugins.flutter.io/path_provider');
    channel.setMockMethodCallHandler((MethodCall call) async {
      if (call.method == 'getTemporaryDirectory') return platformTemp.path;
      return null;
    });
    final data = Uint8List.fromList(List<int>.generate(16, (i) => i % 256));
    final fake = FakeBackendClientForThumbnailTest(data);

    final path = await ThumbnailUtil.extractThumbnail('local', '', 'test.sl1',
        client: fake);

    // The function returns a path; ensure file exists and contents look like a PNG
    final f = File(path);
    expect(await f.exists(), isTrue);
    final bytes = await f.readAsBytes();
    // Thumbnail extraction produces an encoded image (PNG). Ensure we got
    // non-empty bytes and that they start with the PNG signature.
    expect(bytes, isNotEmpty);
    expect(bytes.length, greaterThanOrEqualTo(8));
    // PNG signature: 137 80 78 71 13 10 26 10
    expect(bytes[0], equals(137));
    expect(bytes[1], equals(80));
    expect(bytes[2], equals(78));
    expect(bytes[3], equals(71));

    // Clean up
    try {
      await f.delete();
    } catch (_) {}
    try {
      channel.setMockMethodCallHandler(null);
      await platformTemp.delete(recursive: true);
    } catch (_) {}
  });
}

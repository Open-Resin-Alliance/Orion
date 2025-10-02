import 'dart:io';
import 'dart:typed_data';

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
    final fake = FakeOdysseyClientForThumbnailTest(data);

    final path = await ThumbnailUtil.extractThumbnail('local', '', 'test.sl1',
        client: fake);

    // The function returns a path; ensure file exists and contents match
    final f = File(path);
    expect(await f.exists(), isTrue);
    final bytes = await f.readAsBytes();
    expect(bytes, equals(data));

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

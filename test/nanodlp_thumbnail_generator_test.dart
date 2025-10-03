import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:orion/backend_service/nanodlp/nanodlp_thumbnail_generator.dart';

void main() {
  group('NanoDlpThumbnailGenerator', () {
    test('generates 400x400 placeholder', () {
      final bytes = NanoDlpThumbnailGenerator.generatePlaceholder(400, 400);
      final decoded = img.decodePng(bytes);
      expect(decoded, isNotNull);
      expect(decoded!.width, 400);
      expect(decoded.height, 400);
    });

    test('generates 800x480 placeholder', () {
      final bytes = NanoDlpThumbnailGenerator.generatePlaceholder(800, 480);
      final decoded = img.decodePng(bytes);
      expect(decoded, isNotNull);
      expect(decoded!.width, 800);
      expect(decoded.height, 480);
    });

    test('resizes source image to requested dimensions', () {
      final original = img.Image(width: 200, height: 100);
      img.fill(original, color: img.ColorRgb8(255, 0, 0));
      final originalBytes = Uint8List.fromList(img.encodePng(original));

      final resized = NanoDlpThumbnailGenerator.resizeOrPlaceholder(
          originalBytes, 400, 400);
      final decoded = img.decodePng(resized);
      expect(decoded, isNotNull);
      expect(decoded!.width, 400);
      expect(decoded.height, 400);
    });

    test('falls back to placeholder when decode fails', () {
      final resized = NanoDlpThumbnailGenerator.resizeOrPlaceholder(
          Uint8List.fromList(<int>[0, 1, 2, 3]), 400, 400);
      final decoded = img.decodePng(resized);
      expect(decoded, isNotNull);
      expect(decoded!.width, 400);
      expect(decoded.height, 400);
    });
  });
}

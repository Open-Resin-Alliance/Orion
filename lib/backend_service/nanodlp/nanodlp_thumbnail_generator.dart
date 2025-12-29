import 'dart:typed_data';

import 'package:image/image.dart' as img;

class NanoDlpThumbnailGenerator {
  const NanoDlpThumbnailGenerator._();

  // Canonical large thumbnail size used in DetailsScreen.
  static const int largeWidth = 800;
  static const int largeHeight = 480;

  static Uint8List generatePlaceholder(int width, int height) {
    final image = img.Image(width: width, height: height);
    final background = img.ColorRgb8(32, 36, 43);
    final accent = img.ColorRgb8(63, 74, 88);
    final highlight = img.ColorRgb8(90, 104, 122);

    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        final band = ((x ~/ 16) + (y ~/ 16)) % 3;
        switch (band) {
          case 0:
            image.setPixel(x, y, background);
            break;
          case 1:
            image.setPixel(x, y, accent);
            break;
          default:
            image.setPixel(x, y, highlight);
        }
      }
    }

    for (var x = width ~/ 4; x < (width * 3) ~/ 4; x++) {
      final y1 = height ~/ 4;
      final y2 = (height * 3) ~/ 4;
      image.setPixel(x, y1, highlight);
      image.setPixel(x, y2, highlight);
    }

    for (var y = height ~/ 4; y < (height * 3) ~/ 4; y++) {
      final x1 = width ~/ 4;
      final x2 = (width * 3) ~/ 4;
      image.setPixel(x1, y, highlight);
      image.setPixel(x2, y, highlight);
    }

    return Uint8List.fromList(img.encodePng(image));
  }

  static Uint8List resizeOrPlaceholder(
      Uint8List? sourceBytes, int width, int height) {
    if (sourceBytes != null && sourceBytes.isNotEmpty) {
      try {
        final decoded = img.decodeImage(sourceBytes);
        if (decoded != null) {
          img.Image resized;
          if (decoded.width == width && decoded.height == height) {
            resized = decoded;
          } else {
            resized = img.copyResize(decoded,
                width: width,
                height: height,
                interpolation: img.Interpolation.cubic);
          }
          return Uint8List.fromList(img.encodePng(resized));
        }
      } catch (_) {
        // fall back to placeholder below
      }
    }
    return generatePlaceholder(width, height);
  }

  /// Convenience helper to force the canonical NanoDLP large size.
  static Uint8List resizeToLarge(Uint8List? sourceBytes) =>
      resizeOrPlaceholder(sourceBytes, largeWidth, largeHeight);
}

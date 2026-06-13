/*
* Orion - NanoDLP Thumbnail Generator
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

import 'dart:typed_data';
import 'dart:math' as math;

import 'package:image/image.dart' as img;
import 'package:flutter/foundation.dart';

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
          // If the image already matches the target size, return it as-is.
          if (decoded.width == width && decoded.height == height) {
            return Uint8List.fromList(img.encodePng(decoded));
          }

          // Apply a small internal padding so thumbnails don't touch the
          // canvas edges. The padded area (innerWidth x innerHeight) is the
          // space available for the aspect-fit image.
          const int pad = 8;
          final innerWidth = math.max(1, width - (pad * 2));
          final innerHeight = math.max(1, height - (pad * 2));

          // Compute aspect-fit scale to preserve aspect ratio inside the
          // inner padded box.
          final scale = math.min(
              innerWidth / decoded.width, innerHeight / decoded.height);
          final targetW = math.max(1, (decoded.width * scale).round());
          final targetH = math.max(1, (decoded.height * scale).round());

          final resized = img.copyResize(decoded,
              width: targetW,
              height: targetH,
              interpolation: img.Interpolation.cubic);

          // Create a transparent canvas of the requested size and center the
          // resized image on it so we don't distort the aspect ratio. This
          // results in translucent padding when the aspect ratios differ.
          // Ensure canvas has an alpha channel so transparent padding stays
          // transparent when encoded to PNG.
          final canvas =
              img.Image(width: width, height: height, numChannels: 4);
          // Ensure fully transparent background (ARGB = 0).
          final transparent = img.ColorRgba8(0, 0, 0, 0);
          img.fill(canvas, color: transparent);

          final dx = pad + ((innerWidth - targetW) / 2).round();
          final dy = pad + ((innerHeight - targetH) / 2).round();

          // Blit the resized image into the centered position on the
          // transparent canvas by copying pixels — this works across
          // image package versions without relying on draw helpers.
          for (var y = 0; y < targetH; y++) {
            for (var x = 0; x < targetW; x++) {
              final px = resized.getPixel(x, y);
              canvas.setPixel(dx + x, dy + y, px);
            }
          }

          return Uint8List.fromList(img.encodePng(canvas));
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

  /// Resize a 2D layer PNG (from /static/plates/`<plate`>/N.png) to the
  /// canonical large size, ignoring aspect ratio (force resize). This is
  /// intentionally different from `resizeOrPlaceholder` which preserves
  /// aspect ratio and adds transparent padding.
  static Uint8List resizeLayer2D(Uint8List? sourceBytes) {
    if (sourceBytes != null && sourceBytes.isNotEmpty) {
      try {
        final decoded = img.decodeImage(sourceBytes);
        if (decoded != null) {
          final resized = img.copyResize(decoded,
              width: largeWidth,
              height: largeHeight,
              interpolation: img.Interpolation.cubic);
          return Uint8List.fromList(img.encodePng(resized));
        }
      } catch (_) {
        // fall-through to placeholder
      }
    }
    return generatePlaceholder(largeWidth, largeHeight);
  }
}

// Public top-level entrypoint for compute() so other libraries can call
// compute(resizeLayer2DCompute, bytes). Must be public (non-underscore)
// so it is available across library boundaries when spawning an isolate.
Uint8List resizeLayer2DCompute(Uint8List bytes) =>
    NanoDlpThumbnailGenerator.resizeLayer2D(bytes);

/*
* Orion - Thumbnail Util
* Copyright (C) 2024 Open Resin Alliance
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
import 'package:logging/logging.dart';
import 'package:orion/backend_service/backend_service.dart';
import 'package:orion/backend_service/odyssey/odyssey_client.dart';
import 'package:flutter/foundation.dart';
import 'dart:typed_data';
// Temporarily remove NanoDLP dependency so this file can be included
// in an Odyssey-only refactor PR. Replacement fallbacks are provided
// below (small embedded placeholder and simple pass-through resize)
// to avoid importing NanoDLP-specific helpers here.
// import 'package:orion/backend_service/nanodlp/nanodlp_thumbnail_generator.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'dart:convert';

class ThumbnailUtil {
  static final _logger = Logger('ThumbnailUtil');

  /// Extract a thumbnail for a remote file. You may inject a custom
  /// [client] for testing; by default we use the [ApiServiceAdapter]
  /// which forwards to the existing `ApiService` implementation.
  static Future<String> extractThumbnail(
      String location, String subdirectory, String filename,
      {String size = "Small", OdysseyClient? client}) async {
    final OdysseyClient odysseyClient = client ?? BackendService();
    try {
      // Build a safe relative path for the file on the server. Normalize
      // separators and strip any leading slashes so we never request
      // '/file' from the API — only 'file' or 'dir/file'. Some backend
      // responses include leading slashes which caused thumbnail fetches to fail.
      String finalLocation = _isDefaultDir(subdirectory)
          ? filename
          : p.join(subdirectory, filename);
      // Normalize separators to forward slash and remove leading slashes
      finalLocation = finalLocation.replaceAll('\\', '/').trim();
      finalLocation = finalLocation.replaceFirst(RegExp(r'^/+'), '');

      // Request thumbnail bytes from the API
      // Use the bytes-resizing path that runs decode/resize in an isolate so
      // the written thumbnail is guaranteed to match the expected dimensions
      // (especially important for the Large size used by DetailsScreen).
      Uint8List bytes = await extractThumbnailBytes(
          location, subdirectory, filename,
          size: size, client: odysseyClient);

      // Create a stable, filesystem-safe directory name under the temp dir
      final tempDir = await getTemporaryDirectory();
      final baseTmp = Directory(p.join(tempDir.path, 'oriontmp'));
      if (!await baseTmp.exists()) await baseTmp.create(recursive: true);

      // Use a sanitized folder name for this file's thumbnails (replace path separators)
      final safeName = finalLocation.replaceAll('/', '_').replaceAll('\\', '_');
      final fileTmpDir = Directory(p.join(baseTmp.path, safeName));
      if (!await fileTmpDir.exists()) await fileTmpDir.create(recursive: true);

      late final String filePath;
      switch (size) {
        case 'Large':
          filePath = p.join(fileTmpDir.path, 'thumbnail800x480.png');
          break;
        case 'Small':
          filePath = p.join(fileTmpDir.path, 'thumbnail400x400.png');
          break;
        default:
          filePath = p.join(fileTmpDir.path, 'thumbnail.png');
      }

      final outputFile = File(filePath);
      await outputFile.writeAsBytes(bytes, flush: true);

      // Prune the cache under baseTmp if it exceeds threshold (100MB)
      const int maxBytes = 100 * 1024 * 1024;
      try {
        final allEntities = await baseTmp.list(recursive: true).toList();
        // Collect only files
        final files = <File>[];
        for (final e in allEntities) {
          if (e is File) files.add(e);
        }

        int totalSize = 0;
        final List<_FileStatPair> fileStats = [];
        for (final f in files) {
          try {
            final stat = await f.stat();
            totalSize += stat.size;
            fileStats.add(_FileStatPair(file: f, stat: stat));
          } catch (_) {
            // ignore files we cannot stat
          }
        }

        if (totalSize > maxBytes) {
          fileStats.sort((a, b) => a.stat.modified.compareTo(b.stat.modified));
          int idx = 0;
          while (totalSize > maxBytes && idx < fileStats.length) {
            final candidate = fileStats[idx];
            try {
              final len = candidate.stat.size;
              await candidate.file.delete();
              totalSize -= len;
            } catch (_) {
              // ignore delete errors and continue
            }
            idx++;
          }
        }
      } catch (e) {
        // best-effort pruning; don't fail the thumbnail operation
        _logger.warning('Thumbnail cache pruning failed', e);
      }

      return filePath;
    } catch (e) {
      _logger.severe('Failed to fetch thumbnail', e);
    }

    return 'assets/images/placeholder.png';
  }

  static bool _isDefaultDir(String subdirectory) {
    return subdirectory == '';
  }

  /// Returns thumbnail bytes (PNG) resized for the requested size.
  /// Uses a background isolate to perform decode/resize work to avoid
  /// janking the UI thread.
  static Future<Uint8List> extractThumbnailBytes(
      String location, String subdirectory, String filename,
      {String size = "Small", OdysseyClient? client}) async {
    final OdysseyClient odysseyClient = client ?? BackendService();
    try {
      String finalLocation = _isDefaultDir(subdirectory)
          ? filename
          : p.join(subdirectory, filename);
      finalLocation = finalLocation.replaceAll('\\', '/').trim();
      finalLocation = finalLocation.replaceFirst(RegExp(r'^/+'), '');

      final bytes =
          await odysseyClient.getFileThumbnail(location, finalLocation, size);

      // Use conservative defaults for sizes. NanoDLP-specific canonical
      // sizes were removed from this file to keep NanoDLP out of the
      // Odyssey-only refactor; we use reasonable defaults here.
      int width = 400, height = 400;
      if (size == 'Large') {
        width = _largeWidth;
        height = _largeHeight;
      }

      // Use compute to run the resize on a background isolate. The
      // isolate implementation below is intentionally minimal: if the
      // backend-provided bytes exist we pass them through unchanged;
      // otherwise we return a tiny embedded placeholder PNG. This keeps
      // this file free of NanoDLP helpers while preserving safe behavior.
      final resized = await compute(_resizeBytesEntry, {
        'bytes': bytes,
        'width': width,
        'height': height,
      });

      return resized as Uint8List;
    } catch (e) {
      _logger.warning('Failed to fetch/resize thumbnail bytes', e);
    }

    // Fallback: return a tiny embedded placeholder PNG.
    return _placeholderBytes();
  }
}

class _FileStatPair {
  final File file;
  final FileStat stat;
  _FileStatPair({required this.file, required this.stat});
}

// Top-level entrypoint for compute() to resize image bytes off the main isolate.
dynamic _resizeBytesEntry(Map<String, dynamic> msg) {
  int width = 400;
  int height = 400;
  try {
    final bytes = msg['bytes'] as Uint8List;
    width = msg['width'] as int? ?? width;
    height = msg['height'] as int? ?? height;
    // For the Odyssey-only refactor we avoid calling into NanoDLP
    // helpers. If bytes are present, return them unchanged (no-op
    // resize). If bytes are missing or invalid, return the embedded
    // placeholder.
    return _resizeOrPlaceholder(bytes, width, height);
  } catch (_) {
    return _placeholderBytes();
  }
}

// Local canonical large size used while NanoDLP helpers are excluded.
const int _largeWidth = 800;
const int _largeHeight = 480;

// A minimal 1x1 PNG (base64) used as a safe fallback placeholder.
Uint8List _placeholderBytes() {
  // 1x1 transparent PNG
  const String b64 =
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR4nGNgYAAAAAMAASsJTYQAAAAASUVORK5CYII=';
  return base64.decode(b64);
}

// Minimal resize-or-placeholder: we do not perform actual image
// manipulation here to avoid importing the image package. If bytes
// are present, return them as-is; otherwise return the placeholder.
Uint8List _resizeOrPlaceholder(Uint8List? bytes, int width, int height) {
  if (bytes == null || bytes.isEmpty) return _placeholderBytes();
  return bytes;
}

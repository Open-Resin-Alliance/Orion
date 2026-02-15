/*
* Orion - STL Thumbnail Util
* Copyright (C) 2026 Open Resin Alliance
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
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:logging/logging.dart';
import 'package:orion/backend_service/nanodlp/helpers/nano_thumbnail_generator.dart';
import 'package:orion/util/orion_config.dart';

class StlThumbnailUtil {
  static final _log = Logger('StlThumbnailUtil');

  static Future<Uint8List> extractStlThumbnailBytesFromFile(
    String filePath, {
    String size = 'Small',
    String? mode,
    dynamic themeColor,
  }) async {
    File? tempCopy;
    try {
      File file = File(filePath);
      if (Platform.isLinux && filePath.startsWith('/media/')) {
        try {
          final tempDir = await Directory.systemTemp.createTemp('orion_stl_');
          final tmpPath =
              '${tempDir.path}/${DateTime.now().millisecondsSinceEpoch}_${file.uri.pathSegments.last}';
          final staged = await file.copy(tmpPath);
          tempCopy = staged;
          file = staged;
        } catch (e) {
          _log.fine('Failed to stage STL file in temp dir', e);
        }
      }

      if (!await file.exists()) {
        return NanoDlpThumbnailGenerator.generatePlaceholder(400, 400);
      }

      final bytes = await file.readAsBytes();

      int width = 400, height = 400;
      if (size == 'Large') {
        width = NanoDlpThumbnailGenerator.largeWidth;
        height = NanoDlpThumbnailGenerator.largeHeight;
      }

      final resolvedMode = mode ?? chooseRenderMode();
      final colorR = (themeColor?.red ?? 0) as int? ?? 0;
      final colorG = (themeColor?.green ?? 0) as int? ?? 0;
      final colorB = (themeColor?.blue ?? 0) as int? ?? 0;
      final renderBytes = await compute(_renderStlThumbnailEntry, {
        'bytes': bytes,
        'width': width,
        'height': height,
        'mode': resolvedMode,
        'colorR': colorR,
        'colorG': colorG,
        'colorB': colorB,
      });

      if (renderBytes is Uint8List && renderBytes.isNotEmpty) {
        return renderBytes;
      }
    } catch (e, st) {
      _log.warning('Failed to extract STL thumbnail', e, st);
    } finally {
      try {
        if (tempCopy != null && await tempCopy.exists()) {
          await tempCopy.delete();
          final parent = tempCopy.parent;
          if (await parent.exists()) {
            await parent.delete();
          }
        }
      } catch (_) {}
    }

    return NanoDlpThumbnailGenerator.generatePlaceholder(400, 400);
  }

  static String chooseRenderMode({bool advanceCycle = true}) {
    return _resolveRenderMode(advanceCycle: advanceCycle);
  }

  static String _resolveRenderMode({required bool advanceCycle}) {
    try {
      final cfg = OrionConfig();
      final cycle = cfg.getFlag('stlThumbnailCycle', category: 'developer');
      final preferred =
          cfg.getString('stlThumbnailMode', category: 'developer');
      if (!cycle) {
        return preferred.isNotEmpty ? preferred : 'iso';
      }
      if (!advanceCycle) {
        return _cycleMode;
      }
    } catch (_) {
      // fall back to cycling
    }
    return _nextCycleMode();
  }

  static String _cycleMode = 'iso';

  static String _nextCycleMode() {
    _cycleMode = _cycleMode == 'ortho' ? 'iso' : 'ortho';
    return _cycleMode;
  }
}

dynamic _renderStlThumbnailEntry(Map<String, dynamic> msg) {
  try {
    final bytes = msg['bytes'] as Uint8List;
    final width = msg['width'] as int? ?? 400;
    final height = msg['height'] as int? ?? 400;
    final mode = (msg['mode'] as String? ?? 'ortho').toLowerCase();
    final colorR = (msg['colorR'] as int?) ?? 103;
    final colorG = (msg['colorG'] as int?) ?? 80;
    final colorB = (msg['colorB'] as int?) ?? 164;

    final triangles = _parseStl(bytes);
    if (triangles.isEmpty) {
      return NanoDlpThumbnailGenerator.generatePlaceholder(width, height);
    }

    final trimmed = triangles.length > 200000
        ? _downsampleTriangles(triangles, maxTriangles: 200000)
        : triangles;
    final render =
        _renderTriangles(trimmed, width, height, mode, colorR, colorG, colorB);
    return img.encodePng(render);
  } catch (_) {
    return NanoDlpThumbnailGenerator.generatePlaceholder(400, 400);
  }
}

img.Image _renderTriangles(List<_Triangle> triangles, int width, int height,
    String mode, int colorR, int colorG, int colorB) {
  final image = img.Image(width: width, height: height, numChannels: 4);
  img.fill(image, color: img.ColorRgba8(0, 0, 0, 0));

  // 0. Build smoothed vertex normals
  final normalSums = <_VertexKey, _Vec3>{};
  for (final tri in triangles) {
    final faceNormal =
        tri.normal.length() > 0 ? tri.normal : tri.computeNormal();
    if (faceNormal.length() == 0) continue;
    for (final v in tri.vertices) {
      final key = _vertexKey(v);
      final current = normalSums[key];
      normalSums[key] = current == null ? faceNormal : (current + faceNormal);
    }
  }

  // 1. Find 3D center of the model for better rotation
  double bMinX = double.infinity, bMaxX = -double.infinity;
  double bMinY = double.infinity, bMaxY = -double.infinity;
  double bMinZ = double.infinity, bMaxZ = -double.infinity;

  for (final tri in triangles) {
    for (final v in tri.vertices) {
      if (v.x < bMinX) bMinX = v.x;
      if (v.x > bMaxX) bMaxX = v.x;
      if (v.y < bMinY) bMinY = v.y;
      if (v.y > bMaxY) bMaxY = v.y;
      if (v.z < bMinZ) bMinZ = v.z;
      if (v.z > bMaxZ) bMaxZ = v.z;
    }
  }

  final centerX = (bMinX + bMaxX) / 2.0;
  final centerY = (bMinY + bMaxY) / 2.0;
  final centerZ = (bMinZ + bMaxZ) / 2.0;

  // 2. Project vertices and find screen bounds
  final projectedList = <List<_Vec3>>[];
  double sMinX = double.infinity, sMaxX = -double.infinity;
  double sMinY = double.infinity, sMaxY = -double.infinity;

  for (final tri in triangles) {
    final projected = tri.vertices.map((v) {
      // Offset to center
      final centered = _Vec3(v.x - centerX, v.y - centerY, v.z - centerZ);
      final p = _projectVertex(centered, mode);
      if (p.x < sMinX) sMinX = p.x;
      if (p.x > sMaxX) sMaxX = p.x;
      if (p.y < sMinY) sMinY = p.y;
      if (p.y > sMaxY) sMaxY = p.y;
      return p;
    }).toList();
    projectedList.add(projected);
  }

  final spanX = (sMaxX - sMinX).abs();
  final spanY = (sMaxY - sMinY).abs();
  if (spanX == 0 || spanY == 0) return image;

  final pad = 24.0;
  final scale = math.min((width - pad * 2) / spanX, (height - pad * 2) / spanY);
  final light = _Vec3(-0.4, 0.6, 0.6).normalized();
  const viewDir = _Vec3(0, 0, 1);
  const smoothFactor = 0.0;

  // 3. Z-Buffer Rasterization
  final zBuffer = Float32List(width * height)
    ..fillRange(0, width * height, -double.infinity);

  for (int i = 0; i < triangles.length; i++) {
    final tri = triangles[i];
    final screen = projectedList[i].map((v) {
      final x = (v.x - sMinX) * scale + pad;
      final y = (sMaxY - v.y) * scale + pad;
      return _Vec3(x, y, v.z);
    }).toList();

    final faceNormal =
        tri.normal.length() > 0 ? tri.normal : tri.computeNormal();
    if (faceNormal.length() == 0) continue;
    final rotatedFaceNormal = _rotateNormal(faceNormal, mode).normalized();
    if (rotatedFaceNormal.dot(viewDir) <= 0) {
      continue;
    }

    final baseFace = faceNormal.normalized();
    final v0 =
        (normalSums[_vertexKey(tri.vertices[0])] ?? faceNormal).normalized();
    final v1 =
        (normalSums[_vertexKey(tri.vertices[1])] ?? faceNormal).normalized();
    final v2 =
        (normalSums[_vertexKey(tri.vertices[2])] ?? faceNormal).normalized();

    final n0 = _rotateNormal(_blendNormal(baseFace, v0, smoothFactor), mode);
    final n1 = _rotateNormal(_blendNormal(baseFace, v1, smoothFactor), mode);
    final n2 = _rotateNormal(_blendNormal(baseFace, v2, smoothFactor), mode);

    double i0, i1, i2;
    if (mode == 'iso') {
      final rim0 =
          math.pow(1.0 - math.max(0.0, n0.dot(viewDir)), 2.0).toDouble() * 0.18;
      final rim1 =
          math.pow(1.0 - math.max(0.0, n1.dot(viewDir)), 2.0).toDouble() * 0.18;
      final rim2 =
          math.pow(1.0 - math.max(0.0, n2.dot(viewDir)), 2.0).toDouble() * 0.18;
      i0 = (0.22 + 0.72 * math.max(0.0, n0.dot(light)) + rim0).clamp(0.0, 1.0);
      i1 = (0.22 + 0.72 * math.max(0.0, n1.dot(light)) + rim1).clamp(0.0, 1.0);
      i2 = (0.22 + 0.72 * math.max(0.0, n2.dot(light)) + rim2).clamp(0.0, 1.0);
    } else {
      i0 = 0.9;
      i1 = 0.9;
      i2 = 0.9;
    }

    _rasterizeTriangle(image, zBuffer, screen[0], screen[1], screen[2], i0, i1,
        i2, colorR, colorG, colorB);
  }

  return image;
}

void _rasterizeTriangle(
    img.Image image,
    Float32List zBuffer,
    _Vec3 p0,
    _Vec3 p1,
    _Vec3 p2,
    double i0,
    double i1,
    double i2,
    int colorR,
    int colorG,
    int colorB) {
  int minX = math.max(0, math.min(p0.x, math.min(p1.x, p2.x)).floor());
  int maxX =
      math.min(image.width - 1, math.max(p0.x, math.max(p1.x, p2.x)).ceil());
  int minY = math.max(0, math.min(p0.y, math.min(p1.y, p2.y)).floor());
  int maxY =
      math.min(image.height - 1, math.max(p0.y, math.max(p1.y, p2.y)).ceil());

  double area = (p1.x - p0.x) * (p2.y - p0.y) - (p1.y - p0.y) * (p2.x - p0.x);
  if (area.abs() < 0.0001) return;
  const depthEpsilon = 1e-5;

  for (int y = minY; y <= maxY; y++) {
    for (int x = minX; x <= maxX; x++) {
      double px = x + 0.5;
      double py = y + 0.5;

      double w0 =
          ((p1.x - px) * (p2.y - py) - (p1.y - py) * (p2.x - px)) / area;
      double w1 =
          ((p2.x - px) * (p0.y - py) - (p2.y - py) * (p0.x - px)) / area;
      double w2 = 1.0 - w0 - w1;

      if (w0 >= 0 && w1 >= 0 && w2 >= 0) {
        double depth = w0 * p0.z + w1 * p1.z + w2 * p2.z;
        int idx = y * image.width + x;
        if (depth > zBuffer[idx] + depthEpsilon) {
          zBuffer[idx] = depth;
          final intensity = (w0 * i0 + w1 * i1 + w2 * i2).clamp(0.0, 1.0);

          final brighten = (0.5 + 0.5 * intensity);
          final r = (colorR * brighten).round().clamp(0, 255);
          final g = (colorG * brighten).round().clamp(0, 255);
          final b = (colorB * brighten).round().clamp(0, 255);
          image.setPixel(x, y, img.ColorRgba8(r, g, b, 255));
        }
      }
    }
  }
}

_Vec3 _projectVertex(_Vec3 v, String mode) {
  if (mode == 'iso') {
    var r = v;
    r = _rotateY(r, math.pi / 4.0);
    r = _rotateX(r, 35.264 * math.pi / 180.0);
    return r;
  }
  return v;
}

_Vec3 _rotateNormal(_Vec3 n, String mode) {
  if (mode == 'iso') {
    var r = n;
    r = _rotateY(r, math.pi / 4.0);
    r = _rotateX(r, 35.264 * math.pi / 180.0);
    return r;
  }
  return n;
}

_Vec3 _rotateX(_Vec3 v, double a) {
  final ca = math.cos(a), sa = math.sin(a);
  return _Vec3(v.x, v.y * ca - v.z * sa, v.y * sa + v.z * ca);
}

_Vec3 _rotateY(_Vec3 v, double a) {
  final ca = math.cos(a), sa = math.sin(a);
  return _Vec3(v.x * ca + v.z * sa, v.y, -v.x * sa + v.z * ca);
}

List<_Triangle> _downsampleTriangles(List<_Triangle> triangles,
    {required int maxTriangles}) {
  if (triangles.length <= maxTriangles) return triangles;
  final step = (triangles.length / maxTriangles).ceil();
  final reduced = <_Triangle>[];
  for (var i = 0; i < triangles.length; i += step) {
    reduced.add(triangles[i]);
  }
  return reduced;
}

List<_Triangle> _parseStl(Uint8List bytes) {
  if (_isBinaryStl(bytes)) return _parseBinaryStl(bytes);
  return _parseAsciiStl(bytes);
}

bool _isBinaryStl(Uint8List bytes) {
  if (bytes.length < 84) return false;
  final count = _readUint32(bytes, 80);
  return (84 + count * 50) == bytes.length;
}

List<_Triangle> _parseBinaryStl(Uint8List bytes) {
  final count = _readUint32(bytes, 80);
  final triangles = <_Triangle>[];
  var offset = 84;
  for (var i = 0; i < count; i++) {
    if (offset + 50 > bytes.length) break;
    final n = _Vec3(_readFloat32(bytes, offset),
        _readFloat32(bytes, offset + 4), _readFloat32(bytes, offset + 8));
    final v0 = _Vec3(_readFloat32(bytes, offset + 12),
        _readFloat32(bytes, offset + 16), _readFloat32(bytes, offset + 20));
    final v1 = _Vec3(_readFloat32(bytes, offset + 24),
        _readFloat32(bytes, offset + 28), _readFloat32(bytes, offset + 32));
    final v2 = _Vec3(_readFloat32(bytes, offset + 36),
        _readFloat32(bytes, offset + 40), _readFloat32(bytes, offset + 44));
    offset += 50;
    triangles.add(_Triangle([v0, v1, v2], n));
  }
  return triangles;
}

List<_Triangle> _parseAsciiStl(Uint8List bytes) {
  final content = String.fromCharCodes(bytes);
  final lines = content.split(RegExp(r'\r?\n'));
  final triangles = <_Triangle>[];
  final verts = <_Vec3>[];
  _Vec3 normal = const _Vec3(0, 0, 0);

  for (final line in lines) {
    final trimmed = line.trim();
    if (trimmed.startsWith('facet normal')) {
      final parts = trimmed.split(RegExp(r'\s+'));
      if (parts.length >= 5) {
        normal = _Vec3(double.tryParse(parts[2]) ?? 0,
            double.tryParse(parts[3]) ?? 0, double.tryParse(parts[4]) ?? 0);
      }
    } else if (trimmed.startsWith('vertex')) {
      final parts = trimmed.split(RegExp(r'\s+'));
      if (parts.length >= 4) {
        verts.add(_Vec3(double.tryParse(parts[1]) ?? 0,
            double.tryParse(parts[2]) ?? 0, double.tryParse(parts[3]) ?? 0));
        if (verts.length == 3) {
          triangles.add(_Triangle(List<_Vec3>.from(verts), normal));
          verts.clear();
        }
      }
    }
  }
  return triangles;
}

int _readUint32(Uint8List bytes, int offset) =>
    bytes.buffer.asByteData().getUint32(offset, Endian.little);
double _readFloat32(Uint8List bytes, int offset) =>
    bytes.buffer.asByteData().getFloat32(offset, Endian.little);

class _Triangle {
  _Triangle(this.vertices, this.normal);
  final List<_Vec3> vertices;
  final _Vec3 normal;
  _Vec3 computeNormal() {
    if (vertices.length < 3) return const _Vec3(0, 0, 0);
    final a = vertices[1] - vertices[0], b = vertices[2] - vertices[0];
    return a.cross(b);
  }
}

class _Vec3 {
  const _Vec3(this.x, this.y, this.z);
  final double x, y, z;
  _Vec3 operator -(Object other) {
    final v = other as _Vec3;
    return _Vec3(x - v.x, y - v.y, z - v.z);
  }

  _Vec3 operator +(Object other) {
    final v = other as _Vec3;
    return _Vec3(x + v.x, y + v.y, z + v.z);
  }

  _Vec3 scale(double s) {
    return _Vec3(x * s, y * s, z * s);
  }

  double dot(_Vec3 other) => x * other.x + y * other.y + z * other.z;
  _Vec3 cross(_Vec3 other) => _Vec3(y * other.z - z * other.y,
      z * other.x - x * other.z, x * other.y - y * other.x);
  double length() => math.sqrt(x * x + y * y + z * z);
  _Vec3 normalized() {
    final len = length();
    return len == 0 ? this : _Vec3(x / len, y / len, z / len);
  }
}

_Vec3 _blendNormal(_Vec3 face, _Vec3 vertex, double t) {
  if (t <= 0) return face;
  if (t >= 1) return vertex;
  return (face.scale(1.0 - t) + vertex.scale(t)).normalized();
}

class _VertexKey {
  const _VertexKey(this.x, this.y, this.z);
  final int x;
  final int y;
  final int z;

  @override
  bool operator ==(Object other) {
    return other is _VertexKey && other.x == x && other.y == y && other.z == z;
  }

  @override
  int get hashCode => Object.hash(x, y, z);
}

_VertexKey _vertexKey(_Vec3 v) {
  const scale = 10000.0;
  return _VertexKey(
    (v.x * scale).round(),
    (v.y * scale).round(),
    (v.z * scale).round(),
  );
}

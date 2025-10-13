/*
* Orion - Layer Preview Cache
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

import 'package:orion/backend_service/backend_service.dart';

/// Simple in-memory LRU cache for 2D layer previews.
class LayerPreviewCache {
  LayerPreviewCache._private();
  static final LayerPreviewCache instance = LayerPreviewCache._private();

  // Key format: '$plateId:$layer'
  final _map = <String, Uint8List>{};
  final _order = <String>[]; // keys in insertion order for simple LRU
  final int _maxEntries = 100;

  // Use proper string interpolation so each plate/layer gets a unique key.
  String _key(int plateId, int layer) => '$plateId:$layer';

  // Track in-flight fetches so concurrent requests for the same
  // plate/layer are deduped and only one network call is made.
  final _inflight = <String, Future<Uint8List>>{};

  /// Fetch a specific plate/layer via [backend] and cache the result.
  /// Concurrent callers for the same plate/layer will await the same
  /// in-flight future.
  Future<Uint8List> fetchAndCache(
      BackendService backend, int plateId, int layer) async {
    final k = _key(plateId, layer);
    final existing = _map[k];
    if (existing != null) return existing;
    final inflight = _inflight[k];
    if (inflight != null) return await inflight;

    final future = backend.getPlateLayerImage(plateId, layer).then((bytes) {
      if (bytes.isNotEmpty) set(plateId, layer, bytes);
      return bytes;
    }).whenComplete(() {
      _inflight.remove(k);
    });

    _inflight[k] = future;
    return await future;
  }

  Uint8List? get(int plateId, int layer) {
    final k = _key(plateId, layer);
    final v = _map[k];
    if (v == null) return null;
    // Refresh order (move to end)
    _order.remove(k);
    _order.add(k);
    return v;
  }

  void set(int plateId, int layer, Uint8List bytes) {
    final k = _key(plateId, layer);
    if (_map.containsKey(k)) {
      _order.remove(k);
    }
    _map[k] = bytes;
    _order.add(k);
    _evictIfNeeded();
  }

  void _evictIfNeeded() {
    while (_order.length > _maxEntries) {
      final oldest = _order.removeAt(0);
      _map.remove(oldest);
    }
  }

  void clear() {
    _map.clear();
    _order.clear();
  }

  /// Preload [count] layers starting at [layer+1]. Runs best-effort in
  /// background using the provided backend service instance.
  void preload(BackendService backend, int plateId, int layer,
      {int count = 2}) async {
    for (int i = 1; i <= count; i++) {
      final target = layer + i;
      final k = _key(plateId, target);
      if (_map.containsKey(k)) continue;
      try {
        // Use fetchAndCache which dedupes inflight requests and ensures
        // resizing is performed off the main isolate where supported.
        await fetchAndCache(backend, plateId, target);
      } catch (_) {
        // ignore preload failures
      }
    }
  }
}

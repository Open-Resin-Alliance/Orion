/*
* Orion - NanoDLP HTTP Client
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

import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';
import 'package:orion/backend_service/nanodlp/models/nano_file.dart';
import 'package:orion/backend_service/nanodlp/models/nano_status.dart';
import 'package:orion/backend_service/nanodlp/models/nano_manual.dart';
import 'package:orion/backend_service/nanodlp/nanodlp_mappers.dart';
import 'package:orion/backend_service/nanodlp/helpers/nano_thumbnail_generator.dart';
import 'package:flutter/foundation.dart';
import 'package:orion/backend_service/backend_client.dart';
import 'package:orion/util/orion_config.dart';

/// NanoDLP adapter (initial implementation)
///
/// Implements a small subset of the `BackendClient` contract needed for
/// StatusProvider and thumbnail fetching. Other methods remain unimplemented
/// and should be added as needed.
class NanoDlpHttpClient implements BackendClient {
  late final String apiUrl;
  final _log = Logger('NanoDlpHttpClient');
  final http.Client Function() _clientFactory;
  final Duration _requestTimeout;
  // Increase plates cache TTL so we don't re-query the plates list on every
  // frequent status poll. Plates metadata is relatively static during a
  // print session so a 2-minute cache avoids needless network load.
  static const Duration _platesCacheTtl = Duration(seconds: 120);
  List<NanoFile>? _platesCacheData;
  DateTime? _platesCacheTime;
  Future<List<NanoFile>>? _platesCacheFuture;
  // Cache a resolved PlateID -> NanoFile mapping so we don't repeatedly
  // perform list lookups for the same active plate while status is polled.
  int? _resolvedPlateId;
  NanoFile? _resolvedPlateFile;
  DateTime? _resolvedPlateTime;
  static const Duration _thumbnailCacheTtl = Duration(seconds: 30);
  static const Duration _thumbnailPlaceholderCacheTtl = Duration(seconds: 5);
  final Map<String, _ThumbnailCacheEntry> _thumbnailCache = {};
  final Map<String, Future<_ThumbnailCacheEntry>> _thumbnailInFlight = {};

  NanoDlpHttpClient(
      {http.Client Function()? clientFactory, Duration? requestTimeout})
      : _clientFactory = clientFactory ?? http.Client.new,
        _requestTimeout = requestTimeout ?? const Duration(seconds: 5) {
    _createdAt = DateTime.now();
    try {
      final cfg = OrionConfig();
      final base = cfg.getString('nanodlp.base_url', category: 'advanced');
      final useCustom = cfg.getFlag('useCustomUrl', category: 'advanced');
      final custom = cfg.getString('customUrl', category: 'advanced');

      if (base.isNotEmpty) {
        apiUrl = base;
      } else if (useCustom && custom.isNotEmpty) {
        apiUrl = custom;
      } else {
        apiUrl = 'http://localhost';
      }
    } catch (e) {
      apiUrl = 'http://localhost';
    }
    // _log.info('constructed NanoDlpHttpClient apiUrl=$apiUrl'); // commented out to reduce noise
  }

  http.Client _createClient() {
    final inner = _clientFactory();
    return _TimeoutHttpClient(inner, _requestTimeout, _log, 'NanoDLP');
  }

  // Timestamp when this client instance was created. Used to avoid
  // performing potentially expensive plate-list resolution during the
  // very first status poll immediately at app startup.
  late final DateTime _createdAt;

  // --- Minimal implemented APIs ---
  @override
  Future<Map<String, dynamic>> getStatus() async {
    final baseNoSlash = apiUrl.replaceAll(RegExp(r'/+$'), '');
    final uri = Uri.parse('$baseNoSlash/status');
    // Attempt the status request with one retry on transient failure.
    int attempt = 0;
    while (true) {
      attempt += 1;
      final client = _createClient();
      try {
        final resp = await client.get(uri);
        if (resp.statusCode != 200) {
          throw Exception('NanoDLP status call failed: ${resp.statusCode}');
        }
        final decoded = json.decode(resp.body) as Map<String, dynamic>;
        // Remove very large fields we don't need (e.g. FillAreas) to avoid
        // costly parsing and memory churn when polling /status frequently.
        if (decoded.containsKey('FillAreas')) {
          try {
            decoded.remove('FillAreas');
          } catch (_) {
            // ignore any removal errors; parsing will continue without it
          }
        }
        var nano = NanoStatus.fromJson(decoded);

        // If the status payload doesn't include file metadata but does include
        // a PlateID, try to resolve the plate from the plates list so we can
        // populate file metadata & enable thumbnail lookup on the UI.
        if (nano.file == null) {
          int? plateId;
          try {
            final candidate = decoded['PlateID'] ??
                decoded['plate_id'] ??
                decoded['Plateid'] ??
                decoded['plateId'];
            if (candidate is int) plateId = candidate;
            if (candidate is String) plateId = int.tryParse(candidate);
          } catch (_) {
            plateId = null;
          }
          if (plateId != null) {
            try {
              // If we previously resolved this plate and the cache is fresh,
              // reuse it.
              if (_resolvedPlateId == plateId &&
                  _resolvedPlateFile != null &&
                  _resolvedPlateTime != null &&
                  DateTime.now().difference(_resolvedPlateTime!) <
                      _platesCacheTtl) {
                final found = _resolvedPlateFile!;
                nano = NanoStatus(
                  printing: nano.printing,
                  paused: nano.paused,
                  statusMessage: nano.statusMessage,
                  currentHeight: nano.currentHeight,
                  layerId: nano.layerId,
                  layersCount: nano.layersCount,
                  resinLevel: nano.resinLevel,
                  temp: nano.temp,
                  mcuTemp: nano.mcuTemp,
                  rawJsonStatus: nano.rawJsonStatus,
                  state: nano.state,
                  stateCode: nano.stateCode,
                  progress: nano.progress,
                  file: found,
                  z: nano.z,
                  curing: nano.curing,
                );
              } else {
                // Only attempt to resolve plate metadata when a job is active
                // (printing). Avoid fetching the plates list while the device
                // is idle to minimize network traffic at startup.
                if (!nano.printing) {
                  // Skipping PlateID $plateId resolve because printer is not printing
                } else {
                  // Don't block status fetch on plates list resolution. Schedule
                  // a background task to refresh plates and populate the
                  // resolved-plate cache for subsequent polls and thumbnail
                  // lookups. However, avoid doing this immediately at startup
                  // (many installs poll status right away) — only schedule the
                  // async resolve if this client was created more than 2s ago.
                  final age = DateTime.now().difference(_createdAt);
                  if (age < const Duration(seconds: 2)) {
                    _log.fine(
                        'Skipping PlateID $plateId resolve during startup (age=${age.inMilliseconds}ms)');
                  } else {
                    _log.fine('Scheduling async resolve for PlateID $plateId');
                    Future(() async {
                      try {
                        final plates = await _fetchPlates();
                        final found = plates.firstWhere(
                            (p) => p.plateId != null && p.plateId == plateId,
                            orElse: () => const NanoFile());
                        if (found.plateId != null) {
                          // Cache resolved plate for future polls
                          _log.fine(
                              'Resolved PlateID $plateId -> ${found.name}');
                          _resolvedPlateId = plateId;
                          _resolvedPlateFile = found;
                          _resolvedPlateTime = DateTime.now();
                        }
                      } catch (e, st) {
                        _log.fine('Async PlateID resolve failed', e, st);
                      }
                    });
                  }
                }
              }
            } catch (e, st) {
              _log.fine('Failed to resolve PlateID $plateId to plate metadata',
                  e, st);
            }
          }
        }

        return nanoStatusToOdysseyMap(nano);
      } catch (e, st) {
        _log.fine('NanoDLP getStatus attempt #$attempt failed', e, st);
        // Close client and, if we haven't retried yet, retry once.
        client.close();
        if (attempt >= 2) rethrow;
        _log.info('Retrying NanoDLP /status (attempt ${attempt + 1})');
        // Small backoff before retry
        await Future.delayed(const Duration(milliseconds: 200));
        continue;
      }
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getNotifications() async {
    final baseNoSlash = apiUrl.replaceAll(RegExp(r'/+$'), '');
    final uri = Uri.parse('$baseNoSlash/notification');
    final client = _createClient();
    try {
      final resp = await client.get(uri);
      if (resp.statusCode != 200) return [];
      final decoded = json.decode(resp.body);
      if (decoded is List) {
        return decoded
            .whereType<Map<String, dynamic>>()
            .toList(growable: false);
      }
      return [];
    } catch (e) {
      // Silent on per-call failure: higher-level StatusProvider will report
      // backend connectivity issues. Suppress fine-level noise here.
      return [];
    } finally {
      client.close();
    }
  }

  @override
  Future<bool> usbAvailable() async {
    // NanoDLP runs on a networked device, USB availability is not applicable.
    return false;
  }

  @override
  Stream<Map<String, dynamic>> getStatusStream() async* {
    const pollInterval = Duration(seconds: 2);
    while (true) {
      try {
        final m = await getStatus();
        yield m;
      } catch (_) {
        // ignore and continue
      }
      await Future.delayed(pollInterval);
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getAnalytics(int n) async {
    final baseNoSlash = apiUrl.replaceAll(RegExp(r'/+$'), '');
    final uri = Uri.parse('$baseNoSlash/analytic/data/$n');
    final client = _createClient();
    try {
      final resp = await client.get(uri);
      if (resp.statusCode != 200) return [];
      final decoded = json.decode(resp.body);
      if (decoded is List) {
        return decoded
            .whereType<Map<String, dynamic>>()
            .toList(growable: false);
      }
      return [];
    } catch (e) {
      // Suppress fine-level noise; keep failure behavior but don't log here.
      return [];
    } finally {
      client.close();
    }
  }

  @override
  Future<dynamic> getAnalyticValue(int id) async {
    final baseNoSlash = apiUrl.replaceAll(RegExp(r'/+$'), '');
    final uri = Uri.parse('$baseNoSlash/analytic/value/$id');
    final client = _createClient();
    try {
      final resp = await client.get(uri);
      if (resp.statusCode != 200) return null;
      final body = resp.body.trim();
      // NanoDLP returns a plain numeric value like "-3.719..." so try parsing
      final v = double.tryParse(body);
      if (v != null) return v;
      // Fallback: try JSON decode (in case the server returns JSON)
      try {
        final decoded = json.decode(body);
        return decoded;
      } catch (_) {
        return body;
      }
    } catch (e) {
      // Suppress fine-level noise; return null on failure.
      return null;
    } finally {
      client.close();
    }
  }

  @override
  Future<Uint8List> getFileThumbnail(
      String location, String filePath, String size) async {
    final dims = _thumbnailDimensions(size);
    Uint8List placeholder() {
      _log.fine(
          'Using placeholder thumbnail for $filePath ($size -> ${dims.$1}x${dims.$2})');
      return NanoDlpThumbnailGenerator.generatePlaceholder(dims.$1, dims.$2);
    }

    final normalizedPath =
        filePath.replaceAll(RegExp(r'^/+'), '').toLowerCase();
    var cacheKey =
        _thumbnailCacheKey('missing:$normalizedPath', dims.$1, dims.$2);
    final cachedBeforeLookup = _getCachedThumbnail(cacheKey);
    if (cachedBeforeLookup != null) {
      return cachedBeforeLookup;
    }

    NanoFile? plate;
    try {
      plate = await _findPlateForPath(filePath);
    } catch (e, st) {
      _log.warning(
          'NanoDLP failed locating plate for thumbnail: $filePath', e, st);
      final bytes = placeholder();
      _storeThumbnail(cacheKey, bytes, placeholder: true);
      return bytes;
    }

    if (plate == null) {
      _log.fine('NanoDLP thumbnail lookup found no plate for $filePath');
      final bytes = placeholder();
      _storeThumbnail(cacheKey, bytes, placeholder: true);
      return bytes;
    }
    cacheKey =
        _thumbnailCacheKeyForPlate(plate, normalizedPath, dims.$1, dims.$2);
    final cached = _getCachedThumbnail(cacheKey);
    if (cached != null) {
      return cached;
    }

    if (plate.plateId == null || !plate.previewAvailable) {
      _log.fine(
          'NanoDLP plate ${plate.resolvedPath} has no preview (plateId=${plate.plateId}, preview=${plate.previewAvailable})');
      final bytes = placeholder();
      _storeThumbnail(cacheKey, bytes, placeholder: true);
      return bytes;
    }

    final inflight = _thumbnailInFlight[cacheKey];
    if (inflight != null) {
      final entry = await inflight;
      final cachedEntry = _getCachedThumbnail(cacheKey);
      if (cachedEntry != null) {
        return cachedEntry;
      }
      _storeThumbnailEntry(cacheKey, entry);
      return entry.bytes;
    }

    final baseNoSlash = apiUrl.replaceAll(RegExp(r'/+$'), '');
    final uri = Uri.parse('$baseNoSlash/static/plates/${plate.plateId}/3d.png');
    final future = _downloadThumbnail(uri, 'plate ${plate.plateId}');
    _thumbnailInFlight[cacheKey] = future;
    try {
      final entry = await future;
      _storeThumbnailEntry(cacheKey, entry);
      return entry.bytes;
    } finally {
      if (identical(_thumbnailInFlight[cacheKey], future)) {
        _thumbnailInFlight.remove(cacheKey);
      }
    }
  }

  // --- Unimplemented / TODOs ---
  @override
  Future<void> cancelPrint() async {
    try {
      final baseNoSlash = apiUrl.replaceAll(RegExp(r'/+$'), '');
      final uri = Uri.parse('$baseNoSlash/printer/stop');
      _log.info('NanoDLP stopPrint request: $uri');
      final client = _createClient();
      try {
        final resp = await client.get(uri);
        if (resp.statusCode != 200) {
          _log.warning(
              'NanoDLP stopPrint failed: ${resp.statusCode} ${resp.body}');
          throw Exception('NanoDLP stopPrint failed: ${resp.statusCode}');
        }
        // Some installs return JSON or plain text; ignore body and treat 200 as success
        return;
      } finally {
        client.close();
      }
    } catch (e, st) {
      _log.warning('NanoDLP stopPrint error', e, st);
      rethrow;
    }
  }

  @override
  Future<Map<String, dynamic>> deleteFile(
          String location, String filePath) async =>
      throw UnimplementedError('NanoDLP deleteFile not implemented');

  @override
  Future<Map<String, dynamic>> getFileMetadata(
      String location, String filePath) async {
    try {
      final plate = await _findPlateForPath(filePath);
      if (plate != null) {
        return plate.toOdysseyMetadata();
      }
      return {
        'file_data': {
          'path': filePath,
          'name': filePath,
          'last_modified': 0,
          'parent_path': '',
        },
      };
    } catch (e, st) {
      _log.warning('NanoDLP getFileMetadata failed for $filePath', e, st);
      throw Exception('NanoDLP getFileMetadata failed: $e');
    }
  }

  @override
  Future<Map<String, dynamic>> getConfig() async =>
      // NanoDLP doesn't have a separate /config endpoint in many setups.
      // Use /status as a best-effort source for device info and expose a
      // minimal config-shaped map expected by ConfigModel.fromJson.
      () async {
        final baseNoSlash = apiUrl.replaceAll(RegExp(r'/+$'), '');
        final uri = Uri.parse('$baseNoSlash/status');
        final client = _createClient();
        try {
          final resp = await client.get(uri);
          if (resp.statusCode != 200) {
            throw Exception('NanoDLP status call failed: ${resp.statusCode}');
          }
          final decoded = json.decode(resp.body) as Map<String, dynamic>;

          // Map relevant keys into a config-shaped map
          final general = <String, dynamic>{
            'hostname': decoded['Hostname'] ?? decoded['hostname'] ?? '',
            'ip': decoded['IP'] ?? decoded['ip'] ?? '',
            'status': decoded['Status'] ?? decoded['status'] ?? '',
          };

          final advanced = <String, dynamic>{
            'backend': 'nanodlp',
            'nanodlp': {
              'build': decoded['Build'] ?? decoded['build'],
              'version': decoded['Version'] ?? decoded['version'],
            }
          };

          final machine = <String, dynamic>{
            'disk': decoded['disk'] ?? decoded['Disk'],
            'wifi': decoded['Wifi'] ?? decoded['wifi'],
            'resin_level': decoded['resin'] ??
                decoded['ResinLevelMm'] ??
                decoded['resin_level_mm'],
          };

          return {
            'general': general,
            'advanced': advanced,
            'machine': machine,
            'vendor': <String, dynamic>{},
          };
        } finally {
          client.close();
        }
      }();

  @override
  Future<String> getBackendVersion() async {
    final baseNoSlash = apiUrl.replaceAll(RegExp(r'/+$'), '');
    final uri = Uri.parse('$baseNoSlash/static/image_version');
    final client = _createClient();
    try {
      final resp = await client.get(uri);
      if (resp.statusCode != 200) {
        _log.fine('NanoDLP image_version returned ${resp.statusCode}');
        return 'NanoDLP';
      }

      final body = resp.body.trim();
      if (body.isEmpty) return 'NanoDLP';

      // Try to capture a full semver and any following +metadata tokens,
      // e.g. "Athena2-16K-CM5+0.9.9+2025-08-01" -> capture "0.9.9+2025-08-01".
      final fullSemverWithMeta =
          RegExp(r'\d+\.\d+\.\d+(?:\+[^\s]+)*').firstMatch(body);
      if (fullSemverWithMeta != null) {
        return 'NanoDLP ${fullSemverWithMeta.group(0)}';
      }

      // Fallback: capture X.Y or X.Y.Z and any +metadata following it.
      final partialWithMeta =
          RegExp(r'\d+\.\d+(?:\.\d+)?(?:\+[^\s]+)*').firstMatch(body);
      if (partialWithMeta != null) {
        return 'NanoDLP ${partialWithMeta.group(0)}';
      }

      // As a last resort, try to pick a token after "+" or return the raw body.
      final plusParts = body.split('+');
      final candidate = plusParts.firstWhere((p) => RegExp(r'\d').hasMatch(p),
          orElse: () => body);
      return 'NanoDLP ${candidate.trim()}';
    } catch (e, st) {
      _log.fine('Failed to fetch backend version', e, st);
      return 'NanoDLP';
    } finally {
      client.close();
    }
  }

  @override
  Future<Map<String, dynamic>> listItems(
      String location, int pageSize, int pageIndex, String subdirectory) async {
    try {
      final plates = await _fetchPlates();
      final files = plates.map((p) => p.toOdysseyFileEntry()).toList();
      _log.info('listItems: mapped ${files.length} files from NanoDLP payload');
      return {
        'files': files,
        'dirs': <Map<String, dynamic>>[],
        'page_index': pageIndex,
        'page_size': pageSize,
      };
    } catch (e, st) {
      _log.warning('NanoDLP listItems failed', e, st);
      return {
        'files': <Map<String, dynamic>>[],
        'dirs': <Map<String, dynamic>>[],
        'page_index': pageIndex,
        'page_size': pageSize,
      };
    }
  }

  @override
  Future<Map<String, dynamic>> move(double height) async {
    // NanoDLP's /z-axis/move endpoint expects a relative micron distance.
    // Our callers may pass an absolute target (Odyssey contract) or a
    // relative delta. We'll behave as follows:
    // - If we can read current Z from /status, treat `height` as an absolute
    //   target and compute delta = height - currentZ (mm).
    // - If we cannot read status, treat `height` as a relative delta (mm).
    // Always read current Z from /status. If we cannot read status,
    // fail the move so callers can surface the error. We must compute
    // a delta against the true device position.
    double currentZ = 0.0;
    try {
      final statusMap = await getStatus();
      final phys = statusMap['physical_state'];
      if (phys is Map && phys['z'] != null) {
        final zVal = phys['z'];
        if (zVal is num) {
          currentZ = zVal.toDouble();
        }
      }
    } catch (e, st) {
      _log.warning('Failed to read NanoDLP status; cannot compute move', e, st);
      throw Exception('Failed to read NanoDLP status: $e');
    }

    // Compute delta in mm: callers provide an absolute target; compute
    // delta = target - currentZ
    final deltaMm = (height - currentZ);

    // Convert to microns (NanoDLP expects integer micron distances). Use
    // rounding to nearest micron. If the resulting delta is zero, no-op.
    final deltaMicrons = deltaMm == 0.0 ? 0 : (deltaMm * 1000).round();
    if (deltaMicrons == 0) {
      return NanoManualResult(ok: true, message: 'no-op').toMap();
    }

    final direction = deltaMicrons > 0 ? 'up' : 'down';
    final distanceMicrons = deltaMicrons.abs();
    final baseNoSlash = apiUrl.replaceAll(RegExp(r'/+$'), '');
    final uri = Uri.parse(
        '$baseNoSlash/z-axis/move/$direction/micron/$distanceMicrons');
    _log.info(
        'NanoDLP relative move request: $uri (deltaMm=$deltaMm currentZ=$currentZ)');

    final client = _createClient();
    try {
      final resp = await client.get(uri);
      if (resp.statusCode != 200) {
        _log.warning('NanoDLP move failed: ${resp.statusCode} ${resp.body}');
        throw Exception('NanoDLP move failed: ${resp.statusCode}');
      }
      try {
        final decoded = json.decode(resp.body);
        final nm = NanoManualResult.fromDynamic(decoded);
        return nm.toMap();
      } catch (_) {
        return NanoManualResult(ok: true).toMap();
      }
    } finally {
      client.close();
    }
  }

  @override
  Future<Map<String, dynamic>> moveDelta(double deltaMm) async {
    // Send a dumb relative move command in microns (NanoDLP expects an
    // integer micron distance). Positive = up, negative = down.
    final deltaMicrons = (deltaMm * 1000).round();
    if (deltaMicrons == 0) {
      return NanoManualResult(ok: true, message: 'no-op').toMap();
    }

    final direction = deltaMicrons > 0 ? 'up' : 'down';
    final distance = deltaMicrons.abs();
    final baseNoSlash = apiUrl.replaceAll(RegExp(r'/+$'), '');
    final uri =
        Uri.parse('$baseNoSlash/z-axis/move/$direction/micron/$distance');
    _log.info('NanoDLP relative moveDelta request: $uri (deltaMm=$deltaMm)');

    final client = _createClient();
    try {
      final resp = await client.get(uri);
      if (resp.statusCode != 200) {
        _log.warning(
            'NanoDLP moveDelta failed: ${resp.statusCode} ${resp.body}');
        throw Exception('NanoDLP moveDelta failed: ${resp.statusCode}');
      }
      try {
        final decoded = json.decode(resp.body);
        final nm = NanoManualResult.fromDynamic(decoded);
        return nm.toMap();
      } catch (_) {
        return NanoManualResult(ok: true).toMap();
      }
    } finally {
      client.close();
    }
  }

  @override
  Future<bool> canMoveToTop() async {
    // Best-effort: check /status to see if device exposes z-axis controls
    try {
      final baseNoSlash = apiUrl.replaceAll(RegExp(r'/+$'), '');
      final uri = Uri.parse('$baseNoSlash/status');
      final client = _createClient();
      try {
        final resp = await client.get(uri);
        if (resp.statusCode != 200) return false;
        // If status contains physical_state or similar keys, assume support.
        final decoded = json.decode(resp.body) as Map<String, dynamic>;
        return decoded.containsKey('CurrentHeight') ||
            decoded.containsKey('physical_state');
      } finally {
        client.close();
      }
    } catch (_) {
      return false;
    }
  }

  @override
  Future<Map<String, dynamic>> moveToTop() async {
    final baseNoSlash = apiUrl.replaceAll(RegExp(r'/+$'), '');
    final uri = Uri.parse('$baseNoSlash/z-axis/top');
    _log.info('NanoDLP moveToTop request: $uri');
    final client = _createClient();
    try {
      final resp = await client.get(uri);
      if (resp.statusCode != 200) {
        _log.warning(
            'NanoDLP moveToTop failed: ${resp.statusCode} ${resp.body}');
        throw Exception('NanoDLP moveToTop failed: ${resp.statusCode}');
      }
      try {
        final decoded = json.decode(resp.body);
        final nm = NanoManualResult.fromDynamic(decoded);
        return nm.toMap();
      } catch (_) {
        return NanoManualResult(ok: true).toMap();
      }
    } finally {
      client.close();
    }
  }

  @override
  Future<bool> canMoveToFloor() async {
    // Best-effort: check /status to see if device exposes z-axis controls
    try {
      final baseNoSlash = apiUrl.replaceAll(RegExp(r'/+$'), '');
      final uri = Uri.parse('$baseNoSlash/status');
      final client = _createClient();
      try {
        final resp = await client.get(uri);
        if (resp.statusCode != 200) return false;
        // If status contains physical_state or similar keys, assume support.
        final decoded = json.decode(resp.body) as Map<String, dynamic>;
        return decoded.containsKey('CurrentHeight') ||
            decoded.containsKey('physical_state');
      } finally {
        client.close();
      }
    } catch (_) {
      return false;
    }
  }

  @override
  Future<Map<String, dynamic>> moveToFloor() async {
    final baseNoSlash = apiUrl.replaceAll(RegExp(r'/+$'), '');
    final uri = Uri.parse('$baseNoSlash/z-axis/bottom');
    _log.info('NanoDLP moveToFloor request: $uri');
    final client = _createClient();
    try {
      final resp = await client.get(uri);
      if (resp.statusCode != 200) {
        _log.warning(
            'NanoDLP moveToFloor failed: ${resp.statusCode} ${resp.body}');
        throw Exception('NanoDLP moveToFloor failed: ${resp.statusCode}');
      }
      try {
        final decoded = json.decode(resp.body);
        final nm = NanoManualResult.fromDynamic(decoded);
        return nm.toMap();
      } catch (_) {
        return NanoManualResult(ok: true).toMap();
      }
    } finally {
      client.close();
    }
  }

  @override
  Future<Map<String, dynamic>> manualCommand(String command) async {
    try {
      final baseNoSlash = apiUrl.replaceAll(RegExp(r'/+$'), '');
      final uri = Uri.parse('$baseNoSlash/gcode');
      _log.info('NanoDLP manualCommand($command) request -> POST /gcode: $uri');
      final client = _createClient();
      try {
        final resp = await client.post(uri, body: {'gcode': command});
        if (resp.statusCode != 200) {
          _log.warning(
              'NanoDLP manualCommand($command) failed: ${resp.statusCode} ${resp.body}');
          throw Exception(
              'NanoDLP manualCommand($command) failed: ${resp.statusCode}');
        }
        try {
          final decoded = json.decode(resp.body);
          final nm = NanoManualResult.fromDynamic(decoded);
          return nm.toMap();
        } catch (_) {
          return NanoManualResult(ok: true).toMap();
        }
      } finally {
        client.close();
      }
    } catch (e, st) {
      _log.warning('NanoDLP manualCommand($command) error', e, st);
      throw Exception('NanoDLP manualCommand($command) failed: $e');
    }
  }

  @override
  Future<Map<String, dynamic>> manualCure(bool cure) async {
    try {
      final action = cure ? 'on' : 'blank';
      final baseNoSlash = apiUrl.replaceAll(RegExp(r'/+$'), '');
      final uri = Uri.parse('$baseNoSlash/projector/$action');
      _log.info(
          'NanoDLP manualCure($cure) request -> /projector/$action: $uri');
      final client = _createClient();
      try {
        final resp = await client.get(uri);
        if (resp.statusCode != 200) {
          _log.warning(
              'NanoDLP manualCure($cure) failed: ${resp.statusCode} ${resp.body}');
          throw Exception(
              'NanoDLP manualCure($cure) failed: ${resp.statusCode}');
        }
        try {
          final decoded = json.decode(resp.body);
          final nm = NanoManualResult.fromDynamic(decoded);
          return nm.toMap();
        } catch (_) {
          return NanoManualResult(ok: true).toMap();
        }
      } finally {
        client.close();
      }
    } catch (e, st) {
      _log.warning('NanoDLP manualCure($cure) error', e, st);
      throw Exception('NanoDLP manualCure($cure) failed: $e');
    }
  }

  @override
  Future<Map<String, dynamic>> emergencyStop() async {
    final baseNoSlash = apiUrl.replaceAll(RegExp(r'/+$'), '');
    final uri = Uri.parse('$baseNoSlash/printer/force-stop');
    _log.info('NanoDLP emergencyStop commanded: $uri');
    final client = _createClient();
    try {
      final resp = await client.get(uri);
      if (resp.statusCode != 200) {
        _log.warning(
            'NanoDLP emergencyStop failed as expected: ${resp.statusCode} ${resp.body}');
        // throw Exception('NanoDLP emergencyStop failed: ${resp.statusCode}');
        client.close();
        return NanoManualResult(ok: true)
            .toMap(); // treat non-200 as success, emergency stop should have occurred.
      }
      try {
        final decoded = json.decode(resp.body);
        final nm = NanoManualResult.fromDynamic(decoded);
        return nm.toMap();
      } catch (_) {
        return NanoManualResult(ok: true).toMap();
      }
    } finally {
      client.close();
    }
  }

  @override
  Future<Map<String, dynamic>> manualHome() async => () async {
        final baseNoSlash = apiUrl.replaceAll(RegExp(r'/+$'), '');
        final uri = Uri.parse('$baseNoSlash/z-axis/calibrate');
        final client = _createClient();
        try {
          final resp = await client.get(uri);
          if (resp.statusCode != 200) {
            _log.warning(
                'NanoDLP manualHome failed: ${resp.statusCode} ${resp.body}');
            throw Exception('NanoDLP manualHome failed: ${resp.statusCode}');
          }
          try {
            final decoded = json.decode(resp.body);
            final nm = NanoManualResult.fromDynamic(decoded);
            return nm.toMap();
          } catch (_) {
            // Some NanoDLP installs return empty body; treat 200 as success.
            return NanoManualResult(ok: true).toMap();
          }
        } finally {
          client.close();
        }
      }();

  @override
  Future<void> disableNotification(int timestamp) async {
    try {
      final baseNoSlash = apiUrl.replaceAll(RegExp(r'/+$'), '');
      final uri = Uri.parse('$baseNoSlash/notification/disable/$timestamp');
      _log.info('NanoDLP disableNotification: $uri');
      final client = _createClient();
      try {
        final resp = await client.get(uri);
        if (resp.statusCode != 200) {
          _log.warning(
              'NanoDLP disableNotification returned ${resp.statusCode}: ${resp.body}');
          throw Exception(
              'NanoDLP disableNotification failed: ${resp.statusCode}');
        }
        return;
      } finally {
        client.close();
      }
    } catch (e, st) {
      _log.warning('NanoDLP disableNotification error', e, st);
      rethrow;
    }
  }

  @override
  Future<void> pausePrint() async {
    try {
      final baseNoSlash = apiUrl.replaceAll(RegExp(r'/+$'), '');
      final uri = Uri.parse('$baseNoSlash/printer/pause');
      _log.info('NanoDLP pausePrint request: $uri');
      final client = _createClient();
      try {
        final resp = await client.get(uri);
        if (resp.statusCode != 200) {
          _log.warning(
              'NanoDLP pausePrint failed: ${resp.statusCode} ${resp.body}');
          throw Exception('NanoDLP pausePrint failed: ${resp.statusCode}');
        }
        // Some installs return JSON or plain text; ignore body and treat 200 as success
        return;
      } finally {
        client.close();
      }
    } catch (e, st) {
      _log.warning('NanoDLP pausePrint error', e, st);
      rethrow;
    }
  }

  @override
  Future<void> resumePrint() async {
    try {
      final baseNoSlash = apiUrl.replaceAll(RegExp(r'/+$'), '');
      final uri = Uri.parse('$baseNoSlash/printer/unpause');
      _log.info('NanoDLP resumePrint request: $uri');
      final client = _createClient();
      try {
        final resp = await client.get(uri);
        if (resp.statusCode != 200) {
          _log.warning(
              'NanoDLP resumePrint failed: ${resp.statusCode} ${resp.body}');
          throw Exception('NanoDLP resumePrint failed: ${resp.statusCode}');
        }
        // Some installs return JSON or plain text; ignore body and treat 200 as success
        return;
      } finally {
        client.close();
      }
    } catch (e, st) {
      _log.warning('NanoDLP resumePrint error', e, st);
      rethrow;
    }
  }

  @override
  @override
  Future<void> startPrint(String location, String filePath) async {
    try {
      // Resolve the plate ID. `filePath` may be a path or already a plateId.
      String? plateId;
      try {
        final plate = await _findPlateForPath(filePath);
        if (plate != null && plate.plateId != null) {
          plateId = plate.plateId!.toString();
        }
      } catch (_) {
        // ignore and try treating filePath as an ID
      }

      final idToUse = plateId ?? filePath;
      final baseNoSlash = apiUrl.replaceAll(RegExp(r'/+$'), '');
      final uri = Uri.parse('$baseNoSlash/printer/start/$idToUse');
      _log.info('NanoDLP startPrint request: $uri');
      final client = _createClient();
      try {
        final resp = await client.get(uri);
        if (resp.statusCode != 200) {
          _log.warning(
              'NanoDLP startPrint failed: ${resp.statusCode} ${resp.body}');
          throw Exception('NanoDLP startPrint failed: ${resp.statusCode}');
        }
        // Some installs return JSON or plain text; ignore body and treat 200 as success
        // Kick off a background plates prefetch so the server-side plate list
        // is refreshed and thumbnails / file metadata become available faster
        // for the UI immediately after a start request.
        Future(() async {
          try {
            final plates = await _fetchPlates(forceRefresh: true);
            // If we already resolved a plate id for this path, prefer that.
            if (plateId != null) {
              final found = plates.firstWhere(
                  (p) => p.plateId != null && p.plateId!.toString() == plateId,
                  orElse: () => const NanoFile());
              if (found.plateId != null) {
                _resolvedPlateId = found.plateId;
                _resolvedPlateFile = found;
                _resolvedPlateTime = DateTime.now();
                _log.fine(
                    'Prefetched and resolved PlateID $plateId -> ${found.name}');
              }
            } else {
              // Try to match by path/name in case caller passed a path.
              final normalized = filePath.replaceAll(RegExp(r'^/+'), '');
              final found = plates.firstWhere(
                  (p) =>
                      _matchesPath(p.resolvedPath, normalized) ||
                      (p.name != null && _matchesPath(p.name, normalized)),
                  orElse: () => const NanoFile());
              if (found.plateId != null) {
                _resolvedPlateId = found.plateId;
                _resolvedPlateFile = found;
                _resolvedPlateTime = DateTime.now();
                _log.fine(
                    'Prefetched and resolved path $filePath -> ${found.name}');
              }
            }
          } catch (e, st) {
            _log.fine('Prefetch plates after startPrint failed', e, st);
          }
        });

        return;
      } finally {
        client.close();
      }
    } catch (e, st) {
      _log.warning('NanoDLP startPrint error', e, st);
      rethrow;
    }
  }

  @override
  Future<void> displayTest(String test) async {
    // Map test names to real NanoDLP test endpoints.
    const Map<String, String> testMappings = {
      'Grid': '/projector/generate/calibration',
      // So far Athena is the only printer with NanoDLP that we support
      'Logo': '/projector/display/general***athena.png',
      'Measure': '/projector/generate/boundaries',
      'White': '/projector/generate/white',
    };

    try {
      final baseNoSlash = apiUrl.replaceAll(RegExp(r'/+$'), '');
      // Resolve mapped command; fall back to legacy /display/test/<test> if unknown.
      final mapped = testMappings[test];
      final command = mapped ?? '/display/test/$test';
      final cmdWithSlash = command.startsWith('/') ? command : '/$command';
      final uri = Uri.parse('$baseNoSlash$cmdWithSlash');

      _log.info('NanoDLP displayTest request for "$test": $uri');
      final client = _createClient();
      try {
        final resp = await client.get(uri);
        if (resp.statusCode != 200) {
          _log.warning(
              'NanoDLP displayTest failed: ${resp.statusCode} ${resp.body}');
          throw Exception('NanoDLP displayTest failed: ${resp.statusCode}');
        }
        // Some installs return JSON or plain text; ignore body and treat 200 as success
        return;
      } finally {
        client.close();
      }
    } catch (e, st) {
      _log.warning('NanoDLP displayTest error', e, st);
      rethrow;
    }
  }

  bool _matchesPath(String? lhs, String rhs) {
    if (lhs == null) return false;
    return lhs.trim().toLowerCase() == rhs.trim().toLowerCase();
  }

  String _thumbnailCacheKey(String identifier, int width, int height) =>
      '$identifier|$width|$height';

  String _thumbnailCacheKeyForPlate(
      NanoFile plate, String fallbackPath, int width, int height) {
    // PlateID can change when files are deleted/replaced on the device.
    // Prefer stable identifiers based on path + lastModified (if available)
    // so cache keys remain valid across plateId churn.
    final resolvedPath = plate.resolvedPath.isNotEmpty
        ? plate.resolvedPath.toLowerCase()
        : fallbackPath;
    final lm = plate.lastModified ?? 0;
    final identifier = 'path:$resolvedPath|lm:$lm';
    return _thumbnailCacheKey(identifier, width, height);
  }

  Uint8List? _getCachedThumbnail(String cacheKey) {
    final entry = _thumbnailCache[cacheKey];
    if (entry == null) return null;
    final ttl =
        entry.placeholder ? _thumbnailPlaceholderCacheTtl : _thumbnailCacheTtl;
    if (DateTime.now().difference(entry.timestamp) >= ttl) {
      _thumbnailCache.remove(cacheKey);
      return null;
    }
    return entry.bytes;
  }

  void _storeThumbnail(String cacheKey, Uint8List bytes,
      {required bool placeholder}) {
    _storeThumbnailEntry(
        cacheKey, _ThumbnailCacheEntry(bytes, DateTime.now(), placeholder));
  }

  void _storeThumbnailEntry(String cacheKey, _ThumbnailCacheEntry entry) {
    _thumbnailCache[cacheKey] = entry;
  }

  Future<_ThumbnailCacheEntry> _downloadThumbnail(
      Uri uri, String debugLabel) async {
    final client = _createClient();
    try {
      final resp = await client.get(uri);
      if (resp.statusCode == 200 && resp.bodyBytes.isNotEmpty) {
        // Return raw bytes from server. Decoding/resizing will be done by the
        // caller in a background isolate (e.g. via compute) to avoid jank.
        return _ThumbnailCacheEntry(resp.bodyBytes, DateTime.now(), false);
      }
      _log.fine(
          'NanoDLP preview request returned ${resp.statusCode} for $debugLabel; returning empty bytes to let caller generate placeholder.');
      return _ThumbnailCacheEntry(Uint8List(0), DateTime.now(), true);
    } catch (e, st) {
      _log.warning('NanoDLP preview request error for $debugLabel', e, st);
      return _ThumbnailCacheEntry(Uint8List(0), DateTime.now(), true);
    } finally {
      client.close();
    }
  }

  /// Fetch a 2D layer PNG for a given plate and layer index. This will
  /// return a canonical large-sized PNG (800x480) by force-resizing the
  /// downloaded image. On error, a generated placeholder is returned.
  @override
  Future<Uint8List> getPlateLayerImage(int plateId, int layer) async {
    final baseNoSlash = apiUrl.replaceAll(RegExp(r'/+$'), '');
    final uri = Uri.parse('$baseNoSlash/static/plates/$plateId/$layer.png');
    final entry = await _downloadThumbnail(uri, 'plate $plateId layer $layer');
    if (entry.bytes.isNotEmpty) {
      try {
        // Resize on a background isolate to avoid blocking the UI thread.
        try {
          return await compute(resizeLayer2DCompute, entry.bytes);
        } catch (_) {
          // If compute fails (e.g., in test environment), fall back to
          // synchronous resize.
          return NanoDlpThumbnailGenerator.resizeLayer2D(entry.bytes);
        }
      } catch (_) {
        // fall through to placeholder
      }
    }
    return NanoDlpThumbnailGenerator.generatePlaceholder(
        NanoDlpThumbnailGenerator.largeWidth,
        NanoDlpThumbnailGenerator.largeHeight);
  }

  Future<List<NanoFile>> _fetchPlates({bool forceRefresh = false}) {
    if (!forceRefresh) {
      final cached = _platesCacheData;
      final cachedTime = _platesCacheTime;
      if (cached != null &&
          cachedTime != null &&
          DateTime.now().difference(cachedTime) < _platesCacheTtl) {
        return Future.value(cached);
      }
      final inflight = _platesCacheFuture;
      if (inflight != null) {
        return inflight;
      }
    } else {
      _platesCacheData = null;
      _platesCacheTime = null;
    }

    final future = _loadPlatesFromNetwork();
    _platesCacheFuture = future;
    return future.then((plates) {
      if (identical(_platesCacheFuture, future)) {
        _platesCacheFuture = null;
        _platesCacheData = plates;
        _platesCacheTime = DateTime.now();
      }
      return plates;
    }).catchError((error, stack) {
      if (identical(_platesCacheFuture, future)) {
        _platesCacheFuture = null;
      }
      throw error;
    });
  }

  Future<List<NanoFile>> _loadPlatesFromNetwork() async {
    final baseNoSlash = apiUrl.replaceAll(RegExp(r'/+$'), '');
    final uri = Uri.parse('$baseNoSlash/plates/list/json');
    // _log.fine('Requesting NanoDLP plates list (no query params): $uri'); // commented out to reduce noise

    final client = _createClient();
    try {
      http.Response resp;
      try {
        resp = await client.get(uri);
      } catch (e, st) {
        _log.warning('NanoDLP plates list request failed', e, st);
        return const <NanoFile>[];
      }
      if (resp.statusCode != 200) {
        _log.warning(
            'NanoDLP plates list call failed: ${resp.statusCode} ${resp.body}');
        return const <NanoFile>[];
      }

      dynamic decoded;
      try {
        decoded = json.decode(resp.body);
      } catch (e) {
        _log.warning('Failed to decode plates/list/json response', e);
        return const <NanoFile>[];
      }

      final rawEntries = _extractPlateEntries(decoded);
      final plates = <NanoFile>[];
      for (final entry in rawEntries) {
        if (entry == null) continue;
        if (entry is Map<String, dynamic>) {
          try {
            plates.add(NanoFile.fromJson(entry));
          } catch (e, st) {
            _log.warning('Failed to parse NanoDLP plate entry', e, st);
          }
          continue;
        }
        if (entry is Map) {
          try {
            plates.add(NanoFile.fromJson(Map<String, dynamic>.from(entry)));
          } catch (e, st) {
            _log.warning(
                'Failed to parse NanoDLP plate entry (Map cast)', e, st);
          }
        }
      }
      return plates;
    } finally {
      client.close();
    }
  }

  List<dynamic> _extractPlateEntries(dynamic decoded) {
    if (decoded is List) return decoded;
    if (decoded is Map) {
      for (final key in ['plates', 'files', 'data']) {
        final value = decoded[key];
        if (value is List) return value;
      }
      final values = decoded.values.whereType<Map>().toList();
      if (values.isNotEmpty) return values;
      return [decoded];
    }
    _log.fine(
        'plates/list/json returned unexpected type: ${decoded.runtimeType}');
    return const [];
  }

  Future<NanoFile?> _findPlateForPath(String filePath) async {
    final normalized = filePath.replaceAll(RegExp(r'^/+'), '');
    final plates = await _fetchPlates();
    for (final plate in plates) {
      final platePath = plate.resolvedPath;
      final plateName = plate.name ?? '';
      if (_matchesPath(platePath, filePath) ||
          _matchesPath(platePath, normalized) ||
          _matchesPath('/$platePath', filePath) ||
          (plateName.isNotEmpty &&
              (_matchesPath(plateName, filePath) ||
                  _matchesPath(plateName, normalized)))) {
        return plate;
      }
    }
    return null;
  }

  (int, int) _thumbnailDimensions(String size) {
    switch (size) {
      case 'Large':
        return (800, 480);
      case 'Small':
      default:
        return (400, 400);
    }
  }

  @override
  Future tareForceSensor() async {
    try {
      manualCommand('[[PressureWrite 1]]');
    } catch (e, st) {
      _log.warning('NanoDLP tareForceSensor error', e, st);
      rethrow;
    }
  }
}

class _TimeoutHttpClient extends http.BaseClient {
  _TimeoutHttpClient(this._inner, this._timeout, this._log, this._label);

  final http.Client _inner;
  final Duration _timeout;
  // ignore: unused_field
  final Logger _log;
  final String _label;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    final future = _inner.send(request);
    return future.timeout(_timeout, onTimeout: () {
      final msg =
          '$_label ${request.method} ${request.url} timed out after ${_timeout.inSeconds}s';
      // Intentionally do not log per-request timeouts here. The higher-level
      // StatusProvider already reports backend connectivity issues and
      // repeated per-request timeout warnings spam the logs during an outage.
      throw TimeoutException(msg);
    });
  }

  @override
  void close() {
    _inner.close();
  }
}

class _ThumbnailCacheEntry {
  _ThumbnailCacheEntry(this.bytes, this.timestamp, this.placeholder);

  final Uint8List bytes;
  final DateTime timestamp;
  final bool placeholder;
}

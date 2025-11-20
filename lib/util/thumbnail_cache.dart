/*
* Orion - Thumbnail Cache
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
import 'dart:collection';
import 'dart:typed_data';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:logging/logging.dart';
import 'package:orion/util/orion_api_filesystem/orion_api_file.dart';
import 'package:orion/util/sl1_thumbnail.dart';
import 'package:orion/util/orion_config.dart';

class ThumbnailCache {
  ThumbnailCache._internal();

  static final ThumbnailCache instance = ThumbnailCache._internal();
  static const Duration _entryTtl = Duration(minutes: 10);

  final _log = Logger('ThumbnailCache');
  final LinkedHashMap<String, _CacheEntry> _cache = LinkedHashMap();
  final Map<String, Future<Uint8List?>> _inFlight = {};
  Directory? _diskCacheDir;
  Duration?
      _diskEntryTtl; // null = disabled, otherwise time-based expiry for disk entries
  bool _pruning = false;
  static const int _diskCacheMaxBytes =
      512 * 1024 * 1024; // 512 MiB rolling cache
  static const int _memoryCacheMaxBytes = 50 * 1024 * 1024; // 50 MiB
  int _memoryCacheBytes = 0;

  Future<Uint8List?> getThumbnail({
    required String location,
    required String subdirectory,
    required String fileName,
    required OrionApiFile file,
    String size = 'Small',
    bool forceRefresh = false,
  }) async {
    _pruneExpired();

    if (forceRefresh) {
      // Bypass memory/disk caches and fetch fresh bytes. Still dedupe in-flight
      // requests by key to avoid duplicate network work.
      final key = _cacheKey(location, file, size);
      final inFlight = _inFlight[key];
      if (inFlight != null) return inFlight;

      final future = ThumbnailUtil.extractThumbnailBytes(
        location,
        subdirectory,
        fileName,
        size: size,
      ).then<Uint8List?>((bytes) {
        _store(key, bytes);
        _inFlight.remove(key);
        return bytes;
      }).catchError((Object error, StackTrace stack) {
        _log.fine('Thumbnail fetch failed for ${file.path}', error, stack);
        _store(key, null);
        _inFlight.remove(key);
        return null;
      });

      _inFlight[key] = future;
      return future;
    }

    // Try to find any cached entry for the same path+size regardless of
    // lastModified. This avoids cache misses when the provider recreates
    // OrionApiFile instances with differing lastModified values while the
    // file itself hasn't changed on disk. We'll return the cached bytes
    // immediately (if not expired) and schedule a background refresh if
    // the reported lastModified differs.
    final prefix = '$location|${file.path}|';
    String? foundKey;
    for (final k in _cache.keys) {
      if (k.startsWith(prefix) && k.endsWith('|$size')) {
        foundKey = k;
        break;
      }
    }
    if (foundKey != null) {
      final existing = _cache.remove(foundKey);
      if (existing != null) {
        if (!_isExpired(existing.timestamp)) {
          // refresh LRU order by reinserting at tail
          _cache[foundKey] = existing;

          // If the cached entry's lastModified differs from the current
          // file.lastModified, schedule a background refresh so we update
          // the cache without delaying the UI.
          try {
            final parts = foundKey.split('|');
            int existingLm = 0;
            if (parts.length >= 3) {
              existingLm = int.tryParse(parts[2]) ?? 0;
            }
            final currentLm = file.lastModified ?? 0;
            if (currentLm != 0 && existingLm != currentLm) {
              final newKey = _cacheKey(location, file, size);
              if (!_inFlight.containsKey(newKey)) {
                // start but don't await
                _inFlight[newKey] = ThumbnailUtil.extractThumbnailBytes(
                  location,
                  subdirectory,
                  fileName,
                  size: size,
                ).then<Uint8List?>((bytes) {
                  _store(newKey, bytes);
                  _inFlight.remove(newKey);
                  return bytes;
                }).catchError((_, __) {
                  _inFlight.remove(newKey);
                  return null;
                });
              }
            }
          } catch (_) {
            // ignore parsing errors and continue returning cached bytes
          }

          // Intentionally suppress memory-load debug logs to keep runtime logs concise.

          return Future.value(existing.bytes);
        }
        _inFlight.remove(foundKey);
      }
    }

    // If nothing found in memory, try disk cache before fetching.
    try {
      final diskBytes = await _readFromDiskIfFresh(location, file, size);
      if (diskBytes != null) {
        // store in memory LRU and return
        final key = _cacheKey(location, file, size);
        _store(key, diskBytes);
        return Future.value(diskBytes);
      }
    } catch (_) {
      // ignore disk errors and continue to fetch
    }

    final key = _cacheKey(location, file, size);
    final inFlight = _inFlight[key];
    if (inFlight != null) return inFlight;

    _evictAlternateVersions(location, file.path, keepKey: key);

    final future = ThumbnailUtil.extractThumbnailBytes(
      location,
      subdirectory,
      fileName,
      size: size,
    ).then<Uint8List?>((bytes) {
      _store(key, bytes);
      _inFlight.remove(key);
      return bytes;
    }).catchError((Object error, StackTrace stack) {
      _log.fine('Thumbnail fetch failed for ${file.path}', error, stack);
      _store(key, null);
      _inFlight.remove(key);
      return null;
    });

    _inFlight[key] = future;
    return future;
  }

  /// Expose the resolved disk cache directory path for diagnostics.
  Future<String> getDiskCacheDirPath() async {
    final dir = await _ensureDiskCacheDir();
    return dir.path;
  }

  void clear() {
    _cache.clear();
    _inFlight.clear();
  }

  void clearLocation(String location) {
    final prefix = '$location|';
    final removeKeys = _cache.keys
        .where((key) => key.startsWith(prefix))
        .toList(growable: false);
    for (final key in removeKeys) {
      _cache.remove(key);
      _inFlight.remove(key);
    }
    // Also remove any disk cache files for this location asynchronously.
    scheduleMicrotask(() async {
      try {
        final dir = await _ensureDiskCacheDir();
        final files = dir.listSync().whereType<File>();
        for (final f in files) {
          final decoded = Uri.decodeComponent(p.basename(f.path));
          if (decoded.startsWith(prefix)) {
            try {
              await f.delete();
            } catch (_) {
              // ignore individual delete failures
            }
          }
        }
      } catch (_) {
        // ignore disk errors
      }
    });
  }

  /// Delete all cached files on disk. This is best-effort and will not
  /// throw on failure; it may be expensive so callers should prefer to run
  /// this asynchronously (it already returns a Future).
  Future<void> clearDisk() async {
    try {
      final dir = await _ensureDiskCacheDir();
      final files = dir.listSync().whereType<File>().toList(growable: false);
      for (final f in files) {
        try {
          await f.delete();
        } catch (_) {
          // ignore deletion errors
        }
      }
    } catch (e, st) {
      _log.fine('Failed to clear disk thumbnail cache: $e', e, st);
    }
  }

  /// Clear both in-memory and on-disk caches. Prefer calling this
  /// from an async context so disk work can be awaited.
  Future<void> clearAll() async {
    clear();
    await clearDisk();
  }

  String _cacheKey(String location, OrionApiFile file, String size) {
    final lastModified = file.lastModified ?? 0;
    return '$location|${file.path}|$lastModified|$size';
  }

  void _store(String key, Uint8List? bytes) {
    // If replacing an existing entry, adjust tracked memory size.
    final prev = _cache.remove(key);
    if (prev?.bytes != null) {
      _memoryCacheBytes -= prev!.bytes!.length;
    }
    _cache[key] = _CacheEntry(bytes, DateTime.now());
    if (bytes != null) {
      _memoryCacheBytes += bytes.length;
    }

    // Evict least-recently-used entries until under memory limit.
    while (_memoryCacheBytes > _memoryCacheMaxBytes && _cache.isNotEmpty) {
      final oldestKey = _cache.keys.first;
      final oldest = _cache.remove(oldestKey);
      if (oldest?.bytes != null) {
        _memoryCacheBytes -= oldest!.bytes!.length;
      }
      _inFlight.remove(oldestKey);
      // If all entries have null bytes, break to avoid infinite loop.
      if (_cache.values.every((e) => e.bytes == null)) break;
    }
    // Persist to disk asynchronously (best-effort).
    if (bytes != null) {
      _writeToDiskSafe(key, bytes);
    }
  }

  void _pruneExpired() {
    if (_cache.isEmpty) return;
    final now = DateTime.now();
    final expired = _cache.entries
        .where((entry) => now.difference(entry.value.timestamp) > _entryTtl)
        .map((entry) => entry.key)
        .toList(growable: false);
    for (final key in expired) {
      _cache.remove(key);
      _inFlight.remove(key);
    }
  }

  Future<Directory> _ensureDiskCacheDir() async {
    if (_diskCacheDir != null) return _diskCacheDir!;
    try {
      // Prefer an app-specific persistent directory when available. This is
      // more robust than relying on environment variables (HOME/XDG) which
      // may not be set in some runtime environments and can cause the cache
      // to be created under a transient tmp directory that doesn't survive
      // reboots.
      Directory dir;
      try {
        final appSupport = await getApplicationSupportDirectory();
        dir = Directory(p.join(appSupport.path, 'orion_thumbnail_cache'));
      } catch (_) {
        // Fall back to platform-specific heuristics if application support
        // directory is not available for some reason.
        if (Platform.isLinux) {
          // Prefer a persistent data directory: XDG_DATA_HOME or
          // ~/.local/share. Using a data directory avoids placing the
          // cache in /tmp (which may be cleared on reboot) and keeps cache
          // files available across restarts.
          final dataHome = Platform.environment['XDG_DATA_HOME'] ??
              (Platform.environment['HOME'] != null
                  ? p.join(Platform.environment['HOME']!, '.local', 'share')
                  : null);
          if (dataHome != null && dataHome.isNotEmpty) {
            dir = Directory(p.join(dataHome, 'orion', 'thumbnail_cache'));
          } else {
            // Fall back to XDG_CACHE_HOME or ~/.cache. Cache directories are
            // persistent across reboots on most desktop systems, but may be
            // pruned by system cleaners; prefer dataHome when available.
            final xdg = Platform.environment['XDG_CACHE_HOME'] ??
                (Platform.environment['HOME'] != null
                    ? p.join(Platform.environment['HOME']!, '.cache')
                    : null);
            if (xdg != null && xdg.isNotEmpty) {
              dir = Directory(p.join(xdg, 'orion_thumbnail_cache'));
            } else {
              final tmp = await getTemporaryDirectory();
              dir = Directory(p.join(tmp.path, 'orion_thumbnail_cache'));
            }
          }
        } else if (Platform.isMacOS) {
          final home = Platform.environment['HOME'] ?? '.';
          dir = Directory(
              p.join(home, 'Library', 'Caches', 'orion_thumbnail_cache'));
        } else if (Platform.isWindows) {
          final local = Platform.environment['LOCALAPPDATA'] ??
              Platform.environment['USERPROFILE'] ??
              '.';
          dir = Directory(p.join(local, 'orion_thumbnail_cache'));
        } else {
          // Unknown platform: use temporary directory
          final tmp = await getTemporaryDirectory();
          dir = Directory(p.join(tmp.path, 'orion_thumbnail_cache'));
        }
      }

      if (!await dir.exists()) await dir.create(recursive: true);
      // Attempt to migrate any existing cache from legacy locations into
      // the chosen persistent directory. This helps when the app previously
      // wrote to XDG_CACHE_HOME or /tmp and the install was updated.
      try {
        if (Platform.isLinux) {
          final home = Platform.environment['HOME'];
          final legacyXdg = Platform.environment['XDG_CACHE_HOME'] ??
              (home != null ? p.join(home, '.cache') : null);
          final legacyTmp = (await getTemporaryDirectory()).path;
          final legacyCandidates = <String>[];
          if (legacyXdg != null && legacyXdg.isNotEmpty) {
            legacyCandidates.add(p.join(legacyXdg, 'orion_thumbnail_cache'));
          }
          legacyCandidates.add(p.join(legacyTmp, 'orion_thumbnail_cache'));

          for (final cand in legacyCandidates) {
            try {
              final oldDir = Directory(cand);
              if (await oldDir.exists()) {
                final files = oldDir.listSync().whereType<File>().toList();
                for (final f in files) {
                  try {
                    final dest = File(p.join(dir.path, p.basename(f.path)));
                    if (!await dest.exists()) {
                      await f.rename(dest.path);
                    } else {
                      // If destination exists, remove the older file to
                      // prefer existing cache.
                      try {
                        await f.delete();
                      } catch (_) {}
                    }
                  } catch (e) {
                    // ignore individual file migration errors
                  }
                }
                // Try to remove legacy directory if empty
                try {
                  if (oldDir.listSync().isEmpty) await oldDir.delete();
                } catch (_) {}
              }
            } catch (_) {
              // ignore candidate errors
            }
          }
        }
      } catch (_) {
        // ignore migration errors
      }
      _diskCacheDir = dir;
      // Suppress disk cache directory log to avoid noisy startup logs.
      // Read TTL from OrionConfig (category: 'cache', key: 'thumbnailDiskTtlDays')
      // If the config key is missing or empty, default to 7 days. If the
      // config value parses to 0 or a negative number, TTL is disabled.
      try {
        final cfg = OrionConfig();
        final ttlStr = cfg.getString('thumbnailDiskTtlDays', category: 'cache');
        if (ttlStr.isEmpty) {
          _diskEntryTtl = Duration(days: 7);
        } else {
          final days = int.tryParse(ttlStr);
          if (days == null) {
            _diskEntryTtl = Duration(days: 7);
          } else if (days <= 0) {
            _diskEntryTtl = null; // disabled
          } else {
            _diskEntryTtl = Duration(days: days);
          }
        }
        // TTL configuration read; suppressing output for cleanliness.
      } catch (e) {
        // Failed to read config; fall back to default silently.
        _diskEntryTtl = Duration(days: 7);
      }
      // Ensure disk size constraints on startup (best-effort).
      scheduleMicrotask(() => _enforceDiskCacheSizeLimit());
      return dir;
    } catch (e, st) {
      _log.warning(
          'Failed to ensure disk cache dir, falling back to system temp: $e',
          e,
          st);
      // fallback to system temp directory
      final dir = Directory.systemTemp;
      _diskCacheDir = dir;
      return dir;
    }
  }

  String _diskFileNameForKey(String key) {
    // Safe filename using URI encoding to avoid illegal chars.
    return Uri.encodeComponent(key);
  }

  Future<void> _writeToDiskSafe(String key, Uint8List bytes) async {
    try {
      final dir = await _ensureDiskCacheDir();
      final fname = _diskFileNameForKey(key);
      final file = File(p.join(dir.path, fname));
      // Write atomically by writing to a temp file and renaming.
      final tmpFile = File(p.join(dir.path, '\$$fname.tmp'));
      await tmpFile.writeAsBytes(bytes, flush: true);
      await tmpFile.rename(file.path);
      // Suppress successful disk write logs.
      // Enforce rolling disk cache size (best-effort, async).
      scheduleMicrotask(() => _enforceDiskCacheSizeLimit());
    } catch (e, st) {
      // Warn about write failures - keep stack visible to aid debugging.
      _log.warning('Failed to write thumbnail to disk for key $key: $e', e, st);
      // best-effort: ignore disk write failures
    }
  }

  Future<void> _enforceDiskCacheSizeLimit() async {
    if (_pruning) return;
    _pruning = true;
    try {
      final dir = await _ensureDiskCacheDir();
      final files = dir.listSync().whereType<File>().toList(growable: false);
      if (files.isEmpty) return;
      // Compute total size
      int total = 0;
      final entries = <File, DateTime>{};
      for (final f in files) {
        try {
          final stat = f.statSync();
          total += stat.size;
          entries[f] = stat.modified;
        } catch (_) {
          // ignore individual file stat errors
        }
      }
      if (total <= _diskCacheMaxBytes) return;

      // Sort by modification time ascending (oldest first) and delete until
      // we're under the limit.
      final sorted = entries.keys.toList()
        ..sort((a, b) => entries[a]!.compareTo(entries[b]!));
      for (final f in sorted) {
        if (total <= _diskCacheMaxBytes) break;
        try {
          final stat = f.statSync();
          total -= stat.size;
          f.deleteSync();
        } catch (_) {
          // ignore deletion errors and continue
        }
      }
    } catch (_) {
      // ignore enforcement errors
    } finally {
      _pruning = false;
    }
  }

  Future<Uint8List?> _readFromDiskIfFresh(
      String location, OrionApiFile file, String size) async {
    try {
      final keyPrefix = '$location|${file.path}|';
      // Attempt to find any matching disk entry for this path+size.
      final dir = await _ensureDiskCacheDir();
      final candidates = dir.listSync().whereType<File>();
      for (final f in candidates) {
        final decoded = Uri.decodeComponent(p.basename(f.path));
        if (decoded.startsWith(keyPrefix) && decoded.endsWith('|$size')) {
          try {
            // If TTL is enabled, check file age and treat as stale if older
            // than configured TTL. Stale files are scheduled for deletion
            // asynchronously and ignored for serving.
            if (_diskEntryTtl != null) {
              try {
                final mtime = f.lastModifiedSync();
                if (DateTime.now().difference(mtime) > _diskEntryTtl!) {
                  // schedule background deletion of the stale file
                  scheduleMicrotask(() async {
                    try {
                      await f.delete();
                    } catch (_) {
                      // ignore deletion errors
                    }
                  });
                  // skip this file and continue searching
                  continue;
                }
              } catch (_) {
                // If we cannot stat the file, skip it and continue
                continue;
              }
            }

            final bytes = await f.readAsBytes();
            return bytes;
          } catch (e, st) {
            _log.fine(
                'Failed to read thumbnail from disk ${f.path}: $e', e, st);
            // continue searching other candidates
            continue;
          }
        }
      }
    } catch (_) {
      // ignore disk read errors
    }
    return null;
  }

  bool _isExpired(DateTime timestamp) {
    return DateTime.now().difference(timestamp) > _entryTtl;
  }

  void _evictAlternateVersions(String location, String filePath,
      {required String keepKey}) {
    final prefix = '$location|$filePath|';
    final toRemove = _cache.keys
        .where((key) => key.startsWith(prefix) && key != keepKey)
        .toList(growable: false);
    for (final key in toRemove) {
      _cache.remove(key);
      _inFlight.remove(key);
    }
    final inflightRemove = _inFlight.keys
        .where((key) => key.startsWith(prefix) && key != keepKey)
        .toList(growable: false);
    for (final key in inflightRemove) {
      _inFlight.remove(key);
    }
  }

  // _dateFromCacheKey removed (unused)
}

class _CacheEntry {
  _CacheEntry(this.bytes, this.timestamp);
  final Uint8List? bytes;
  final DateTime timestamp;
}

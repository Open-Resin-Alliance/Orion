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
  bool _startupNeedsPrefetch = false;
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

    // If the disk cache was empty on startup, prefer fetching fresh bytes
    // for the first set of thumbnails so the UI can repopulate the cache
    // without waiting for user interaction to individually refresh items.
    if (_startupNeedsPrefetch) {
      forceRefresh = true;
    }

    if (forceRefresh) {
      // Bypass memory/disk caches and fetch fresh bytes. Still dedupe in-flight
      // requests by key to avoid duplicate network work.
      final key = _cacheKey(location, file, size);
      final inFlight = _inFlight[key];
      if (inFlight != null) return inFlight;

      final future = _extractBytesForFile(
        location: location,
        subdirectory: subdirectory,
        fileName: fileName,
        file: file,
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

    // First, try exact match with the current cache key (includes lastModified)
    // to avoid serving stale thumbnails when files are replaced with same path.
    final exactKey = _cacheKey(location, file, size);
    final exactMatch = _cache[exactKey];
    if (exactMatch != null) {
      if (!_isExpired(exactMatch.timestamp)) {
        // refresh LRU order by reinserting at tail
        _cache.remove(exactKey);
        _cache[exactKey] = exactMatch;
        return Future.value(exactMatch.bytes);
      } else {
        _cache.remove(exactKey);
        _inFlight.remove(exactKey);
      }
    }

    // Fallback: Try to find cached entries for same path+size with different
    // lastModified. This handles the case where the provider recreates
    // OrionApiFile instances with slightly different lastModified values
    // (e.g., millisecond precision differences) while the file content
    // hasn't actually changed. Only use this as a fallback if the exact
    // match above failed, and only if lastModified is zero or very small
    // (indicating the file's actual mtime might not be reliably available).
    if ((file.lastModified ?? 0) == 0) {
      final prefix = '$location|${file.path}|';
      String? fallbackKey;
      for (final k in _cache.keys) {
        if (k.startsWith(prefix) && k.endsWith('|$size')) {
          fallbackKey = k;
          break;
        }
      }
      if (fallbackKey != null) {
        final fallback = _cache[fallbackKey];
        if (fallback != null && !_isExpired(fallback.timestamp)) {
          _cache.remove(fallbackKey);
          _cache[fallbackKey] = fallback;
          return Future.value(fallback.bytes);
        }
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

    final future = _extractBytesForFile(
      location: location,
      subdirectory: subdirectory,
      fileName: fileName,
      file: file,
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

  Future<Uint8List> _extractBytesForFile({
    required String location,
    required String subdirectory,
    required String fileName,
    required OrionApiFile file,
    required String size,
  }) async {
    try {
      final lower = fileName.toLowerCase();
      if (lower.endsWith('.nanodlp')) {
        final localPath = file.path;
        if (localPath.isNotEmpty) {
          final f = File(localPath);
          if (await f.exists()) {
            _log.fine('Using local NanoDLP zip thumbnail: $localPath');
            return ThumbnailUtil.extractNanodlpThumbnailBytesFromFile(
              localPath,
              size: size,
            );
          }
        }
      }
    } catch (_) {
      // fall back to API-based thumbnails
    }

    return ThumbnailUtil.extractThumbnailBytes(
      location,
      subdirectory,
      fileName,
      size: size,
    );
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

  /// Remove thumbnails for a specific file from memory and disk cache.
  /// Use this when a file is deleted to clean up its cached thumbnails.
  void removeFile(String location, String filePath) {
    // Remove all versions (different sizes, timestamps) of this file from cache
    final prefix = '$location|$filePath|';
    final removeKeys = _cache.keys
        .where((key) => key.startsWith(prefix))
        .toList(growable: false);
    for (final key in removeKeys) {
      final entry = _cache.remove(key);
      if (entry?.bytes != null) {
        _memoryCacheBytes -= entry!.bytes!.length;
      }
      _inFlight.remove(key);
    }
    // Also remove disk cache files for this file asynchronously
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

  void clearLocation(String location) {
    final prefix = '$location|';
    final removeKeys = _cache.keys
        .where((key) => key.startsWith(prefix))
        .toList(growable: false);
    for (final key in removeKeys) {
      final entry = _cache.remove(key);
      if (entry?.bytes != null) {
        _memoryCacheBytes -= entry!.bytes!.length;
      }
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

  /// Validate cached thumbnails against current file list and remove orphaned entries.
  /// Call this after refreshing file listings to clean up thumbnails for deleted files.
  void validateAndCleanup(String location, List<String> currentFilePaths) {
    final locationPrefix = '$location|';
    final currentPathsSet = currentFilePaths.toSet();
    final removeKeys = <String>[];
    
    for (final key in _cache.keys) {
      if (!key.startsWith(locationPrefix)) continue;
      
      // Parse: location|path|timestamp|size
      final parts = key.split('|');
      if (parts.length < 2) continue;
      
      final cachedPath = parts[1];
      if (!currentPathsSet.contains(cachedPath)) {
        removeKeys.add(key);
      }
    }
    
    if (removeKeys.isNotEmpty) {
      _log.fine('Removing ${removeKeys.length} cached thumbnails for deleted files');
      for (final key in removeKeys) {
        final entry = _cache.remove(key);
        if (entry?.bytes != null) {
          _memoryCacheBytes -= entry!.bytes!.length;
        }
        _inFlight.remove(key);
      }
      
      // Clean up disk cache asynchronously
      scheduleMicrotask(() async {
        try {
          final dir = await _ensureDiskCacheDir();
          final files = dir.listSync().whereType<File>();
          for (final f in files) {
            final decoded = Uri.decodeComponent(p.basename(f.path));
            if (!decoded.startsWith(locationPrefix)) continue;
            
            final parts = decoded.split('|');
            if (parts.length >= 2) {
              final cachedPath = parts[1];
              if (!currentPathsSet.contains(cachedPath)) {
                try {
                  await f.delete();
                } catch (_) {}
              }
            }
          }
        } catch (_) {}
      });
    }
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
      // If we were in a startup-prefetch state, consider the cache
      // repopulated after successfully storing at least one thumbnail.
      if (_startupNeedsPrefetch) _startupNeedsPrefetch = false;
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
      final dir = await _findWritableCacheDir();
      await _migrateLegacyCaches(dir);
      _updateStartupPrefetchState(dir);
      _diskCacheDir = dir;
      _loadDiskEntryTtl();
      scheduleMicrotask(() => _enforceDiskCacheSizeLimit());
      return dir;
    } catch (e, st) {
      _log.warning(
          'Failed to ensure disk cache dir, falling back to system temp: $e',
          e,
          st);
      final dir = Directory.systemTemp;
      _diskCacheDir = dir;
      return dir;
    }
  }

  Future<Directory> _findWritableCacheDir() async {
    final resolvers = <Future<Directory?> Function()>[
      _tryConfigAdjacentDir,
      _tryAppSupportDir,
      _platformFallbackDir,
    ];

    for (final resolver in resolvers) {
      final candidate = await resolver();
      if (candidate == null) continue;
      try {
        if (!await candidate.exists()) {
          await candidate.create(recursive: true);
        }
        return candidate;
      } catch (_) {
        // If we cannot materialize this directory, continue to the next resolver.
      }
    }

    throw StateError('Unable to create a writable thumbnail cache directory');
  }

  Future<Directory?> _tryConfigAdjacentDir() async {
    if (!Platform.isLinux) return null;
    try {
      final cfg = OrionConfig();
      final cfgPath = cfg.getConfigPath();
      if (cfgPath.isEmpty) return null;
      return Directory(p.join(cfgPath, 'thumbnail_cache'));
    } catch (_) {
      return null;
    }
  }

  Future<Directory?> _tryAppSupportDir() async {
    try {
      final appSupport = await getApplicationSupportDirectory();
      return Directory(p.join(appSupport.path, 'orion_thumbnail_cache'));
    } catch (_) {
      return null;
    }
  }

  Future<Directory> _platformFallbackDir() async {
    if (Platform.isLinux) {
      final dataHome = Platform.environment['XDG_DATA_HOME'] ??
          (Platform.environment['HOME'] != null
              ? p.join(Platform.environment['HOME']!, '.local', 'share')
              : null);
      if (dataHome?.isNotEmpty == true) {
        return Directory(p.join(dataHome!, 'orion', 'thumbnail_cache'));
      }
      final xdg = Platform.environment['XDG_CACHE_HOME'] ??
          (Platform.environment['HOME'] != null
              ? p.join(Platform.environment['HOME']!, '.cache')
              : null);
      if (xdg?.isNotEmpty == true) {
        return Directory(p.join(xdg!, 'orion_thumbnail_cache'));
      }
      final tmp = await getTemporaryDirectory();
      return Directory(p.join(tmp.path, 'orion_thumbnail_cache'));
    } else if (Platform.isMacOS) {
      final home = Platform.environment['HOME'] ?? '.';
      return Directory(
          p.join(home, 'Library', 'Caches', 'orion_thumbnail_cache'));
    } else if (Platform.isWindows) {
      final local = Platform.environment['LOCALAPPDATA'] ??
          Platform.environment['USERPROFILE'] ??
          '.';
      return Directory(p.join(local, 'orion_thumbnail_cache'));
    }
    final tmp = await getTemporaryDirectory();
    return Directory(p.join(tmp.path, 'orion_thumbnail_cache'));
  }

  Future<void> _migrateLegacyCaches(Directory dir) async {
    if (!Platform.isLinux) return;
    final legacyCandidates = <String>[];
    final home = Platform.environment['HOME'];
    final legacyXdg = Platform.environment['XDG_CACHE_HOME'] ??
        (home != null ? p.join(home, '.cache') : null);
    if (legacyXdg?.isNotEmpty == true) {
      legacyCandidates.add(p.join(legacyXdg!, 'orion_thumbnail_cache'));
    }
    final legacyTmp = (await getTemporaryDirectory()).path;
    legacyCandidates.add(p.join(legacyTmp, 'orion_thumbnail_cache'));

    for (final cand in legacyCandidates) {
      try {
        final oldDir = Directory(cand);
        if (!await oldDir.exists()) continue;
        final files = oldDir.listSync().whereType<File>().toList();
        for (final f in files) {
          try {
            final dest = File(p.join(dir.path, p.basename(f.path)));
            if (!await dest.exists()) {
              await f.rename(dest.path);
            } else {
              try {
                await f.delete();
              } catch (_) {}
            }
          } catch (_) {
            // ignore individual file migration errors
          }
        }
        try {
          if (oldDir.listSync().isEmpty) await oldDir.delete();
        } catch (_) {}
      } catch (_) {
        // ignore candidate errors
      }
    }
  }

  void _updateStartupPrefetchState(Directory dir) {
    try {
      final files = dir.listSync().whereType<File>();
      if (files.isEmpty) {
        _startupNeedsPrefetch = true;
      }
    } catch (_) {
      // ignore listing errors
    }
  }

  void _loadDiskEntryTtl() {
    try {
      final cfg = OrionConfig();
      final ttlStr = cfg.getString('thumbnailDiskTtlDays', category: 'cache');
      _diskEntryTtl = _parseTtl(ttlStr);
    } catch (_) {
      _diskEntryTtl = Duration(days: 7);
    }
  }

  Duration? _parseTtl(String value) {
    if (value.isEmpty) return Duration(days: 7);
    final days = int.tryParse(value);
    if (days == null) return Duration(days: 7);
    if (days <= 0) return null;
    return Duration(days: days);
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
      // First, try exact key match (includes lastModified) to avoid
      // serving stale disk cache entries when files are replaced.
      final exactKey = _cacheKey(location, file, size);
      final dir = await _ensureDiskCacheDir();
      final exactKeyEncoded = Uri.encodeComponent(exactKey);
      final exactFile = File(p.join(dir.path, exactKeyEncoded));
      
      if (await exactFile.exists()) {
        try {
          if (_diskEntryTtl != null) {
            final mtime = exactFile.lastModifiedSync();
            if (DateTime.now().difference(mtime) > _diskEntryTtl!) {
              // stale file, delete and continue
              scheduleMicrotask(() async {
                try {
                  await exactFile.delete();
                } catch (_) {}
              });
            } else {
              // Fresh exact match found
              return await exactFile.readAsBytes();
            }
          } else {
            // No TTL, return the exact match
            return await exactFile.readAsBytes();
          }
        } catch (e, st) {
          _log.fine('Failed to read exact thumbnail from disk: $e', e, st);
        }
      }

      // Fallback: Search for entries with same path+size but different lastModified.
      // This handles cases where file lastModified isn't reliably available (zero value).
      // Only use this if current file's lastModified is zero/unavailable.
      if ((file.lastModified ?? 0) == 0) {
        final keyPrefix = '$location|${file.path}|';
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

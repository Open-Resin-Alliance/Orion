/*
* Orion - Grid Files Screen
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

// ignore_for_file: unnecessary_type_check, use_build_context_synchronously
// import 'package:orion/files/search_file_screen.dart';

import 'dart:async';
import 'dart:io';
import 'dart:collection';
import 'dart:math' as math;

import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_i18n/flutter_i18n.dart';
import 'package:image/image.dart' as img;
import 'package:logging/logging.dart';
import 'package:orion/util/widgets/system_status_widget.dart';
import 'package:orion/widgets/orion_app_bar.dart';
import 'package:path/path.dart' as path;
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';

import 'package:orion/backend_service/backend_service.dart';
import 'package:orion/backend_service/providers/files_provider.dart';
import 'package:orion/backend_service/providers/local_files_provider.dart';

import 'package:orion/files/details_screen.dart';
import 'package:orion/files/import_screen.dart';
import 'package:orion/glasser/glasser.dart';
import 'package:orion/util/error_handling/error_dialog.dart';
import 'package:orion/util/orion_api_filesystem/orion_api_directory.dart';
import 'package:orion/util/orion_api_filesystem/orion_api_file.dart';
import 'package:orion/util/orion_api_filesystem/orion_api_item.dart';
import 'package:orion/util/orion_config.dart';
import 'package:orion/util/orion_spacing.dart';
import 'package:orion/util/providers/theme_provider.dart';
import 'package:orion/util/thumbnail_cache.dart';
import 'package:orion/util/stl_thumbnail.dart';

ScrollController _scrollController = ScrollController();

class _QueuedThumb {
  _QueuedThumb({
    required this.key,
    required this.task,
    required this.completer,
  });

  final String key;
  final FutureOr<void> Function() task;
  final Completer<Uint8List?> completer;
}

class GridFilesScreen extends StatefulWidget {
  const GridFilesScreen({super.key});
  @override
  GridFilesScreenState createState() => GridFilesScreenState();
}

class GridFilesScreenState extends State<GridFilesScreen> {
  final _logger = Logger('GridFiles');
  // ApiService usage moved into FilesProvider; remove unused field

  late String _directory = '';
  late String _subdirectory = '';
  late String _defaultDirectory = '';

  // provider-driven: items are read from FilesProvider.items
  // provider-driven: use FilesProvider.items instead

  // `location` is now provided by `FilesProvider.location`.
  //bool _sortByAlpha = true;
  //bool _sortAscending = true;
  bool _isUSB = false;
  bool _usbAvailable = false;
  bool _apiErrorState = false;
  bool _isLoading = true; // true until initial prewarm completes
  bool _isNavigating = false;
  bool _isNanoDlp = false;
  bool _useLocalFilesProvider = false; // Use local filesystem instead of API
  bool _selectionMode = false;
  final Set<String> _selectedFileKeys = <String>{};
  bool _isBulkDeleting = false;
  int _bulkDeleteTotal = 0;
  int _bulkDeleteCompleted = 0;

  // Thumbnail fetch concurrency control to avoid starting too many
  // simultaneous ThumbnailCache requests which can lag the app on low-end
  // devices. We queue requests and allow only [_maxConcurrentThumbnails]
  // active at a time. ThumbnailCache itself dedupes identical keys so this
  // is just a client-side throttle.
  final int _maxConcurrentThumbnails = 2;
  int _activeThumbnailFetches = 0;
  final Queue<_QueuedThumb> _thumbQueue = Queue<_QueuedThumb>();
  final Map<String, Future<Uint8List?>> _queuedInFlight = {};
  static final LinkedHashMap<String, Future<Uint8List?>>
      _thumbnailFutureCacheGlobal = LinkedHashMap<String, Future<Uint8List?>>();
  static final LinkedHashMap<String, Uint8List?>
      _processedThumbnailCacheGlobal = LinkedHashMap<String, Uint8List?>();
  static const int _maxSharedThumbnailEntries = 1200;

  Map<String, Future<Uint8List?>> get _thumbnailFutureCache =>
      _thumbnailFutureCacheGlobal;
  Map<String, Uint8List?> get _processedThumbnailCache =>
      _processedThumbnailCacheGlobal;

  @override
  void initState() {
    super.initState();
    final OrionConfig config = OrionConfig();
    _isUSB = config.getFlag('useUsbByDefault');
    _isNanoDlp =
        config.getString('backend', category: 'advanced').toLowerCase() ==
            'nanodlp';

    // Check if we CAN use LocalFilesProvider for USB on this machine
    _useLocalFilesProvider = _canUseLocalFilesProvider();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (_defaultDirectory.isEmpty) {
        // First, always check LocalFilesProvider availability if it's enabled
        if (_useLocalFilesProvider) {
          final localProvider =
              Provider.of<LocalFilesProvider>(context, listen: false);
          final localUsbAvail = await localProvider.usbAvailable();
          setState(() {
            _usbAvailable = localUsbAvail;
          });
        }

        // Load from appropriate provider based on _isUSB and _useLocalFilesProvider
        if (_isUSB && _useLocalFilesProvider) {
          // Load from LocalFilesProvider (USB)
          final provider =
              Provider.of<LocalFilesProvider>(context, listen: false);
          await provider.loadItems('Usb', '');
          await _syncAfterLoad(provider, 'Usb');
          if (provider.error != null && !_apiErrorState) {
            setState(() {
              _apiErrorState = true;
            });
            showErrorDialog(context, 'PINK-CARROT');
          }
          final items = provider.items;
          if (items.isNotEmpty) {
            _defaultDirectory = provider.baseDirectory;
            _directory = _defaultDirectory;
          } else {
            // Fall back to the base directory from provider
            _defaultDirectory = provider.baseDirectory;
            _directory = _defaultDirectory;
          }
          await _prewarmThumbnailCache(provider, 'Usb');
        } else {
          // Load from FilesProvider (API)
          final provider = Provider.of<FilesProvider>(context, listen: false);
          await provider.loadItems(_isUSB ? 'Usb' : 'Local', '');
          await _syncAfterLoad(provider, _isUSB ? 'Usb' : 'Local');
          if (provider.error != null && !_apiErrorState) {
            setState(() {
              _apiErrorState = true;
            });
            showErrorDialog(context, 'PINK-CARROT');
          }
          final items = provider.items;
          if (items.isNotEmpty) {
            _defaultDirectory = path.dirname(items.first.path);
            _directory = _defaultDirectory;
          } else {
            // Fall back to home directory expanded
            final homeDir = Platform.environment['HOME'] ??
                Platform.environment['USERPROFILE'] ??
                '/root';
            _defaultDirectory = homeDir;
            _directory = _defaultDirectory;
          }
          await _prewarmThumbnailCache(provider, _isUSB ? 'Usb' : 'Local');
        }
        if (mounted) setState(() => _isLoading = false);
      }
    });
  }

  @override
  void dispose() {
    _thumbQueue.clear();
    _queuedInFlight.clear();
    super.dispose();
  }

  void _touchProcessedCache(String key, Uint8List bytes) {
    _processedThumbnailCache.remove(key);
    _processedThumbnailCache[key] = bytes;
    while (_processedThumbnailCache.length > _maxSharedThumbnailEntries) {
      _processedThumbnailCache.remove(_processedThumbnailCache.keys.first);
    }
  }

  void _touchFutureCache(String key, Future<Uint8List?> value) {
    _thumbnailFutureCache.remove(key);
    _thumbnailFutureCache[key] = value;
    while (_thumbnailFutureCache.length > _maxSharedThumbnailEntries) {
      _thumbnailFutureCache.remove(_thumbnailFutureCache.keys.first);
    }
  }

  // Build a cache key similar to ThumbnailCache._cacheKey so we can
  // de-duplicate requests at this layer too.
  String _thumbCacheKey(String location, OrionApiFile file, String size,
      {String? variant, Color? themeColor}) {
    final rawLastModified = file.lastModified ?? 0;
    final lastModified = rawLastModified > 999999999999
        ? (rawLastModified / 1000).round()
        : rawLastModified;
    // Match the format used by ThumbnailCache._cacheKey so we can
    // de-duplicate identical requests at this layer.
    final colorSuffix =
        themeColor != null ? '|${themeColor.toARGB32().toRadixString(16)}' : '';
    final base = '$location|${file.path}|$lastModified|$size$colorSuffix';
    if (variant == null || variant.isEmpty) return base;
    return '$base|$variant';
  }

  String? _resolveStlVariantForCache(String fileName, OrionApiFile file,
      {bool advanceCycle = false}) {
    final lower = fileName.toLowerCase();
    if (!lower.endsWith('.stl')) return null;
    final localPath = file.path;
    if (localPath.isEmpty) return null;
    try {
      final f = File(localPath);
      if (!f.existsSync()) return null;
    } catch (_) {
      return null;
    }
    return StlThumbnailUtil.chooseRenderMode(advanceCycle: advanceCycle);
  }

  Future<Uint8List?> _queuedGetThumbnail({
    required String location,
    required String subdirectory,
    required String fileName,
    required OrionApiFile file,
    String size = 'Small',
    String? stlVariant,
    Color? themeColor,
  }) {
    final key = _thumbCacheKey(
      location,
      file,
      size,
      variant: stlVariant,
      themeColor: themeColor,
    );

    final processedHit = _processedThumbnailCache[key];
    if (processedHit != null && processedHit.isNotEmpty) {
      _touchProcessedCache(key, processedHit);
      return SynchronousFuture<Uint8List?>(processedHit);
    }

    // If we already started or queued this request, return the existing future
    final existing = _queuedInFlight[key];
    if (existing != null) return existing;

    final completer = Completer<Uint8List?>();
    _queuedInFlight[key] = completer.future;

    final queued = _QueuedThumb(
      key: key,
      task: () async {
        try {
          final rawBytes = await ThumbnailCache.instance.getThumbnail(
            location: location,
            subdirectory: subdirectory,
            fileName: fileName,
            file: file,
            size: size,
            stlMode: stlVariant,
            themeColor: themeColor,
          );
          final bytes = await _postProcessGridThumbnail(
            rawBytes,
            size: size,
          );
          if (bytes != null && bytes.isNotEmpty) {
            _touchProcessedCache(key, bytes);
          }
          if (!completer.isCompleted) completer.complete(bytes);
        } catch (e, st) {
          if (!completer.isCompleted) completer.completeError(e, st);
        }
      },
      completer: completer,
    );

    // Enqueue and process
    _thumbQueue.add(queued);
    scheduleMicrotask(_processThumbnailQueue);

    return completer.future;
  }

  Future<Uint8List?> _getThumbnailFuture({
    required String location,
    required String subdirectory,
    required String fileName,
    required OrionApiFile file,
    String size = 'Small',
  }) {
    final stlVariant =
        _resolveStlVariantForCache(fileName, file, advanceCycle: false);
    final isStl = fileName.toLowerCase().endsWith('.stl');
    final themeColor = isStl ? Theme.of(context).colorScheme.primary : null;
    final key = _thumbCacheKey(
      location,
      file,
      size,
      variant: stlVariant,
      themeColor: themeColor,
    );
    final existing = _thumbnailFutureCache[key];
    if (existing != null) {
      _touchFutureCache(key, existing);
      return existing;
    }
    final created = _queuedGetThumbnail(
      location: location,
      subdirectory: subdirectory,
      fileName: fileName,
      file: file,
      size: size,
      stlVariant: stlVariant,
      themeColor: themeColor,
    );
    _touchFutureCache(key, created);
    return created;
  }

  Future<Uint8List?> _postProcessGridThumbnail(Uint8List? bytes,
      {required String size}) async {
    if (bytes == null || bytes.isEmpty) return bytes;
    // Keep large/detail thumbnails unchanged; only tighten framing on the
    // small grid tiles.
    if (size != 'Small') return bytes;
    try {
      final cropped = await compute(_trimTransparentPaddingEntry, bytes);
      if (cropped is Uint8List && cropped.isNotEmpty) {
        return cropped;
      }
    } catch (_) {
      // If crop fails, gracefully fall back to original bytes.
    }
    return bytes;
  }

  ImageProvider _gridThumbProvider(
      Uint8List bytes, BoxConstraints constraints) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final decodeW =
        math.max(64, math.min(512, (constraints.maxWidth * dpr).round()));
    final decodeH =
        math.max(64, math.min(512, (constraints.maxHeight * dpr).round()));
    return ResizeImage(
      MemoryImage(bytes),
      width: decodeW,
      height: decodeH,
      allowUpscaling: false,
    );
  }

  Widget _buildGridThumbnailImage(Uint8List bytes, {required double radius}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          child: Image(
            image: _gridThumbProvider(bytes, constraints),
            fit: BoxFit.cover,
            gaplessPlayback: true,
            filterQuality: FilterQuality.none,
          ),
        );
      },
    );
  }

  void _pruneThumbnailFutureCache(
      String location, Iterable<OrionApiFile> files) {
    final allowed = files.map((f) {
      final fileName = f.name;
      final stlVariant =
          _resolveStlVariantForCache(fileName, f, advanceCycle: false);
      final isStl = fileName.toLowerCase().endsWith('.stl');
      final themeColor = isStl ? Theme.of(context).colorScheme.primary : null;
      return _thumbCacheKey(
        location,
        f,
        'Small',
        variant: stlVariant,
        themeColor: themeColor,
      );
    }).toSet();
    _thumbnailFutureCache.removeWhere((key, _) => !allowed.contains(key));
    _processedThumbnailCache.removeWhere((key, _) => !allowed.contains(key));
  }

  /// Pre-populate [_processedThumbnailCacheGlobal] from disk for all files in
  /// the current view so the grid can show images without per-item spinners.
  /// STL files are skipped (they require runtime rendering, not a simple disk
  /// read).  Items already in the processed cache are also skipped.
  /// A 2-second wall-clock timeout prevents this from blocking the UI
  /// indefinitely when many files are uncached.
  Future<void> _prewarmThumbnailCache(dynamic provider, String location) async {
    final List<OrionApiItem> items = List<OrionApiItem>.from(provider.items);
    final files = items.whereType<OrionApiFile>().toList();
    if (files.isEmpty) return;

    const maxParallel = 4;
    final tasks = <Future<void> Function()>[];

    for (final file in files) {
      final fileName = path.basename(file.path);
      final lower = fileName.toLowerCase();
      // STL thumbnails are rendered at runtime, not stored as simple image data.
      if (lower.endsWith('.stl')) continue;

      final subdirectory = provider is LocalFilesProvider
          ? _resolveLocalSubdirectoryForFile(file, provider)
          : _resolveSubdirectoryForFile(file);

      final key = _thumbCacheKey(location, file, 'Small');
      if (_processedThumbnailCache.containsKey(key)) continue;

      tasks.add(() async {
        try {
          final rawBytes = await ThumbnailCache.instance.getThumbnail(
            location: location,
            subdirectory: subdirectory,
            fileName: fileName,
            file: file,
            size: 'Small',
          );
          final bytes =
              await _postProcessGridThumbnail(rawBytes, size: 'Small');
          if (bytes != null && bytes.isNotEmpty) {
            _touchProcessedCache(key, bytes);
          }
        } catch (_) {}
      });
    }

    if (tasks.isEmpty) return;

    // Run in batches to avoid saturating I/O; cap total time at 2 s.
    Future<void> runBatched() async {
      for (int i = 0; i < tasks.length; i += maxParallel) {
        final batch = tasks.skip(i).take(maxParallel).map((t) => t()).toList();
        await Future.wait(batch);
      }
    }

    await Future.any([
      runBatched(),
      Future.delayed(const Duration(seconds: 2)),
    ]);
  }

  void _processThumbnailQueue() {
    if (_activeThumbnailFetches >= _maxConcurrentThumbnails) return;
    if (_thumbQueue.isEmpty) return;

    final item = _thumbQueue.removeFirst();
    _activeThumbnailFetches++;

    // Run the task and ensure bookkeeping when complete.
    final Future<void> runFuture = Future<void>.sync(() => item.task());
    runFuture.whenComplete(() {
      _activeThumbnailFetches--;
      // remove from in-flight once finished
      _queuedInFlight.remove(item.key);
      // schedule next
      scheduleMicrotask(_processThumbnailQueue);
    });
  }

  /// Check if we CAN use LocalFilesProvider for USB on this machine
  /// (doesn't mean we're using it now, just if it's possible)
  bool _canUseLocalFilesProvider() {
    try {
      final cfg = OrionConfig();

      // On macOS (development), always available
      if (Platform.isMacOS) return true;

      // On Linux, only for NanoDLP machines without custom backend URL
      if (!_isNanoDlp) return false;

      // Check if there's a custom backend URL configured
      final customUrl = cfg.getString('customUrl', category: 'advanced');
      final useCustom = cfg.getFlag('useCustomUrl', category: 'advanced');
      final baseUrl = cfg.getString('nanodlp.base_url', category: 'advanced');

      // If any custom URL is set, LocalFilesProvider is not available
      if (baseUrl.isNotEmpty || (useCustom && customUrl.isNotEmpty)) {
        return false;
      }

      // No custom URL, so LocalFilesProvider can be used
      return true;
    } catch (_) {
      return false;
    }
  }

  // removed placeholder bytes field; using spinner + background decode now

  // Helper: after calling provider.loadItems(requestedLocation,..)
  // update _isUSB/_usbAvailable and notify user if we fell back from USB->Local.
  Future<void> _syncAfterLoad(
      dynamic provider, String requestedLocation) async {
    try {
      // If LocalFilesProvider is available, only check its USB availability
      // Don't use the FilesProvider (API) USB check when LocalFilesProvider can be used
      if (_useLocalFilesProvider) {
        final localProvider =
            Provider.of<LocalFilesProvider>(context, listen: false);
        final avail = await localProvider.usbAvailable();
        setState(() {
          _usbAvailable = avail;
        });
      } else {
        // Only use FilesProvider USB check if LocalFilesProvider is not available
        final avail = await provider.usbAvailable();
        setState(() {
          _usbAvailable = avail;
        });
      }
    } catch (_) {
      // ignore
    }

    final actual = provider.location.toLowerCase();
    final requested = requestedLocation.toLowerCase();

    if (requested == 'usb' && actual != 'usb') {
      // Auto-fallback happened
      setState(() {
        _isUSB = false;
        _usbAvailable = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        try {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(FlutterI18n.translate(
                    context, 'files.usbSwitchToInternal'))),
          );
        } catch (_) {
          // ignore
        }
      });
    } else {
      setState(() {
        _isUSB = actual == 'usb';
      });
    }
  }

  Future<void> refresh() async {
    //_sortAscending = !_sortAscending;
    //_toggleSortOrder();
    setState(() {
      _isLoading = true; // Indicate loading state
    });
    try {
      // Invalidate backend cache to ensure we fetch fresh data (e.g., after WebUI deletions)
      BackendService().invalidateFilesCache();

      if (_isUSB && _useLocalFilesProvider) {
        final provider =
            Provider.of<LocalFilesProvider>(context, listen: false);
        await provider.loadItems('Usb', _subdirectory);
        await _syncAfterLoad(provider, 'Usb');

        // Clean up cached thumbnails for deleted files
        final currentFiles = provider.items.whereType<OrionApiFile>().toList();
        final currentPaths = currentFiles.map((f) => f.path).toList();
        ThumbnailCache.instance.validateAndCleanup('Usb', currentPaths);
        _pruneThumbnailFutureCache('Usb', currentFiles);
        await _prewarmThumbnailCache(provider, 'Usb');
      } else {
        final provider = Provider.of<FilesProvider>(context, listen: false);
        await provider.loadItems(_isUSB ? 'Usb' : 'Local', _subdirectory);
        await _syncAfterLoad(provider, _isUSB ? 'Usb' : 'Local');

        // Clean up cached thumbnails for deleted files
        final currentFiles = provider.items.whereType<OrionApiFile>().toList();
        final currentPaths = currentFiles.map((f) => f.path).toList();
        ThumbnailCache.instance
            .validateAndCleanup(_isUSB ? 'Usb' : 'Local', currentPaths);
        _pruneThumbnailFutureCache(_isUSB ? 'Usb' : 'Local', currentFiles);
        await _prewarmThumbnailCache(provider, _isUSB ? 'Usb' : 'Local');
      }
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _apiErrorState = true;
        showErrorDialog(context, 'PINK-CARROT');
        _isLoading = false;
      });
    }
  }

  void _enterSelection(OrionApiFile file) {
    setState(() {
      _selectionMode = true;
      _selectedFileKeys.add(_selectionKey(file));
    });
  }

  void _toggleSelection(OrionApiFile file) {
    final key = _selectionKey(file);
    setState(() {
      if (_selectedFileKeys.contains(key)) {
        _selectedFileKeys.remove(key);
      } else {
        _selectedFileKeys.add(key);
      }
      if (_selectedFileKeys.isEmpty) {
        _selectionMode = false;
      }
    });
  }

  void _clearSelection() {
    setState(() {
      _selectionMode = false;
      _selectedFileKeys.clear();
    });
  }

  Future<void> _deleteSelectedFiles() async {
    if (_selectedFileKeys.isEmpty) return;
    if (_isBulkDeleting) return;

    if (_isUSB && _useLocalFilesProvider) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              FlutterI18n.translate(context, 'files.bulkDeleteNotSupported')),
        ),
      );
      return;
    }

    final count = _selectedFileKeys.length;
    final isSingle = count == 1;
    final dialogTitle = isSingle
        ? FlutterI18n.translate(context, 'files.deleteFile')
        : FlutterI18n.translate(context, 'files.deleteFile');
    final targetLabel = isSingle
        ? _resolveSelectionDisplayName(_selectedFileKeys.first)
        : FlutterI18n.translate(context, 'files.files',
            translationParams: {'0': count.toString()});

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => GlassAlertDialog(
        title: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(
              Icons.delete_forever_rounded,
              color: Theme.of(context).colorScheme.error,
              size: 32,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                dialogTitle,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text.rich(
              TextSpan(
                text:
                    FlutterI18n.translate(context, 'files.deleteConfirmPrefix'),
                children: [
                  TextSpan(
                    text: targetLabel,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  TextSpan(
                      text: FlutterI18n.translate(
                          context, 'files.deleteConfirmSuffix')),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Text(
              FlutterI18n.translate(context, 'files.deleteCannotUndo'),
              style: TextStyle(
                decoration: TextDecoration.underline,
              ),
            ),
          ],
        ),
        actions: [
          GlassButton(
            tint: GlassButtonTint.neutral,
            wantIcon: false,
            onPressed: () => Navigator.of(context).pop(false),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(0, 60),
            ),
            child: Text(FlutterI18n.translate(context, 'common.cancel')),
          ),
          GlassButton(
            tint: GlassButtonTint.negative,
            wantIcon: false,
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(0, 60),
            ),
            child: Text(FlutterI18n.translate(context, 'common.delete')),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _isBulkDeleting = true;
      _bulkDeleteTotal = _selectedFileKeys.length;
      _bulkDeleteCompleted = 0;
    });

    final provider = Provider.of<FilesProvider>(context, listen: false);
    final location = _isUSB ? 'Usb' : 'Local';
    final failures = <String>[];

    try {
      for (final key in _selectedFileKeys) {
        final filePath = _selectionKeyToPath(key);
        final ok = await provider.deleteFile(location, filePath);
        if (!ok) failures.add(filePath);
        if (mounted) {
          setState(() {
            _bulkDeleteCompleted += 1;
          });
        }
      }

      if (failures.isNotEmpty && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(FlutterI18n.translate(context, 'files.deleteFailed',
                translationParams: {'0': failures.length.toString()})),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isBulkDeleting = false;
          _bulkDeleteTotal = 0;
          _bulkDeleteCompleted = 0;
        });
      }
    }

    _clearSelection();
    await refresh();
  }

  String _selectionKey(OrionApiFile file) {
    final plateId = file.plateId;
    if (plateId != null) {
      return 'plate:$plateId';
    }
    final lastModified = file.lastModified ?? 0;
    final parentPath = file.parentPath;
    final name = file.name;
    final pathValue = file.path;
    if (pathValue.isNotEmpty && lastModified > 0) {
      return '$pathValue|$lastModified';
    }
    if (pathValue.isNotEmpty) {
      return '$pathValue|$name|$parentPath|$lastModified';
    }
    return '$parentPath|$name|$lastModified';
  }

  String _resolveSelectionDisplayName(String selectionKey) {
    final provider = Provider.of<FilesProvider>(context, listen: false);
    for (final item in provider.items) {
      if (item is OrionApiFile && _selectionKey(item) == selectionKey) {
        final itemName = item.name.trim();
        if (itemName.isNotEmpty) return itemName;
        final fromPath = path.basename(item.path).trim();
        if (fromPath.isNotEmpty) return fromPath;
      }
    }

    if (!selectionKey.startsWith('plate:')) {
      final fallback = path.basename(_selectionKeyToPath(selectionKey)).trim();
      if (fallback.isNotEmpty) return fallback;
    }

    return FlutterI18n.translate(context, 'files.thisFile');
  }

  String _selectionKeyToPath(String key) {
    if (key.startsWith('plate:')) {
      return key.substring('plate:'.length);
    }
    final parts = key.split('|');
    return parts.isNotEmpty ? parts.first : key;
  }

  Future<void> _switchToLocalAfterImport() async {
    setState(() {
      _isNavigating = true;
      _isUSB = false;
      _subdirectory = '';
    });

    try {
      final provider = Provider.of<FilesProvider>(context, listen: false);
      await provider.loadItems('Local', '');
      await _syncAfterLoad(provider, 'Local');

      final items = provider.items;
      if (items.isNotEmpty) {
        _defaultDirectory = path.dirname(items.first.path);
        _directory = _defaultDirectory;
      } else {
        final homeDir = Platform.environment['HOME'] ??
            Platform.environment['USERPROFILE'] ??
            '/root';
        _defaultDirectory = homeDir;
        _directory = _defaultDirectory;
      }
    } catch (e) {
      _logger.warning('Failed to switch to Local after import', e);
    } finally {
      if (mounted) {
        setState(() {
          _isNavigating = false;
        });
      }
    }
  }

  // _getItems replaced by FilesProvider.loadItems/listItemsAsOrionApiItems

  // TODO: Re-implement sorting
  /*void _toggleSortOrder() {
    setState(() {
      _items.sort((a, b) {
        if (a is OrionApiFile && b is OrionApiFile) {
          if (a.lastModified == null || b.lastModified == null) {
            return 0; // or any default value
          }
          return _sortAscending
              ? a.lastModified!.compareTo(b.lastModified!)
              : b.lastModified!.compareTo(a.lastModified!);
        }
        return 0;
      });
    });
  }*/

  String _getDisplayNameForDirectory(BuildContext context, String directory) {
    if (directory == _defaultDirectory && !_apiErrorState) {
      if (_isNanoDlp) return FlutterI18n.translate(context, 'files.printFiles');
      return _isUSB == false
          ? FlutterI18n.translate(context, 'print.titleInternal')
          : FlutterI18n.translate(context, 'print.titleUsb');
    }

    // If it's a subdirectory of the default directory, only show the relative path
    if (_apiErrorState)
      return FlutterI18n.translate(context, 'print.titleApiError');

    try {
      final relativePath = path.relative(directory, from: _defaultDirectory);
      if (relativePath == '.') {
        // If we're at the base, show the label
        return _isUSB == false
            ? FlutterI18n.translate(context, 'print.titleInternal')
            : FlutterI18n.translate(context, 'print.titleUsb');
      }
      return "$relativePath ${_isUSB ? FlutterI18n.translate(context, 'print.titleUsbError') : FlutterI18n.translate(context, 'print.titleInternalError')}";
    } catch (_) {
      // Fallback to full path if relative fails
      return "$directory ${_isUSB ? FlutterI18n.translate(context, 'print.titleUsbError') : FlutterI18n.translate(context, 'print.titleInternalError')}";
    }
  }

  String _resolveSubdirectoryForFile(OrionApiFile file) {
    if (_defaultDirectory.isEmpty) return _subdirectory;
    try {
      final parentDir = path.dirname(file.path);
      final relative = path.relative(parentDir, from: _defaultDirectory);
      if (relative == '.' || relative == _defaultDirectory) {
        return '';
      }
      return relative;
    } catch (_) {
      return _subdirectory;
    }
  }

  String _resolveLocalSubdirectoryForFile(
      OrionApiFile file, LocalFilesProvider provider) {
    try {
      final baseDir = provider.baseDirectory;
      final parentDir = path.dirname(file.path);
      final relative = path.relative(parentDir, from: baseDir);
      if (relative == '.' || relative == baseDir) {
        return '';
      }
      return relative;
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return GlassApp(
      child: Scaffold(
        appBar: OrionAppBar(
          title: Text(_getDisplayNameForDirectory(context, _directory)),
          toolbarHeight: Theme.of(context).appBarTheme.toolbarHeight,
          actions: <Widget>[SystemStatusWidget()],
        ),
        body: (_isUSB && _useLocalFilesProvider)
            ? _buildLocalFilesContent(context)
            : _buildApiFilesContent(context),
        floatingActionButton: _isLoading
            ? null
            : _selectedFileKeys.isNotEmpty
                ? _buildDeleteFab()
                : _buildRefreshFab(),
      ),
    );
  }

  /// Build content using LocalFilesProvider (filesystem-based)
  Widget _buildLocalFilesContent(BuildContext context) {
    final isGlassTheme = context.watch<ThemeProvider>().isGlassTheme;

    return Consumer<LocalFilesProvider>(
      builder: (context, provider, child) {
        // If the provider reports an error at any time, show the dialog once
        if (provider.error != null && !_apiErrorState) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            setState(() {
              _apiErrorState = true;
            });
            // Show the standard error dialog
            showErrorDialog(context, 'PINK-CARROT');
          });
        }
        final loading = provider.isLoading || _isLoading;
        final itemsList = provider.items;
        if (loading) {
          return const Center(child: CircularProgressIndicator());
        }
        // For LocalFilesProvider, always show parent card for directory navigation
        final crossCount =
            MediaQuery.of(context).orientation == Orientation.landscape ? 4 : 2;
        return Padding(
          padding: EdgeInsets.only(
            left: OrionSpacing.gridScreenHorizontal,
            right: OrionSpacing.gridScreenHorizontal,
            top: isGlassTheme ? 1.0 : 0.0,
            bottom: 10,
          ),
          child: GridView.builder(
            controller: _scrollController,
            cacheExtent: 300,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              childAspectRatio: 1.03,
              mainAxisSpacing: 5,
              crossAxisSpacing: 5,
              crossAxisCount: crossCount,
            ),
            itemCount: itemsList.length + 1,
            itemBuilder: (BuildContext context, int index) {
              if (index == 0) {
                return _buildParentCard(context);
              }
              final OrionApiItem item = itemsList[index - 1];
              return _buildLocalItemCard(context, item, provider);
            },
          ),
        );
      },
    );
  }

  /// Build content using FilesProvider (API-based)
  Widget _buildApiFilesContent(BuildContext context) {
    final isGlassTheme = context.watch<ThemeProvider>().isGlassTheme;

    return Consumer<FilesProvider>(
      builder: (context, provider, child) {
        // If the provider reports an error at any time, show the dialog once
        if (provider.error != null && !_apiErrorState) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            setState(() {
              _apiErrorState = true;
            });
            // Show the standard error dialog
            showErrorDialog(context, 'PINK-CARROT');
          });
        }
        final loading = provider.isLoading || _isLoading;
        final itemsList = provider.items;
        if (loading) {
          return const Center(child: CircularProgressIndicator());
        }
        // Show parent card only if we can toggle to USB (i.e., LocalFilesProvider is available)
        // For NanoDLP without LocalFilesProvider available, hide the card
        final hideParentCard = _isNanoDlp && !_useLocalFilesProvider;
        final crossCount =
            MediaQuery.of(context).orientation == Orientation.landscape ? 4 : 2;
        return Padding(
          padding: EdgeInsets.only(
            left: OrionSpacing.gridScreenHorizontal,
            right: OrionSpacing.gridScreenHorizontal,
            top: isGlassTheme ? 1.0 : 0.0,
            bottom: 10,
          ),
          child: GridView.builder(
            controller: _scrollController,
            cacheExtent: 300,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              childAspectRatio: 1.03,
              mainAxisSpacing: 5,
              crossAxisSpacing: 5,
              crossAxisCount: crossCount,
            ),
            itemCount: itemsList.length + (hideParentCard ? 0 : 1),
            itemBuilder: (BuildContext context, int index) {
              if (!hideParentCard) {
                if (index == 0) {
                  return _buildParentCard(context);
                }
                final OrionApiItem item = itemsList[index - 1];
                return _buildItemCard(context, item, provider);
              } else {
                final OrionApiItem item = itemsList[index];
                return _buildItemCard(context, item, provider);
              }
            },
          ),
        );
      },
    );
  }

  Widget _buildParentCard(BuildContext context) {
    return GlassCard(
      elevation: 1,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: _isLoading
            ? null
            : (!_usbAvailable && !_isUSB && _directory == _defaultDirectory)
                ? null
                : _directory == _defaultDirectory
                    ? () async {
                        // Toggle between USB and Internal
                        final targetIsUsb = !_isUSB;
                        setState(() {
                          _isLoading = true;
                          _isUSB = targetIsUsb;
                        });

                        try {
                          if (_isUSB && _useLocalFilesProvider) {
                            // Switch to LocalFilesProvider (USB)
                            final provider = Provider.of<LocalFilesProvider>(
                                context,
                                listen: false);
                            setState(() {
                              _defaultDirectory = provider.baseDirectory;
                              _directory = _defaultDirectory;
                              _subdirectory = '';
                            });
                            await provider.loadItems('Usb', '');
                            await _syncAfterLoad(provider, 'Usb');
                          } else {
                            // Switch to FilesProvider (API)
                            final provider = Provider.of<FilesProvider>(context,
                                listen: false);
                            final newLocation = _isUSB ? 'Usb' : 'Local';
                            await provider.loadItems(newLocation, '');
                            await _syncAfterLoad(provider, newLocation);
                            final items = provider.items;
                            if (items.isNotEmpty) {
                              setState(() {
                                _defaultDirectory =
                                    path.dirname(items.first.path);
                                _directory = _defaultDirectory;
                                _subdirectory = '';
                              });
                            } else {
                              setState(() {
                                _subdirectory = '';
                              });
                            }
                          }
                        } finally {
                          if (mounted) {
                            setState(() {
                              _isLoading = false;
                            });
                          }
                        }
                      }
                    : () async {
                        try {
                          _scrollController.jumpTo(0);
                          final parentDirectory = path.dirname(_directory);
                          setState(() {
                            _isNavigating = true;
                            _directory = parentDirectory;
                          });
                          final localBase = _isUSB && _useLocalFilesProvider
                              ? Provider.of<LocalFilesProvider>(context,
                                      listen: false)
                                  .baseDirectory
                              : _defaultDirectory;
                          final rawSubdir = parentDirectory == localBase
                              ? ''
                              : path.relative(parentDirectory, from: localBase);
                          final subdir = rawSubdir == '.' ? '' : rawSubdir;

                          if (_isUSB && _useLocalFilesProvider) {
                            final provider = Provider.of<LocalFilesProvider>(
                                context,
                                listen: false);
                            await provider.loadItems('Usb', subdir);
                            await _syncAfterLoad(provider, 'Usb');
                          } else {
                            final provider = Provider.of<FilesProvider>(context,
                                listen: false);
                            await provider.loadItems(
                                _isUSB ? 'Usb' : 'Local', subdir);
                            await _syncAfterLoad(
                                provider, _isUSB ? 'Usb' : 'Local');
                          }
                          setState(() {
                            _isNavigating = false;
                            _subdirectory = subdir;
                          });
                        } catch (e) {
                          _logger.severe(
                              'Failed to navigate to parent directory', e);
                          if (e is FileSystemException) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(FlutterI18n.translate(
                                    context, 'files.operationNotPermitted')),
                              ),
                            );
                          }
                        }
                      },
        child: GridTile(
          footer: GridTileBar(
            backgroundColor: Colors.transparent,
            title: AutoSizeText(
              _directory == _defaultDirectory
                  ? _isUSB == false
                      ? _usbAvailable
                          ? FlutterI18n.translate(context, 'print.switchUsb')
                          : FlutterI18n.translate(
                              context, 'print.usbUnavailable')
                      : FlutterI18n.translate(context, 'print.internalSwitch')
                  : FlutterI18n.translate(context, 'print.parentDir'),
              textAlign: TextAlign.center,
              maxLines: 2,
              minFontSize: 18,
              style: const TextStyle(
                  fontSize: 24,
                  color: Colors.grey,
                  fontFamily: 'AtkinsonHyperlegible'),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: PhosphorIcon(
              _directory == _defaultDirectory
                  ? _isUSB == false
                      ? _usbAvailable
                          ? PhosphorIcons.usb()
                          : PhosphorIcons.xCircle()
                      : PhosphorIcons.hardDrives()
                  : PhosphorIcons.arrowUUpLeft(),
              size: 75,
              color: Colors.grey,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLocalItemCard(
      BuildContext context, OrionApiItem item, LocalFilesProvider provider) {
    final String fileName = path.basename(item.path);
    final String displayName = fileName;
    final bool isFile = item is OrionApiFile;
    final OrionApiFile? fileItem = item is OrionApiFile ? item : null;
    final bool isSelected =
        fileItem != null && _selectedFileKeys.contains(_selectionKey(fileItem));
    final String fileSubdirectory = fileItem != null
        ? _resolveLocalSubdirectoryForFile(fileItem, provider)
        : '';
    final String fileExt = path.extension(fileName).toLowerCase();
    final bool shouldShowLocalThumbnail =
        fileItem != null && (fileExt == '.nanodlp' || fileExt == '.stl');

    return GlassCard(
      elevation: 2,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () async {
          if (_selectionMode) {
            if (fileItem != null) {
              _toggleSelection(fileItem);
            }
            return;
          }
          if (item is OrionApiDirectory) {
            _scrollController.jumpTo(0);

            // Calculate the relative path from the local base directory
            final baseDir = provider.baseDirectory;
            final relativeSubdir = path.relative(item.path, from: baseDir);
            final normalizedSubdir =
                relativeSubdir == '.' ? '' : relativeSubdir;

            setState(() {
              _isNavigating = true;
              _defaultDirectory = baseDir;
              _directory = item.path;
              _subdirectory = normalizedSubdir;
            });

            await provider.loadItems('Usb', normalizedSubdir);
            await _syncAfterLoad(provider, 'Usb');

            setState(() {
              _isNavigating = false;
            });
          }
          // Files are not directly opened in LocalFilesProvider mode - they need to be loaded via USB to the machine
          else if (fileItem != null && _isNanoDlp) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ImportScreen(
                  fileName: fileName,
                  filePath: fileItem.path,
                ),
              ),
            ).then((result) {
              if (result == true) {
                refresh();
                return;
              }
              if (result is Map) {
                if (result['switchToLocal'] == true) {
                  _switchToLocalAfterImport();
                } else if (result['refresh'] == true) {
                  refresh();
                }
              }
            });
          }
        },
        onLongPress: () {
          if (fileItem == null) return;
          if (_selectionMode) {
            _toggleSelection(fileItem);
          } else {
            _enterSelection(fileItem);
          }
        },
        child: _isNavigating
            ? const Center(child: CircularProgressIndicator())
            : _wrapWithSelectionOverlay(
                context,
                GridTile(
                  footer: isFile
                      ? _buildFileFooter(context, displayName)
                      : _buildDirectoryFooter(context, displayName),
                  child: item is OrionApiDirectory
                      ? IconTheme(
                          data: const IconThemeData(color: Colors.grey),
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 15),
                            child:
                                PhosphorIcon(PhosphorIcons.folder(), size: 75),
                          ),
                        )
                      : Padding(
                          padding: const EdgeInsets.all(4.5),
                          child: shouldShowLocalThumbnail
                              ? FutureBuilder<Uint8List?>(
                                  future: _getThumbnailFuture(
                                    location: provider.location,
                                    subdirectory: fileSubdirectory,
                                    fileName: fileName,
                                    file: fileItem,
                                  ),
                                  builder: (BuildContext context,
                                      AsyncSnapshot<Uint8List?> snapshot) {
                                    if (snapshot.connectionState ==
                                        ConnectionState.waiting) {
                                      return const Padding(
                                          padding: EdgeInsets.all(20),
                                          child: Center(
                                              child:
                                                  CircularProgressIndicator()));
                                    } else if (snapshot.hasError) {
                                      return _buildFileIcon(fileName);
                                    }

                                    final bytes = snapshot.data;
                                    if (bytes == null || bytes.isEmpty) {
                                      return _buildFileIcon(fileName);
                                    }

                                    return _buildGridThumbnailImage(
                                      bytes,
                                      radius: 7.75,
                                    );
                                  },
                                )
                              : _buildFileIcon(fileName),
                        ),
                ),
                isSelected,
              ),
      ),
    );
  }

  /// Build a file icon based on file extension
  Widget _buildFileIcon(String fileName) {
    final ext = path.extension(fileName).toLowerCase();
    final IconData iconData;

    if (ext == '.stl') {
      iconData = PhosphorIcons.cube();
    } else if (ext == '.nanodlp') {
      iconData = PhosphorIcons.file();
    } else {
      iconData = PhosphorIcons.file();
    }

    return IconTheme(
      data: const IconThemeData(color: Colors.grey),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 15),
        child: PhosphorIcon(iconData, size: 75),
      ),
    );
  }

  Widget _buildItemCard(
      BuildContext context, OrionApiItem item, FilesProvider provider) {
    final String fileName = path.basename(item.path);
    final String displayName = fileName;
    final OrionApiFile? fileItem = item is OrionApiFile ? item : null;
    final bool isFile = fileItem != null;
    final bool isSelected =
        fileItem != null && _selectedFileKeys.contains(_selectionKey(fileItem));
    final String fileSubdirectory = fileItem != null
        ? _resolveSubdirectoryForFile(fileItem)
        : _subdirectory;
    final themeProvider = Provider.of<ThemeProvider>(context);

    return GlassCard(
      elevation: 2,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () async {
          if (_selectionMode) {
            if (fileItem != null) {
              _toggleSelection(fileItem);
            }
            return;
          }
          if (item is OrionApiDirectory) {
            _scrollController.jumpTo(0);
            setState(() {
              _isNavigating = true;
              _directory = item.path;
            });
            final subdir = item.path == _defaultDirectory
                ? ''
                : path.relative(item.path, from: _defaultDirectory);
            await provider.loadItems(_isUSB ? 'Usb' : 'Local', subdir);
            await _syncAfterLoad(provider, _isUSB ? 'Usb' : 'Local');
            setState(() {
              _isNavigating = false;
              _subdirectory = subdir;
            });
          } else if (fileItem != null) {
            // Prefetch large thumbnail for the details screen so it's ready
            // (or already in-flight) by the time the DetailScreen mounts.
            try {
              ThumbnailCache.instance.getThumbnail(
                location: provider.location,
                subdirectory: fileSubdirectory,
                fileName: fileName,
                file: fileItem,
                size: 'Large',
              );
            } catch (_) {
              // best-effort; ignore prefetch failures
            }

            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => DetailScreen(
                  fileName: fileName,
                  fileSubdirectory: fileSubdirectory,
                  fileLocation: provider.location,
                ),
              ),
            ).then((result) {
              if (result == true) {
                refresh();
                return;
              }
              if (result is Map && result['refresh'] == true) {
                refresh();
              }
            });
          }
        },
        onLongPress: () {
          if (fileItem == null) return;
          if (_selectionMode) {
            _toggleSelection(fileItem);
          } else {
            _enterSelection(fileItem);
          }
        },
        child: _isNavigating
            ? const Center(child: CircularProgressIndicator())
            : _wrapWithSelectionOverlay(
                context,
                GridTile(
                  footer: isFile
                      ? _buildFileFooter(context, displayName)
                      : _buildDirectoryFooter(context, displayName),
                  child: item is OrionApiDirectory
                      ? IconTheme(
                          data: const IconThemeData(color: Colors.grey),
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 15),
                            child:
                                PhosphorIcon(PhosphorIcons.folder(), size: 75),
                          ),
                        )
                      : Padding(
                          padding: const EdgeInsets.all(4.5),
                          child: FutureBuilder<Uint8List?>(
                            future: _getThumbnailFuture(
                              location: provider.location,
                              subdirectory: fileSubdirectory,
                              fileName: fileName,
                              file: fileItem!,
                            ),
                            builder: (BuildContext context,
                                AsyncSnapshot<Uint8List?> snapshot) {
                              if (snapshot.connectionState ==
                                  ConnectionState.waiting) {
                                return const Padding(
                                    padding: EdgeInsets.all(20),
                                    child: Center(
                                        child: CircularProgressIndicator()));
                              } else if (snapshot.hasError) {
                                return const Icon(Icons.error);
                              }

                              final bytes = snapshot.data;
                              if (bytes == null || bytes.isEmpty) {
                                return const Icon(Icons.error);
                              }

                              return _buildGridThumbnailImage(
                                bytes,
                                radius:
                                    themeProvider.isGlassTheme ? 10.5 : 7.75,
                              );
                            },
                          ),
                        ),
                ),
                isSelected,
              ),
      ),
    );
  }

  Widget _buildFileFooter(BuildContext context, String displayName) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    if (themeProvider.isGlassTheme) {
      // Lightweight gradient footer (no blur) for glass theme.
      return Padding(
        padding: const EdgeInsets.only(
          left: 4.0,
          right: 4.0,
          bottom: 4.0,
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(6),
            topRight: Radius.circular(6),
            bottomLeft: Radius.circular(12),
            bottomRight: Radius.circular(12),
          ),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.7),
                  Colors.black.withValues(alpha: 0.15),
                ],
              ),
              border: Border(
                top: BorderSide(
                  color: Colors.white.withValues(alpha: 0.12),
                  width: 1,
                ),
              ),
            ),
            child: GridTileBar(
              title: AutoSizeText(
                displayName,
                textAlign: TextAlign.center,
                maxLines: 2,
                minFontSize: 20,
                style: const TextStyle(
                    fontSize: 24,
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                    fontFamily: 'AtkinsonHyperlegible'),
              ),
            ),
          ),
        ),
      );
    } else {
      // Original theme styling - restore the original Card-based approach
      return Card(
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            bottomLeft: Radius.circular(10),
            bottomRight: Radius.circular(10),
          ),
        ),
        color: Theme.of(context).cardColor.withValues(alpha: 0.65),
        elevation: 2,
        child: GridTileBar(
          title: AutoSizeText(
            displayName,
            textAlign: TextAlign.center,
            maxLines: 2,
            minFontSize: 20,
            style: TextStyle(
                fontSize: 24,
                color: Theme.of(context).textTheme.bodyLarge!.color,
                fontFamily: 'AtkinsonHyperlegible'),
          ),
        ),
      );
    }
  }

  Widget _buildDirectoryFooter(BuildContext context, String displayName) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    if (themeProvider.isGlassTheme) {
      // For glass theme, directories have transparent background like dark mode
      return GridTileBar(
        backgroundColor: Colors.transparent,
        title: AutoSizeText(
          displayName,
          textAlign: TextAlign.center,
          maxLines: 2,
          minFontSize: 20,
          style: const TextStyle(
              fontSize: 24,
              color: Colors.white70,
              fontFamily: 'AtkinsonHyperlegible'),
        ),
      );
    } else {
      // Original theme styling - transparent background like the original
      return Card(
        color: Colors.transparent,
        elevation: 0,
        child: GridTileBar(
          backgroundColor: Colors.transparent,
          title: AutoSizeText(
            displayName,
            textAlign: TextAlign.center,
            maxLines: 2,
            minFontSize: 20,
            style: TextStyle(
                fontSize: 24,
                color: Theme.of(context).textTheme.bodyLarge!.color,
                fontFamily: 'AtkinsonHyperlegible'),
          ),
        ),
      );
    }
  }

  Widget _wrapWithSelectionOverlay(
      BuildContext context, Widget child, bool isSelected) {
    if (!isSelected) return child;

    final showDeleting = _isBulkDeleting;
    final progressText = _bulkDeleteTotal > 0
        ? FlutterI18n.translate(context, 'files.deletingProgress',
            translationParams: {
                '0': _bulkDeleteCompleted.toString(),
                '1': _bulkDeleteTotal.toString()
              })
        : FlutterI18n.translate(context, 'files.deleting');

    final color = Theme.of(context).colorScheme.primary;
    return Stack(
      children: [
        child,
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(glassCornerRadius + 1),
              border: Border.all(color: color, width: 3),
              color: color.withValues(alpha: 0.12),
            ),
          ),
        ),
        Positioned(
          top: 8,
          right: 8,
          child: Container(
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
            padding: const EdgeInsets.all(4),
            child: const Icon(Icons.check, size: 16, color: Colors.white),
          ),
        ),
        if (showDeleting)
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(glassCornerRadius + 1),
                color: Colors.black.withValues(alpha: 0.25),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      strokeWidth: 2.4,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    progressText,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildRefreshFab() {
    return SizedBox(
      width: 70,
      height: 70,
      child: GlassFloatingActionButton(
        doForceBlur: true,
        tint: GlassButtonTint.positive,
        onPressed: _isLoading ? null : () => refresh(),
        child: _isLoading
            ? const SizedBox(
                width: 30,
                height: 30,
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  strokeWidth: 2.5,
                ),
              )
            : PhosphorIcon(PhosphorIcons.arrowClockwise(), size: 36),
      ),
    );
  }

  Widget _buildDeleteFab() {
    final hasSelection = _selectedFileKeys.isNotEmpty;
    return SizedBox(
      width: 70,
      height: 70,
      child: GlassFloatingActionButton(
        doForceBlur: true,
        tint: GlassButtonTint.negative,
        onPressed: (_isLoading || _isBulkDeleting || !hasSelection)
            ? null
            : _deleteSelectedFiles,
        child: _isBulkDeleting
            ? const SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  strokeWidth: 2.5,
                ),
              )
            : PhosphorIcon(PhosphorIcons.trash(), size: 34),
      ),
    );
  }
}

// Top-level entrypoint for compute() so transparent-border trimming happens
// off the UI thread.
Uint8List _trimTransparentPaddingEntry(Uint8List source) {
  try {
    final decoded = img.decodeImage(source);
    if (decoded == null) return source;

    final w = decoded.width;
    final h = decoded.height;
    if (w <= 2 || h <= 2) return source;

    int minX = w;
    int minY = h;
    int maxX = -1;
    int maxY = -1;

    // Treat near-transparent pixels as empty so antialiased borders are
    // trimmed too, but keep this fairly low so we don't clip faint edges.
    const alphaThreshold = 6;
    // Also treat pure/near-pure black (#000000) as background.
    // Keep this tight so dark model details are preserved.
    const blackThreshold = 2;

    for (int y = 0; y < h; y++) {
      for (int x = 0; x < w; x++) {
        final px = decoded.getPixel(x, y);
        final a = px.a;
        final r = px.r;
        final g = px.g;
        final b = px.b;
        final isBlackBackground =
            r <= blackThreshold && g <= blackThreshold && b <= blackThreshold;
        if (a > alphaThreshold && !isBlackBackground) {
          if (x < minX) minX = x;
          if (y < minY) minY = y;
          if (x > maxX) maxX = x;
          if (y > maxY) maxY = y;
        }
      }
    }

    // No visible content found; keep original.
    if (maxX < 0 || maxY < 0) return source;

    // Keep a safety margin so silhouettes don't hug tile edges.
    // Scale with source size to keep visual framing consistent across
    // different thumbnail resolutions.
    final margin = ((math.min(w, h) * 0.03).round()).clamp(5, 14);
    minX = math.max(0, minX - margin);
    minY = math.max(0, minY - margin);
    maxX = math.min(w - 1, maxX + margin);
    maxY = math.min(h - 1, maxY + margin);

    final cropW = maxX - minX + 1;
    final cropH = maxY - minY + 1;
    if (cropW <= 0 || cropH <= 0) return source;

    // If crop is effectively full-size, skip re-encode.
    if (cropW >= w - 2 && cropH >= h - 2) return source;

    final cropped = img.copyCrop(
      decoded,
      x: minX,
      y: minY,
      width: cropW,
      height: cropH,
    );

    // Keep output square so `BoxFit.cover` in square grid tiles doesn't crop
    // off the sides of wide models (or top/bottom of tall models).
    final side = math.max(w, h);
    if (side <= 0) return source;

    // Add a light framing pad inside the square canvas.
    final innerPad = ((side * 0.045).round()).clamp(8, 20);
    final innerSide = math.max(1, side - (innerPad * 2));

    final scale = math.min(innerSide / cropW, innerSide / cropH);
    final targetW = math.max(1, (cropW * scale).round());
    final targetH = math.max(1, (cropH * scale).round());
    final resized = img.copyResize(
      cropped,
      width: targetW,
      height: targetH,
      interpolation: img.Interpolation.cubic,
    );

    final canvas = img.Image(width: side, height: side, numChannels: 4);
    img.fill(canvas, color: img.ColorRgba8(0, 0, 0, 0));

    final dx = ((side - targetW) / 2).round();
    final dy = ((side - targetH) / 2).round();
    for (int y = 0; y < targetH; y++) {
      for (int x = 0; x < targetW; x++) {
        canvas.setPixel(dx + x, dy + y, resized.getPixel(x, y));
      }
    }

    return Uint8List.fromList(img.encodePng(canvas));
  } catch (_) {
    return source;
  }
}

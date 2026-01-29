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
import 'dart:ui';
import 'dart:collection';

import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
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
import 'package:orion/util/providers/theme_provider.dart';
import 'package:orion/util/thumbnail_cache.dart';
import 'dart:typed_data';

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
  bool _isLoading = false;
  bool _isNavigating = false;
  bool _isNanoDlp = false;
  bool _useLocalFilesProvider = false; // Use local filesystem instead of API

  // Thumbnail fetch concurrency control to avoid starting too many
  // simultaneous ThumbnailCache requests which can lag the app on low-end
  // devices. We queue requests and allow only [_maxConcurrentThumbnails]
  // active at a time. ThumbnailCache itself dedupes identical keys so this
  // is just a client-side throttle.
  final int _maxConcurrentThumbnails = 4;
  int _activeThumbnailFetches = 0;
  final Queue<_QueuedThumb> _thumbQueue = Queue<_QueuedThumb>();
  final Map<String, Future<Uint8List?>> _queuedInFlight = {};

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
        }
      }
    });
  }

  @override
  void dispose() {
    _thumbQueue.clear();
    _queuedInFlight.clear();
    super.dispose();
  }

  // Build a cache key similar to ThumbnailCache._cacheKey so we can
  // de-duplicate requests at this layer too.
  String _thumbCacheKey(String location, OrionApiFile file, String size) {
    final lastModified = file.lastModified ?? 0;
    // Match the format used by ThumbnailCache._cacheKey so we can
    // de-duplicate identical requests at this layer.
    return '$location|${file.path}|$lastModified|$size';
  }

  Future<Uint8List?> _queuedGetThumbnail({
    required String location,
    required String subdirectory,
    required String fileName,
    required OrionApiFile file,
    String size = 'Small',
  }) {
    final key = _thumbCacheKey(location, file, size);

    // If we already started or queued this request, return the existing future
    final existing = _queuedInFlight[key];
    if (existing != null) return existing;

    final completer = Completer<Uint8List?>();
    _queuedInFlight[key] = completer.future;

    final queued = _QueuedThumb(
      key: key,
      task: () async {
        try {
          final bytes = await ThumbnailCache.instance.getThumbnail(
            location: location,
            subdirectory: subdirectory,
            fileName: fileName,
            file: file,
            size: size,
          );
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
            const SnackBar(
                content: Text('USB unavailable, switched to Internal')),
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
        final currentPaths = provider.items
            .whereType<OrionApiFile>()
            .map((f) => f.path)
            .toList();
        ThumbnailCache.instance.validateAndCleanup('Usb', currentPaths);
      } else {
        final provider = Provider.of<FilesProvider>(context, listen: false);
        await provider.loadItems(_isUSB ? 'Usb' : 'Local', _subdirectory);
        await _syncAfterLoad(provider, _isUSB ? 'Usb' : 'Local');

        // Clean up cached thumbnails for deleted files
        final currentPaths = provider.items
            .whereType<OrionApiFile>()
            .map((f) => f.path)
            .toList();
        ThumbnailCache.instance
            .validateAndCleanup(_isUSB ? 'Usb' : 'Local', currentPaths);
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

  String _getDisplayNameForDirectory(String directory) {
    if (directory == _defaultDirectory && !_apiErrorState) {
      if (_isNanoDlp) return 'Print Files';
      return _isUSB == false ? 'Print Files (Internal)' : 'Print Files (USB)';
    }

    // If it's a subdirectory of the default directory, only show the relative path
    if (_apiErrorState) return 'Odyssey API Error';

    try {
      final relativePath = path.relative(directory, from: _defaultDirectory);
      if (relativePath == '.') {
        // If we're at the base, show the label
        return _isUSB == false ? 'Print Files (Internal)' : 'Print Files (USB)';
      }
      return "$relativePath ${_isUSB ? '(USB)' : '(Internal)'}";
    } catch (_) {
      // Fallback to full path if relative fails
      return "$directory ${_isUSB ? '(USB)' : '(Internal)'}";
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
          title: Text(_getDisplayNameForDirectory(_directory)),
          toolbarHeight: Theme.of(context).appBarTheme.toolbarHeight,
          actions: <Widget>[SystemStatusWidget()],
        ),
        body: (_isUSB && _useLocalFilesProvider)
            ? _buildLocalFilesContent(context)
            : _buildApiFilesContent(context),
        floatingActionButton: _buildRefreshFab(),
      ),
    );
  }

  /// Build content using LocalFilesProvider (filesystem-based)
  Widget _buildLocalFilesContent(BuildContext context) {
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
          padding: const EdgeInsets.only(left: 10, right: 10, bottom: 10),
          child: GridView.builder(
            controller: _scrollController,
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
          padding: const EdgeInsets.only(left: 10, right: 10, bottom: 10),
          child: GridView.builder(
            controller: _scrollController,
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
        onTap: !_usbAvailable && !_isUSB && _directory == _defaultDirectory
            ? null
            : _directory == _defaultDirectory
                ? () async {
                    // Toggle between USB and Internal
                    _isUSB = !_isUSB;

                    if (_isUSB && _useLocalFilesProvider) {
                      // Switch to LocalFilesProvider (USB)
                      final provider = Provider.of<LocalFilesProvider>(context,
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
                      final provider =
                          Provider.of<FilesProvider>(context, listen: false);
                      final newLocation = _isUSB ? 'Usb' : 'Local';
                      await provider.loadItems(newLocation, '');
                      await _syncAfterLoad(provider, newLocation);
                      final items = provider.items;
                      if (items.isNotEmpty) {
                        setState(() {
                          _defaultDirectory = path.dirname(items.first.path);
                          _directory = _defaultDirectory;
                          _subdirectory = '';
                        });
                      } else {
                        setState(() {
                          _subdirectory = '';
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
                        final provider =
                            Provider.of<FilesProvider>(context, listen: false);
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
                          const SnackBar(
                            content: Text('Operation not permitted'),
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
                          ? 'Switch to USB'
                          : 'USB unavailable'
                      : 'Switch to Internal'
                  : 'Parent Directory',
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
    final String fileSubdirectory = fileItem != null
        ? _resolveLocalSubdirectoryForFile(fileItem, provider)
        : '';
    final String fileExt = path.extension(fileName).toLowerCase();
    final bool shouldShowLocalThumbnail =
        fileItem != null && fileExt == '.nanodlp';

    return GlassCard(
      elevation: 2,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () async {
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
        child: _isNavigating
            ? const Center(child: CircularProgressIndicator())
            : GridTile(
                footer: isFile
                    ? _buildFileFooter(context, displayName)
                    : _buildDirectoryFooter(context, displayName),
                child: item is OrionApiDirectory
                    ? IconTheme(
                        data: const IconThemeData(color: Colors.grey),
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 15),
                          child: PhosphorIcon(PhosphorIcons.folder(), size: 75),
                        ),
                      )
                    : Padding(
                        padding: const EdgeInsets.all(4.5),
                        child: shouldShowLocalThumbnail
                            ? FutureBuilder<Uint8List?>(
                                future: _queuedGetThumbnail(
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

                                  return ClipRRect(
                                    borderRadius: BorderRadius.circular(7.75),
                                    child:
                                        Image.memory(bytes, fit: BoxFit.cover),
                                  );
                                },
                              )
                            : _buildFileIcon(fileName),
                      ),
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
    final String fileSubdirectory = fileItem != null
        ? _resolveSubdirectoryForFile(fileItem)
        : _subdirectory;
    final themeProvider = Provider.of<ThemeProvider>(context);

    return GlassCard(
      elevation: 2,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () async {
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
        child: _isNavigating
            ? const Center(child: CircularProgressIndicator())
            : GridTile(
                footer: isFile
                    ? _buildFileFooter(context, displayName)
                    : _buildDirectoryFooter(context, displayName),
                child: item is OrionApiDirectory
                    ? IconTheme(
                        data: const IconThemeData(color: Colors.grey),
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 15),
                          child: PhosphorIcon(PhosphorIcons.folder(), size: 75),
                        ),
                      )
                    : Padding(
                        padding: const EdgeInsets.all(4.5),
                        child: FutureBuilder<Uint8List?>(
                          future: _queuedGetThumbnail(
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

                            return ClipRRect(
                              borderRadius: themeProvider.isGlassTheme
                                  ? BorderRadius.circular(10.5)
                                  : BorderRadius.circular(7.75),
                              child: Image.memory(bytes, fit: BoxFit.cover),
                            );
                          },
                        ),
                      ),
              ),
      ),
    );
  }

  Widget _buildFileFooter(BuildContext context, String displayName) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    if (themeProvider.isGlassTheme) {
      // Glassmorphic styling for glass theme
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
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.2),
                  width: 1,
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(6),
                  topRight: Radius.circular(6),
                  bottomLeft: Radius.circular(12),
                  bottomRight: Radius.circular(12),
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

  Widget _buildRefreshFab() {
    return SizedBox(
      width: 70,
      height: 70,
      child: GlassFloatingActionButton(
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
}

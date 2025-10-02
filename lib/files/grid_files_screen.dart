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

import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as path;
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';

import 'package:orion/backend_service/providers/files_provider.dart';

import 'package:orion/files/details_screen.dart';
import 'package:orion/glasser/glasser.dart';
import 'package:orion/util/error_handling/error_dialog.dart';
import 'package:orion/util/orion_api_filesystem/orion_api_directory.dart';
import 'package:orion/util/orion_api_filesystem/orion_api_file.dart';
import 'package:orion/util/orion_api_filesystem/orion_api_item.dart';
import 'package:orion/util/orion_config.dart';
import 'package:orion/util/providers/theme_provider.dart';
import 'package:orion/util/sl1_thumbnail.dart';
import 'dart:typed_data';

ScrollController _scrollController = ScrollController();

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

  @override
  void initState() {
    super.initState();
    // No immediate placeholder; we'll show a smooth spinner while bytes are
    // decoded off the main isolate.
    final OrionConfig config = OrionConfig();
    _isUSB = config.getFlag('useUsbByDefault');
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (_defaultDirectory.isEmpty) {
        final provider = Provider.of<FilesProvider>(context, listen: false);
        await provider.loadItems(_isUSB ? 'Usb' : 'Local', '');
        await _syncAfterLoad(provider, _isUSB ? 'Usb' : 'Local');
        // If provider reported an error during initial load, display an error dialog
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
          _defaultDirectory = '~';
          _directory = _defaultDirectory;
        }
      }
    });
  }

  // removed placeholder bytes field; using spinner + background decode now

  // Helper: after calling provider.loadItems(requestedLocation,..)
  // update _isUSB/_usbAvailable and notify user if we fell back from USB->Local.
  Future<void> _syncAfterLoad(
      FilesProvider provider, String requestedLocation) async {
    try {
      final avail = await provider.usbAvailable();
      setState(() {
        _usbAvailable = avail;
      });
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
      final provider = Provider.of<FilesProvider>(context, listen: false);
      await provider.loadItems(_isUSB ? 'Usb' : 'Local', _subdirectory);
      await _syncAfterLoad(provider, _isUSB ? 'Usb' : 'Local');
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
      return _isUSB == false ? 'Print Files (Internal)' : 'Print Files (USB)';
    }

    // If it's a subdirectory of the default directory, only show the directory name
    if (_apiErrorState) return 'Odyssey API Error';
    return "$directory ${_isUSB ? '(USB)' : '(Internal)'}";
  }

  @override
  Widget build(BuildContext context) {
    return GlassApp(
      child: Scaffold(
        appBar: AppBar(
          title: Text(_getDisplayNameForDirectory(_directory)),
          centerTitle: false,
          actions: <Widget>[
            Padding(
              padding: const EdgeInsets.only(right: 15.0),
              child: IconButton(
                icon: const Icon(Icons.refresh),
                iconSize: 35,
                onPressed: () {
                  refresh();
                },
              ),
            ),
          ],
        ),
        body: Consumer<FilesProvider>(
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
            return Padding(
              padding: const EdgeInsets.only(left: 10, right: 10, bottom: 10),
              child: GridView.builder(
                controller: _scrollController,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  childAspectRatio: 1.03,
                  mainAxisSpacing: 5,
                  crossAxisSpacing: 5,
                  crossAxisCount: MediaQuery.of(context).orientation ==
                          Orientation.landscape
                      ? 4
                      : 2,
                ),
                itemCount: itemsList.length + 1,
                itemBuilder: (BuildContext context, int index) {
                  if (index == 0) {
                    return _buildParentCard(context);
                  }
                  final OrionApiItem item = itemsList[index - 1];
                  return _buildItemCard(context, item);
                },
              ),
            );
          },
        ),
      ),
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
                    _isUSB = !_isUSB;
                    final provider =
                        Provider.of<FilesProvider>(context, listen: false);
                    final newLocation = _isUSB ? 'Usb' : 'Local';
                    final subdir = _defaultDirectory.isEmpty
                        ? ''
                        : path.relative(_directory, from: _defaultDirectory);
                    await provider.loadItems(newLocation, subdir);
                    await _syncAfterLoad(provider, newLocation);
                    setState(() {});
                  }
                : () async {
                    try {
                      _scrollController.jumpTo(0);
                      final parentDirectory = path.dirname(_directory);
                      setState(() {
                        _isNavigating = true;
                        _directory = parentDirectory;
                      });
                      final provider =
                          Provider.of<FilesProvider>(context, listen: false);
                      final subdir = parentDirectory == _defaultDirectory
                          ? ''
                          : path.relative(parentDirectory,
                              from: _defaultDirectory);
                      await provider.loadItems(
                          _isUSB ? 'Usb' : 'Local', subdir);
                      await _syncAfterLoad(provider, _isUSB ? 'Usb' : 'Local');
                      setState(() {
                        _isNavigating = false;
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

  Widget _buildItemCard(BuildContext context, OrionApiItem item) {
    final String fileName = path.basename(item.path);
    final String displayName = fileName;
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
            final provider = Provider.of<FilesProvider>(context, listen: false);
            final subdir = item.path == _defaultDirectory
                ? ''
                : path.relative(item.path, from: _defaultDirectory);
            await provider.loadItems(_isUSB ? 'Usb' : 'Local', subdir);
            await _syncAfterLoad(provider, _isUSB ? 'Usb' : 'Local');
            setState(() {
              _isNavigating = false;
              _subdirectory = subdir;
            });
          } else if (item is OrionApiFile) {
            final provider = Provider.of<FilesProvider>(context, listen: false);
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => DetailScreen(
                  fileName: fileName,
                  fileSubdirectory: _subdirectory,
                  fileLocation: provider.location,
                ),
              ),
            ).then((result) {
              if (result == true) refresh();
            });
          }
        },
        child: _isNavigating
            ? const Center(child: CircularProgressIndicator())
            : GridTile(
                footer: item is OrionApiFile
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
                        child: FutureBuilder<Uint8List>(
                          future: ThumbnailUtil.extractThumbnailBytes(
                              Provider.of<FilesProvider>(context, listen: false)
                                  .location,
                              _subdirectory,
                              fileName),
                          builder: (BuildContext context,
                              AsyncSnapshot<Uint8List> snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const Padding(
                                  padding: EdgeInsets.all(20),
                                  child: Center(
                                      child: CircularProgressIndicator()));
                            } else if (snapshot.hasError ||
                                snapshot.data == null ||
                                snapshot.data!.isEmpty) {
                              return const Icon(Icons.error);
                            } else {
                              return ClipRRect(
                                borderRadius: themeProvider.isGlassTheme
                                    ? BorderRadius.circular(10.5)
                                    : BorderRadius.circular(7.75),
                                child: Image.memory(snapshot.data!,
                                    fit: BoxFit.cover),
                              );
                            }
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
}

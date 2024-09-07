// ignore_for_file: use_build_context_synchronously

/*
* Orion - Web Files Screen
* Copyright (C) 2024 TheContrappostoShop
*
* This program is free software: you can redistribute it and/or modify
* it under the terms of the GNU General Public License as published by
* the Free Software Foundation, either version 3 of the License, or
* (at your option) any later version.
*
* This program is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
* GNU General Public License for more details.
*
* You should have received a copy of the GNU General Public License
* along with this program.  If not, see <http://www.gnu.org/licenses/>.
*/

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:logging/logging.dart';

import 'package:path/path.dart' as path;
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:universal_io/io.dart';

import 'package:orion/api_services/api_services.dart';
import 'package:orion/util/error_handling/error_dialog.dart';
import 'package:orion/util/orion_api_filesystem/orion_api_directory.dart';
import 'package:orion/util/orion_api_filesystem/orion_api_file.dart';
import 'package:orion/util/orion_api_filesystem/orion_api_item.dart';
import 'package:orion/util/orion_config.dart';
import 'package:orion/util/sl1_thumbnail.dart';

ScrollController _scrollController = ScrollController();

class WebFilesScreen extends StatefulWidget {
  final bool isBusy;
  const WebFilesScreen({super.key, this.isBusy = false});

  @override
  WebFilesScreenState createState() => WebFilesScreenState();
}

class WebFilesScreenState extends State<WebFilesScreen> {
  final _logger = Logger('GridFiles');
  final ApiService _api = ApiService();

  late String _directory = '';
  late String _subdirectory = '';
  late String _defaultDirectory = '';

  String layerHeightInMicrons = '';
  String materialVolume = '';
  double materialVolumeInMilliliters = 0.0;
  String printTime = '';
  String printTimeInSeconds = '';

  late List<OrionApiItem> _items = [];
  late Future<List<OrionApiItem>> _itemsFuture = Future.value([]);
  late Completer<List<OrionApiItem>> _itemsCompleter =
      Completer<List<OrionApiItem>>();

  String location = '';
  bool _isUSB = false;
  bool _usbAvailable = false;
  bool _apiErrorState = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final OrionConfig config = OrionConfig();
    _isUSB = config.getFlag('useUsbByDefault');
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (_defaultDirectory.isEmpty) {
        final items = await _getItems('<init>', true);
        if (items.isNotEmpty) {
          _defaultDirectory = path.dirname(items.first.path);
          _directory = _defaultDirectory;
        } else {
          _defaultDirectory = '~';
          _directory = _defaultDirectory;
        }
        _itemsCompleter.complete(items);
      }
    });
  }

  Future<void> refresh() async {
    setState(() {
      _isLoading = true; // Indicate loading state
    });
    try {
      final items =
          await _getItems(_directory, false); // Fetch latest items from API
      _itemsCompleter = Completer<List<OrionApiItem>>(); // Reset the completer
      _itemsCompleter.complete(items); // Complete with new items
      setState(() {
        _items = items; // Update items
        _isLoading = false; // Reset loading state
      });
    } catch (e) {
      setState(() {
        _apiErrorState = true;
        showErrorDialog(context, 'PINK-CARROT');
        _isLoading = false;
      });
    }
  }

  Future<List<OrionApiItem>> _getItems(String directory,
      [bool init = false]) async {
    _logger.warning(
        await _api.usbAvailable() ? 'USB Available' : 'USB Not Available');
    _usbAvailable = await _api.usbAvailable();
    if (!_usbAvailable) _isUSB = false;
    try {
      setState(() {
        _isLoading = true;
      });
      _apiErrorState = false;
      _subdirectory = path.relative(directory, from: _defaultDirectory);
      if (init) _subdirectory = '';
      if (directory == _defaultDirectory) {
        _subdirectory = '';
      }

      location = _isUSB ? 'Usb' : 'Local';

      final itemResponse =
          await _api.listItems(location, 100, 0, _subdirectory);

      final List<OrionApiFile> files = (itemResponse['files'] as List)
          .where((item) => item != null)
          .map<OrionApiFile>((item) => OrionApiFile.fromJson(item))
          .toList();

      final List<OrionApiDirectory> dirs = (itemResponse['dirs'] as List)
          .where((item) => item != null)
          .map<OrionApiDirectory>((item) => OrionApiDirectory.fromJson(item))
          .toList();

      final List<OrionApiItem> items = [...dirs, ...files];
      if (items.isNotEmpty) {}

      setState(() {
        _isLoading = false;
      });
      return items;
    } catch (e) {
      _logger.severe('Failed to fetch files', e);
      setState(() {
        _isLoading = false;
      });
      _apiErrorState = true;
      showErrorDialog(context, 'PINK-CARROT');
      return [];
    }
  }

  String _getDisplayNameForDirectory(String directory) {
    if (directory == _defaultDirectory && !_apiErrorState) {
      return _isUSB == false ? 'Print Files (Internal)' : 'Print Files (USB)';
    }

    if (_apiErrorState) return 'Odyssey API Error';
    return "$directory ${_isUSB ? '(USB)' : '(Internal)'}";
  }

  String formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String hours = twoDigits(duration.inHours);
    String minutes = twoDigits(duration.inMinutes.remainder(60));
    String seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$hours:$minutes:$seconds";
  }

  Future<Map<String, dynamic>> getFileDetails(
      String location, String path) async {
    final metadata = await _api.getFileMetadata(location, path);
    final materialVolume = double.parse(metadata['used_material'].toString());
    return {
      'layerHeightInMicrons': metadata['layer_height_microns'].toString(),
      'materialVolume': metadata['used_material'].toString(),
      'materialVolumeInMilliliters': '${materialVolume.toStringAsFixed(2)} mL',
      'printTimeInSeconds': metadata['print_time'].toString(),
      'printTimeDuration': Duration(seconds: metadata['print_time'].toInt()),
      'printTime':
          formatDuration(Duration(seconds: metadata['print_time'].toInt()))
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _getDisplayNameForDirectory(_directory),
        ),
        centerTitle: false,
        actions: <Widget>[
          Padding(
            padding: const EdgeInsets.only(right: 15.0),
            child: IconButton(
              icon: const Icon(
                Icons.refresh,
              ),
              iconSize: 35,
              onPressed: () {
                refresh();
              },
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : FutureBuilder<List<OrionApiItem>>(
              future: _itemsCompleter.future,
              builder: (BuildContext context,
                  AsyncSnapshot<List<OrionApiItem>> snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting ||
                    snapshot.connectionState == ConnectionState.none) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                } else if (snapshot.hasError) {
                  return const Center(
                    child: Text('Failed to fetch files'),
                  );
                } else {
                  _items = snapshot.data!;
                  return Padding(
                    padding:
                        const EdgeInsets.only(left: 10, right: 10, bottom: 10),
                    child: ListView.builder(
                      controller: _scrollController,
                      itemCount: _items.length + 1,
                      itemBuilder: (BuildContext context, int index) {
                        if (index == 0) {
                          return Card(
                            elevation: 1,
                            child: ListTile(
                              contentPadding: const EdgeInsets.all(10),
                              leading: Padding(
                                padding: const EdgeInsets.only(
                                    left: 17.75, right: 27.75),
                                child: Icon(
                                  _directory == _defaultDirectory
                                      ? _isUSB == false
                                          ? _usbAvailable
                                              ? PhosphorIcons.usb()
                                              : PhosphorIcons.xCircle()
                                          : PhosphorIcons.hardDrives()
                                      : PhosphorIcons.arrowUUpLeft(),
                                  size: 50,
                                  color: Colors.grey,
                                ),
                              ),
                              title: Text(
                                _directory == _defaultDirectory
                                    ? _isUSB == false
                                        ? _usbAvailable
                                            ? 'Switch to USB'
                                            : 'USB unavailable'
                                        : 'Switch to Internal'
                                    : 'Parent Directory',
                                style: const TextStyle(
                                    fontSize: 22,
                                    color: Colors.grey,
                                    fontFamily: 'AtkinsonHyperlegible'),
                              ),
                              onTap: !_usbAvailable &&
                                      !_isUSB &&
                                      _directory == _defaultDirectory
                                  ? null
                                  : _directory == _defaultDirectory
                                      ? () async {
                                          _isUSB = !_isUSB;
                                          _itemsFuture = _getItems(_directory);
                                          _itemsCompleter =
                                              Completer<List<OrionApiItem>>();
                                          final items = await _itemsFuture;
                                          _itemsCompleter.complete(items);
                                          setState(() {
                                            _items = items;
                                          });
                                        }
                                      : () async {
                                          try {
                                            _scrollController.jumpTo(0);
                                            final parentDirectory =
                                                path.dirname(_directory);
                                            _directory = parentDirectory;
                                            _itemsFuture =
                                                _getItems(parentDirectory);
                                            _itemsCompleter =
                                                Completer<List<OrionApiItem>>();
                                            final items = await _itemsFuture;
                                            _itemsCompleter.complete(items);
                                          } catch (e) {
                                            _logger.severe(
                                                'Failed to navigate to parent directory',
                                                e);
                                            if (e is FileSystemException) {
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(
                                                const SnackBar(
                                                  content: Text(
                                                      'Operation not permitted'),
                                                ),
                                              );
                                            }
                                          }
                                        },
                            ),
                          );
                        } else {
                          final OrionApiItem item = _items[index - 1];
                          final String fileName = path.basename(item.path);
                          final String displayName = fileName;

                          return Card(
                            elevation: 2,
                            child: FutureBuilder<Map<String, dynamic>>(
                              future: item is OrionApiFile
                                  ? getFileDetails(location, item.path)
                                  : Future.value({}),
                              builder: (BuildContext context,
                                  AsyncSnapshot<Map<String, dynamic>>
                                      snapshot) {
                                if (snapshot.connectionState ==
                                        ConnectionState.waiting ||
                                    snapshot.connectionState ==
                                        ConnectionState.none) {
                                  return const ListTile(
                                    title: Text('Loading...'),
                                  );
                                } else if (snapshot.hasError) {
                                  return const ListTile(
                                    title: Text('Failed to load details'),
                                  );
                                } else {
                                  final details = snapshot.data!;
                                  return ListTile(
                                    subtitle: Text(
                                      item is OrionApiDirectory
                                          ? 'Directory'
                                          : '${details['printTime']} - ${details['materialVolumeInMilliliters']}',
                                      style: const TextStyle(
                                          fontSize: 18,
                                          fontFamily: 'AtkinsonHyperlegible'),
                                    ),
                                    trailing: item is OrionApiDirectory
                                        ? null
                                        : Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              ElevatedButton.icon(
                                                icon: const Icon(Icons.delete),
                                                label: const Text('Delete'),
                                                onPressed: widget.isBusy
                                                    ? null
                                                    : () async {
                                                        final confirmed =
                                                            await showDialog<
                                                                bool>(
                                                          context: context,
                                                          builder: (context) =>
                                                              AlertDialog(
                                                            title: const Text(
                                                                'Confirm Delete'),
                                                            content: const Text(
                                                                'Are you sure you want to delete this file?'),
                                                            actions: [
                                                              TextButton(
                                                                onPressed: () =>
                                                                    Navigator.of(
                                                                            context)
                                                                        .pop(
                                                                            false),
                                                                child: const Text(
                                                                    'Cancel'),
                                                              ),
                                                              TextButton(
                                                                onPressed: () =>
                                                                    Navigator.of(
                                                                            context)
                                                                        .pop(
                                                                            true),
                                                                child: const Text(
                                                                    'Delete'),
                                                              ),
                                                            ],
                                                          ),
                                                        );

                                                        if (confirmed == true) {
                                                          await _api.deleteFile(
                                                              location,
                                                              item.path);
                                                          refresh();
                                                        }
                                                      },
                                              ),
                                              const SizedBox(
                                                  width:
                                                      8), // Add some spacing between the buttons
                                              ElevatedButton.icon(
                                                icon: const Icon(Icons.print),
                                                label: const Text('Print'),
                                                onPressed: widget.isBusy
                                                    ? null
                                                    : () async {
                                                        await _api.startPrint(
                                                            location,
                                                            item.path);
                                                      },
                                              ),
                                            ],
                                          ),
                                    leading: item is OrionApiDirectory
                                        ? Padding(
                                            padding: const EdgeInsets.only(
                                                left: 17.75, right: 27.75),
                                            child: Icon(
                                              PhosphorIcons.folder(),
                                              size: 50,
                                              color: Colors.grey,
                                            ),
                                          )
                                        : Padding(
                                            padding: const EdgeInsets.only(
                                                left: 5, right: 10),
                                            child: FutureBuilder<String>(
                                              future: ThumbnailUtil
                                                  .extractThumbnail(
                                                location,
                                                _subdirectory,
                                                fileName,
                                                size: 'Large',
                                              ),
                                              builder: (BuildContext context,
                                                  AsyncSnapshot<String>
                                                      snapshot) {
                                                if (snapshot.connectionState ==
                                                    ConnectionState.waiting) {
                                                  return const Padding(
                                                      padding:
                                                          EdgeInsets.all(0),
                                                      child:
                                                          CircularProgressIndicator());
                                                } else if (snapshot.error !=
                                                    null) {
                                                  return const Icon(
                                                      Icons.error);
                                                } else {
                                                  return ClipRRect(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            7.75),
                                                    child: kIsWeb
                                                        ? Image.network(
                                                            snapshot.data!,
                                                            fit: BoxFit.cover,
                                                          )
                                                        : Image.file(
                                                            File(
                                                                snapshot.data!),
                                                            fit: BoxFit.cover,
                                                          ),
                                                  );
                                                }
                                              },
                                            ),
                                          ),
                                    title: Text(
                                      displayName,
                                      style: const TextStyle(
                                        fontSize: 22,
                                        fontFamily: 'AtkinsonHyperlegible',
                                      ),
                                    ),
                                    onTap: item is OrionApiFile
                                        ? null
                                        : () async {
                                            _scrollController.jumpTo(0);
                                            _directory = item.path;
                                            _itemsFuture = _getItems(item.path);
                                            _itemsCompleter =
                                                Completer<List<OrionApiItem>>();
                                            final items = await _itemsFuture;
                                            _itemsCompleter.complete(items);
                                          },
                                  );
                                }
                              },
                            ),
                          );
                        }
                      },
                    ),
                  );
                }
              },
            ),
    );
  }
}

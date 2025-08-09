/*
* Orion - Detail Screen
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

import 'dart:io';

import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as path;

import 'package:orion/api_services/api_services.dart';
import 'package:orion/glasser/glasser.dart';
import 'package:orion/status/status_screen.dart';
import 'package:orion/util/sl1_thumbnail.dart';

class DetailScreen extends StatefulWidget {
  final String fileName;
  final String fileSubdirectory;
  final String fileLocation;

  const DetailScreen({
    super.key,
    required this.fileName,
    required this.fileSubdirectory,
    required this.fileLocation,
  });

  @override
  DetailScreenState createState() => DetailScreenState();

  static bool _isDefaultDir(String dir) {
    return dir == '';
  }
}

class DetailScreenState extends State<DetailScreen> {
  final _logger = Logger('DetailScreen');
  final ApiService _api = ApiService();

  bool isLandScape = false;
  int maxNameLength = 0;
  bool loading = true; // Add loading state

  FileStat? fileStat;
  String fileName = ''; // path.basename(widget.file.path)
  String layerHeight = ''; // layerHeight
  String fileSize = ''; // fileStat!.size
  String modifiedDate = ''; // fileCreationTimestamp
  String materialName = ''; // materialName
  String fileExtension = ''; // path.extension(widget.file.path)
  String thumbnailPath = ''; // extractThumbnail(widget.file, hash)
  String printTime = ''; // printTime
  double printTimeInSeconds = 0; // printTime in seconds
  String materialVolume = ''; // usedMaterial
  double materialVolumeInMilliliters = 0; // usedMaterial in milliliters

  late ValueNotifier<Future<String>> thumbnailFutureNotifier;
  // ignore: unused_field
  Future<void>? _initFileDetailsFuture;

  @override
  void initState() {
    super.initState();
    _initFileDetailsFuture = _initFileDetails();
  }

  Future<void> _initFileDetails() async {
    try {
      final fileDetails = await _api.getFileMetadata(
        widget.fileLocation,
        [
          (DetailScreen._isDefaultDir(widget.fileSubdirectory)
              ? ''
              : widget.fileSubdirectory),
          widget.fileName
        ].join(DetailScreen._isDefaultDir(widget.fileSubdirectory) ? '' : '/'),
      );

      String tempFileName = fileDetails['file_data']['name'] ?? 'Placeholder';
      String tempFileSize =
          (fileDetails['file_data']['file_size'] / 1024 / 1024)
                  .toStringAsFixed(2) +
              ' MB'; // convert to MB
      String tempFileExtension = path.extension(tempFileName);
      String tempLayerHeight =
          '${fileDetails['layer_height'].toStringAsFixed(3)} mm';
      String tempModifiedDate = DateTime.fromMillisecondsSinceEpoch(
              fileDetails['file_data']['last_modified'] * 1000)
          .toString(); // convert to milliseconds
      String tempMaterialName =
          'N/A'; // this information is not provided by the API
      String tempThumbnailPath = await ThumbnailUtil.extractThumbnail(
          widget.fileLocation, widget.fileSubdirectory, widget.fileName,
          size: 'Large'); // fetch thumbnail from API
      double tempPrintTimeInSeconds = fileDetails['print_time'];
      Duration printDuration =
          Duration(seconds: tempPrintTimeInSeconds.toInt());
      String tempPrintTime =
          '${printDuration.inHours.remainder(24).toString().padLeft(2, '0')}:${printDuration.inMinutes.remainder(60).toString().padLeft(2, '0')}:${printDuration.inSeconds.remainder(60).toString().padLeft(2, '0')}';
      double tempMaterialVolumeInMilliliters = fileDetails['used_material'];
      String tempMaterialVolume =
          '${tempMaterialVolumeInMilliliters.toStringAsFixed(2)} mL';

      setState(() {
        fileName = tempFileName;
        fileSize = tempFileSize;
        fileExtension = tempFileExtension;
        layerHeight = tempLayerHeight;
        modifiedDate = tempModifiedDate;
        materialName = tempMaterialName;
        thumbnailPath = tempThumbnailPath;
        printTimeInSeconds = tempPrintTimeInSeconds;
        printTime = tempPrintTime;
        materialVolumeInMilliliters = tempMaterialVolumeInMilliliters;
        materialVolume = tempMaterialVolume;
        loading = false; // Set loading to false when data is fetched
      });
    } catch (e) {
      _logger.severe('Failed to fetch file details', e);
      setState(() {
        loading = false; // Set loading to false even if there's an error
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    isLandScape = MediaQuery.of(context).orientation == Orientation.landscape;
    maxNameLength = isLandScape ? 12 : 24;
    return GlassApp(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('File Details'),
          centerTitle: true,
        ),
        body: Center(
          child: loading // Show CircularProgressIndicator if loading
              ? const CircularProgressIndicator()
              : LayoutBuilder(
                  builder: (BuildContext context, BoxConstraints constraints) {
                    return isLandScape
                        ? Padding(
                            padding: const EdgeInsets.only(
                                left: 16, right: 16, bottom: 20),
                            child: buildLandscapeLayout(context))
                        : Padding(
                            padding: const EdgeInsets.only(
                                left: 16, right: 16, bottom: 20),
                            child: buildPortraitLayout(context));
                  },
                ),
        ),
      ),
    );
  }

  Widget buildPortraitLayout(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              buildNameCard(fileName),
              const SizedBox(height: 16),
              Expanded(
                child: Column(
                  children: [
                    buildThumbnailView(context),
                    const Spacer(),
                    Row(
                      children: [
                        Expanded(
                          child: buildInfoCard('Layer Height', layerHeight),
                        ),
                        Expanded(
                          child: buildInfoCard('Material & Volume',
                              '$materialName - $materialVolume'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Row(children: [
                      Expanded(
                        child: buildInfoCard('Print Time', printTime),
                      ),
                      Expanded(
                        child: buildInfoCard('File Size', fileSize),
                      ),
                    ]),
                    const SizedBox(height: 5),
                    buildInfoCard('Modified Date', modifiedDate),
                    const Spacer(),
                    buildPrintButtons(),
                  ],
                ),
              ),
            ],
          ),
        )
      ],
    );
  }

  Widget buildLandscapeLayout(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: Row(
            children: [
              Expanded(
                flex: 1,
                child: ListView(
                  children: [
                    buildNameCard(fileName),
                    buildInfoCard('Layer Height', layerHeight),
                    buildInfoCard(
                        'Material & Volume', '$materialName - $materialVolume'),
                    buildInfoCard('Print Time', printTime),
                    buildInfoCard('Modified Date', modifiedDate),
                    buildInfoCard('File Size', fileSize),
                  ],
                ),
              ),
              const SizedBox(width: 16.0),
              Flexible(
                flex: 0,
                child: buildThumbnailView(context),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Padding(
          padding: const EdgeInsets.only(left: 5.0, right: 5.0),
          child: buildPrintButtons(),
        ),
      ],
    );
  }

  Widget buildInfoCard(String title, String subtitle) {
    final cardContent = ListTile(
      title: Text(title),
      subtitle: Text(subtitle),
    );

    return GlassCard(
      outlined: true,
      elevation: 1.0,
      child: cardContent,
    );
  }

  Widget buildNameCard(String title) {
    final displayName = fileName.length > maxNameLength
        ? '${fileName.substring(0, maxNameLength)}...'
        : fileName;

    final nameText = AutoSizeText(
      displayName,
      maxLines: 1,
      minFontSize: 16,
      style: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.bold,
        color: Theme.of(context).colorScheme.primary,
      ),
    );

    final cardChild = ListTile(title: nameText);

    return GlassCard(
      outlined: true,
      child: cardChild,
    );
  }

  Widget buildThumbnailView(BuildContext context) {
    final Widget imageWidget = thumbnailPath.isNotEmpty
        ? Image.file(File(thumbnailPath))
        : const Center(child: CircularProgressIndicator());

    final Widget cardContent = Padding(
      padding: const EdgeInsets.all(4.5),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(7.75),
        child: imageWidget,
      ),
    );

    return Center(
      child: GlassCard(
        outlined: true,
        child: cardContent,
      ),
    );
  }

  Future<void> launchDeleteDialog() async {
    final bool? deleteConfirmed = await showDialog<bool>(
      barrierDismissible: false,
      context: context,
      builder: (BuildContext context) {
        return GlassAlertDialog(
          title: const Text('Delete File'),
          content: const Text(
            'Are you sure you want to delete this file?\nThis action cannot be undone.',
          ),
          actions: [
            GlassButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel', style: TextStyle(fontSize: 20)),
            ),
            GlassButton(
              onPressed: () async {
                try {
                  await _api.deleteFile(
                    widget.fileLocation,
                    path.join(widget.fileSubdirectory, widget.fileName),
                  );
                  _logger.info('File deleted successfully');
                  if (mounted) Navigator.of(context).pop(true);
                } catch (e) {
                  _logger.severe('Failed to delete file', e);
                  if (mounted) Navigator.of(context).pop(false);
                }
              },
              child: const Text('Delete', style: TextStyle(fontSize: 20)),
            ),
          ],
        );
      },
    );
    if (deleteConfirmed == true) {
      Navigator.of(context).pop(); // Close the detail screen
    }
  }

  Widget buildPrintButtons() {
    return Row(
      children: [
        GlassButton(
          wantIcon: false,
          onPressed: () {
            launchDeleteDialog();
          },
          style: ElevatedButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            minimumSize: const Size(120, 60), // Same width as Edit button
          ),
          child: const Text(
            'Delete',
            style: TextStyle(fontSize: 20),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: GlassButton(
            onPressed: () {
              try {
                String subdirectory = widget.fileSubdirectory;
                _api.startPrint(widget.fileLocation,
                    path.join(subdirectory, widget.fileName));
                Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const StatusScreen(
                        newPrint: true,
                      ),
                    ));
              } catch (e) {
                _logger.severe('Failed to start print', e);
              }
            },
            style: ElevatedButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              minimumSize: const Size(0, 60), // Taller to work for both themes
            ),
            child: const Text(
              'Print',
              style: TextStyle(fontSize: 22),
              textAlign: TextAlign.center,
            ),
          ),
        ),
        const SizedBox(width: 20),
        GlassButton(
          onPressed: null, // Disabled button
          style: ElevatedButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            minimumSize: const Size(120, 60), // Taller to work for both themes
          ),
          child: const Text(
            'Edit',
            style: TextStyle(fontSize: 20),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}

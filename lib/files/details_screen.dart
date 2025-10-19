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
import 'package:marquee/marquee.dart';
import 'package:provider/provider.dart';

import 'package:orion/backend_service/providers/files_provider.dart';
import 'package:orion/backend_service/odyssey/models/files_models.dart';

import 'package:orion/glasser/glasser.dart';
import 'package:orion/status/status_screen.dart';
import 'package:orion/util/sl1_thumbnail.dart';
import 'package:orion/util/providers/theme_provider.dart';

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

  bool isLandScape = false;
  int maxNameLength = 0;
  bool loading = true; // Add loading state
  FileMetadata? _meta;
  Future<String>? _thumbnailFuture;
  bool _isThumbnailLoading = false;

  @override
  void initState() {
    super.initState();
    _loadMetadata();
  }

  Future<void> _loadMetadata() async {
    setState(() {
      loading = true;
    });

    final provider = Provider.of<FilesProvider>(context, listen: false);
    final filePath = DetailScreen._isDefaultDir(widget.fileSubdirectory)
        ? widget.fileName
        : '${widget.fileSubdirectory}/${widget.fileName}';

    try {
      final FileMetadata? meta =
          await provider.fetchFileMetadata(widget.fileLocation, filePath);
      if (meta == null) {
        setState(() {
          _meta = null;
          _thumbnailFuture = null;
          loading = false;
        });
        return;
      }

      // Kick off thumbnail extraction but render metadata directly from the
      // typed model in build(). This mirrors the approach used in StatusScreen
      // where presentation derives values directly from the provider model.
      final thumbFuture = ThumbnailUtil.extractThumbnail(
        widget.fileLocation,
        widget.fileSubdirectory,
        widget.fileName,
        size: 'Large',
      );

      // Track thumbnail loading separately so we can optionally overlay a
      // full-screen spinner while the image downloads to avoid UI flicker.
      if (mounted) {
        setState(() {
          _meta = meta;
          _thumbnailFuture = thumbFuture;
          loading = false;
          _isThumbnailLoading = true;
        });
      }

      // Clear the thumbnail-loading flag when the future completes (success or error).
      thumbFuture.whenComplete(() {
        if (mounted) {
          setState(() {
            _isThumbnailLoading = false;
          });
        }
      });
    } catch (e, st) {
      _logger.severe('Failed to load file metadata', e, st);
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    isLandScape = MediaQuery.of(context).orientation == Orientation.landscape;
    maxNameLength = isLandScape ? 12 : 24;
    return GlassApp(
      child: Scaffold(
        appBar: AppBar(
          title: Text(_meta?.fileData.name ?? widget.fileName),
          centerTitle: true,
        ),
        body: Center(
          child: loading
              ? const CircularProgressIndicator()
              : _meta == null
                  ? const Text('Failed to load file metadata')
                  // If the thumbnail is still downloading, show a full-screen
                  // spinner instead of rendering the details layout to avoid
                  // partial UI flicker.
                  : (_isThumbnailLoading
                      ? const Center(child: CircularProgressIndicator())
                      : LayoutBuilder(
                          builder: (BuildContext context,
                              BoxConstraints constraints) {
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
                        )),
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
              buildNameCard(_meta?.fileData.name ?? widget.fileName),
              const SizedBox(height: 16),
              Expanded(
                child: Column(
                  children: [
                    buildThumbnailView(context),
                    const Spacer(),
                    Row(
                      children: [
                        Expanded(
                          child: buildInfoCard(
                            'Layer Height',
                            _meta?.layerHeight != null
                                ? '${_meta!.layerHeight!.toStringAsFixed(3)} mm'
                                : '-',
                          ),
                        ),
                        Expanded(
                          child: buildInfoCard(
                            'Material & Volume',
                            _meta?.usedMaterial != null
                                ? _meta?.materialName != null
                                    ? '${_meta?.materialName} - ${_meta!.usedMaterial!.toStringAsFixed(2)} mL'
                                    : 'N/A - ${_meta!.usedMaterial!.toStringAsFixed(2)} mL'
                                : 'N/A - -',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Row(children: [
                      Expanded(
                        child: buildInfoCard(
                          'Print Time',
                          _meta?.printTime != null
                              ? _meta!.formattedPrintTime
                              : '-',
                        ),
                      ),
                      Expanded(
                        child: buildInfoCard(
                          'File Size',
                          _meta?.fileData.fileSize != null
                              ? '${(_meta!.fileData.fileSize! / 1024 / 1024).toStringAsFixed(2)} MB'
                              : '-',
                        ),
                      ),
                    ]),
                    const SizedBox(height: 5),
                    buildInfoCard(
                      'Modified Date',
                      _meta != null
                          ? DateTime.fromMillisecondsSinceEpoch(
                                  _meta!.fileData.lastModified * 1000)
                              .toString()
                          : '-',
                    ),
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
                    buildNameCard(_meta?.fileData.name ?? widget.fileName),
                    buildInfoCard(
                        'Layer Height',
                        _meta?.layerHeight != null
                            ? '${_meta!.layerHeight!.toStringAsFixed(3)} mm'
                            : '-'),
                    buildInfoCard(
                      'Material & Volume',
                      _meta?.usedMaterial != null
                          ? _meta?.materialName != null
                              ? '${_meta?.materialName} - ${_meta!.usedMaterial!.toStringAsFixed(2)} mL'
                              : 'N/A - ${_meta!.usedMaterial!.toStringAsFixed(2)} mL'
                          : 'N/A - -',
                    ),
                    buildInfoCard(
                      'Print Time',
                      _meta?.printTime != null
                          ? _meta!.formattedPrintTime
                          : '-',
                    ),
                    buildInfoCard(
                      'Modified Date',
                      _meta != null
                          ? DateTime.fromMillisecondsSinceEpoch(
                                  _meta!.fileData.lastModified * 1000)
                              .toString()
                          : '-',
                    ),
                    buildInfoCard(
                        'File Size',
                        _meta?.fileData.fileSize != null
                            ? '${(_meta!.fileData.fileSize! / 1024 / 1024).toStringAsFixed(2)} MB'
                            : '-'),
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final marqueeHeight = 32.0; // or 36.0 if you want more vertical space
        final nameText = AutoSizeText(
          title,
          maxLines: 1,
          minFontSize: 18,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.primary,
          ),
          overflowReplacement: SizedBox(
            width: constraints.maxWidth > 0 ? constraints.maxWidth : 200,
            height: marqueeHeight,
            child: Marquee(
              startAfter: const Duration(seconds: 2),
              pauseAfterRound: const Duration(seconds: 3),
              showFadingOnlyWhenScrolling: true,
              fadingEdgeStartFraction: 0.1,
              fadingEdgeEndFraction: 0.1,
              blankSpace: 40.0,
              startPadding: 4.0,
              text: title,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
        );

        final cardChild = ListTile(
          title: Row(
            children: [
              Expanded(child: nameText),
            ],
          ),
        );

        return GlassCard(
          outlined: true,
          child: cardChild,
        );
      },
    );
  }

  Widget buildThumbnailView(BuildContext context) {
    final Widget imageWidget = _thumbnailFuture == null
        ? const Center(child: CircularProgressIndicator())
        : FutureBuilder<String>(
            future: _thumbnailFuture,
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snap.hasError || snap.data == null || snap.data!.isEmpty) {
                return const Center(child: Icon(Icons.broken_image));
              }
              return Image.file(File(snap.data!));
            },
          );

    final themeProvider = Provider.of<ThemeProvider>(context);

    final Widget cardContent = Padding(
      padding: const EdgeInsets.all(4.5),
      child: ClipRRect(
        borderRadius: themeProvider.isGlassTheme
            ? BorderRadius.circular(10.5)
            : BorderRadius.circular(7.75),
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
                  final provider =
                      Provider.of<FilesProvider>(context, listen: false);
                  final filePath =
                      DetailScreen._isDefaultDir(widget.fileSubdirectory)
                          ? widget.fileName
                          : path.join(widget.fileSubdirectory, widget.fileName);
                  final ok =
                      await provider.deleteFile(widget.fileLocation, filePath);
                  if (ok) {
                    _logger
                        .info('File ${widget.fileName} deleted successfully');
                    if (mounted) Navigator.of(context).pop(true);
                  } else {
                    _logger.severe('Failed to delete file ${widget.fileName}');
                    if (mounted) Navigator.of(context).pop(false);
                  }
                } catch (e) {
                  _logger.severe('Failed to delete file ${widget.fileName}', e);
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
      // Pop this detail screen and signal to previous screen to refresh
      Navigator.of(context).pop(true); // Pass true to indicate refresh needed
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
            minimumSize: const Size(120, 65), // Same width as Edit button
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
            onPressed: () async {
              try {
                final provider =
                    Provider.of<FilesProvider>(context, listen: false);
                final filePath =
                    DetailScreen._isDefaultDir(widget.fileSubdirectory)
                        ? widget.fileName
                        : path.join(widget.fileSubdirectory, widget.fileName);
                final ok =
                    await provider.startPrint(widget.fileLocation, filePath);
                if (ok) {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const StatusScreen(
                          newPrint: true,
                        ),
                      ));
                } else {
                  _logger.severe('Failed to start print');
                }
              } catch (e) {
                _logger.severe('Failed to start print', e);
              }
            },
            style: ElevatedButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              minimumSize: const Size(0, 65), // Taller to work for both themes
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
            minimumSize: const Size(120, 65), // Taller to work for both themes
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

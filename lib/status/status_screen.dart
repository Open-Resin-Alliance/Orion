/*
* Orion - Status Screen
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

// dart:io not needed once thumbnails are rendered from memory

import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'dart:typed_data';
import 'package:orion/backend_service/nanodlp/nanodlp_thumbnail_generator.dart';

import 'package:orion/files/grid_files_screen.dart';
import 'package:orion/glasser/glasser.dart';
import 'package:orion/settings/settings_screen.dart';
import 'package:orion/util/hold_button.dart';
import 'package:orion/util/providers/theme_provider.dart';
import 'package:orion/util/status_card.dart';
import 'package:orion/backend_service/providers/status_provider.dart';
import 'package:orion/backend_service/odyssey/models/status_models.dart';
import 'package:orion/backend_service/backend_service.dart';
import 'package:orion/util/layer_preview_cache.dart';

class StatusScreen extends StatefulWidget {
  final bool newPrint;
  final Uint8List? initialThumbnailBytes;
  final String? initialFilePath;
  final int? initialPlateId;

  const StatusScreen({
    super.key,
    required this.newPrint,
    this.initialThumbnailBytes,
    this.initialFilePath,
    this.initialPlateId,
  });

  @override
  StatusScreenState createState() => StatusScreenState();
}

class StatusScreenState extends State<StatusScreen> {
  // While starting a new print we suppress rendering of any stale provider
  // status until after we've issued a reset in a post-frame callback. This
  // avoids calling notifyListeners during the same build frame that mounted
  // this widget (which previously caused a FlutterError) while still ensuring
  // a clean spinner instead of flashing the prior job.
  bool _suppressOldStatus = false;
  String? _frozenFileName;
  // Presentation-local state (derived values computed per build instead of storing)
  bool get _isLandscape =>
      MediaQuery.of(context).orientation == Orientation.landscape;

  // Duration formatting moved to StatusModel.formattedElapsedPrintTime

  @override
  void initState() {
    super.initState();
    if (widget.newPrint) {
      _suppressOldStatus = true; // force spinner for fresh print session
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        context.read<StatusProvider>().resetStatus(
              initialThumbnailBytes: widget.initialThumbnailBytes,
              initialFilePath: widget.initialFilePath,
              initialPlateId: widget.initialPlateId,
            );
        setState(() => _suppressOldStatus = false);
      });
    }
  }

  // Local UI state for toggling 2D layer preview
  bool _showLayer2D = false;
  Uint8List? _layer2DBytes;
  ImageProvider? _layer2DImageProvider;
  bool _layer2DLoading = false;
  DateTime? _lastLayerToggleTime;
  bool _prefetched = false;
  int? _lastPrefetchedLayer;
  int? _resolvedPlateIdForPrefetch;
  String? _resolvedFilePathForPrefetch;

  bool _bytesEqual(Uint8List a, Uint8List b) {
    if (identical(a, b)) return true;
    if (a.lengthInBytes != b.lengthInBytes) return false;
    for (int i = 0; i < a.lengthInBytes; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<StatusProvider>(
      builder: (context, provider, _) {
        final StatusModel? status = provider.status;
        final awaiting = provider.awaitingNewPrintData;
        final newPrintReady = provider.newPrintReady;

        // If we're awaiting a new print session, clear any previously
        // frozen filename so the next job can set it when available.
        if (awaiting) {
          _frozenFileName = null;
        }

        // Freeze the file name once we observe it for the active print so
        // it does not change mid-print if backend later updates metadata.
        if (_frozenFileName == null &&
            status?.printData?.fileData?.name != null) {
          final name = status!.printData!.fileData!.name;
          // Only freeze when a job is active (printing or paused) so we
          // don't persist names for idle snapshots.
          if (status.isPrinting || status.isPaused) {
            _frozenFileName = name;
          }
        }
        // We do not expose elapsed awaiting time (private); could add later via provider getter.
        const int waitMillis = 0;
        // Provider handles polling, transitional flags (pause/cancel), thumbnail caching, and
        // exposes a typed StatusModel. The screen now focuses solely on presentation.

        // Show global loading while provider indicates loading, we have no status yet,
        // or while the thumbnail is still being prepared. For new prints we
        // continue to wait until the provider signals the print is ready
        // (we have active job+file metadata+thumbnail). For auto-open (newPrint
        // == false) we also show a spinner while the provider is still fetching
        // the thumbnail so the UI doesn't immediately render a stale/placeholder
        // preview. However, if the backend reports the job has already finished
        // (idle with layer data) or is canceled we should not remain in a
        // spinner indefinitely — render the final status instead.
        final bool finishedSnapshot =
            status?.isIdle == true && status?.layer != null;
        final bool canceledSnapshot = status?.isCanceled == true;

        final bool thumbnailLoadingForAutoOpen =
            !widget.newPrint && // only apply to auto-open path
                status != null &&
                (status.isPrinting || status.isPaused) &&
                !provider.thumbnailReady &&
                !finishedSnapshot &&
                !canceledSnapshot;

        if (_suppressOldStatus ||
            provider.isLoading ||
            provider.minSpinnerActive ||
            status == null ||
            thumbnailLoadingForAutoOpen ||
            // If this screen was opened as a new print, wait until the
            // provider reports the job is ready to display. But allow
            // finished/canceled snapshots through so the UI doesn't lock up.
            // If opened as a new print, wait until provider signals readiness
            // (active job + file metadata + thumbnail). Additionally, ensure
            // we have at least the file name (or have frozen it) before
            // dismissing the global spinner. Some backends report the job
            // active before file metadata arrives; keep showing the spinner
            // until the UI can display a stable filename.
            ((widget.newPrint &&
                    (awaiting ||
                        ((status.printData?.fileData?.name == null) &&
                            _frozenFileName == null))) &&
                !newPrintReady &&
                !finishedSnapshot &&
                !canceledSnapshot)) {
          return GlassApp(
            child: Scaffold(
              body: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(),
                    if (awaiting && waitMillis > 5000)
                      const Padding(
                        padding: EdgeInsets.only(top: 16.0),
                        child: Text(
                          'Waiting for printer to start…',
                          style: TextStyle(fontSize: 16),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        }

        if (provider.error != null) {
          return GlassApp(
            child: Scaffold(
              appBar: AppBar(title: const Text('Error')),
              body: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'An Error has occurred while fetching status!\n'
                      'Please ensure that Odyssey is running and accessible.\n\n'
                      'If the issue persists, please contact support.\n'
                      'Error Code: PINK-CARROT',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        // No active or last print data (only show when not in awaiting transitional phase)
        if (!awaiting && status.printData == null) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('No Print Data Available'),
            ),
            body: Center(
              child: GlassButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const GridFilesScreen(),
                    ),
                  );
                },
                child: const Padding(
                  padding: EdgeInsets.all(20),
                  child: Text(
                    'Go to Files',
                    style: TextStyle(fontSize: 26),
                  ),
                ),
              ),
            ),
          );
        }

        final elapsedStr = status.formattedElapsedPrintTime;
        // Trigger a one-time prefetch of 3D and current 2D layer thumbnails
        // when we first observe a valid status with file metadata.
        if (!_prefetched && status.printData?.fileData != null) {
          _prefetched = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            _prefetchThumbnails(status);
          });
        }

        // Proactively preload next layers when the reported layer changes.
        // Use a post-frame callback to perform async work outside build.
        if (status.layer != null &&
            status.printData?.fileData != null &&
            status.printData?.fileData?.path != _resolvedFilePathForPrefetch) {
          // File changed; clear previously-resolved plate id so we'll re-resolve.
          _resolvedFilePathForPrefetch = status.printData?.fileData?.path;
          _resolvedPlateIdForPrefetch = null;
          _lastPrefetchedLayer = null;
        }

        if (status.layer != null && status.layer != _lastPrefetchedLayer) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            _maybePreloadNextLayers(status);
          });
        }
        final fileName =
            _frozenFileName ?? status.printData?.fileData?.name ?? '';

        return GlassApp(
          child: Scaffold(
            appBar: AppBar(
              automaticallyImplyLeading: false,
              centerTitle: true,
              title: Builder(builder: (context) {
                final deviceMsg = provider.deviceStatusMessage;
                final statusText =
                    (deviceMsg != null && deviceMsg.trim().isNotEmpty)
                        ? deviceMsg
                        : provider.displayStatus;
                // Use a single base font size for both title lines so they appear
                // visually consistent. If the AppBar theme provides a title
                // fontSize, use that as the base; otherwise default to 14 and
                // reduce slightly.
                final baseFontSize =
                    (Theme.of(context).appBarTheme.titleTextStyle?.fontSize ??
                            14) -
                        10;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      fileName.isNotEmpty ? fileName : 'No file',
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context)
                          .appBarTheme
                          .titleTextStyle
                          ?.copyWith(
                            fontSize: baseFontSize,
                            fontWeight: FontWeight.normal,
                            color: Theme.of(context)
                                .appBarTheme
                                .titleTextStyle
                                ?.color
                                ?.withValues(alpha: 0.95),
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      statusText,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context)
                              .appBarTheme
                              .titleTextStyle
                              ?.merge(TextStyle(
                                fontWeight: FontWeight.normal,
                                fontSize: baseFontSize,
                              ))
                              .copyWith(
                                // Make status less visually dominant by lowering
                                // its alpha relative to the AppBar title color.
                                color: Theme.of(context)
                                    .appBarTheme
                                    .titleTextStyle
                                    ?.color
                                    ?.withValues(alpha: 0.65),
                              ) ??
                          TextStyle(
                            fontSize: baseFontSize,
                            fontWeight: FontWeight.normal,
                            color: Theme.of(context)
                                .appBarTheme
                                .titleTextStyle
                                ?.color
                                ?.withValues(alpha: 0.65),
                          ),
                    ),
                  ],
                );
              }),
            ),
            body: Center(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return _isLandscape
                      ? Padding(
                          padding: const EdgeInsets.only(
                            left: 16,
                            right: 16,
                            bottom: 20,
                          ),
                          child: _buildLandscapeLayout(
                            context,
                            provider,
                            status,
                            elapsedStr,
                            fileName,
                          ),
                        )
                      : Padding(
                          padding: const EdgeInsets.only(
                            left: 16,
                            right: 16,
                            bottom: 20,
                          ),
                          child: _buildPortraitLayout(
                            context,
                            provider,
                            status,
                            elapsedStr,
                            fileName,
                          ),
                        );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPortraitLayout(BuildContext context, StatusProvider provider,
      StatusModel? status, String elapsedStr, String fileName) {
    final statusModel = status;
    final layerCurrent = statusModel?.layer;
    final layerTotal = statusModel?.printData?.layerCount;
    final usedMaterial = statusModel?.printData?.usedMaterial;
    return Row(children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            Expanded(
              child: Column(
                children: [
                  _buildThumbnailView(context, provider, statusModel),
                  const Spacer(),
                  Row(children: [
                    Expanded(
                      child: _buildInfoCard(
                        'Current Z Position',
                        '${statusModel?.physicalState.z.toStringAsFixed(3) ?? '-'} mm',
                      ),
                    ),
                    Expanded(
                      child: _buildInfoCard(
                        'Print Layers',
                        layerCurrent == null || layerTotal == null
                            ? '- / -'
                            : '$layerCurrent / $layerTotal',
                      ),
                    ),
                  ]),
                  const SizedBox(height: 5),
                  _buildInfoCard('Estimated Print Time', elapsedStr),
                  const SizedBox(height: 5),
                  _buildInfoCard(
                    'Estimated Volume',
                    usedMaterial == null
                        ? '-'
                        : '${usedMaterial.toStringAsFixed(2)} mL',
                  ),
                  const Spacer(),
                  _buildButtons(provider, statusModel),
                ],
              ),
            ),
          ],
        ),
      )
    ]);
  }

  Widget _buildLandscapeLayout(BuildContext context, StatusProvider provider,
      StatusModel? status, String elapsedStr, String fileName) {
    final statusModel = status;
    final layerCurrent = statusModel?.layer;
    final layerTotal = statusModel?.printData?.layerCount;
    final usedMaterial = statusModel?.printData?.usedMaterial;
    return Column(children: [
      Expanded(
        child: Row(children: [
          Expanded(
            flex: 1,
            child: ListView(children: [
              _buildInfoCard(
                'Current Z Position',
                '${statusModel?.physicalState.z.toStringAsFixed(3) ?? '-'} mm',
              ),
              _buildInfoCard(
                'Print Layers',
                layerCurrent == null || layerTotal == null
                    ? '- / -'
                    : '$layerCurrent / $layerTotal',
              ),
              _buildInfoCard('Estimated Print Time', elapsedStr),
              _buildInfoCard(
                'Estimated Volume',
                usedMaterial == null
                    ? '-'
                    : '${usedMaterial.toStringAsFixed(2)} mL',
              ),
            ]),
          ),
          const SizedBox(width: 16.0),
          Flexible(
            flex: 0,
            child: _buildThumbnailView(context, provider, statusModel),
          ),
        ]),
      ),
      const SizedBox(height: 20),
      Padding(
        padding: const EdgeInsets.only(left: 5, right: 5),
        child: _buildButtons(provider, statusModel),
      ),
    ]);
  }

  Widget _buildInfoCard(String title, String subtitle) {
    Provider.of<ThemeProvider>(context); // theming
    return GlassCard(
      outlined: true,
      elevation: 1.0,
      child: ListTile(
        title: Text(title),
        subtitle: Text(subtitle),
      ),
    );
  }

  Widget _buildThumbnailView(
      BuildContext context, StatusProvider provider, StatusModel? status) {
    // Prefer provider's thumbnail bytes. If none yet, consider the
    // initialThumbnailBytes passed from the Details screen — but do not
    // show a generated placeholder as the initial preview while the
    // provider is still probing for a real preview. In that case show the
    // spinner until provider provides a non-placeholder or finishes.
    Uint8List? thumbnail;
    if (provider.thumbnailBytes != null) {
      thumbnail = provider.thumbnailBytes;
    } else if (widget.initialThumbnailBytes != null) {
      // Detect whether the provided initial bytes are the NanoDLP generated
      // placeholder. If so and provider isn't ready yet, prefer spinner.
      final placeholder = NanoDlpThumbnailGenerator.generatePlaceholder(
          NanoDlpThumbnailGenerator.largeWidth,
          NanoDlpThumbnailGenerator.largeHeight);
      bool isPlaceholder =
          widget.initialThumbnailBytes!.length == placeholder.length &&
              _bytesEqual(widget.initialThumbnailBytes!, placeholder);
      if (isPlaceholder && !provider.thumbnailReady) {
        thumbnail = null;
      } else {
        thumbnail = widget.initialThumbnailBytes;
      }
    } else {
      thumbnail = null;
    }
    final themeProvider = Provider.of<ThemeProvider>(context);
    final progress = provider.progress;
    final statusColor = provider.statusColor(context);
    final statusModel = provider.status;
    final finishedSnapshot =
        statusModel?.isIdle == true && statusModel?.layer != null;
    // Prefer canonical 'finished' hint from the parsed model.
    final effectivelyFinished = statusModel?.finished == true;
    final effectiveStatusColor = (finishedSnapshot && !effectivelyFinished)
        ? Theme.of(context).colorScheme.error
        : statusColor;
    return Center(
      child: GestureDetector(
        onTap: () {
          // Debounce toggles: ignore taps that occur within 500ms of the
          // previous toggle, and ignore while a layer load is in progress.
          final now = DateTime.now();
          if (_layer2DLoading) return;
          if (_lastLayerToggleTime != null &&
              now.difference(_lastLayerToggleTime!) <
                  const Duration(milliseconds: 500)) {
            return;
          }

          // Toggle 2D layer preview. If enabling, trigger fetch.
          final providerState =
              Provider.of<StatusProvider>(context, listen: false);
          setState(() {
            _showLayer2D = !_showLayer2D;
            _lastLayerToggleTime = now;
          });
          if (_showLayer2D) {
            _fetchLayer2D(providerState, statusModel);
          }
        },
        child: Stack(
          children: [
            GlassCard(
              outlined: true,
              elevation: 1.0,
              child: Padding(
                padding: const EdgeInsets.all(4.5),
                child: ClipRRect(
                  borderRadius: themeProvider.isGlassTheme
                      ? BorderRadius.circular(12.5)
                      : BorderRadius.circular(7.75),
                  child: Stack(children: [
                    // Base thumbnail / spinner
                    ColorFiltered(
                      colorFilter: const ColorFilter.matrix(<double>[
                        0.2126, 0.7152, 0.0722, 0, 0, // grayscale matrix
                        0.2126, 0.7152, 0.0722, 0, 0,
                        0.2126, 0.7152, 0.0722, 0, 0,
                        0, 0, 0, 1, 0,
                      ]),
                      child: thumbnail != null && thumbnail.isNotEmpty
                          ? Image.memory(
                              thumbnail,
                              fit: BoxFit.cover,
                            )
                          : Center(
                              child: CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(
                                    effectiveStatusColor),
                              ),
                            ),
                    ),

                    // Dim overlay
                    Positioned.fill(
                      child: Container(
                        color: Colors.black.withValues(alpha: 0.35),
                      ),
                    ),

                    // Progress wipe
                    Positioned.fill(
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: ClipRect(
                          child: Align(
                            alignment: Alignment.bottomCenter,
                            heightFactor: progress,
                            child: thumbnail != null && thumbnail.isNotEmpty
                                ? Image.memory(
                                    thumbnail,
                                    fit: BoxFit.cover,
                                  )
                                : Center(
                                    child: CircularProgressIndicator(
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                          effectiveStatusColor),
                                    ),
                                  ),
                          ),
                        ),
                      ),
                    ),

                    // 2D layer overlay (covers base thumbnail and status card when active)
                    if (_showLayer2D)
                      Positioned.fill(
                        child: _layer2DLoading
                            ? Center(
                                child: CircularProgressIndicator(
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      effectiveStatusColor),
                                ),
                              )
                            : (_layer2DImageProvider != null
                                ? Image(
                                    image: _layer2DImageProvider!,
                                    gaplessPlayback: true,
                                    fit: BoxFit.cover,
                                  )
                                : (_layer2DBytes != null &&
                                        _layer2DBytes!.isNotEmpty
                                    ? Image.memory(
                                        _layer2DBytes!,
                                        fit: BoxFit.cover,
                                      )
                                    : Center(
                                        child: Text('2D preview unavailable'),
                                      ))),
                      ),
                  ]),
                ),
              ),
            ),
            Positioned.fill(
              right: 15,
              child: Center(
                child: StatusCard(
                  isCanceling: provider.isCanceling,
                  isPausing: provider.isPausing,
                  progress: progress,
                  statusColor: effectiveStatusColor,
                  status: status,
                  showPercentage: !_showLayer2D,
                ),
              ),
            ),
            Positioned(
              top: 0,
              bottom: 0,
              right: 0,
              child: Padding(
                padding: const EdgeInsets.all(2),
                child: Builder(builder: (context) {
                  final isGlassTheme = themeProvider.isGlassTheme;
                  return GlassCard(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.only(
                        topRight: isGlassTheme
                            ? const Radius.circular(14.0)
                            : const Radius.circular(9.75),
                        bottomRight: isGlassTheme
                            ? const Radius.circular(14.0)
                            : const Radius.circular(9.75),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(2.5),
                      child: ClipRRect(
                        borderRadius: BorderRadius.only(
                          topRight: isGlassTheme
                              ? const Radius.circular(11.5)
                              : const Radius.circular(7.75),
                          bottomRight: isGlassTheme
                              ? const Radius.circular(11.5)
                              : const Radius.circular(7.75),
                        ),
                        child: RotatedBox(
                          quarterTurns: 3,
                          child: LinearProgressIndicator(
                            minHeight: 15,
                            color: effectiveStatusColor,
                            value: progress,
                            backgroundColor: isGlassTheme
                                ? effectiveStatusColor.withValues(alpha: 0.1)
                                : null,
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _fetchLayer2D(
      StatusProvider provider, StatusModel? status) async {
    if (status == null) return;
    final fileData = status.printData?.fileData;
    int? plateId;
    final layerIndex = status.layer;
    if (layerIndex == null) return;

    try {
      if (fileData != null) {
        final meta = await BackendService().getFileMetadata(
            fileData.locationCategory ?? 'Local', fileData.path);
        if (meta['plate_id'] != null) {
          plateId = meta['plate_id'] as int?;
        }
      }
    } catch (_) {
      plateId = widget.initialPlateId;
    }
    if (plateId == null) return;

    final cached = LayerPreviewCache.instance.get(plateId, layerIndex);
    if (cached != null) {
      setState(() {
        _layer2DBytes = cached;
        _layer2DImageProvider = MemoryImage(cached);
        _showLayer2D = true;
      });
      LayerPreviewCache.instance
          .preload(BackendService(), plateId, layerIndex, count: 2);
      return;
    }

    setState(() {
      _layer2DLoading = true;
    });
    try {
      final bytes = await LayerPreviewCache.instance
          .fetchAndCache(BackendService(), plateId, layerIndex);
      if (bytes.isNotEmpty) {
        final imgProv = MemoryImage(bytes);
        // Start precaching but don't await it — decoding can be expensive
        // and awaiting here can cause UI jank. Fire-and-forget instead.
        precacheImage(imgProv, context).catchError((_) {});
        setState(() {
          _layer2DBytes = bytes;
          _layer2DImageProvider = imgProv;
          _showLayer2D = true;
        });
        LayerPreviewCache.instance
            .preload(BackendService(), plateId, layerIndex, count: 2);
      }
    } catch (_) {
      // ignore
    } finally {
      setState(() {
        _layer2DLoading = false;
      });
    }
  }

  Future<void> _prefetchThumbnails(StatusModel status) async {
    // Prefetch the 3D thumbnail for the current file (Large) and the
    // current 2D layer (and preload next layers). Best-effort; ignore
    // any failures.
    try {
      final fileData = status.printData?.fileData;
      if (fileData != null) {
        // Prefetch 3D thumbnail (Large size) — fetch bytes and precache so
        // Flutter's image cache holds a decoded image for instant display.
        BackendService()
            .getFileThumbnail(
                fileData.locationCategory ?? 'Local', fileData.path, 'Large')
            .then((bytes) async {
          try {
            if (bytes.isNotEmpty) {
              await precacheImage(MemoryImage(bytes), context);
            }
          } catch (_) {
            // ignore precache failures
          }
        }, onError: (_) {});
      }
    } catch (_) {
      // ignore
    }

    // Prefetch current layer via LayerPreviewCache.fetchAndCache and
    // then preload n+1/n+2 layers.
    try {
      final layerIndex = status.layer;
      if (layerIndex == null) return;

      int? plateId;
      try {
        final fileData = status.printData?.fileData;
        if (fileData != null) {
          final meta = await BackendService().getFileMetadata(
              fileData.locationCategory ?? 'Local', fileData.path);
          if (meta['plate_id'] != null) {
            plateId = meta['plate_id'] as int?;
          }
        }
      } catch (_) {
        plateId = widget.initialPlateId;
      }
      if (plateId == null) return;

      // Use fetchAndCache to dedupe concurrent fetches.
      try {
        final bytes = await LayerPreviewCache.instance
            .fetchAndCache(BackendService(), plateId, layerIndex);
        if (bytes.isNotEmpty) {
          // If user already enabled 2D preview, immediately display the
          // prefetched current layer so the preview reflects the active
          // layer without requiring a manual toggle.
          if (mounted && _showLayer2D) {
            if (!(_layer2DBytes != null &&
                _bytesEqual(_layer2DBytes!, bytes))) {
              setState(() {
                _layer2DBytes = bytes;
                _layer2DImageProvider = MemoryImage(bytes);
              });
            }
          }
          // Fire off preloads for the next two layers in parallel; do not
          // await to avoid blocking the UI thread.
          for (int i = 1; i <= 2; i++) {
            final target = layerIndex + i;
            LayerPreviewCache.instance
                .fetchAndCache(BackendService(), plateId, target)
                .then((nextBytes) {
              if (nextBytes.isNotEmpty) {
                precacheImage(MemoryImage(nextBytes), context)
                    .catchError((_) {});
              }
            }).catchError((_) {});
          }
        }
      } catch (_) {
        // ignore
      }
    } catch (_) {
      // ignore
    }
  }

  Future<void> _maybePreloadNextLayers(StatusModel status) async {
    final layerIndex = status.layer;
    if (layerIndex == null) return;

    // Resolve plate id if not already resolved for current file path.
    int? plateId = _resolvedPlateIdForPrefetch;
    if (plateId == null) {
      try {
        final fileData = status.printData?.fileData;
        if (fileData != null) {
          final meta = await BackendService().getFileMetadata(
              fileData.locationCategory ?? 'Local', fileData.path);
          if (meta['plate_id'] != null) {
            plateId = meta['plate_id'] as int?;
            _resolvedPlateIdForPrefetch = plateId;
          }
        }
      } catch (_) {
        plateId = widget.initialPlateId;
        _resolvedPlateIdForPrefetch = plateId;
      }
    }
    if (plateId == null) return;

    try {
      // Ensure current layer is cached (deduped) then fetch+precache next two.
      // Fetch current layer (deduped) but don't block on any decoding.
      LayerPreviewCache.instance
          .fetchAndCache(BackendService(), plateId, layerIndex)
          .then((curBytes) {
        if (curBytes.isNotEmpty) {
          // Precache decoded image for faster rendering (fire-and-forget).
          precacheImage(MemoryImage(curBytes), context).catchError((_) {});
          // If the user currently has the 2D preview visible, immediately
          // update the displayed image so the preview follows the layer.
          if (mounted && _showLayer2D) {
            // Avoid re-setting if the bytes are identical.
            if (!(_layer2DBytes != null &&
                _bytesEqual(_layer2DBytes!, curBytes))) {
              setState(() {
                _layer2DBytes = curBytes;
                _layer2DImageProvider = MemoryImage(curBytes);
              });
            }
          }
        }
      }).catchError((_) {});

      // Launch preloads for the next two layers in parallel.
      for (int i = 1; i <= 2; i++) {
        final target = layerIndex + i;
        LayerPreviewCache.instance
            .fetchAndCache(BackendService(), plateId, target)
            .then((nextBytes) {
          if (nextBytes.isNotEmpty) {
            precacheImage(MemoryImage(nextBytes), context).catchError((_) {});
          }
        }).catchError((_) {});
      }
      _lastPrefetchedLayer = layerIndex;
    } catch (_) {
      // ignore
    }
  }

  Widget _buildButtons(StatusProvider provider, StatusModel? status) {
    final s = status;
    final isFinished = s != null && s.isIdle && s.layer != null;
    final isCanceled = s?.isCanceled ?? false;
    final canShowOptions =
        s != null && !isFinished && !isCanceled && s.layer != null;
    // Primary action button should be enabled in these cases:
    // * Active print (to allow pause/resume)
    // * Finished print (return home)
    // * Canceled print (return home)
    // Disabled when status not yet loaded, during cancel transition, or
    // while a pause is latched (provider.isPausing) and we're not already
    // in the paused state (i.e., disable the Pause action while it's
    // latched). Resume should still be enabled when paused.
    final isPaused = s?.isPaused ?? false;
    final pauseResumeEnabled = s != null &&
        !provider.isCanceling &&
        !(provider.isPausing && !isPaused);

    return Row(children: [
      Expanded(
        child: GlassButton(
          tint: GlassButtonTint.neutral,
          onPressed: (!canShowOptions || provider.isCanceling)
              ? null
              : () {
                  showDialog(
                    context: context,
                    builder: (ctx) {
                      Provider.of<ThemeProvider>(ctx);
                      final buttonStyle = ElevatedButton.styleFrom(
                        minimumSize: const Size(120, 65),
                        maximumSize: const Size(120, 65),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                      );
                      return GlassDialog(
                        padding: const EdgeInsets.all(8),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(height: 10),
                            const Padding(
                              padding: EdgeInsets.all(8.0),
                              child: Text(
                                'Options',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 20),
                              child: SizedBox(
                                height: 65,
                                width: 450,
                                child: GlassButton(
                                  tint: GlassButtonTint.neutral,
                                  style: buttonStyle,
                                  onPressed: () {
                                    Navigator.pop(ctx);
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            const SettingsScreen(),
                                      ),
                                    );
                                  },
                                  child: const Text(
                                    'Settings',
                                    style: TextStyle(fontSize: 24),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 20),
                              child: SizedBox(
                                height: 65,
                                width: 450,
                                child: HoldButton(
                                  tint: GlassButtonTint.negative,
                                  style: buttonStyle,
                                  duration: const Duration(seconds: 2),
                                  onPressed: () {
                                    Navigator.pop(ctx);
                                    provider.cancel();
                                  },
                                  child: const Text(
                                    'Cancel Print',
                                    style: TextStyle(fontSize: 24),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                          ],
                        ),
                      );
                    },
                  );
                },
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(120, 65),
            maximumSize: const Size(120, 65),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
          ),
          child: const Text('Options', style: TextStyle(fontSize: 24)),
        ),
      ),
      const SizedBox(width: 20),
      Expanded(
        child: GlassButton(
          tint: isCanceled || isFinished
              ? GlassButtonTint.neutral
              : isPaused
                  ? GlassButtonTint.positive
                  : GlassButtonTint.warn,
          onPressed: !pauseResumeEnabled
              ? null
              : () {
                  if (isCanceled || isFinished) {
                    // Navigate home first so the status reset does not briefly
                    // render a spinner on the StatusScreen just before popping.
                    Navigator.popUntil(context, ModalRoute.withName('/'));
                    // Defer reset until after navigation settles; we only care
                    // about showing a clean spinner on the NEXT status visit.
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      final mountedContext = context;
                      // Provider still available via root; safe to reset.
                      try {
                        mountedContext.read<StatusProvider>().resetStatus();
                      } catch (_) {
                        // If provider no longer in tree (unlikely), ignore.
                      }
                    });
                    return;
                  }
                  if (s.isIdle && s.layer == null) {
                    Navigator.pop(context);
                    return;
                  }
                  provider.pauseOrResume();
                },
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(120, 65),
            maximumSize: const Size(120, 65),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
          ),
          child: AutoSizeText(
            minFontSize: 16,
            maxLines: 1,
            (isCanceled || isFinished)
                ? 'Return to Home'
                : isPaused
                    ? 'Resume'
                    : 'Pause',
            style: const TextStyle(fontSize: 24),
          ),
        ),
      ),
    ]);
  }
}

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

import 'dart:io';

import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:orion/files/grid_files_screen.dart';
import 'package:orion/glasser/glasser.dart';
import 'package:orion/settings/settings_screen.dart';
import 'package:orion/util/hold_button.dart';
import 'package:orion/util/providers/theme_provider.dart';
import 'package:orion/util/status_card.dart';
import 'package:orion/backend_service/providers/status_provider.dart';
import 'package:orion/backend_service/odyssey/models/status_models.dart';

class StatusScreen extends StatefulWidget {
  final bool newPrint;
  const StatusScreen({super.key, required this.newPrint});

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
  // Presentation-local state (derived values computed per build instead of storing)
  bool get _isLandscape =>
      MediaQuery.of(context).orientation == Orientation.landscape;
  int get _maxNameLength => _isLandscape ? 12 : 24;

  String _truncateFileName(String name) => name.length >= _maxNameLength
      ? '${name.substring(0, _maxNameLength)}...'
      : name;

  // Duration formatting moved to StatusModel.formattedElapsedPrintTime

  @override
  void initState() {
    super.initState();
    if (widget.newPrint) {
      _suppressOldStatus = true; // force spinner for fresh print session
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        context.read<StatusProvider>().resetStatus();
        setState(() => _suppressOldStatus = false);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<StatusProvider>(
      builder: (context, provider, _) {
        final StatusModel? status = provider.status;
        final awaiting = provider.awaitingNewPrintData;
        final newPrintReady = provider.newPrintReady;
        // We do not expose elapsed awaiting time (private); could add later via provider getter.
        const int waitMillis = 0;
        // Provider handles polling, transitional flags (pause/cancel), thumbnail caching, and
        // exposes a typed StatusModel. The screen now focuses solely on presentation.

        // Show global loading while provider indicates loading, we have no status yet,
        // or we are in the transitional window awaiting initial print data to avoid
        // an empty flicker state.
        if (_suppressOldStatus ||
            provider.isLoading ||
            status == null ||
            (awaiting && !newPrintReady)) {
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
        final fileName = status.printData?.fileData?.name ?? '';

        return GlassApp(
          child: Scaffold(
            appBar: AppBar(
              automaticallyImplyLeading: false,
              title: RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: 'Print Status',
                      style: Theme.of(context).appBarTheme.titleTextStyle,
                    ),
                    TextSpan(
                      text: ' - ',
                      style: Theme.of(context).appBarTheme.titleTextStyle,
                    ),
                    TextSpan(
                      text: provider.displayStatus,
                      style: Theme.of(context).appBarTheme.titleTextStyle,
                    ),
                  ],
                ),
              ),
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
            _buildNameCard(fileName, provider),
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
                            : '${layerCurrent + 1} / ${layerTotal + 1}',
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
              _buildNameCard(fileName, provider),
              _buildInfoCard(
                'Current Z Position',
                '${statusModel?.physicalState.z.toStringAsFixed(3) ?? '-'} mm',
              ),
              _buildInfoCard(
                'Print Layers',
                layerCurrent == null || layerTotal == null
                    ? '- / -'
                    : '${layerCurrent + 1} / ${layerTotal + 1}',
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

  Widget _buildNameCard(String fileName, StatusProvider provider) {
    final truncated = _truncateFileName(fileName);
    final color = provider.statusColor(context);
    return GlassCard(
      outlined: true,
      child: ListTile(
        title: AutoSizeText.rich(
          maxLines: 1,
          minFontSize: 16,
          TextSpan(children: [
            TextSpan(
              text: truncated,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _buildThumbnailView(
      BuildContext context, StatusProvider provider, StatusModel? status) {
    final thumbnail = provider.thumbnailPath;
    final themeProvider = Provider.of<ThemeProvider>(context);
    final progress = provider.progress;
    final statusColor = provider.statusColor(context);
    return Center(
      child: Stack(
        children: [
          GlassCard(
            outlined: true,
            elevation: 1.0,
            child: Padding(
              padding: const EdgeInsets.all(4.5),
              child: ClipRRect(
                borderRadius: themeProvider.isGlassTheme
                    ? BorderRadius.circular(10.5)
                    : BorderRadius.circular(7.75),
                child: Stack(children: [
                  ColorFiltered(
                    colorFilter: const ColorFilter.matrix(<double>[
                      0.2126, 0.7152, 0.0722, 0, 0, // grayscale matrix
                      0.2126, 0.7152, 0.0722, 0, 0,
                      0.2126, 0.7152, 0.0722, 0, 0,
                      0, 0, 0, 1, 0,
                    ]),
                    child: thumbnail != null && thumbnail.isNotEmpty
                        ? Image.file(
                            File(thumbnail),
                            fit: BoxFit.cover,
                          )
                        : const Center(child: CircularProgressIndicator()),
                  ),
                  Positioned.fill(
                    child: Container(
                      color: Colors.black.withValues(alpha: 0.35),
                    ),
                  ),
                  Positioned.fill(
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: ClipRect(
                        child: Align(
                          alignment: Alignment.bottomCenter,
                          heightFactor: progress,
                          child: thumbnail != null && thumbnail.isNotEmpty
                              ? Image.file(
                                  File(thumbnail),
                                  fit: BoxFit.cover,
                                )
                              : const Center(
                                  child: CircularProgressIndicator(),
                                ),
                        ),
                      ),
                    ),
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
                statusColor: statusColor,
                status: status,
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
                return Card(
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
                          minHeight: 30,
                          color: statusColor,
                          value: progress,
                          backgroundColor: isGlassTheme
                              ? Colors.white.withValues(alpha: 0.1)
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
    );
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
    // Disabled only when status not yet loaded or during cancel transition.
    final pauseResumeEnabled = s != null && (!provider.isCanceling);
    final isPaused = s?.isPaused ?? false;

    return Row(children: [
      Expanded(
        child: GlassButton(
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

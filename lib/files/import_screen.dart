/*
* Orion - Import Screen
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
import 'package:flutter_i18n/flutter_i18n.dart';
import 'package:logging/logging.dart';
import 'package:provider/provider.dart';
import 'package:path/path.dart' as path;

import 'package:orion/glasser/glasser.dart';
import 'package:orion/util/widgets/system_status_widget.dart';
import 'package:orion/widgets/orion_app_bar.dart';
import 'package:orion/util/orion_kb/orion_textfield_spawn.dart';
import 'package:orion/util/orion_kb/orion_keyboard_expander.dart';
import 'package:orion/backend_service/providers/resins_provider.dart';
import 'package:orion/backend_service/backend_service.dart';
import 'package:orion/backend_service/domain/models.dart';
import 'package:orion/backend_service/providers/files_provider.dart';
import 'package:orion/backend_service/odyssey/models/files_models.dart';
import 'package:orion/files/details_screen.dart';
import 'package:orion/files/import_progress_overlay.dart';
import 'package:orion/util/orion_api_filesystem/orion_api_file.dart';
import 'package:orion/util/orion_spacing.dart';
import 'package:orion/widgets/selection_screens.dart';

class ImportScreen extends StatefulWidget {
  final String fileName;
  final String filePath;

  const ImportScreen({
    super.key,
    required this.fileName,
    required this.filePath,
  });

  @override
  ImportScreenState createState() => ImportScreenState();
}

class ImportScreenState extends State<ImportScreen> {
  final _logger = Logger('ImportScreen');

  final GlobalKey<SpawnOrionTextFieldState> _jobNameKey =
      GlobalKey<SpawnOrionTextFieldState>();

  String? _selectedResinKey;

  @override
  void initState() {
    super.initState();
    // Ensure resin profiles are fetched when import screen opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<ResinsProvider>(context, listen: false);
      // If list is empty and not currently loading, trigger a refresh
      if (provider.resins.isEmpty && !provider.isLoading) {
        provider.refresh();
      }
    });
  }

  String _defaultJobName() {
    return path.basenameWithoutExtension(widget.fileName);
  }

  bool _isStlFile() {
    return widget.fileName.toLowerCase().endsWith('.stl');
  }

  Future<void> _deleteLocalFile() async {
    try {
      final file = File(widget.filePath);
      if (await file.exists()) {
        await file.delete();
      }
      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e, st) {
      _logger.warning('Failed to delete local file', e, st);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text(FlutterI18n.translate(context, 'files.failedToDelete'))),
        );
      }
    }
  }

  Future<void> _importFile() async {
    final jobName =
        _jobNameKey.currentState?.getCurrentText().trim() ?? _defaultJobName();

    if (jobName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text(FlutterI18n.translate(context, 'import.enterJobName'))),
      );
      return;
    }

    if (_selectedResinKey == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text(FlutterI18n.translate(context, 'import.selectMaterial'))),
      );
      return;
    }

    // Create notifiers for progress overlay
    final progressNotifier = ValueNotifier<double>(0.0);
    final messageNotifier = ValueNotifier<String>(
        FlutterI18n.translate(context, 'import.preparing'));
    final titleNotifier = ValueNotifier<String>(
        FlutterI18n.translate(context, 'import.importingFile'));

    // Show import progress overlay
    late final navigator = Navigator.of(context);
    late final messenger = ScaffoldMessenger.of(context);
    if (mounted) {
      navigator.push(
        MaterialPageRoute(
          builder: (context) => ImportProgressOverlay(
            progress: progressNotifier,
            message: messageNotifier,
            title: titleNotifier,
          ),
          fullscreenDialog: true,
        ),
      );
    }

    try {
      messageNotifier.value =
          FlutterI18n.translate(context, 'import.uploading');
      progressNotifier.value = 0.05;

      final resinsProvider =
          Provider.of<ResinsProvider>(context, listen: false);
      final resins = resinsProvider.userResins;
      final selectedResin = resins.firstWhere(
        (r) => (r.path ?? r.name) == _selectedResinKey,
        orElse: () => resins.first,
      );

      // Extract profile ID from the resin profile key.
      final profileKey = selectedResin.path ?? selectedResin.name;
      final profileId = int.tryParse(profileKey);
      if (profileId == null) {
        throw Exception('Invalid profile ID: $profileKey');
      }

      // Create a backend service instance to import the file
      final backendService = BackendService();

      // Capture current file list so we can detect the newly imported file
      final filesProvider = FilesProvider(client: backendService);
      final existingItems =
          await filesProvider.listItemsAsOrionApiItems('Local', '');
      final existingKeys = existingItems
          .whereType<OrionApiFile>()
          .map((f) => _fileKey(f))
          .toSet();

      final importRequest = FileImportRequest(
        usbFilePath: widget.filePath,
        jobName: jobName,
        profileId: profileId,
      );

      final plateId = await backendService.importFile(importRequest);

      if (mounted) {
        messageNotifier.value =
            FlutterI18n.translate(context, 'calibration.processingFile');

        // Poll for the newly imported file to appear with valid metadata
        bool fileReady = false;
        int pollAttempts = 0;
        const maxAttempts =
            50; // 50 attempts * 300ms = 15 seconds max (NanoDLP needs time to process)

        while (!fileReady && pollAttempts < maxAttempts && mounted) {
          await Future.delayed(const Duration(milliseconds: 300));
          pollAttempts++;

          try {
            backendService.invalidateFilesCache();
            final items =
                await filesProvider.listItemsAsOrionApiItems('Local', '');

            // Find the imported file: prefer plate ID when available, otherwise diff or name match
            OrionApiFile? newFile;
            if (plateId != null) {
              newFile = items.whereType<OrionApiFile>().firstWhere(
                    (item) => item.plateId?.toString() == plateId.toString(),
                    orElse: () => throw Exception('File not found'),
                  );
            } else {
              // Try diff against the pre-import snapshot
              final newCandidates = items
                  .whereType<OrionApiFile>()
                  .where((item) => !existingKeys.contains(_fileKey(item)))
                  .toList();

              // Prefer a candidate that matches the requested job name
              if (newCandidates.isNotEmpty) {
                newFile = newCandidates.firstWhere(
                  (item) => _matchesJobName(item, jobName),
                  orElse: () => newCandidates.first,
                );
              }

              // If no diff was detected, fall back to a name match in the full list
              newFile ??= items.whereType<OrionApiFile>().firstWhere(
                    (item) => _matchesJobName(item, jobName),
                    orElse: () => throw Exception('File not found'),
                  );
            }

            // Check if metadata is populated (NanoDLP may take time to fill fields)
            final metaPath = _metadataPathForFile(newFile);
            final meta =
                await filesProvider.fetchFileMetadata('Local', metaPath);
            final metaReady = _isMetadataReady(meta);
            final listReady =
                (newFile.layerHeight != null && newFile.layerHeight! > 0) ||
                    (newFile.layerCount != null && newFile.layerCount! > 0) ||
                    (newFile.printTime != null && newFile.printTime! > 0);

            if (metaReady || listReady) {
              fileReady = true;
              if (_isStlFile()) {
                progressNotifier.value = 0.5;
                await _pollSlicerProgress(
                  progressNotifier,
                  messageNotifier,
                  baseProgress: 0.5,
                  span: 0.5,
                  titleNotifier: titleNotifier,
                );
              } else {
                progressNotifier.value = 1.0;
                messageNotifier.value =
                    FlutterI18n.translate(context, 'import.importComplete');
              }

              // Wait a moment for the UI to show completion, then navigate
              await Future.delayed(const Duration(milliseconds: 800));

              if (mounted) {
                // Close overlay and navigate to DetailsScreen
                navigator.pop(); // Close overlay

                final result = await navigator.push(
                  MaterialPageRoute(
                    builder: (context) => DetailScreen(
                      fileName: newFile!.name,
                      fileSubdirectory: '',
                      fileLocation: 'Local',
                      returnToLocalOnPop: true,
                    ),
                  ),
                );
                if (mounted) {
                  navigator.pop(
                    result ?? <String, dynamic>{'switchToLocal': true},
                  );
                }
              }
            } else {
              // File found but metadata not ready yet, update progress
              final progress =
                  (pollAttempts / maxAttempts).clamp(0.0, 1.0) * 0.5;
              progressNotifier.value = progress;
            }
          } catch (e) {
            if (pollAttempts >= maxAttempts && mounted) {
              // Timeout waiting for file/metadata
              messageNotifier.value = FlutterI18n.translate(
                  context, 'import.importCompletePending');
              progressNotifier.value = 1.0;

              await Future.delayed(const Duration(milliseconds: 800));

              if (mounted) {
                navigator.pop(); // Close overlay
                navigator.pop(true); // Go back to files screen
              }
            }
          }
        }
      }
    } catch (e, st) {
      _logger.severe('Failed to import file', e, st);
      if (mounted) {
        messageNotifier.value =
            FlutterI18n.translate(context, 'import.importFailed');
        progressNotifier.value = 0.0;

        await Future.delayed(const Duration(milliseconds: 1000));
        if (!context.mounted) return;

        navigator.pop(); // Close overlay

        messenger.showSnackBar(
          SnackBar(
              content: Text(
                  '${FlutterI18n.translate(context, 'import.failedToImport').replaceAll('%s', e.toString())}')),
        );
      }
    }
  }

  String _fileKey(OrionApiFile file) {
    final pathPart = file.path.trim().toLowerCase();
    final namePart = file.name.trim().toLowerCase();
    return '$pathPart|$namePart';
  }

  bool _matchesJobName(OrionApiFile file, String jobName) {
    final normalizedJob = jobName.trim().toLowerCase();
    if (normalizedJob.isEmpty) return false;
    final name = file.name.trim().toLowerCase();
    final path = file.path.trim().toLowerCase();
    return name.contains(normalizedJob) || path.contains(normalizedJob);
  }

  String _metadataPathForFile(OrionApiFile file) {
    final pathValue = file.path.trim();
    if (pathValue.isNotEmpty) return pathValue;
    return file.name.trim();
  }

  bool _isMetadataReady(FileMetadata? meta) {
    if (meta == null) return false;
    if (meta.layerHeight != null && meta.layerHeight! > 0) return true;
    if (meta.printTime != null && meta.printTime! > 0) return true;
    if (meta.usedMaterial != null && meta.usedMaterial! > 0) return true;
    if (meta.fileData.lastModified > 0) return true;
    return false;
  }

  Future<void> _pollSlicerProgress(ValueNotifier<double> progressNotifier,
      ValueNotifier<String> messageNotifier,
      {double baseProgress = 0.0,
      double span = 1.0,
      ValueNotifier<String>? titleNotifier}) async {
    messageNotifier.value =
        FlutterI18n.translate(context, 'import.dragonfruit');

    final startTime = DateTime.now();
    const timeout = Duration(minutes: 15);
    bool sawReset = false;
    bool sawProgress = false;

    while (mounted) {
      final progress = await BackendService().getSlicerProgress();

      if (progress == null) {
        if (!sawProgress) {
          messageNotifier.value =
              FlutterI18n.translate(context, 'import.waitingSlicer');
        }
        progressNotifier.value = baseProgress;
      } else {
        sawProgress = true;
        final raw = progress < 0 ? 0.0 : progress;
        final normalizedValue = raw > 1.0 ? (raw / 100.0) : raw;
        final clamped = normalizedValue.clamp(0.0, 1.0);

        // Ignore stale 100% from a previous slice until we observe a reset.
        if (!sawReset && clamped >= 0.99) {
          messageNotifier.value =
              FlutterI18n.translate(context, 'import.waitingSlicer');
          progressNotifier.value = baseProgress;
        } else {
          if (clamped < 0.95) {
            sawReset = true;
          }
          if (sawReset) {
            titleNotifier?.value =
                FlutterI18n.translate(context, 'import.slicingJob');
          }
          messageNotifier.value =
              FlutterI18n.translate(context, 'import.dragonfruit');
          final normalized = clamped.clamp(0.0, 0.99);
          progressNotifier.value = baseProgress + (normalized * span);
        }

        if (sawReset && clamped >= 0.99) {
          messageNotifier.value =
              FlutterI18n.translate(context, 'import.slicedSuccess');
          progressNotifier.value = baseProgress + span;
          break;
        }
      }

      if (DateTime.now().difference(startTime) > timeout) {
        messageNotifier.value =
            FlutterI18n.translate(context, 'import.slicedTimeout');
        break;
      }

      await Future.delayed(const Duration(seconds: 1));
    }
  }

  Future<void> _sliceFile() async {
    await _importFile();
  }

  @override
  Widget build(BuildContext context) {
    return GlassApp(
      child: Scaffold(
        appBar: OrionAppBar(
          actions: const [SystemStatusWidget()],
          toolbarHeight: Theme.of(context).appBarTheme.toolbarHeight,
          title: Text(FlutterI18n.translate(context, 'common.back')),
        ),
        body: Padding(
          padding: OrionSpacing.screenPadding,
          child: Column(
            children: [
              Expanded(
                flex: 1,
                child: _buildJobNameField(context),
              ),
              const SizedBox(height: 16),
              Expanded(
                flex: 1,
                child: _buildMaterialSelector(context),
              ),
              const SizedBox(height: 24),
              _buildActionButtons(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildJobNameField(BuildContext context) {
    return GlassCard(
      outlined: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: SpawnOrionTextField(
                  key: _jobNameKey,
                  keyboardHint:
                      FlutterI18n.translate(context, 'import.jobName'),
                  locale: Localizations.localeOf(context).toString(),
                  presetText: _defaultJobName(),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: OrionKbExpander(textFieldKey: _jobNameKey),
          ),
        ],
      ),
    );
  }

  Widget _buildMaterialSelector(BuildContext context) {
    final provider = Provider.of<ResinsProvider>(context);

    if (provider.isLoading) {
      return GlassCard(
        outlined: true,
        child: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (provider.error != null) {
      return GlassCard(
        outlined: true,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(FlutterI18n.translate(context, 'import.failedLoadMaterials')),
            const SizedBox(height: 16),
            GlassButton(
              onPressed: provider.refresh,
              child: Text(FlutterI18n.translate(context, 'common.retry')),
            ),
          ],
        ),
      );
    }

    final resins = provider.userResins;
    if (resins.isEmpty) {
      return GlassCard(
        outlined: true,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(FlutterI18n.translate(context, 'import.materialProfile'),
                  style: TextStyle(fontSize: 16)),
              const SizedBox(height: 8),
              Text(FlutterI18n.translate(context, 'import.noProfilesFound'),
                  style: TextStyle(fontSize: 14, color: Colors.grey)),
              const SizedBox(height: 16),
              GlassButton(
                onPressed: provider.refresh,
                child: Text(FlutterI18n.translate(context, 'common.retry')),
              ),
            ],
          ),
        ),
      );
    }

    // Find selected resin object for display
    ResinProfile? selectedResin;
    if (_selectedResinKey != null) {
      selectedResin = resins.firstWhere(
        (r) => (r.path ?? r.name) == _selectedResinKey,
        orElse: () => resins.first,
      );
    }
    // Default to active resin if available
    if (selectedResin == null) {
      selectedResin = resins.firstWhere(
        (r) => (r.path ?? r.name) == provider.activeResinKey,
        orElse: () => resins.first,
      );
      _selectedResinKey = selectedResin.path ?? selectedResin.name;
    }

    return GlassCard(
      outlined: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _selectResinProfile(resins),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: Text(
                FlutterI18n.translate(context, 'import.materialProfile'),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
            Expanded(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            AutoSizeText(
                              selectedResin.name,
                              maxLines: 2,
                              minFontSize: 14,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w500,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right,
                          color: Colors.grey.shade400, size: 24),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _selectResinProfile(List<ResinProfile> resins) async {
    if (resins.isEmpty) {
      return;
    }

    final selectedKey = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) => _ImportResinProfilePickerScreen(
          resins: resins,
          selectedResinKey: _selectedResinKey,
        ),
      ),
    );

    if (selectedKey == null || !mounted) return;
    setState(() {
      _selectedResinKey = selectedKey;
    });
  }

  Widget _buildActionButtons(BuildContext context) {
    return Row(
      children: [
        Expanded(
          flex: 1,
          child: GlassButton(
            tint: GlassButtonTint.negative,
            wantIcon: false,
            onPressed: () {
              _deleteLocalFile();
            },
            style: ElevatedButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              minimumSize: const Size(0, 65),
            ),
            child: Text(
              FlutterI18n.translate(context, 'common.delete'),
              style: const TextStyle(fontSize: 20),
              textAlign: TextAlign.center,
            ),
          ),
        ),
        const SizedBox(width: 20),
        Expanded(
          flex: 1,
          child: GlassButton(
            tint: GlassButtonTint.positive,
            onPressed: _isStlFile() ? _sliceFile : _importFile,
            style: ElevatedButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              minimumSize: const Size(0, 65),
            ),
            child: Text(
              _isStlFile()
                  ? FlutterI18n.translate(context, 'common.slice')
                  : FlutterI18n.translate(context, 'common.import_'),
              style: const TextStyle(fontSize: 22),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ],
    );
  }
}

class _ImportResinProfilePickerScreen extends StatelessWidget {
  final List<ResinProfile> resins;
  final String? selectedResinKey;

  const _ImportResinProfilePickerScreen({
    required this.resins,
    required this.selectedResinKey,
  });

  @override
  Widget build(BuildContext context) {
    return ResinProfileSelectionScreen(
      title: FlutterI18n.translate(context, 'calibration.selectResin'),
      resins: resins,
      selectedResinKey: selectedResinKey,
      onSelected: (resin) {
        Navigator.of(context).pop(resin.path ?? resin.name);
      },
    );
  }
}

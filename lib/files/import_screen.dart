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
import 'package:orion/backend_service/nanodlp/models/nano_import_request.dart';
import 'package:orion/backend_service/providers/files_provider.dart';
import 'package:orion/backend_service/odyssey/models/files_models.dart';
import 'package:orion/files/details_screen.dart';
import 'package:orion/files/import_progress_overlay.dart';
import 'package:orion/util/orion_api_filesystem/orion_api_file.dart';

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
          const SnackBar(content: Text('Failed to delete file')),
        );
      }
    }
  }

  Future<void> _importFile() async {
    final jobName =
        _jobNameKey.currentState?.getCurrentText().trim() ?? _defaultJobName();

    if (jobName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a job name')),
      );
      return;
    }

    if (_selectedResinKey == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a material profile')),
      );
      return;
    }

    // Create notifiers for progress overlay
    final progressNotifier = ValueNotifier<double>(0.0);
    final messageNotifier = ValueNotifier<String>('Preparing import...');
    final titleNotifier = ValueNotifier<String>('IMPORTING FILE');

    // Show import progress overlay
    if (mounted) {
      Navigator.of(context).push(
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
      messageNotifier.value = 'Uploading file...';
      progressNotifier.value = 0.05;

      final resinsProvider =
          Provider.of<ResinsProvider>(context, listen: false);
      final resins = resinsProvider.userResins;
      final selectedResin = resins.firstWhere(
        (r) => (r.path ?? r.name) == _selectedResinKey,
        orElse: () => resins.first,
      );

      // Extract profile ID from the resin profile
      final profileId = selectedResin.path ?? selectedResin.name;

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

      final importRequest = NanoImportRequest(
        usbFilePath: widget.filePath,
        jobName: jobName,
        profileId: profileId,
      );

      final plateId = await backendService.importFile(importRequest);

      if (mounted) {
        messageNotifier.value = 'Processing file metadata...';

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
                    (item) => item.file == plateId.toString(),
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
                messageNotifier.value = 'Import complete!';
              }

              // Wait a moment for the UI to show completion, then navigate
              await Future.delayed(const Duration(milliseconds: 800));

              if (mounted) {
                // Close overlay and navigate to DetailsScreen
                Navigator.of(context).pop(); // Close overlay

                final result = await Navigator.of(context).push(
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
                  Navigator.of(context).pop(
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
              messageNotifier.value = 'Import complete (metadata pending)';
              progressNotifier.value = 1.0;

              await Future.delayed(const Duration(milliseconds: 800));

              if (mounted) {
                Navigator.of(context).pop(); // Close overlay
                Navigator.of(context).pop(true); // Go back to files screen
              }
            }
          }
        }
      }
    } catch (e, st) {
      _logger.severe('Failed to import file', e, st);
      if (mounted) {
        messageNotifier.value = 'Import failed!';
        progressNotifier.value = 0.0;

        await Future.delayed(const Duration(milliseconds: 1000));

        Navigator.of(context).pop(); // Close overlay

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to import file: $e')),
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
    messageNotifier.value = 'Ever tried DragonFruit? It\'s delicious!';

    final startTime = DateTime.now();
    const timeout = Duration(minutes: 15);
    bool sawReset = false;
    bool sawProgress = false;

    while (mounted) {
      final progress = await BackendService().getSlicerProgress();

      if (progress == null) {
        if (!sawProgress) {
          messageNotifier.value = 'Waiting for slicer to start...';
        }
        progressNotifier.value = baseProgress;
      } else {
        sawProgress = true;
        final raw = progress < 0 ? 0.0 : progress;
        final normalizedValue = raw > 1.0 ? (raw / 100.0) : raw;
        final clamped = normalizedValue.clamp(0.0, 1.0);

        // Ignore stale 100% from a previous slice until we observe a reset.
        if (!sawReset && clamped >= 0.99) {
          messageNotifier.value = 'Waiting for slicer to start...';
          progressNotifier.value = baseProgress;
        } else {
          if (clamped < 0.95) {
            sawReset = true;
          }
          if (sawReset) {
            titleNotifier?.value = 'SLICING JOB';
          }
          messageNotifier.value = 'Ever tried DragonFruit? It\'s delicious!';
          final normalized = clamped.clamp(0.0, 0.99);
          progressNotifier.value = baseProgress + (normalized * span);
        }

        if (sawReset && clamped >= 0.99) {
          messageNotifier.value = 'File sliced successfully!';
          progressNotifier.value = baseProgress + span;
          break;
        }
      }

      if (DateTime.now().difference(startTime) > timeout) {
        messageNotifier.value = 'Slicing timed out';
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
          title: const Text('Back'),
        ),
        body: Padding(
          padding: const EdgeInsets.all(16),
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
                  keyboardHint: 'Job Name',
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
            const Text('Failed to load material profiles'),
            const SizedBox(height: 16),
            GlassButton(
              onPressed: provider.refresh,
              child: const Text('Retry'),
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
              const Text('Material Profile', style: TextStyle(fontSize: 16)),
              const SizedBox(height: 8),
              const Text('No material profiles found',
                  style: TextStyle(fontSize: 14, color: Colors.grey)),
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
                'Material Profile',
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

    await showDialog(
      context: context,
      builder: (context) => GlassDialog(
        padding: EdgeInsets.zero,
        child: SizedBox(
          width: MediaQuery.of(context).size.width * 0.9,
          height: MediaQuery.of(context).size.height * 0.8,
          child: Column(
            children: [
              // Header Section
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color:
                          Theme.of(context).dividerColor.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.water_drop, size: 24),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Select Resin Profile',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    if (_selectedResinKey != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          resins
                              .firstWhere(
                                (r) => (r.path ?? r.name) == _selectedResinKey,
                                orElse: () => resins.first,
                              )
                              .name,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close, size: 20),
                      padding: const EdgeInsets.all(4),
                      constraints:
                          const BoxConstraints(minWidth: 32, minHeight: 32),
                      tooltip: 'Close',
                    ),
                  ],
                ),
              ),

              // Content Section
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: ListView.separated(
                    itemCount: resins.length,
                    separatorBuilder: (ctx, i) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final resin = resins[index];
                      final resinKey = resin.path ?? resin.name;
                      final isSelected = _selectedResinKey == resinKey;
                      final meta = resin.meta;
                      final parts = <String>[];
                      if (meta['viscosity'] != null) {
                        parts.add('Viscosity: ${meta['viscosity']}');
                      }
                      if (meta['exposure'] != null) {
                        parts.add('Exposure: ${meta['exposure']}');
                      }

                      return GlassCard(
                        elevation: isSelected ? 2.0 : 1.0,
                        outlined: true,
                        color: isSelected
                            ? Theme.of(context)
                                .colorScheme
                                .primaryContainer
                                .withValues(alpha: 0.3)
                            : null,
                        child: InkWell(
                          onTap: () {
                            setState(() {
                              _selectedResinKey = resinKey;
                            });
                            Navigator.of(context).pop();
                          },
                          borderRadius: BorderRadius.circular(16),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 20),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        resin.name,
                                        style: TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.w500,
                                          color: isSelected
                                              ? Theme.of(context)
                                                  .colorScheme
                                                  .primary
                                              : null,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      if (parts.isNotEmpty) ...[
                                        const SizedBox(height: 6),
                                        Text(
                                          parts.join(' • '),
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Theme.of(context)
                                                .textTheme
                                                .bodySmall
                                                ?.color,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Container(
                                  width: 28,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? Theme.of(context).colorScheme.primary
                                        : Colors.transparent,
                                    border: isSelected
                                        ? null
                                        : Border.all(
                                            color:
                                                Theme.of(context).dividerColor,
                                            width: 2),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: isSelected
                                      ? const Icon(Icons.check,
                                          color: Colors.white, size: 18)
                                      : null,
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
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
            child: const Text(
              'Delete',
              style: TextStyle(fontSize: 20),
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
              _isStlFile() ? 'Slice' : 'Import',
              style: const TextStyle(fontSize: 22),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ],
    );
  }
}

/*
* Orion - Calibration Screen
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

import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:orion/backend_service/providers/resins_provider.dart';
import 'package:orion/backend_service/backend_service.dart';
import 'package:provider/provider.dart';
import 'package:orion/glasser/glasser.dart';
import 'package:orion/materials/calibration_progress_overlay.dart';
import 'package:orion/materials/calibration_context_provider.dart';

class CalibrationScreen extends StatefulWidget {
  const CalibrationScreen({super.key});

  @override
  CalibrationScreenState createState() => CalibrationScreenState();
}

class CalibrationScreenState extends State<CalibrationScreen> {
  final _log = Logger('CalibrationScreen');

  CalibrationModel? _selectedModel;
  ResinProfile? _selectedResin;
  double _startingExposure = 1.0; // seconds
  double _exposureIncrement = 0.2; // seconds

  @override
  void initState() {
    super.initState();
    // Set default model after first frame when provider is available
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final resinsProvider =
          Provider.of<ResinsProvider>(context, listen: false);
      if (_selectedModel == null &&
          resinsProvider.calibrationModels.isNotEmpty) {
        setState(() {
          _selectedModel = resinsProvider.calibrationModels.first;
        });
      }
    });
  }

  void _resetValues(ResinsProvider provider) {
    setState(() {
      _selectedModel = provider.calibrationModels.isNotEmpty
          ? provider.calibrationModels.first
          : null;
      _selectedResin = null;
      _startingExposure = 1.0;
      _exposureIncrement = 0.2;
    });
  }

  @override
  Widget build(BuildContext context) {
    final resinsProvider = Provider.of<ResinsProvider>(context);
    final resins = resinsProvider.resins;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Padding(
        padding: const EdgeInsets.only(
            left: 16.0, right: 16.0, top: 4.0, bottom: 4.0),
        child: Column(
          children: [
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Left side: Parameter cards
                  Expanded(
                    flex: 9,
                    child: Column(
                      children: [
                        // Resin Profile
                        Expanded(
                          child: _buildCompactCard(
                            title: 'Resin Profile',
                            value: _selectedResin?.name ?? 'Select Resin',
                            onTap: () => _selectResinProfile(resins),
                          ),
                        ),
                        const SizedBox(height: 8),
                        // Starting Exposure
                        Expanded(
                          child: _buildCompactCard(
                            title: 'Starting Exposure',
                            value: '${_startingExposure.toStringAsFixed(1)} s',
                            onTap: () => _editValue(
                              title: 'Starting Exposure',
                              currentValue: _startingExposure,
                              min: 0,
                              max: 15,
                              suffix: ' s',
                              decimals: 1,
                              step: 0.1,
                              onSave: (v) =>
                                  setState(() => _startingExposure = v),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        // Exposure Increment
                        Expanded(
                          child: _buildCompactCard(
                            title: 'Exposure Increment',
                            value: '${_exposureIncrement.toStringAsFixed(1)} s',
                            onTap: () => _editValue(
                              title: 'Exposure Increment',
                              currentValue: _exposureIncrement,
                              min: 0,
                              max: 5,
                              suffix: ' s',
                              decimals: 1,
                              step: 0.1,
                              onSave: (v) =>
                                  setState(() => _exposureIncrement = v),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Right side: Model selector with large thumbnail
                  Expanded(
                    flex: 11,
                    child: _buildLargeModelSelectorCard(
                      model: _selectedModel,
                      onTap: () => _selectCalibrationModel(
                          resinsProvider.calibrationModels),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Bottom Buttons: Reset | Start
            Row(
              children: [
                Expanded(
                  flex: 9,
                  child: GlassButton(
                    tint: GlassButtonTint.negative,
                    onPressed: () => _resetValues(resinsProvider),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 65),
                    ),
                    child: const Text('Reset', style: TextStyle(fontSize: 22)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 11,
                  child: GlassButton(
                    tint: GlassButtonTint.positive,
                    onPressed:
                        _selectedResin == null ? null : _startCalibration,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 65),
                    ),
                    child: const Text('Start Calibration',
                        style: TextStyle(fontSize: 22)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactCard({
    required String title,
    required String value,
    required VoidCallback onTap,
  }) {
    return GlassCard(
      outlined: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade400,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Spacer(),
                    Text(
                      value,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.grey.shade400, size: 28),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pollSlicerProgress(
    ValueNotifier<double> progressNotifier,
    ValueNotifier<String> messageNotifier,
  ) async {
    messageNotifier.value = 'Slicing calibration file...';

    final startTime = DateTime.now();
    const timeout = Duration(minutes: 10); // 10 minute timeout for slicing

    // Poll every 1 second
    while (mounted) {
      // Get slicer progress for UI display
      final progress = await BackendService().getSlicerProgress();

      if (progress != null) {
        // Treat 93% as complete (show as 100% on progress bar)
        if (progress >= 0.93) {
          progressNotifier.value = 1.0;
        } else {
          // Scale 0-93% to 0-100% for display
          progressNotifier.value = progress / 0.93;
        }
      }

      // Calibration prints don't report percentage correctly in /slicer endpoint
      // so we check plates.json directly for plate 0's Processed flag
      final isProcessed = await BackendService().isCalibrationPlateProcessed();

      // Break at 93% or when processed flag is set (print starts at 99%)
      if (isProcessed == true || (progress != null && progress >= 0.93)) {
        messageNotifier.value = 'Slicing complete';
        progressNotifier.value = 1.0;
        _log.info('Calibration preparation complete');
        break;
      }

      // Check timeout
      if (DateTime.now().difference(startTime) > timeout) {
        _log.warning(
            'Slicer progress polling timed out after ${timeout.inMinutes} minutes');
        throw Exception('Slicing operation timed out');
      }

      await Future.delayed(const Duration(seconds: 1));
    }
  }

  Widget _buildChecklistItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.check_circle_outline,
            size: 20,
            color: Colors.grey.shade400,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 18),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLargeModelSelectorCard({
    required CalibrationModel? model,
    required VoidCallback onTap,
  }) {
    return GlassCard(
      outlined: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (model != null) ...[
                // Large preview image
                Expanded(
                  child: FutureBuilder<String?>(
                    future: BackendService().getCalibrationImageUrl(model.id),
                    builder: (context, snapshot) {
                      if (snapshot.hasData && snapshot.data != null) {
                        return ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            snapshot.data!,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade800,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Center(
                                  child: Icon(Icons.image,
                                      size: 64, color: Colors.grey),
                                ),
                              );
                            },
                          ),
                        );
                      }
                      return Container(
                        decoration: BoxDecoration(
                          color: Colors.grey.shade800,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Center(
                          child: CircularProgressIndicator(),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
              ] else
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.grey.shade800,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.science,
                              size: 64, color: Colors.grey.shade600),
                          const SizedBox(height: 12),
                          Text(
                            'No Model Selected',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              if (model != null)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Text(
                        model.name,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Icon(Icons.chevron_right,
                        color: Colors.grey.shade400, size: 28),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _editValue({
    required String title,
    required double currentValue,
    required double min,
    required double max,
    required String suffix,
    required int decimals,
    double? step,
    required ValueChanged<double> onSave,
  }) async {
    double tempValue = currentValue;
    final effectiveStep = step ?? (decimals == 0 ? 1.0 : 0.1);

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => GlassAlertDialog(
          title: Text(title,
              style:
                  const TextStyle(fontSize: 24, fontWeight: FontWeight.w600)),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 24),
                Text(
                  decimals == 0
                      ? '${tempValue.round()}$suffix'
                      : '${tempValue.toStringAsFixed(decimals)}$suffix',
                  style: const TextStyle(
                      fontSize: 46, fontWeight: FontWeight.w700, height: 1.0),
                ),
                const SizedBox(height: 18),
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: Theme.of(context).colorScheme.primary,
                    inactiveTrackColor: Colors.grey.shade700,
                    thumbColor: Colors.white,
                    overlayColor: Colors.white.withValues(alpha: 0.2),
                    thumbShape:
                        const RoundSliderThumbShape(enabledThumbRadius: 12.0),
                    overlayShape:
                        const RoundSliderOverlayShape(overlayRadius: 24.0),
                    trackHeight: 8.0,
                  ),
                  child: Slider(
                    value: tempValue,
                    min: min,
                    max: max,
                    divisions: ((max - min) / effectiveStep).round(),
                    onChanged: (v) {
                      setDialogState(() {
                        tempValue = decimals == 0
                            ? v.roundToDouble()
                            : double.parse(v.toStringAsFixed(decimals));
                      });
                    },
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
          actions: [
            GlassButton(
              tint: GlassButtonTint.negative,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(120, 60),
              ),
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            GlassButton(
              tint: GlassButtonTint.positive,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(120, 60),
              ),
              onPressed: () {
                onSave(tempValue);
                Navigator.of(context).pop();
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _selectCalibrationModel(List<CalibrationModel> models) async {
    if (models.isEmpty) {
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
                    const Icon(Icons.science, size: 24),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Select Calibration Model',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    if (_selectedModel != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _selectedModel!.name,
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

              // Content Section with image-based selection
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: models.asMap().entries.map((entry) {
                      final index = entry.key;
                      final model = entry.value;
                      final isSelected = _selectedModel == model;
                      final imageUrlFuture =
                          BackendService().getCalibrationImageUrl(model.id);

                      return Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(
                              left: index > 0 ? 6 : 0,
                              right: index < models.length - 1 ? 6 : 0),
                          child: GlassCard(
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
                                  _selectedModel = model;
                                });
                                Navigator.of(context).pop();
                              },
                              borderRadius: BorderRadius.circular(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  // Image preview
                                  Expanded(
                                    child: ClipRRect(
                                      borderRadius: const BorderRadius.vertical(
                                          top: Radius.circular(16)),
                                      child: FutureBuilder<String?>(
                                        future: imageUrlFuture,
                                        builder: (context, snapshot) {
                                          if (snapshot.hasData &&
                                              snapshot.data != null) {
                                            return Image.network(
                                              snapshot.data!,
                                              fit: BoxFit.contain,
                                              errorBuilder:
                                                  (context, error, stackTrace) {
                                                return Container(
                                                  color: Colors.grey.shade800,
                                                  child: const Icon(Icons.image,
                                                      size: 64,
                                                      color: Colors.grey),
                                                );
                                              },
                                            );
                                          }
                                          return Container(
                                            color: Colors.grey.shade800,
                                            child: const Center(
                                                child:
                                                    CircularProgressIndicator()),
                                          );
                                        },
                                      ),
                                    ),
                                  ),

                                  // Model name and selection indicator
                                  Padding(
                                    padding: const EdgeInsets.all(12.0),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            model.name,
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                              color: isSelected
                                                  ? Theme.of(context)
                                                      .colorScheme
                                                      .primary
                                                  : null,
                                            ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Container(
                                          width: 24,
                                          height: 24,
                                          decoration: BoxDecoration(
                                            color: isSelected
                                                ? Theme.of(context)
                                                    .colorScheme
                                                    .primary
                                                : Colors.transparent,
                                            border: isSelected
                                                ? null
                                                : Border.all(
                                                    color: Theme.of(context)
                                                        .dividerColor,
                                                    width: 2),
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                          child: isSelected
                                              ? const Icon(Icons.check,
                                                  color: Colors.white, size: 16)
                                              : null,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),
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
                    const Icon(Icons.water_drop, size: 24),
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
                    if (_selectedResin != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _selectedResin!.name,
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
                    separatorBuilder: (ctx, i) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final resin = resins[index];
                      final isSelected = _selectedResin == resin;
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
                              _selectedResin = resin;
                            });
                            Navigator.of(context).pop();
                          },
                          borderRadius: BorderRadius.circular(16),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 14),
                            child: Row(
                              children: [
                                // Resin Icon

                                // Resin Info
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        resin.name,
                                        style: TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.w600,
                                          color: isSelected
                                              ? Theme.of(context)
                                                  .colorScheme
                                                  .primary
                                              : null,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      if (parts.isNotEmpty)
                                        Padding(
                                          padding:
                                              const EdgeInsets.only(top: 4.0),
                                          child: Text(
                                            parts.join(' • '),
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: Theme.of(context)
                                                  .textTheme
                                                  .bodySmall
                                                  ?.color,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),

                                // Selection Indicator
                                Container(
                                  width: 24,
                                  height: 24,
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
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: isSelected
                                      ? const Icon(Icons.check,
                                          color: Colors.white, size: 16)
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

  void _startCalibration() async {
    _log.info(
        'Starting calibration: model=${_selectedModel?.name} (id=${_selectedModel?.id}), resin=${_selectedResin?.name}, start=$_startingExposure, increment=$_exposureIncrement');

    // Build a human-readable sequence of exposures for each of the six test pieces
    final exposuresList = List.generate(6, (i) {
      final value = _startingExposure + (_exposureIncrement * i);
      return '${value.toStringAsFixed(1)}s';
    }).join(' → ');

    // Show confirmation dialog with checklist
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final pageNotifier = ValueNotifier<int>(0);
        return ValueListenableBuilder<int>(
          valueListenable: pageNotifier,
          builder: (context, page, _) {
            if (page == 0) {
              // Page 1: Confirmation
              return GlassAlertDialog(
                title: const Text('Start Calibration'),
                content: Text(
                  'Six test pieces will be printed with progressively increasing layer exposure times.\n\n'
                  'Exposure sequence:\n$exposuresList\n\n'
                  'After printing completes, you\'ll be guided through measuring and evaluating the results to determine the optimal exposure time.',
                  style: const TextStyle(fontSize: 20),
                ),
                actions: [
                  GlassButton(
                    tint: GlassButtonTint.neutral,
                    onPressed: () => Navigator.of(dialogContext).pop(false),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(120, 60),
                    ),
                    child: const Text('Cancel', style: TextStyle(fontSize: 22)),
                  ),
                  GlassButton(
                    tint: GlassButtonTint.positive,
                    onPressed: () => pageNotifier.value = 1,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(120, 60),
                    ),
                    child: const Text('Next', style: TextStyle(fontSize: 22)),
                  ),
                ],
              );
            } else {
              // Page 2: Pre-flight checklist
              return GlassAlertDialog(
                title: const Text('Pre-Flight Checklist'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Resin Profile:',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade400,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _selectedResin?.name ?? 'Unknown',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Please verify:',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _buildChecklistItem('Resin filled in vat'),
                    _buildChecklistItem('Build plate is clean'),
                    _buildChecklistItem('Vat is clear'),
                  ],
                ),
                actions: [
                  GlassButton(
                    tint: GlassButtonTint.neutral,
                    onPressed: () => pageNotifier.value = 0,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(120, 60),
                    ),
                    child: const Text('Back', style: TextStyle(fontSize: 22)),
                  ),
                  GlassButton(
                    tint: GlassButtonTint.positive,
                    onPressed: () => Navigator.of(dialogContext).pop(true),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(120, 60),
                    ),
                    child: const Text('Start', style: TextStyle(fontSize: 22)),
                  ),
                ],
              );
            }
          },
        );
      },
    );

    if (confirmed == true) {
      _log.info('Checklist confirmed, starting calibration...');

      // Show progress overlay
      final progressNotifier = ValueNotifier<double>(0.0);
      final messageNotifier = ValueNotifier<String>('');
      final showReadyNotifier = ValueNotifier<bool>(false);

      if (!mounted) return;

      // Reset overlay state for new calibration
      CalibrationProgressOverlay.reset();

      // Show overlay as a route
      Navigator.of(context).push(
        PageRouteBuilder(
          settings: const RouteSettings(name: 'calibration_progress_overlay'),
          opaque: false,
          barrierDismissible: false,
          transitionDuration: const Duration(milliseconds: 300),
          reverseTransitionDuration: const Duration(milliseconds: 300),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: animation,
              child: child,
            );
          },
          pageBuilder: (context, _, __) => CalibrationProgressOverlay(
            progress: progressNotifier,
            message: messageNotifier,
            showReady: showReadyNotifier,
          ),
        ),
      );

      // Calculate exposure times
      final exposureTimes = List.generate(
        6,
        (i) => _startingExposure + (_exposureIncrement * i),
      );

      try {
        // Store calibration context for post-print evaluation
        if (mounted) {
          context.read<CalibrationContextProvider>().setContext(
                CalibrationContext(
                  calibrationModelName: _selectedModel!.name,
                  resinProfileName: _selectedResin?.name,
                  startExposure: _startingExposure,
                  exposureIncrement: _exposureIncrement,
                  profileId: _selectedResin?.meta['ProfileID'] ?? 0,
                  calibrationModelId: _selectedModel!.id,
                  evaluationGuideUrl: _selectedModel!.evaluationGuideUrl,
                ),
              );
        }

        // Show progress
        messageNotifier.value = 'Submitting calibration job...';
        progressNotifier.value = 0.1;

        // Submit calibration job to backend
        final success = await BackendService().startCalibrationPrint(
          calibrationModelId: _selectedModel!.id,
          exposureTimes: exposureTimes,
          profileId: _selectedResin?.meta['ProfileID'] ?? 0,
        );

        if (!success) {
          _log.warning('Calibration submission did not receive acknowledgment, '
              'but job may have started. Proceeding with progress polling...');
        }

        // Poll slicer progress regardless of ack
        // (the job may have started even if we timed out waiting for response)
        await _pollSlicerProgress(progressNotifier, messageNotifier);

        _log.info('Calibration preparation complete');

        // Show ready state with green flask
        showReadyNotifier.value = true;

        // StatusScreen will automatically open when print starts
        // and will dismiss overlay + pop CalibrationScreen
        _log.info('Waiting for StatusScreen to open...');
      } catch (e) {
        _log.severe('Error starting calibration: $e');
        messageNotifier.value = 'Error: $e';
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) {
          Navigator.of(context).pop();
        }
      }
    }
  }
}

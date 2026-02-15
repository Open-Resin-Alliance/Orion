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

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:logging/logging.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:orion/backend_service/providers/resins_provider.dart';
import 'package:orion/backend_service/backend_service.dart';
import 'package:provider/provider.dart';
import 'package:orion/glasser/glasser.dart';
import 'package:orion/util/providers/theme_provider.dart';
import 'package:orion/materials/calibration_progress_overlay.dart';
import 'package:orion/materials/calibration_context_provider.dart';
import 'package:orion/widgets/zoom_value_editor_dialog.dart';
import 'package:orion/util/orion_config.dart';

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
    // Refresh data and set default model after first frame when provider is available
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final resinsProvider =
          Provider.of<ResinsProvider>(context, listen: false);

      // Refresh to get latest data from backend
      await resinsProvider.refresh();

      // Initialize the screen selection from the provider's selected
      // calibration model (the provider guarantees one will be selected
      // when models are available).
      if (mounted) {
        final providerModel = resinsProvider.selectedCalibrationModel;
        if (_selectedModel == null && providerModel != null) {
          setState(() {
            _selectedModel = providerModel;
            // Pre-select a recommended resin profile for this model.
            _selectedResin = resinsProvider.getRecommendedResin(_selectedModel);
          });
        }
      }
    });
  }

  void _resetValues(ResinsProvider provider) {
    setState(() {
      _selectedModel = provider.selectedCalibrationModel;
      _selectedResin = null;
      _startingExposure = 1.0;
      _exposureIncrement = 0.2;
    });
  }

  @override
  Widget build(BuildContext context) {
    final resinsProvider = Provider.of<ResinsProvider>(context);
    // Use provider's user-visible resin list so locked/vendor profiles
    // (e.g. NanoDLP AFP templates) are hidden from calibration flows.
    final resins = resinsProvider.userResins;
    final isLoading = resinsProvider.isLoading;

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
                            value: isLoading
                                ? 'Loading...'
                                : (_selectedResin?.name ?? 'Select Resin'),
                            onTap: isLoading
                                ? () {}
                                : () => _selectResinProfile(resins),
                          ),
                        ),
                        const SizedBox(height: 8),
                        // Starting Exposure
                        Expanded(
                          child: _buildCompactCard(
                            title: 'Starting Exposure',
                            value: '${_startingExposure.toStringAsFixed(2)} s',
                            onTap: () => _editValue(
                              title: 'Starting Exposure',
                              description:
                                  'The exposure time for the first test piece. This should be lower than your expected optimal exposure.',
                              currentValue: _startingExposure,
                              min: 0.5,
                              max: 10,
                              suffix: ' sec',
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
                            value: '${_exposureIncrement.toStringAsFixed(2)} s',
                            onTap: () => _editValue(
                              title: 'Exposure Increment',
                              description:
                                  'How much exposure time increases for each successive test piece. Larger increments cover a wider range faster.',
                              currentValue: _exposureIncrement,
                              min: 0.1,
                              max: 2,
                              suffix: ' s',
                              decimals: 2,
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
                      isLoading: isLoading,
                      imageUrl: _selectedModel != null
                          ? resinsProvider
                              .calibrationImageUrl(_selectedModel!.id)
                          : null,
                      onTap: isLoading
                          ? () {}
                          : () => _selectCalibrationModel(
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
                        fontSize: 19,
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

  Widget _buildLargeModelSelectorCard({
    required CalibrationModel? model,
    required VoidCallback onTap,
    required bool isLoading,
    String? imageUrl,
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
              if (isLoading) ...[
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.grey.shade800,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 12),
                          Text(
                            'Loading models...',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ] else if (model != null) ...[
                // Large preview image
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: imageUrl != null
                        ? Image.network(
                            imageUrl,
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
                          )
                        : Container(
                            decoration: BoxDecoration(
                              color: Colors.grey.shade800,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Center(
                              child: CircularProgressIndicator(),
                            ),
                          ),
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
    String? description,
    required double currentValue,
    required double min,
    required double max,
    required String suffix,
    required int decimals,
    double? step,
    required ValueChanged<double> onSave,
  }) async {
    final result = await ZoomValueEditorDialog.show(
      context,
      title: title,
      description: description,
      currentValue: currentValue,
      min: min,
      max: max,
      suffix: suffix,
      decimals: decimals,
      step: step,
    );
    if (result != null) onSave(result);
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
                      final resinsProvider =
                          Provider.of<ResinsProvider>(context, listen: false);
                      final imageUrl =
                          resinsProvider.calibrationImageUrl(model.id);

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
                                // Update both the screen state and provider's
                                // selected calibration model so the choice is
                                // visible app-wide. Keep the user's resin
                                // selection (don't reset it).
                                setState(() {
                                  _selectedModel = model;
                                });
                                resinsProvider
                                    .setSelectedCalibrationModelId(model.id);
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
                                      child: imageUrl != null
                                          ? Image.network(
                                              imageUrl,
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
                                            )
                                          : Container(
                                              color: Colors.grey.shade800,
                                              child: const Center(
                                                  child:
                                                      CircularProgressIndicator()),
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
                                          fontSize: 22,
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

    // Show unified pre-calibration overlay with info and checklist
    final confirmed = await Navigator.of(context).push<bool>(
      PageRouteBuilder(
        opaque: false,
        barrierDismissible: true,
        transitionDuration: const Duration(milliseconds: 300),
        reverseTransitionDuration: const Duration(milliseconds: 300),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
        pageBuilder: (context, _, __) => _PreCalibrationOverlay(
          calibrationModelName: _selectedModel!.name,
          resinProfileName: _selectedResin?.name,
          exposuresList: exposuresList,
          calibrationModelId: _selectedModel!.id,
        ),
      ),
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
        // Prefer the provider helper for consistent resolution logic.
        final resolvedProfileId =
            ResinsProvider.resolveProfileIdFromMeta(_selectedResin?.meta) ?? 0;

        // Store calibration context for post-print evaluation
        if (mounted) {
          context.read<CalibrationContextProvider>().setContext(
                CalibrationContext(
                  calibrationModelName: _selectedModel!.name,
                  resinProfileName: _selectedResin?.name,
                  startExposure: _startingExposure,
                  exposureIncrement: _exposureIncrement,
                  profileId: resolvedProfileId,
                  calibrationModelId: _selectedModel!.id,
                  evaluationGuideUrl: _selectedModel!.evaluationGuideUrl,
                ),
              );
        }

        // Show progress
        messageNotifier.value = 'Submitting calibration job...';
        progressNotifier.value = 0.1;

        final reuseCalibrationPlate = OrionConfig()
            .getFlag('reuseCalibrationPlate', category: 'developer');
        if (reuseCalibrationPlate) {
          _log.info(
              'Developer mode: reusing existing calibration plate, skipping slicer');
          messageNotifier.value =
              'Starting existing calibration plate (debug)...';
          progressNotifier.value = 0.6;
          await BackendService().startPrint('Local', '0');
          showReadyNotifier.value = true;
          _log.info('Calibration print started (reuse mode)');
          return;
        }

        // Submit calibration job to backend
        final success = await BackendService().startCalibrationPrint(
          calibrationModelId: _selectedModel!.id,
          exposureTimes: exposureTimes,
          profileId: resolvedProfileId,
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

/// Compact pre-calibration overlay
/// Shows info and checklist in single screen
class _PreCalibrationOverlay extends StatelessWidget {
  final String calibrationModelName;
  final String? resinProfileName;
  final String exposuresList;
  final int calibrationModelId;

  const _PreCalibrationOverlay({
    required this.calibrationModelName,
    this.resinProfileName,
    required this.exposuresList,
    required this.calibrationModelId,
  });

  @override
  Widget build(BuildContext context) {
    final isGlass =
        Provider.of<ThemeProvider>(context, listen: false).isGlassTheme;

    return GlassApp(
      child: Scaffold(
        backgroundColor: isGlass
            ? Colors.transparent
            : Theme.of(context).colorScheme.surface,
        appBar: AppBar(
          backgroundColor: isGlass
              ? Colors.transparent
              : Theme.of(context).colorScheme.surface,
          elevation: 0,
          automaticallyImplyLeading: false,
          title: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                PhosphorIconsFill.flask,
                size: 32,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 12),
              Text(
                calibrationModelName,
                style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary),
              ),
            ],
          ),
          centerTitle: true,
        ),
        body: SafeArea(
          child: LayoutBuilder(builder: (context, constraints) {
            return SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Resin info
                      if (resinProfileName != null) ...[
                        Text(
                          resinProfileName!,
                          style: TextStyle(
                            fontSize: 22,
                            color: Colors.grey.shade300,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                      ],
                      // Two-column layout
                      IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Left box - What's happening
                            Expanded(
                              child: GlassCard(
                                outlined: true,
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(
                                            PhosphorIconsFill.info,
                                            size: 20,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .primary,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            'What\'s Happening',
                                            style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.grey.shade300,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        'Six test pieces will be printed with progressively increasing exposure times to help you find the optimal cure time for this resin.',
                                        style: TextStyle(
                                          fontSize: 18,
                                          color: Colors.grey.shade400,
                                          height: 1.4,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),

                            // Right box - Checklist
                            Expanded(
                              child: GlassCard(
                                outlined: true,
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(
                                            PhosphorIconsFill.clipboardText,
                                            size: 20,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .primary,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            'Pre-Flight Check',
                                            style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.grey.shade300,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      _buildChecklistItem(context,
                                          'Correct resin is filled into the vat.'),
                                      const SizedBox(height: 10),
                                      _buildChecklistItem(
                                          context, 'The build plate is clean.'),
                                      const SizedBox(height: 10),
                                      _buildChecklistItem(context,
                                          'The vat is clear of any debris.'),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 8),
                      GlassCard(
                        outlined: true,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Center(
                            child: Column(
                              children: [
                                Text(
                                  'Exposure Sequence',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey.shade300,
                                    letterSpacing: 0.5,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  exposuresList,
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                    color:
                                        Theme.of(context).colorScheme.primary,
                                    letterSpacing: 0.3,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 85), // Space for FABs
                    ],
                  ), // end Column
                ), // end Padding
              ), // end ConstrainedBox
            ); // end SingleChildScrollView
          }), // end LayoutBuilder
        ),
        floatingActionButton: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              GlassFloatingActionButton.extended(
                tint: GlassButtonTint.negative,
                heroTag: 'cancel',
                onPressed: () => Navigator.of(context).pop(false),
                label: 'Cancel',
                icon: Icon(PhosphorIcons.x()),
                scale: 1.2,
                iconAfterLabel: false,
              ),
              GlassFloatingActionButton.extended(
                tint: GlassButtonTint.positive,
                heroTag: 'start',
                onPressed: () => Navigator.of(context).pop(true),
                label: 'Start Print',
                icon: Icon(PhosphorIcons.play()),
                scale: 1.2,
                iconAfterLabel: true,
              ),
            ],
          ),
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      ),
    );
  }

  Widget _buildChecklistItem(BuildContext context, String text) {
    return Row(
      children: [
        Icon(
          PhosphorIcons.checkCircle(),
          size: 22,
          color: Colors.green.shade400,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey.shade300,
              height: 1.3,
            ),
          ),
        ),
      ],
    );
  }
}

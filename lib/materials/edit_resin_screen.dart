/*
* Orion - Edit Resin Screen
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
import 'package:orion/backend_service/nanodlp/models/nano_profiles.dart';
import 'package:orion/glasser/glasser.dart';
import 'package:orion/util/error_handling/error_dialog.dart';

/// Edit screen showing 6 cards (2x3 grid) displaying current resin parameter
/// values. Tapping any card opens a dialog with a slider to adjust the value.
class EditResinScreen extends StatefulWidget {
  final ResinProfile? resin;

  const EditResinScreen({super.key, this.resin});

  @override
  EditResinScreenState createState() => EditResinScreenState();
}

class EditResinScreenState extends State<EditResinScreen> {
  final _log = Logger('EditResinScreen');

  late double _burnInTime; // seconds
  late double _normalTime; // seconds
  late double _liftAfter; // mm
  late int _burnInCount; // count
  late double _waitAfterCure; // seconds
  late double _waitAfterLife; // seconds

  late Map<String, dynamic> _initial;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    // Initialize from any metadata available on the provided resin immediately
    // so the UI can render quickly. After that, attempt to fetch the full
    // profile JSON from the backend (when supported) and, if available,
    // overwrite the in-memory fields with the authoritative values.
    final meta = widget.resin?.meta ?? {};
    final norm = NanoProfile.normalizeForEdit(meta);

    _burnInTime = (norm['burn_in_cure_time'] as num).toDouble();
    _normalTime = (norm['normal_cure_time'] as num).toDouble();
    _liftAfter = norm['lift_after_print'] as double;
    _burnInCount = norm['burn_in_count'] as int;
    _waitAfterCure = (norm['wait_after_cure'] as num).toDouble();
    _waitAfterLife = (norm['wait_after_life'] as num).toDouble();

    _initial = Map<String, dynamic>.from(norm);

    // Fetch and normalize detailed profile data (model handles backend
    // specifics). This keeps the UI simple and backend-agnostic.
    Future(() async {
      try {
        final svc = BackendService();
        final details = await NanoProfile.getResinProfileDetails(
            widget.resin?.meta ?? {}, svc);
        if (details.isEmpty) return;

        final mergedMeta = details['meta'] as Map<String, dynamic>? ?? {};
        final normalized = details['normalized'] as Map<String, dynamic>? ?? {};

        try {
          _log.fine(
              'Applying normalized profile values preview=${normalized.toString()}');
        } catch (_) {}

        if (!mounted) return;
        setState(() {
          _loadFromMeta(mergedMeta);
          _burnInTime = (normalized['burn_in_cure_time'] as num?)?.toDouble() ??
              _burnInTime;
          _normalTime = (normalized['normal_cure_time'] as num?)?.toDouble() ??
              _normalTime;
          _liftAfter = normalized['lift_after_print'] as double? ?? _liftAfter;
          _burnInCount = normalized['burn_in_count'] as int? ?? _burnInCount;
          _waitAfterCure =
              (normalized['wait_after_cure'] as num?)?.toDouble() ??
                  _waitAfterCure;
          _waitAfterLife =
              (normalized['wait_after_life'] as num?)?.toDouble() ??
                  _waitAfterLife;
        });
      } catch (e, st) {
        _log.fine('Failed to fetch or apply profile details', e, st);
      }
    });
  }

  void _loadFromMeta(Map<String, dynamic> meta) {
    // Delegate normalization to the NanoProfile model so the UI remains
    // backend-agnostic and we avoid duplicating candidate-key logic here.
    final normalized = NanoProfile.normalizeForEdit(meta);

    _burnInTime = (normalized['burn_in_cure_time'] as num?)?.toDouble() ?? 10.0;
    _normalTime = (normalized['normal_cure_time'] as num?)?.toDouble() ?? 8.0;
    _liftAfter = normalized['lift_after_print'] as double? ?? 5.0;
    _burnInCount = normalized['burn_in_count'] as int? ?? 3;
    _waitAfterCure = (normalized['wait_after_cure'] as num?)?.toDouble() ?? 2.0;
    _waitAfterLife = (normalized['wait_after_life'] as num?)?.toDouble() ?? 2.0;

    _initial = Map<String, dynamic>.from(normalized);
  }

  void _reset() {
    setState(() {
      _burnInTime = (_initial['burn_in_cure_time'] as num).toDouble();
      _normalTime = (_initial['normal_cure_time'] as num).toDouble();
      _liftAfter = _initial['lift_after_print'] as double;
      _burnInCount = _initial['burn_in_count'] as int;
      _waitAfterCure = (_initial['wait_after_cure'] as num).toDouble();
      _waitAfterLife = (_initial['wait_after_life'] as num).toDouble();
    });
  }

  void _save() async {
    final result = {
      'burn_in_cure_time': _burnInTime,
      'normal_cure_time': _normalTime,
      'lift_after_print': _liftAfter,
      'burn_in_count': _burnInCount,
      'wait_after_cure': _waitAfterCure,
      'wait_after_life': _waitAfterLife,
    };

    _log.info('Saving profile edits: $result');
    // Try to post back to backend when we can identify a profile id in the
    // provided resin meta. Otherwise just return the result to the caller.
    int? profileId;
    try {
      final meta = widget.resin?.meta ?? {};
      profileId = ResinsProvider.resolveProfileIdFromMeta(meta);
    } catch (_) {
      profileId = null;
    }

    if (profileId == null || profileId == 0) {
      Navigator.of(context).pop(result);
      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      final svc = BackendService();
      // Convert our normalized fields to backend-specific format using the
      // model layer (keeps UI backend-agnostic)
      final backendFields = NanoProfile.denormalizeForBackend(result);
      final resp = await svc.editProfile(profileId, backendFields);
      _log.fine('editProfile response: $resp');

      if (mounted) {
        setState(() {
          _saving = false;
        });
      }

      // Show success dialog with old→new comparison for normal cure time
      double parseNum(dynamic v) {
        if (v == null) return 0.0;
        if (v is num) return v.toDouble();
        final pd = double.tryParse('$v');
        return pd ?? 0.0;
      }

      final oldNormalTime = parseNum(_initial['normal_cure_time']);
      final newNormalTime = parseNum(result['normal_cure_time']);
      final hasChanged = oldNormalTime != newNormalTime;

      if (mounted) {
        await showDialog(
          context: context,
          builder: (context) => GlassAlertDialog(
            title: const Text('Profile Saved',
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.resin?.name ?? 'Resin Profile',
                  style: TextStyle(
                    fontSize: 22,
                    color: Colors.grey.shade400,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (hasChanged) ...[
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Column(
                        children: [
                          Text(
                            'Previous',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey.shade500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${oldNormalTime.toStringAsFixed(2)}s',
                            style: TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade600,
                              decoration: TextDecoration.lineThrough,
                            ),
                          ),
                        ],
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Icon(
                          Icons.arrow_forward,
                          color: Theme.of(context).colorScheme.primary,
                          size: 40,
                        ),
                      ),
                      Column(
                        children: [
                          Text(
                            'Updated',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey.shade400,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${newNormalTime.toStringAsFixed(2)}s',
                            style: TextStyle(
                              fontSize: 42,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
                Text(
                  hasChanged
                      ? 'Layer exposure time updated'
                      : 'Profile settings saved successfully',
                  style: TextStyle(
                    fontSize: 20,
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ),
            actions: [
              GlassButton(
                tint: GlassButtonTint.positive,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(120, 65),
                ),
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: const Text('Done', style: TextStyle(fontSize: 22)),
              ),
            ],
          ),
        );
      }

      // Return the submitted result (or backend response) to the caller so
      // callers can update UI immediately.
      if (mounted) {
        Navigator.of(context).pop(resp.isNotEmpty ? resp : result);
      }
    } catch (e, st) {
      _log.severe('Failed to post profile edits', e, st);
      if (mounted) showErrorDialog(context, 'PROFILE-EDIT-FAILED');
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  Widget _buildCard({
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
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade400,
                  letterSpacing: 0.3,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const Spacer(),
              Align(
                alignment: Alignment.bottomCenter,
                child: Text(
                  value,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    height: 1.0,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
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
                if (description != null) ...[
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 19,
                      color: Colors.grey.shade400,
                      height: 1.4,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                ] else
                  const SizedBox(height: 24),
                Text(
                  decimals == 0
                      ? '${tempValue.round()}$suffix'
                      : '${tempValue.toStringAsFixed(decimals)}$suffix',
                  style: TextStyle(
                    fontSize: 46,
                    fontWeight: FontWeight.w700,
                    height: 1.0,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 12),
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
              child: const Text(
                'Cancel',
                style: TextStyle(fontSize: 22),
              ),
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
              child: const Text(
                'Save',
                style: TextStyle(fontSize: 22),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.resin?.name ?? 'Edit Resin';

    return GlassApp(
      child: Scaffold(
        appBar: AppBar(title: Text(title)),
        body: Padding(
          padding: const EdgeInsets.only(
              left: 16.0, right: 16.0, bottom: 20.0, top: 8.0),
          child: Column(
            children: [
              Expanded(
                child: Column(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Expanded(
                            child: _buildCard(
                              title: 'Burn-In Layer Cure Time',
                              value: '${_burnInTime.toStringAsFixed(2)} s',
                              onTap: () => _editValue(
                                title: 'Burn-In Layer Cure Time',
                                description:
                                    'UV exposure time for the initial layers that adhere the print to the build plate. Longer times improve adhesion.',
                                currentValue: _burnInTime.toDouble(),
                                min: 0,
                                max: 30,
                                suffix: ' s',
                                decimals: 2,
                                step: 0.20,
                                onSave: (v) => setState(() => _burnInTime = v),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildCard(
                              title: 'Burn-In Layer Count',
                              value: '$_burnInCount',
                              onTap: () => _editValue(
                                title: 'Burn-In Layer Count',
                                description:
                                    'How many initial layers use the longer burn-in cure time. More layers provide stronger build plate adhesion.',
                                currentValue: _burnInCount.toDouble(),
                                min: 0,
                                max: 20,
                                suffix: '',
                                decimals: 0,
                                onSave: (v) =>
                                    setState(() => _burnInCount = v.round()),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: Row(
                        children: [
                          Expanded(
                            child: _buildCard(
                              title: 'Normal Layer Cure Time',
                              // Display two decimals but restrict edits to 0.1s
                              value: '${_normalTime.toStringAsFixed(2)} s',
                              onTap: () => _editValue(
                                title: 'Normal Layer Cure Time',
                                description:
                                    'UV exposure time for all layers after burn-in. This is the main parameter that affects print quality and detail.',
                                currentValue: _normalTime.toDouble(),
                                min: 0,
                                max: 15,
                                suffix: ' s',
                                decimals: 2,
                                step: 0.1,
                                onSave: (v) => setState(() => _normalTime = v),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildCard(
                              title: 'Wait After Cure',
                              value: '${_waitAfterCure.toStringAsFixed(2)} s',
                              onTap: () => _editValue(
                                title: 'Wait After Cure',
                                description:
                                    'Pause after UV exposure before lifting. Allows the layer to stabilize and helps prevent layer separation.',
                                currentValue: _waitAfterCure.toDouble(),
                                min: 0,
                                max: 20,
                                suffix: ' s',
                                decimals: 2,
                                step: 0.2,
                                onSave: (v) =>
                                    setState(() => _waitAfterCure = v),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: Row(
                        children: [
                          Expanded(
                            child: _buildCard(
                              title: 'Lift After Print',
                              value: '${_liftAfter.toStringAsFixed(1)} mm',
                              onTap: () => _editValue(
                                title: 'Lift After Print',
                                description:
                                    'How far the build plate lifts between layers. Higher values ensure complete separation but slow down prints.',
                                currentValue: _liftAfter,
                                min: 0,
                                max: 20,
                                suffix: ' mm',
                                decimals: 2,
                                step: 0.2,
                                onSave: (v) => setState(() => _liftAfter = v),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildCard(
                              title: 'Wait After Lift',
                              value: '${_waitAfterLife.toStringAsFixed(2)} s',
                              onTap: () => _editValue(
                                title: 'Wait After Lift',
                                description:
                                    'Pause after lifting to let resin flow back and settle before the next layer exposure begins.',
                                currentValue: _waitAfterLife.toDouble(),
                                min: 0,
                                max: 20,
                                suffix: ' s',
                                decimals: 2,
                                step: 0.2,
                                onSave: (v) =>
                                    setState(() => _waitAfterLife = v),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: GlassButton(
                      tint: GlassButtonTint.negative,
                      onPressed: _reset,
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(0, 65),
                      ),
                      child:
                          const Text('Reset', style: TextStyle(fontSize: 22)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GlassButton(
                      tint: GlassButtonTint.positive,
                      onPressed: _saving ? null : _save,
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(0, 65),
                      ),
                      child: _saving
                          ? const Text('Saving…',
                              style: TextStyle(fontSize: 22))
                          : const Text('Save', style: TextStyle(fontSize: 22)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

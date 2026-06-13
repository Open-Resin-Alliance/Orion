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
import 'package:orion/backend_service/domain/models.dart';
import 'package:orion/glasser/glasser.dart';
import 'package:orion/util/error_handling/error_dialog.dart';
import 'package:orion/util/orion_spacing.dart';
import 'package:orion/util/widgets/system_status_widget.dart';
import 'package:orion/widgets/orion_app_bar.dart';
import 'package:orion/widgets/zoom_value_editor_dialog.dart';

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

  ResinSettings _settingsFromMeta(Map<String, dynamic> meta) {
    num asNum(dynamic v, num fallback) {
      if (v is num) return v;
      if (v is String) return num.tryParse(v) ?? fallback;
      return fallback;
    }

    final customValues = (meta['CustomValues'] is Map<String, dynamic>)
        ? (meta['CustomValues'] as Map<String, dynamic>)
        : <String, dynamic>{};

    dynamic pick(String normalized, List<String> aliases, dynamic fallback) {
      if (meta.containsKey(normalized)) return meta[normalized];
      for (final key in aliases) {
        if (meta.containsKey(key)) return meta[key];
      }
      if (customValues.containsKey(normalized)) return customValues[normalized];
      for (final key in aliases) {
        if (customValues.containsKey(key)) return customValues[key];
      }
      return fallback;
    }

    return ResinSettings(
      burnInCureTime:
          asNum(pick('burn_in_cure_time', ['SupportCureTime'], 10.0), 10.0)
              .toDouble(),
      normalCureTime:
          asNum(pick('normal_cure_time', ['CureTime'], 8.0), 8.0).toDouble(),
      liftAfterPrint: asNum(
              pick('lift_after_print',
                  ['TopDistance', 'WaitHeight', 'LiftAfterPrint'], 5.0),
              5.0)
          .toDouble(),
      burnInCount:
          asNum(pick('burn_in_count', ['SupportLayerNumber'], 3), 3).toInt(),
      waitAfterCure: asNum(
              pick('wait_after_cure', ['WaitAfterPrint', 'WaitAfterCure'], 2.0),
              2.0)
          .toDouble(),
      waitAfterLife: asNum(pick('wait_after_life', ['WaitAfterLift'], 2.0), 2.0)
          .toDouble(),
    );
  }

  void _applySettings(ResinSettings settings, {bool setInitial = false}) {
    _burnInTime = settings.burnInCureTime;
    _normalTime = settings.normalCureTime;
    _liftAfter = settings.liftAfterPrint;
    _burnInCount = settings.burnInCount;
    _waitAfterCure = settings.waitAfterCure;
    _waitAfterLife = settings.waitAfterLife;

    if (setInitial) {
      _initial = settings.toNormalizedMap();
    }
  }

  @override
  void initState() {
    super.initState();
    // Initialize from any metadata available on the provided resin immediately
    // so the UI can render quickly. After that, attempt to fetch the full
    // profile JSON from the backend (when supported) and, if available,
    // overwrite the in-memory fields with the authoritative values.
    final meta = widget.resin?.meta ?? {};
    final fallbackSettings = _settingsFromMeta(meta);
    _applySettings(fallbackSettings, setInitial: true);

    // Fetch and normalize detailed profile data (model handles backend
    // specifics). This keeps the UI simple and backend-agnostic.
    Future(() async {
      try {
        int? profileId;
        try {
          profileId = ResinsProvider.resolveProfileIdFromMeta(meta);
        } catch (_) {
          profileId = null;
        }
        if (profileId == null || profileId == 0) return;

        final svc = BackendService();
        final settings = await svc.getResinSettings(profileId);
        if (settings == null) return;

        if (!mounted) return;
        setState(() {
          _applySettings(settings, setInitial: true);
        });
      } catch (e, st) {
        _log.fine('Failed to fetch or apply profile details', e, st);
      }
    });
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
      final settings = ResinSettings(
        burnInCureTime: _burnInTime,
        normalCureTime: _normalTime,
        liftAfterPrint: _liftAfter,
        burnInCount: _burnInCount,
        waitAfterCure: _waitAfterCure,
        waitAfterLife: _waitAfterLife,
      );
      await svc.saveResinSettings(profileId, settings);

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
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
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
                child: const Text('Done'),
              ),
            ],
          ),
        );
      }

      // Return the submitted result (or backend response) to the caller so
      // callers can update UI immediately.
      if (mounted) {
        Navigator.of(context).pop(result);
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

  @override
  Widget build(BuildContext context) {
    final title = widget.resin?.name ?? 'Edit Resin';

    return GlassApp(
      child: Scaffold(
        appBar: OrionAppBar(
          title: Text(title),
          actions: const [SystemStatusWidget()],
          toolbarHeight: Theme.of(context).appBarTheme.toolbarHeight,
        ),
        body: Padding(
          padding: const EdgeInsets.only(
              left: OrionSpacing.screenHorizontal,
              right: OrionSpacing.screenHorizontal,
              top: OrionSpacing.screenTop,
              bottom: 20.0),
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
                                step: 0.10,
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
                                step: 0.1,
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
                                step: 0.1,
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
                                step: 0.1,
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

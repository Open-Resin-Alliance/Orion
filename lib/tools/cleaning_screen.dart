/*
* Orion - Cleaning Screen
* Copyright (C) 2026 Open Resin Alliance
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
import 'package:flutter_i18n/flutter_i18n.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'package:orion/backend_service/backend_registry.dart';
import 'package:orion/backend_service/backend_service.dart';
import 'package:orion/glasser/glasser.dart';
import 'package:orion/util/orion_config.dart';
import 'package:orion/util/orion_spacing.dart';
import 'package:orion/widgets/zoom_value_editor_dialog.dart';

/// Cleaning run: a full-field UV exposure for a set time and intensity.
///
/// The operator picks the duration and the UV power here; the values are
/// remembered between visits.  The run itself needs a backend command that no
/// backend serves yet, so Start stays disabled until one advertises
/// [BackendCapabilities.supportsCleaning].
class CleaningScreen extends StatefulWidget {
  const CleaningScreen({super.key});

  @override
  State<CleaningScreen> createState() => _CleaningScreenState();
}

class _CleaningScreenState extends State<CleaningScreen> {
  final OrionConfig _config = OrionConfig();
  final BackendService _backend = BackendService();

  late int _seconds;
  late int _intensity;

  // Duration bounds: long enough to strip a vat, short enough to be safe to
  // leave running.  Intensity is a percentage of full UV power, floored at 10%
  // so a run is still effective.
  static const int _minSeconds = 1;
  static const int _maxSeconds = 60;
  static const int _minIntensity = 10;
  static const int _maxIntensity = 100;

  @override
  void initState() {
    super.initState();
    // Clamp anything persisted before these bounds existed.
    _seconds =
        _config.getCleaningSeconds().clamp(_minSeconds, _maxSeconds);
    _intensity =
        _config.getCleaningIntensity().clamp(_minIntensity, _maxIntensity);
  }

  bool get _supported =>
      _backend.supportsCapability(BackendCapabilities.supportsCleaning);

  Future<void> _editSeconds() async {
    final result = await ZoomValueEditorDialog.show(
      context,
      title: FlutterI18n.translate(context, 'cleaning.time'),
      currentValue: _seconds.toDouble(),
      min: _minSeconds.toDouble(),
      max: _maxSeconds.toDouble(),
      suffix: FlutterI18n.translate(context, 'exposure.unitSec'),
      decimals: 0,
      step: 1,
      keepValueOnOpen: true,
    );
    if (result == null) return;
    final value = result.round().clamp(_minSeconds, _maxSeconds);
    setState(() => _seconds = value);
    _config.setCleaningSeconds(value);
  }

  Future<void> _editIntensity() async {
    final result = await ZoomValueEditorDialog.show(
      context,
      title: FlutterI18n.translate(context, 'cleaning.intensity'),
      currentValue: _intensity.toDouble(),
      min: _minIntensity.toDouble(),
      max: _maxIntensity.toDouble(),
      suffix: '%',
      decimals: 0,
      step: 1,
      keepValueOnOpen: true,
    );
    if (result == null) return;
    final value = result.round().clamp(_minIntensity, _maxIntensity);
    setState(() => _intensity = value);
    _config.setCleaningIntensity(value);
  }

  @override
  Widget build(BuildContext context) {
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Padding(
        padding: OrionSpacing.screenPaddingWithBottomNav,
        child: Column(
          children: [
            Expanded(
              child: isLandscape
                  ? Row(
                      children: [
                        Expanded(child: _buildTimeCard(context)),
                        const SizedBox(width: OrionSpacing.controlGap),
                        Expanded(child: _buildIntensityCard(context)),
                      ],
                    )
                  : Column(
                      children: [
                        Expanded(child: _buildTimeCard(context)),
                        const SizedBox(height: OrionSpacing.controlGap),
                        Expanded(child: _buildIntensityCard(context)),
                      ],
                    ),
            ),
            const SizedBox(height: OrionSpacing.controlGap),
            _buildStart(context),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeCard(BuildContext context) {
    return _buildSettingCard(
      context,
      icon: PhosphorIcons.timer(),
      labelKey: 'cleaning.time',
      value: '$_seconds ${FlutterI18n.translate(context, 'exposure.unitSec')}',
      onEdit: _editSeconds,
    );
  }

  Widget _buildIntensityCard(BuildContext context) {
    return _buildSettingCard(
      context,
      icon: PhosphorIcons.lightbulbFilament(),
      labelKey: 'cleaning.intensity',
      value: '$_intensity %',
      onEdit: _editIntensity,
    );
  }

  Widget _buildSettingCard(
    BuildContext context, {
    required IconData icon,
    required String labelKey,
    required String value,
    required VoidCallback onEdit,
  }) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    return GlassCard(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: OrionSpacing.cardPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                PhosphorIcon(icon, size: 30, color: primary),
                const SizedBox(width: 14),
                Flexible(
                  child: Text(
                    FlutterI18n.translate(context, labelKey),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
            // The value takes the middle of the card: header above, the
            // Change button pinned below.
            const Spacer(),
            Text(
              value,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 46,
                fontWeight: FontWeight.w700,
                height: 1.1,
                color: primary,
              ),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: GlassButton(
                tint: GlassButtonTint.neutral,
                onPressed: onEdit,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 55),
                ),
                child: Text(
                  FlutterI18n.translate(context, 'common.change'),
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStart(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: GlassButton(
        tint: GlassButtonTint.positive,
        onPressed: _supported ? _start : null,
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(double.infinity, 65),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            PhosphorIcon(PhosphorIcons.sparkle(), size: 22),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                FlutterI18n.translate(
                    context,
                    _supported
                        ? 'cleaning.start'
                        : 'cleaning.notAvailable'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 22, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Kick off a cleaning run.  Only reachable once a backend advertises
  /// [BackendCapabilities.supportsCleaning]; the command itself lands with
  /// that backend support.
  Future<void> _start() async {
    await _backend.startCleaning(
      seconds: _seconds,
      intensityPercent: _intensity,
    );
  }
}

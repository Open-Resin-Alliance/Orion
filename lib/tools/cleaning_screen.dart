/*
* Orion - Tank Clean Screen
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

import 'package:orion/backend_service/backend_registry.dart';
import 'package:orion/backend_service/backend_service.dart';
import 'package:orion/glasser/glasser.dart';
import 'package:orion/util/hold_button.dart';
import 'package:orion/util/orion_config.dart';
import 'package:orion/util/orion_spacing.dart';
import 'package:orion/widgets/exposure_countdown_dialog.dart';

/// Tank Clean: a full-screen UV exposure that cures a thin film across the vat
/// so debris lifts out in one piece.
///
/// The operator sets the duration on a slider and starts the run by holding the
/// button down; the run itself needs [BackendCapabilities.supportsCleaning].
class CleaningScreen extends StatefulWidget {
  const CleaningScreen({super.key});

  @override
  State<CleaningScreen> createState() => _CleaningScreenState();
}

class _CleaningScreenState extends State<CleaningScreen> {
  final OrionConfig _config = OrionConfig();
  final BackendService _backend = BackendService();

  late int _seconds;

  // Duration bounds: long enough to strip a vat, short enough to be safe to
  // leave running.
  static const int _minSeconds = 1;
  static const int _maxSeconds = 60;

  @override
  void initState() {
    super.initState();
    // Clamp anything persisted before these bounds existed.
    _seconds = _config.getCleaningSeconds().clamp(_minSeconds, _maxSeconds);
  }

  bool get _supported =>
      _backend.supportsCapability(BackendCapabilities.supportsCleaning);

  void _setSeconds(int value) {
    final clamped = value.clamp(_minSeconds, _maxSeconds);
    setState(() => _seconds = clamped);
    _config.setCleaningSeconds(clamped);
  }

  @override
  Widget build(BuildContext context) {
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;
    // A 2x2 grid of equal cells: explainer and warning on the left, the time
    // slider and the run button on the right.  Portrait stacks the same cells.
    final explainer = _buildExplainer(context);
    final warning = _buildWarning(context);
    final timeCard = _buildTimeCard(context);
    final action = _buildAction(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Padding(
        padding: OrionSpacing.screenPaddingWithBottomNav,
        child: isLandscape
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(child: explainer),
                        const SizedBox(height: OrionSpacing.controlGap),
                        Expanded(child: warning),
                      ],
                    ),
                  ),
                  const SizedBox(width: OrionSpacing.controlGap),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(child: timeCard),
                        const SizedBox(height: OrionSpacing.controlGap),
                        Expanded(child: action),
                      ],
                    ),
                  ),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: explainer),
                  const SizedBox(height: OrionSpacing.controlGap),
                  Expanded(child: warning),
                  const SizedBox(height: OrionSpacing.controlGap),
                  Expanded(child: timeCard),
                  const SizedBox(height: OrionSpacing.controlGap),
                  Expanded(child: action),
                ],
              ),
      ),
    );
  }

  /// What the run does.
  Widget _buildExplainer(BuildContext context) {
    final theme = Theme.of(context);
    return GlassCard(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: OrionSpacing.cardPadding,
        child: Center(
          child: SingleChildScrollView(
            child: Text(
              FlutterI18n.translate(context, 'cleaning.explainer'),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 19,
                height: 1.4,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// The one thing the operator must not do while it is going.
  Widget _buildWarning(BuildContext context) {
    final warning = Colors.orangeAccent;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
        color: warning.withValues(alpha: 0.12),
        border: Border.all(color: warning.withValues(alpha: 0.45)),
      ),
      child: Center(
        child: SingleChildScrollView(
          child: Text(
            FlutterI18n.translate(context, 'cleaning.uvWarning'),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 19,
              height: 1.4,
              fontWeight: FontWeight.w700,
              color: warning,
            ),
          ),
        ),
      ),
    );
  }

  /// Duration, in the shape of the heater's temperature slider — same padding,
  /// same label row over a gradient track, so the two read the same.
  Widget _buildTimeCard(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    return GlassCard(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(
                    FlutterI18n.translate(context, 'cleaning.time'),
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 20,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      '$_seconds',
                      style: const TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -1,
                      ),
                    ),
                    Text(
                      ' ${FlutterI18n.translate(context, 'exposure.unitSec')}',
                      style: TextStyle(
                        fontSize: 20,
                        color:
                            theme.colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const Spacer(),
            SizedBox(
              height: 30,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    height: 10,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      gradient: LinearGradient(
                        colors: [
                          primary.withValues(alpha: 0.25),
                          primary,
                        ],
                      ),
                    ),
                  ),
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: Colors.transparent,
                      inactiveTrackColor: Colors.transparent,
                      thumbColor: Colors.white,
                      overlayColor: Colors.white.withValues(alpha: 0.2),
                      thumbShape: const RoundSliderThumbShape(
                        enabledThumbRadius: 12.0,
                      ),
                      overlayShape: const RoundSliderOverlayShape(
                        overlayRadius: 28.0,
                      ),
                      trackHeight: 48.0,
                    ),
                    child: Slider(
                      value: _seconds.toDouble(),
                      min: _minSeconds.toDouble(),
                      max: _maxSeconds.toDouble(),
                      divisions: _maxSeconds - _minSeconds,
                      onChanged: (value) => _setSeconds(value.round()),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAction(BuildContext context) {
    if (!_supported) {
      return GlassButton(
        onPressed: null,
        tint: GlassButtonTint.none,
        style: ElevatedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          minimumSize: const Size(double.infinity, double.infinity),
        ),
        child: Text(
          FlutterI18n.translate(context, 'cleaning.notAvailable'),
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
        ),
      );
    }
    final theme = Theme.of(context);
    return HoldButton(
      duration: const Duration(milliseconds: 1500),
      tint: GlassButtonTint.positive,
      style: ElevatedButton.styleFrom(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
        ),
        minimumSize: const Size(double.infinity, double.infinity),
      ),
      onPressed: _start,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            FlutterI18n.translate(context, 'cleaning.start'),
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            FlutterI18n.translate(context, 'cleaning.holdHint'),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 17,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }

  /// Kick off a cleaning run and hold the countdown until it finishes or the
  /// operator stops it.  Either way the LED is switched off afterwards.
  Future<void> _start() async {
    final started = await _backend.startCleaning();
    if (!started) {
      if (mounted) _showStartFailed();
      return;
    }
    if (!mounted) {
      await _backend.stopCleaning();
      return;
    }
    try {
      // Same countdown the Exposure page shows.
      await showExposureCountdownDialog(
        context,
        countdownSeconds: _seconds,
        title: FlutterI18n.translate(context, 'cleaning.running'),
        stopLabelKey: 'cleaning.stop',
      );
    } finally {
      await _backend.stopCleaning();
    }
  }

  void _showStartFailed() {
    showDialog<void>(
      context: context,
      builder: (ctx) => GlassAlertDialog(
        title: Text(FlutterI18n.translate(context, 'common.error')),
        content: Text(
          FlutterI18n.translate(context, 'cleaning.startFailed'),
          style: const TextStyle(fontSize: 20),
        ),
        actions: [
          GlassButton(
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(0, 60),
            ),
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(FlutterI18n.translate(context, 'common.ok')),
          ),
        ],
      ),
    );
  }
}

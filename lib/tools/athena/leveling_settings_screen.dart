/*
* Orion - Leveling Settings Screen
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

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_i18n/flutter_i18n.dart';
import 'package:orion/backend_service/providers/manual_provider.dart';
import 'package:orion/backend_service/providers/status_provider.dart';
import 'package:orion/glasser/glasser.dart';
import 'package:orion/util/error_handling/error_dialog.dart';
import 'package:orion/util/orion_config.dart';
import 'package:orion/util/orion_spacing.dart';
import 'package:orion/util/providers/theme_provider.dart';
import 'package:orion/util/widgets/system_status_widget.dart';
import 'package:orion/widgets/orion_app_bar.dart';
import 'package:orion/widgets/zoom_value_editor_dialog.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';

/// Leveling settings — currently the applied Z offset, editable via a
/// slider that is limited to ±20% of the current value so it can only be
/// nudged, not wildly changed.
class LevelingSettingsScreen extends StatefulWidget {
  const LevelingSettingsScreen({super.key});

  @override
  State<LevelingSettingsScreen> createState() => _LevelingSettingsScreenState();
}

class _LevelingSettingsScreenState extends State<LevelingSettingsScreen> {
  @override
  void initState() {
    super.initState();
    // Fetch the current kinematic status so the Z offset is up to date.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Provider.of<StatusProvider>(context, listen: false)
            .refreshKinematicStatus();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isGlass =
        Provider.of<ThemeProvider>(context, listen: false).isGlassTheme;

    return GlassApp(
      child: Scaffold(
        backgroundColor: isGlass
            ? Colors.transparent
            : Theme.of(context).colorScheme.surface,
        appBar: OrionAppBar(
          title: Text(
            FlutterI18n.translate(context, 'leveling.settingsTitle'),
          ),
          toolbarHeight: Theme.of(context).appBarTheme.toolbarHeight,
          actions: const [SystemStatusWidget()],
        ),
        body: SafeArea(
          child: Padding(
            padding: OrionSpacing.screenPaddingWithBottomNav,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildZOffsetSection(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildZOffsetSection(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final config = OrionConfig();
    final base = config.getBaseZOffset();
    final double? offset = base != null
        ? base + config.getZOffsetOverride()
        : Provider.of<StatusProvider>(context).kinematicStatus?.offset;

    return GlassCard(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: OrionSpacing.cardPadding,
        child: Row(
          children: [
            PhosphorIcon(PhosphorIcons.arrowsVertical(),
                size: 28, color: primary),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    FlutterI18n.translate(context, 'leveling.settingsZOffset'),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    offset != null ? '${offset.toStringAsFixed(3)} mm' : '--',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: primary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    FlutterI18n.translate(
                        context, 'leveling.settingsZOffsetHint'),
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.2,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
            GlassButton(
              tint: GlassButtonTint.neutral,
              onPressed: _editOffset,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(0, 48),
              ),
              child: Text(
                FlutterI18n.translate(context, 'common.edit'),
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _editOffset() async {
    final config = OrionConfig();
    final statusProvider =
        Provider.of<StatusProvider>(context, listen: false);
    var base = config.getBaseZOffset();
    if (base == null) {
      // No leveling base recorded yet — capture the current backend offset
      // as the reference so the ±20% range doesn't drift across edits.
      base = statusProvider.kinematicStatus?.offset ?? 0.0;
      config.setBaseZOffset(base);
    }
    final current = base + config.getZOffsetOverride();
    // Limit the slider to ±20% of the base offset (0.1 mm floor so it stays
    // usable when the base is at or near zero).  Anchoring to the base —
    // not the current effective offset — keeps the range from walking every
    // time a new offset is saved.
    final delta = max(base.abs() * 0.2, 0.1);
    final result = await ZoomValueEditorDialog.show(
      context,
      title: FlutterI18n.translate(context, 'leveling.settingsZOffset'),
      currentValue: current,
      min: base - delta,
      max: base + delta,
      suffix: 'mm',
      decimals: 3,
      step: 0.01,
    );
    if (result == null || !mounted) return;

    final ok = await Provider.of<ManualProvider>(context, listen: false)
        .setZOffset(result);
    if (!ok) {
      if (mounted) showErrorDialog(context, 'GOLDEN-APE');
      return;
    }
    // Persist the override relative to the fixed base, rounded to the
    // slider's precision so it doesn't accumulate float noise.
    config.setZOffsetOverride(double.parse((result - base).toStringAsFixed(3)));
    await statusProvider.refreshKinematicStatus();
    if (mounted) setState(() {});
  }
}

/*
* Orion - Leveling Screen
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
import 'package:orion/tools/c3d_athena2_wizard.dart';
import 'package:orion/tools/leveling_configs.dart';
import 'package:orion/tools/manual_leveling_screen.dart';
import 'package:orion/util/orion_config.dart';
import 'package:orion/util/orion_spacing.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

class LevelingScreen extends StatelessWidget {
  const LevelingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final config = OrionConfig();
    final levelingConfig = getLevelingConfigForMachine(
      config.getMachineModelName(),
    );
    final backend = BackendService();
    final assistedEnabled = levelingConfig != null &&
        config.hasForceSensor() &&
        config.getLevelingMode() == 'athena2' &&
        backend.supportsCapability(BackendCapabilities.supportsForceLeveling);

    return SafeArea(
      child: Padding(
        padding: OrionSpacing.screenPaddingWithBottomNav,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: _buildModeCard(
                context,
                title: FlutterI18n.translate(context, 'leveling.assisted'),
                description:
                    FlutterI18n.translate(context, 'leveling.assistedDesc'),
                icon: PhosphorIcons.magicWand(),
                accentColor: accent,
                accentCard: assistedEnabled,
                heroTag: 'start-assisted',
                actionLabel: assistedEnabled
                    ? FlutterI18n.translate(context, 'leveling.startLeveling')
                    : FlutterI18n.translate(context, 'leveling.notAvailable'),
                actionTint: assistedEnabled
                    ? GlassButtonTint.positive
                    : GlassButtonTint.none,
                actionEnabled: assistedEnabled,
                actionIcon: assistedEnabled
                    ? PhosphorIcon(PhosphorIcons.magicWand())
                    : PhosphorIcon(PhosphorIcons.warning()),
                onPressed: assistedEnabled
                    ? () => Navigator.of(context).push(
                          _buildOverlayRoute(
                            Athena2LevelingWizard(config: levelingConfig),
                          ),
                        )
                    : null,
              ),
            ),
            const SizedBox(width: OrionSpacing.controlGap),
            Expanded(
              child: _buildModeCard(
                context,
                title: FlutterI18n.translate(context, 'leveling.manual'),
                description:
                    FlutterI18n.translate(context, 'leveling.manualDesc'),
                icon: PhosphorIconsFill.wrench,
                accentColor: accent,
                accentCard: true,
                heroTag: 'start-manual',
                actionLabel:
                    FlutterI18n.translate(context, 'leveling.manualMode'),
                actionTint: GlassButtonTint.positive,
                actionEnabled: true,
                actionIcon: const Icon(PhosphorIconsFill.wrench),
                onPressed: () {
                  Navigator.of(context).push(
                    _buildOverlayRoute(const ManualLevelingScreen()),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModeCard(
    BuildContext context, {
    required String title,
    required String description,
    required IconData icon,
    required Color accentColor,
    required bool accentCard,
    required String heroTag,
    required String actionLabel,
    required GlassButtonTint actionTint,
    required bool actionEnabled,
    required Widget actionIcon,
    VoidCallback? onPressed,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return GlassCard(
      margin: EdgeInsets.zero,
      accentColor: accentCard ? accentColor : null,
      child: Padding(
        padding: OrionSpacing.cardPadding.copyWith(top: 16, bottom: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: accentColor.withValues(alpha: isDark ? 0.14 : 0.10),
                    border: Border.all(
                      color:
                          accentColor.withValues(alpha: isDark ? 0.35 : 0.24),
                    ),
                  ),
                  child: Icon(icon, color: accentColor, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      fontSize: 24,
                      height: 1.15,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Expanded(
              child: Center(
                child: Text(
                  description,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    height: 1.35,
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: GlassFloatingActionButton.extended(
                heroTag: heroTag,
                scale: 1.2,
                icon: actionIcon,
                label: actionLabel,
                tint: actionTint,
                onPressed: actionEnabled ? onPressed : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

PageRouteBuilder<T> _buildOverlayRoute<T>(Widget child) {
  return PageRouteBuilder<T>(
    opaque: false,
    barrierDismissible: false,
    barrierColor: Colors.black.withValues(alpha: 0.35),
    transitionDuration: const Duration(milliseconds: 300),
    reverseTransitionDuration: const Duration(milliseconds: 250),
    pageBuilder: (_, __, ___) => child,
    transitionsBuilder: (_, animation, __, child) {
      return FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
        child: child,
      );
    },
  );
}

/*
* Orion - Resin Row
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
import 'package:provider/provider.dart';
import 'package:orion/backend_service/providers/resins_provider.dart';
import 'package:orion/glasser/glasser.dart';
import 'package:orion/util/providers/theme_provider.dart';
import 'package:orion/widgets/resin_chip.dart';

/// One resin profile row, drawn exactly as the materials list draws it: name
/// (success green when it is the active or chosen one), its lock/template
/// marker and its parameter chips.
///
/// The materials list passes its edit affordance as [trailing]; the picker
/// screens leave it empty.
class ResinRow extends StatelessWidget {
  const ResinRow({
    super.key,
    required this.resin,
    required this.highlighted,
    required this.onTap,
    this.trailing,
  });

  final ResinProfile resin;

  /// Draws the row in the active/default treatment.
  final bool highlighted;

  /// Tapping the row itself - the edit affordance is [trailing].
  final VoidCallback onTap;

  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final depthUm = resin.layerHeightUm;
    final exposureS = resin.normalExposureSeconds;

    final isLocked = resin.locked;
    final templatePrefix = RegExp(r'^\s*\[template\]\s*', caseSensitive: false);
    final isTemplate = templatePrefix.hasMatch(resin.name);
    final cleanedName = resin.name.replaceFirst(templatePrefix, '').trim();
    final displayName = cleanedName.isEmpty ? resin.name : cleanedName;

    final outlineColor = highlighted
        ? Colors.green.shade400.withValues(alpha: 0.55)
        : Theme.of(context).dividerColor.withValues(alpha: 0.35);

    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final isGlassMode =
        Provider.of<ThemeProvider>(context, listen: false).isGlassTheme;

    final fillColor = highlighted && !isGlassMode
        ? Colors.green.shade400.withValues(alpha: 0.08)
        : (isDarkMode
            ? Color.alphaBlend(
                Colors.white.withValues(alpha: 0.05),
                Theme.of(context).colorScheme.surface,
              )
            : null);

    final accentColorForCard =
        highlighted && isGlassMode ? Colors.green.shade400 : null;

    return GlassCard(
      elevation: highlighted ? 2 : 1,
      outlined: false,
      color: fillColor,
      accentColor: accentColorForCard,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: outlineColor,
              width: highlighted ? 1.6 : 1.0,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 10,
            ),
            child: Row(
              children: [
                if (highlighted) ...[
                  Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: Colors.green.shade400.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.green.shade400.withValues(alpha: 0.55),
                        width: 1,
                      ),
                    ),
                    child: Icon(
                      Icons.check_rounded,
                      size: 14,
                      color: Colors.green.shade300,
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                // Name + meta
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (isLocked) ...[
                            // Deliberately not a Tooltip: Tooltip uses an
                            // OverlayPortal whose semantics graft trips a
                            // Windows engine AXTree bug when it sits inside a
                            // scrollable viewport (flutter/flutter#182444).
                            // The icon keeps the same accessibility label.
                            Icon(
                              Icons.lock_outline,
                              size: 16,
                              color:
                                  Theme.of(context).textTheme.bodySmall?.color,
                              semanticLabel: FlutterI18n.translate(
                                  context, 'resins.locked'),
                            ),
                            const SizedBox(width: 6),
                          ],
                          if (isTemplate) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 9, vertical: 3),
                              decoration: BoxDecoration(
                                color: Theme.of(context)
                                    .colorScheme
                                    .surface
                                    .withValues(alpha: 0.5),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                  color: Theme.of(context)
                                      .dividerColor
                                      .withValues(alpha: 0.3),
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                FlutterI18n.translate(
                                    context, 'resins.template'),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.color,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                          Expanded(
                            child: Text(
                              displayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: highlighted ? Colors.green.shade400 : null,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Material parameters, immediately left of the edit
                // affordance so they read as one cluster.
                if (depthUm != null)
                  ResinChip(
                    icon: PhosphorIcons.stack(),
                    label: FlutterI18n.translate(
                        context, 'resins.layerHeightChip',
                        translationParams: {
                          'value': formatResinChipNumber(depthUm)
                        }),
                  ),
                if (depthUm != null) const SizedBox(width: 6),
                if (exposureS != null)
                  ResinChip(
                    icon: PhosphorIcons.timer(),
                    label: FlutterI18n.translate(
                        context, 'resins.exposureChip',
                        translationParams: {
                          'value': formatResinChipNumber(exposureS)
                        }),
                  ),
                if (exposureS != null) const SizedBox(width: 10),
                // Edit affordance. Locked (manufacturer) profiles stay
                // tappable: tapping one explains the lock and offers to
                // open it as a clone instead of editing it in place.
                // No Tooltip wrapper here on purpose: Tooltip's OverlayPortal
                // semantics graft trips the Windows AXTree bug inside this
                // ListView (flutter/flutter#182444). The visible "Edit" text
                // and the icon's semantic label carry the meaning instead.
                if (trailing != null) ...[
                  const SizedBox(width: 10),
                  trailing!,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

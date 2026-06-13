/*
* Glasser - Glass Dialog Header Widget
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

/// Standardized header for custom [GlassDialog] content.
///
/// Use this in dialogs that have custom bodies (lists, pickers, complex
/// controls) so the title row follows the same visual language as Orion's
/// other dialogs.
class GlassDialogHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData? icon;
  final Widget? leading;
  final Widget? badge;
  final Widget? trailing;
  final bool showCloseButton;
  final VoidCallback? onClose;
  final EdgeInsetsGeometry padding;

  const GlassDialogHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.leading,
    this.badge,
    this.trailing,
    this.showCloseButton = true,
    this.onClose,
    this.padding = const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
  });

  @override
  Widget build(BuildContext context) {
    final resolvedLeading = leading ??
        (icon != null
            ? Icon(
                icon,
                size: 24,
                color: Theme.of(context).colorScheme.primary,
              )
            : null);

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).dividerColor.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          if (resolvedLeading != null) ...[
            resolvedLeading,
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (subtitle != null && subtitle!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.68),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (badge != null) ...[
            badge!,
            const SizedBox(width: 8),
          ],
          if (trailing != null) ...[
            trailing!,
            const SizedBox(width: 8),
          ],
          if (showCloseButton)
            IconButton(
              onPressed: onClose ?? () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close, size: 20),
              padding: const EdgeInsets.all(4),
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              tooltip: 'Close',
            ),
        ],
      ),
    );
  }
}

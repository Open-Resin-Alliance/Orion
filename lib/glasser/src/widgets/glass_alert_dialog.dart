/*
* Glasser - Glass Alert Dialog Widget
* Copyright (C) 2024 Open Resin Alliance
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

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../util/providers/theme_provider.dart';
import '../constants.dart';

/// An alert dialog that automatically becomes glassmorphic when the glass theme is active.
///
/// This widget is a drop-in replacement for [AlertDialog]. When the glass theme is enabled,
/// it renders with a glassmorphic effect for visual consistency. Otherwise, it falls back to a normal alert dialog.
///
/// Example usage:
/// ```dart
/// GlassAlertDialog(
///   title: Text('Alert'),
///   content: Text('Are you sure?'),
///   actions: [TextButton(onPressed: () {}, child: Text('OK'))],
/// )
/// ```
///
/// See also:
///
///  * [GlassDialog], for a more generic glass dialog.
///  * [AlertDialog], the standard Flutter alert dialog.
class GlassAlertDialog extends StatelessWidget {
  /// An alert dialog that automatically becomes glassmorphic when the glass theme is active.
  final Widget? title;
  final Widget? content;
  final List<Widget>? actions;
  final EdgeInsetsGeometry titlePadding;
  final EdgeInsetsGeometry contentPadding;
  final EdgeInsetsGeometry actionsPadding;

  const GlassAlertDialog({
    super.key,
    this.title,
    this.content,
    this.actions,
    this.titlePadding = const EdgeInsets.fromLTRB(24.0, 24.0, 24.0, 0.0),
    this.contentPadding = const EdgeInsets.fromLTRB(24.0, 20.0, 24.0, 24.0),
    this.actionsPadding = const EdgeInsets.fromLTRB(24.0, 0.0, 24.0, 16.0),
  });

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    if (!themeProvider.isGlassTheme) {
      return AlertDialog(
        title: title,
        content: content,
        actions: actions,
        titlePadding: titlePadding,
        contentPadding: contentPadding,
        actionsPadding: actionsPadding,
      );
    }

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding:
          const EdgeInsets.symmetric(horizontal: 40.0, vertical: 24.0),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minWidth: 280,
          maxWidth: MediaQuery.of(context).size.width * 0.8,
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(glassCornerRadius),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(glassCornerRadius),
                    color: Colors.white.withValues(alpha: 0.1),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.2),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 30,
                        offset: const Offset(0, 15),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (title != null)
                        Padding(
                          padding: titlePadding,
                          child: DefaultTextStyle(
                            style: const TextStyle(
                              fontFamily: 'AtkinsonHyperlegible',
                              fontSize: 24,
                              fontWeight: FontWeight.w500,
                              color: Colors.white,
                            ),
                            child: title!,
                          ),
                        ),
                      if (content != null)
                        Flexible(
                          child: Padding(
                            padding: contentPadding,
                            child: DefaultTextStyle(
                              style: const TextStyle(
                                fontFamily: 'AtkinsonHyperlegible',
                                fontSize: 20,
                                color: Colors.white70,
                              ),
                              child: content!,
                            ),
                          ),
                        ),
                      if (actions != null && actions!.isNotEmpty)
                        Padding(
                          padding: actionsPadding,
                          child: Row(
                            children: actions!.asMap().entries.map((entry) {
                              final index = entry.key;
                              final action = entry.value;
                              return Expanded(
                                child: Padding(
                                  padding: EdgeInsets.only(
                                    left: index == 0 ? 0 : 4,
                                    right: index == actions!.length - 1 ? 0 : 4,
                                  ),
                                  child: _GlassTextButton(child: action),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Internal glass text button for alert dialog actions
class _GlassTextButton extends StatelessWidget {
  final Widget child;

  const _GlassTextButton({required this.child});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    if (!themeProvider.isGlassTheme) {
      return child;
    }

    // Extract the onPressed and child from the TextButton
    if (child is TextButton) {
      final textButton = child as TextButton;
      return ClipRRect(
        borderRadius: BorderRadius.circular(8.0), // glassSmallCornerRadius
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius:
                  BorderRadius.circular(8.0), // glassSmallCornerRadius
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius:
                    BorderRadius.circular(8.0), // glassSmallCornerRadius
                onTap: textButton.onPressed,
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: DefaultTextStyle(
                    style: const TextStyle(
                      fontFamily: 'AtkinsonHyperlegible',
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                    child: _buildButtonContentWithIcon(textButton.child!),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return child;
  }
}

/// Helper function to add icons to button content based on text
Widget _buildButtonContentWithIcon(Widget originalChild) {
  if (originalChild is Text) {
    final text = originalChild.data?.toLowerCase() ?? '';

    IconData? icon;

    // Map common button text to icons
    if (text.contains('cancel') ||
        text.contains('close') ||
        text.contains('later')) {
      icon = Icons.close;
    } else if (text.contains('confirm') ||
        text.contains('ok') ||
        text.contains('set') ||
        text.contains('save') ||
        text.contains('now')) {
      icon = Icons.check;
    } else if (text.contains('delete')) {
      icon = Icons.delete_outline;
    } else if (text.contains('disconnect')) {
      icon = Icons.wifi_off;
    } else if (text.contains('connect')) {
      icon = Icons.wifi;
    } else if (text.contains('skip')) {
      icon = Icons.skip_next;
    } else if (text.contains('stay')) {
      icon = Icons.stay_current_portrait;
    }

    if (icon != null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 18,
            color: Colors.white,
          ),
          const SizedBox(width: 8),
          Text(originalChild.data ?? ''),
        ],
      );
    }
  }

  return originalChild;
} // Backwards compatibility alias

typedef GlassAwareAlertDialog = GlassAlertDialog;

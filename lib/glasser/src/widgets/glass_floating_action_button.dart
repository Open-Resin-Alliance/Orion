/*
* Glasser - Glass Floating Action Button Widget
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

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../util/providers/theme_provider.dart';
import '../constants.dart';

/// A floating action button that automatically becomes glassmorphic when the glass theme is active.
///
/// This widget is a drop-in replacement for [FloatingActionButton] and [FloatingActionButton.extended].
/// When the glass theme is enabled, it renders with a glassmorphic effect for visual consistency.
///
/// Example usage:
/// ```dart
/// GlassFloatingActionButton(
///   onPressed: () {},
///   child: Icon(Icons.add),
/// )
/// ```
///
/// See also:
///
///  * [GlassScaffold], for glass-aware scaffolds.
///  * [FloatingActionButton], the standard Flutter FAB.
class GlassFloatingActionButton extends StatelessWidget {
  /// A floating action button that automatically becomes glassmorphic when the glass theme is active.
  final Widget? child;
  final String? label;
  final Widget? icon;
  final VoidCallback? onPressed;
  final String? heroTag;
  final bool extended;
  // Size variant scaling: 1.0 default, >1 for larger buttons.
  final double scale;
  // If true and extended, places the icon after the text (e.g. "Next ->").
  final bool iconAfterLabel;

  const GlassFloatingActionButton({
    super.key,
    this.child,
    this.onPressed,
    this.heroTag,
    this.scale = 1.0,
    this.iconAfterLabel = false,
  })  : label = null,
        icon = null,
        extended = false;

  const GlassFloatingActionButton.extended({
    super.key,
    this.label,
    this.icon,
    this.onPressed,
    this.heroTag,
    this.scale = 1.0,
    this.iconAfterLabel = false,
  })  : child = null,
        extended = true;

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    // (theme lookup removed; currently not needed in this branch)

    if (!themeProvider.isGlassTheme) {
      final cs = Theme.of(context).colorScheme;
      final bg = cs.secondaryContainer;
      final fg = cs.onSecondaryContainer;
      if (extended) {
        final iconWidget = icon == null
            ? null
            : IconTheme(
                data: IconThemeData(size: 20 * scale, color: fg),
                child: icon!,
              );
        final textWidget = Flexible(
          child: Text(
            label ?? '',
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'AtkinsonHyperlegible',
              color: fg,
              fontSize: 16 * scale,
              fontWeight: FontWeight.w500,
            ),
          ),
        );
        final children = iconAfterLabel
            ? [
                textWidget,
                if (iconWidget != null) SizedBox(width: 8 * scale),
                if (iconWidget != null) iconWidget
              ]
            : [
                if (iconWidget != null) iconWidget,
                if (iconWidget != null) SizedBox(width: 8 * scale),
                textWidget
              ];
        return Container(
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(glassCornerRadius),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onPressed,
              borderRadius: BorderRadius.circular(glassCornerRadius),
              splashColor: fg.withValues(alpha: 0.1),
              highlightColor: fg.withValues(alpha: 0.05),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: 16 * scale,
                  vertical: 12 * scale,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: children,
                ),
              ),
            ),
          ),
        );
      } else {
        return FloatingActionButton(
          heroTag: heroTag,
          onPressed: onPressed,
          backgroundColor: bg,
          child: IconTheme(
            data: IconThemeData(size: 24 * scale, color: fg),
            child: child ?? const SizedBox(),
          ),
        );
      }
    }

    // Glass theme: create a glassmorphic floating action button
    if (extended) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(glassCornerRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(glassCornerRadius),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.3),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(glassCornerRadius),
                onTap: onPressed,
                splashColor: Colors.white.withValues(alpha: 0.2),
                highlightColor: Colors.white.withValues(alpha: 0.1),
                child: Container(
                  constraints: BoxConstraints(
                    minHeight: 48 * scale,
                    minWidth: 48 * scale,
                  ),
                  padding: EdgeInsets.symmetric(
                    horizontal: 16 * scale,
                    vertical: 12 * scale,
                  ),
                  child: Builder(builder: (context) {
                    final iconWidget = icon == null
                        ? null
                        : DefaultTextStyle(
                            style: const TextStyle(
                                fontFamily: 'AtkinsonHyperlegible',
                                color: Colors.white),
                            child: IconTheme(
                              data: IconThemeData(
                                  color: Colors.white, size: 20 * scale),
                              child: icon!,
                            ),
                          );
                    final textWidget = Flexible(
                      child: DefaultTextStyle(
                        style: TextStyle(
                          fontFamily: 'AtkinsonHyperlegible',
                          color: Colors.white,
                          fontSize: 16 * scale,
                          fontWeight: FontWeight.w500,
                        ),
                        child: Text(
                          label ?? '',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    );
                    final children = iconAfterLabel
                        ? [
                            textWidget,
                            if (iconWidget != null) SizedBox(width: 8 * scale),
                            if (iconWidget != null) iconWidget
                          ]
                        : [
                            if (iconWidget != null) iconWidget,
                            if (iconWidget != null) SizedBox(width: 8 * scale),
                            textWidget
                          ];
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: children,
                    );
                  }),
                ),
              ),
            ),
          ),
        ),
      );
    } else {
      return FloatingActionButton(
        heroTag: heroTag,
        onPressed: onPressed,
        elevation: 0,
        backgroundColor: Colors.transparent,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.3),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(28),
                  onTap: onPressed,
                  splashColor: Colors.white.withValues(alpha: 0.2),
                  highlightColor: Colors.white.withValues(alpha: 0.1),
                  child: Container(
                    constraints: BoxConstraints(
                      minHeight: 56 * scale,
                      minWidth: 56 * scale,
                    ),
                    child: Center(
                      child: DefaultTextStyle(
                        style: const TextStyle(
                            fontFamily: 'AtkinsonHyperlegible',
                            color: Colors.white),
                        child: IconTheme(
                          data: IconThemeData(
                              color: Colors.white, size: 24 * scale),
                          child: child ?? const SizedBox(),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }
  }
}

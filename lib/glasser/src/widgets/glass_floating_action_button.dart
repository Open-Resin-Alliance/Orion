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

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../util/providers/theme_provider.dart';
import 'glass_button.dart';
import '../constants.dart';
import '../glass_effect.dart';
import '../platform_config.dart';

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
  final GlassButtonTint tint;
  final bool doForceBlur;

  const GlassFloatingActionButton({
    super.key,
    this.child,
    this.onPressed,
    this.heroTag,
    this.scale = 1.0,
    this.iconAfterLabel = false,
    this.doForceBlur = false,
    this.tint = GlassButtonTint.none,
  })  : label = null,
        icon = null,
        extended = false;

  const GlassFloatingActionButton.withTint({
    super.key,
    this.child,
    this.onPressed,
    this.heroTag,
    this.scale = 1.0,
    this.iconAfterLabel = false,
    this.doForceBlur = false,
    this.tint = GlassButtonTint.none,
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
    this.doForceBlur = false,
    this.tint = GlassButtonTint.none,
  })  : child = null,
        extended = true;

  const GlassFloatingActionButton.extendedWithTint({
    super.key,
    this.label,
    this.icon,
    this.onPressed,
    this.heroTag,
    this.scale = 1.0,
    this.iconAfterLabel = false,
    this.doForceBlur = false,
    this.tint = GlassButtonTint.none,
  })  : child = null,
        extended = true;

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    // Resolve tint palette for this FAB. If the button is disabled, ignore tint.
    final effectiveTint = (onPressed == null) ? GlassButtonTint.none : tint;
    final _FabTintPalette? tintPalette =
        _resolveFabTintPalette(effectiveTint, context);

    // (theme lookup removed; currently not needed in this branch)

    if (!themeProvider.isGlassTheme) {
      final cs = Theme.of(context).colorScheme;
      final bg = tintPalette != null
          ? tintPalette.color.withValues(alpha: 0.10)
          : cs.secondaryContainer;
      final fg = tintPalette != null
          ? tintPalette.materialForeground
          : cs.onSecondaryContainer;
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
      final borderRadius = BorderRadius.circular(glassCornerRadius);
      final isEnabled = onPressed != null;
      final forceBlur = doForceBlur;
      final shadow = GlassPlatformConfig.interactiveShadow(
        enabled: isEnabled,
        blurRadius: 24,
        yOffset: 6,
        alpha: 0.18,
      );
      final fillOpacity =
          GlassPlatformConfig.surfaceOpacity(0.14, emphasize: true);
      // If tinted, compute a blended fill color and a border color
      final bool hasTint = tintPalette != null;
      final Color? blendedFillColor = hasTint
          ? Color.alphaBlend(
              tintPalette.color.withValues(alpha: 0.75), Colors.white)
          : null;
      final Color? borderColor = hasTint ? tintPalette.color : null;

      return Container(
        decoration: BoxDecoration(
          borderRadius: borderRadius,
          boxShadow: shadow,
        ),
        child: GlassEffect(
          borderRadius: borderRadius,
          sigma: glassBlurSigma,
          opacity: fillOpacity,
          color: blendedFillColor,
          floatingSurface: true,
          interactiveSurface: forceBlur ? false : true,
          borderWidth: 1.6,
          emphasizeBorder: true,
          borderColor: borderColor,
          useRawBorderAlpha: hasTint,
          borderAlpha: hasTint ? 0.45 : 0.2,
          child: Material(
            color: Colors.transparent,
            shape: RoundedRectangleBorder(borderRadius: borderRadius),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              borderRadius: borderRadius,
              onTap: onPressed,
              splashColor:
                  isEnabled ? Colors.white.withValues(alpha: 0.2) : null,
              highlightColor:
                  isEnabled ? Colors.white.withValues(alpha: 0.1) : null,
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
                          style: TextStyle(
                              fontFamily: 'AtkinsonHyperlegible',
                              color: hasTint
                                  ? tintPalette.glassForeground
                                  : Colors.white),
                          child: IconTheme(
                            data: IconThemeData(
                                color: hasTint
                                    ? tintPalette.glassForeground
                                    : Colors.white,
                                size: 20 * scale),
                            child: icon!,
                          ),
                        );
                  final textWidget = Flexible(
                    child: DefaultTextStyle(
                      style: TextStyle(
                        fontFamily: 'AtkinsonHyperlegible',
                        color: hasTint
                            ? tintPalette.glassForeground
                            : Colors.white,
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
      );
    } else {
      final borderRadius = BorderRadius.circular(glassCornerRadius);
      final shadow = GlassPlatformConfig.interactiveShadow(
        enabled: onPressed != null,
        blurRadius: 24,
        yOffset: 8,
        alpha: 0.18,
      );
      final fillOpacity =
          GlassPlatformConfig.surfaceOpacity(0.15, emphasize: true);

      final bool hasTint = tintPalette != null;
      final Color? blendedFillColor = hasTint
          ? Color.alphaBlend(
              tintPalette.color.withValues(alpha: 0.75), Colors.white)
          : null;
      final Color? borderColor = hasTint ? tintPalette.color : null;

      return FloatingActionButton(
        heroTag: heroTag,
        onPressed: onPressed,
        elevation: 0,
        hoverElevation: 0,
        focusElevation: 0,
        highlightElevation: 0,
        backgroundColor: Colors.transparent,
        child: SizedBox.expand(
          child: Container(
            decoration: BoxDecoration(
              borderRadius: borderRadius,
              boxShadow: shadow,
            ),
            child: GlassEffect(
              borderRadius: borderRadius,
              sigma: glassBlurSigma,
              opacity: fillOpacity,
              color: blendedFillColor,
              floatingSurface: true,
              interactiveSurface: true,
              borderWidth: 1.6,
              emphasizeBorder: true,
              borderColor: borderColor,
              useRawBorderAlpha: hasTint,
              borderAlpha: hasTint ? 0.45 : 0.2,
              child: Center(
                child: DefaultTextStyle(
                  style: const TextStyle(
                      fontFamily: 'AtkinsonHyperlegible', color: Colors.white),
                  child: IconTheme(
                    data: IconThemeData(
                        color: hasTint
                            ? tintPalette.glassForeground
                            : Colors.white,
                        size: 24 * scale),
                    child: child ?? const SizedBox(),
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

class _FabTintPalette {
  final Color color;
  final Color materialForeground;
  final Color glassForeground;

  const _FabTintPalette({
    required this.color,
    required this.materialForeground,
    required this.glassForeground,
  });
}

_FabTintPalette? _resolveFabTintPalette(
    GlassButtonTint tint, BuildContext context) {
  if (tint == GlassButtonTint.none) return null;
  if (tint == GlassButtonTint.neutral) {
    final primary = Theme.of(context).colorScheme.primary;
    return _FabTintPalette(
      color: primary,
      materialForeground: Colors.white,
      glassForeground: primary,
    );
  }
  switch (tint) {
    case GlassButtonTint.positive:
      return const _FabTintPalette(
        color: Colors.greenAccent,
        materialForeground: Colors.white,
        glassForeground: Colors.greenAccent,
      );
    case GlassButtonTint.warn:
      return const _FabTintPalette(
        color: Colors.orangeAccent,
        materialForeground: Colors.white,
        glassForeground: Colors.orangeAccent,
      );
    case GlassButtonTint.negative:
      return const _FabTintPalette(
        color: Colors.redAccent,
        materialForeground: Colors.white,
        glassForeground: Colors.redAccent,
      );
    default:
      return null;
  }
}

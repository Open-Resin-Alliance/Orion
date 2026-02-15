/*
* Glasser - Glass Card Widget
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
import 'package:orion/util/providers/theme_provider.dart';
import '../constants.dart';
import '../glass_effect.dart';
import '../platform_config.dart';

/// A card that automatically becomes glassmorphic when the glass theme is active.
///
/// This widget is a drop-in replacement for [Card]. When the glass theme is enabled,
/// it renders with a glassmorphic effect for visual consistency. Otherwise, it falls back to a normal card.
///
/// Example usage:
/// ```dart
/// GlassCard(
///   child: Text('Hello'),
/// )
/// ```
///
/// See also:
///
///  * [GlassScaffold], for glass-aware scaffolds.
///  * [Card], the standard Flutter card.
class GlassCard extends StatelessWidget {
  /// A card that automatically becomes glassmorphic when the glass theme is active.
  final Widget child;
  final EdgeInsetsGeometry? margin;
  final Color? color;
  final double? elevation;
  final ShapeBorder? shape;
  final bool outlined;

  /// Optional accent color applied as a border and subtle overlay tint when non-null.
  final Color? accentColor;

  /// Opacity of the accent overlay (0.0 - 1.0). Defaults to a subtle tint.
  final double accentOpacity;

  const GlassCard({
    super.key,
    required this.child,
    this.margin,
    this.color,
    this.elevation,
    this.shape,
    this.outlined = false,
    this.accentColor,
    this.accentOpacity = 0.06,
  });

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    if (!themeProvider.isGlassTheme) {
      // For non-glass theme, prefer to apply the accent color to the Card's
      // existing border (shape side) so the accent tints the card edge rather
      // than adding a separate outer border which looks visually detached.
      ShapeBorder? effectiveShape = shape;

      if (accentColor != null) {
        // Determine a sensible border radius to preserve the caller's shape
        // when possible, otherwise fall back to the standard corner radius.
        final BorderRadius resolvedRadius = (shape is RoundedRectangleBorder &&
                (shape as RoundedRectangleBorder).borderRadius is BorderRadius)
            ? (shape as RoundedRectangleBorder).borderRadius as BorderRadius
            : BorderRadius.circular(glassCornerRadius);

        if (shape == null || shape is RoundedRectangleBorder) {
          // If there is no custom shape or it's a RoundedRectangleBorder,
          // construct a RoundedRectangleBorder that includes a stroked side so
          // the accent color appears as the card's border.
          effectiveShape = RoundedRectangleBorder(
            borderRadius: resolvedRadius,
            side: BorderSide(color: accentColor!, width: 1.4),
          );
        } else {
          // If the provided shape is not a RoundedRectangleBorder we can't
          // reliably inject a side. Fall back to wrapping with a container
          // border (previous behavior) so we still show the accent.
          final card = outlined
              ? Card.outlined(
                  margin: margin ?? const EdgeInsets.all(4.0),
                  color: color,
                  elevation: elevation,
                  shape: shape,
                  child: child,
                )
              : Card(
                  margin: margin ?? const EdgeInsets.all(4.0),
                  color: color,
                  elevation: elevation,
                  shape: shape,
                  child: child,
                );

          return Container(
            margin: margin ?? const EdgeInsets.all(4.0),
            decoration: BoxDecoration(
              borderRadius: resolvedRadius,
              border: Border.all(color: accentColor!, width: 1.4),
            ),
            child: card,
          );
        }
      }

      // Compose a child that includes a subtly tinted overlay when an accent
      // color is present. The overlay is placed inside the Card and the Card
      // is clipped to the same shape so the tint stays within the card bounds
      // and doesn't paint outside or over the card's border.
      Widget cardInner = child;
      if (accentColor != null) {
        // Resolve a borderRadius matching the Card shape so the inner tint is
        // clipped and matches the rounded corners of the card.
        BorderRadius innerBorderRadius =
            BorderRadius.circular(glassCornerRadius);
        if (effectiveShape is RoundedRectangleBorder) {
          final rrb = effectiveShape;
          if (rrb.borderRadius is BorderRadius) {
            innerBorderRadius = rrb.borderRadius as BorderRadius;
          }
        }

        cardInner = Stack(
          children: [
            child,
            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    color: accentColor!.withValues(alpha: accentOpacity),
                    borderRadius: innerBorderRadius,
                  ),
                ),
              ),
            ),
          ],
        );
      }

      final card = outlined
          ? Card.outlined(
              margin: margin ?? const EdgeInsets.all(4.0),
              color: color,
              elevation: elevation,
              shape: effectiveShape,
              clipBehavior: Clip.antiAlias,
              child: cardInner,
            )
          : Card(
              margin: margin ?? const EdgeInsets.all(4.0),
              color: color,
              elevation: elevation,
              shape: effectiveShape,
              clipBehavior: Clip.antiAlias,
              child: cardInner,
            );

      return card;
    }

    // Extract borderRadius from shape if possible
    BorderRadius borderRadius = BorderRadius.circular(glassCornerRadius);
    if (shape is RoundedRectangleBorder) {
      final rrb = shape as RoundedRectangleBorder;
      if (rrb.borderRadius is BorderRadius) {
        borderRadius = rrb.borderRadius as BorderRadius;
      }
    }

    final hasAccent = accentColor != null;
    final tintColor = accentColor;

    // Provide a blended white base when tinted so the glass stays frosted
    // but carries the accent color subtly (matching GlassButton behavior).
    Color? blendedFillColor;
    if (hasAccent) {
      blendedFillColor =
          Color.alphaBlend(tintColor!.withOpacity(0.75), Colors.white);
    }

    return Container(
      margin: margin ?? const EdgeInsets.all(4.0), // Default Card margin
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: GlassPlatformConfig.surfaceShadow(
          blurRadius: outlined ? 14 : 16,
          yOffset: outlined ? 3 : 4,
          alpha: outlined ? 0.14 : 0.12,
        ),
        // In the glass theme, prefer drawing the border via GlassEffect so
        // we avoid a doubled border (outer Container + inner GlassEffect).
        // The material/non-glass branch still draws an outer border.
        border: null,
      ),
      child: GlassEffect(
        borderRadius: borderRadius,
        opacity: GlassPlatformConfig.surfaceOpacity(
          outlined ? 0.12 : 0.1,
          emphasize: outlined,
        ),
        sigma: glassBlurSigma,
        borderWidth: outlined ? 1.4 : 1.0,
        // When tinted, prefer a stronger border alpha and use the raw tint
        // alpha so the color matches the material button variant.
        borderColor: hasAccent ? tintColor : null,
        // When not accented, fall back to the standard subtle border alpha
        // so untinted cards still have a visible edge in the glass theme.
        borderAlpha: hasAccent ? 0.45 : 0.2,
        useRawBorderAlpha: hasAccent,
        // Provide a subtle tinted white base when a tint is present.
        color: blendedFillColor,
        floatingSurface: false,
        child: Material(
          type: MaterialType.transparency,
          shape: RoundedRectangleBorder(borderRadius: borderRadius),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              child,
              if (hasAccent)
                Positioned.fill(
                  child: IgnorePointer(
                    child: Container(
                      decoration: BoxDecoration(
                        color: tintColor!.withOpacity(accentOpacity),
                        borderRadius: borderRadius,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/*
* Glasser - Glass Effect Utilities
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
import 'constants.dart';
import 'platform_config.dart';

/// A widget that applies glassmorphic effects
class GlassEffect extends StatelessWidget {
  final Widget child;
  final double opacity;
  final double cornerRadius;
  final double sigma;
  final Color? color;
  final BorderRadiusGeometry? borderRadius;
  final double borderWidth;
  final bool emphasizeBorder;
  final double borderAlpha;
  final bool useRawOpacity;
  final bool useRawBorderAlpha;
  final bool interactiveSurface;
  final bool disableBlur;
  final bool forceBlur;

  const GlassEffect({
    super.key,
    required this.child,
    this.opacity = glassOpacity,
    this.cornerRadius = glassCornerRadius,
    this.sigma = glassBlurSigma,
    this.color,
    this.borderRadius,
    this.borderWidth = 1.0,
    this.emphasizeBorder = false,
    this.borderAlpha = 0.2,
    this.useRawOpacity = false,
    this.useRawBorderAlpha = false,
    this.interactiveSurface = false,
    this.disableBlur = false,
    this.forceBlur = false,
  });

  @override
  Widget build(BuildContext context) {
    final resolvedBorderRadius =
        borderRadius ?? BorderRadius.circular(cornerRadius);
    final clipRadius = _resolveClipRadius(resolvedBorderRadius, cornerRadius);
    final effectiveSigma = GlassPlatformConfig.blurSigma(sigma);
    final effectiveOpacity =
        useRawOpacity ? opacity : GlassPlatformConfig.surfaceOpacity(opacity);
    final enableBlur = !disableBlur &&
        GlassPlatformConfig.shouldBlur(
          interactiveSurface: interactiveSurface,
          force: forceBlur,
        );

    Widget decoratedChild = DecoratedBox(
      decoration: createGlassDecoration(
        opacity: effectiveOpacity,
        borderRadius: resolvedBorderRadius,
        color: color,
        borderWidth: borderWidth,
        emphasizeBorder: emphasizeBorder,
        borderAlpha: borderAlpha,
        useRawBorderAlpha: useRawBorderAlpha,
      ),
      child: child,
    );

    return RepaintBoundary(
      child: ClipRRect(
        borderRadius: clipRadius,
        clipBehavior: GlassPlatformConfig.clipBehavior,
        child: enableBlur
            ? BackdropFilter(
                filter: ImageFilter.blur(
                  sigmaX: effectiveSigma,
                  sigmaY: effectiveSigma,
                  tileMode: GlassPlatformConfig.blurTileMode,
                ),
                child: decoratedChild,
              )
            : decoratedChild,
      ),
    );
  }
}

/// Creates a standard glassmorphic decoration
BoxDecoration createGlassDecoration({
  double opacity = glassOpacity,
  BorderRadiusGeometry borderRadius =
      const BorderRadius.all(Radius.circular(glassCornerRadius)),
  Color? color,
  double borderWidth = 1.0,
  bool emphasizeBorder = false,
  double borderAlpha = 0.2,
  bool useRawBorderAlpha = false,
}) {
  final double effectiveBorderAlpha = useRawBorderAlpha
      ? borderAlpha
      : GlassPlatformConfig.borderOpacity(
          borderAlpha,
          emphasize: emphasizeBorder,
        );

  return BoxDecoration(
    color: (color ?? Colors.white).withValues(alpha: opacity),
    borderRadius: borderRadius,
    border: Border.all(
      color: Colors.white.withValues(
        alpha: effectiveBorderAlpha,
      ),
      width: borderWidth,
    ),
  );
}

/// Creates a glass backdrop filter
Widget createGlassBackdrop({
  required Widget child,
  double sigma = glassBlurSigma,
}) {
  return BackdropFilter(
    filter: ImageFilter.blur(
      sigmaX: GlassPlatformConfig.blurSigma(sigma),
      sigmaY: GlassPlatformConfig.blurSigma(sigma),
      tileMode: GlassPlatformConfig.blurTileMode,
    ),
    child: child,
  );
}

BorderRadius _resolveClipRadius(
  BorderRadiusGeometry geometry,
  double fallbackCornerRadius,
) {
  if (geometry is BorderRadius) {
    return geometry;
  }

  try {
    return geometry.resolve(TextDirection.ltr);
  } catch (_) {
    return BorderRadius.circular(fallbackCornerRadius);
  }
}

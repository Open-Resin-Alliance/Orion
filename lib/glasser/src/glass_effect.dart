/*
* Glasser - Glass Effect Utilities
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
import 'constants.dart';

/// A widget that applies glassmorphic effects
class GlassEffect extends StatelessWidget {
  final Widget child;
  final double opacity;
  final double cornerRadius;
  final double sigma;
  final Color? color;

  const GlassEffect({
    super.key,
    required this.child,
    this.opacity = glassOpacity,
    this.cornerRadius = glassCornerRadius,
    this.sigma = glassBlurSigma,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(cornerRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
        child: Container(
          decoration: createGlassDecoration(
            opacity: opacity,
            cornerRadius: cornerRadius,
            color: color,
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Creates a standard glassmorphic decoration
BoxDecoration createGlassDecoration({
  double opacity = glassOpacity,
  double cornerRadius = glassCornerRadius,
  Color? color,
}) {
  return BoxDecoration(
    color: (color ?? Colors.white).withValues(alpha: opacity),
    borderRadius: BorderRadius.circular(cornerRadius),
    border: Border.all(
      color: Colors.white.withValues(alpha: 0.2),
      width: 1.0,
    ),
  );
}

/// Creates a glass backdrop filter
Widget createGlassBackdrop({
  required Widget child,
  double sigma = glassBlurSigma,
}) {
  return BackdropFilter(
    filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
    child: child,
  );
}

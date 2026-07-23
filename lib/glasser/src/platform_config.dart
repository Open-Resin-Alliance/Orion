/*
* Glasser - Platform Adaptive Configuration
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

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Platform-adaptive configuration for glass widgets.
class GlassPlatformConfig {
  const GlassPlatformConfig._();

  static bool get isLinuxDesktop =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.linux;

  /// Whether to apply a backdrop blur for this surface.
  /// Small interactive controls (interactiveSurface=true) skip blur by
  /// default to improve performance; pass [force] to override.
  static bool shouldBlur(
      {bool interactiveSurface = false, bool force = false}) {
    if (force) return true;
    return !interactiveSurface;
  }

  /// Platform-tuned blur sigma.
  static double blurSigma(double base) {
    if (!isLinuxDesktop) return base;
    final adjusted = (base * 0.65) + 1.5;
    return adjusted.clamp(0.0, base).toDouble();
  }

  /// Surface opacity normalization. Slightly boosts opacity for better
  /// readability; [emphasize] increases the boost.
  static double surfaceOpacity(double base, {bool emphasize = false}) {
    final reducedBase = (base - 0.02).clamp(0.0, 1.0);
    final boost = emphasize ? 0.06 : 0.04;
    final maxOpacity = emphasize ? 0.28 : 0.22;
    final targetCap = (reducedBase + boost).clamp(0.0, maxOpacity);
    final adjusted = reducedBase + boost;
    return adjusted > targetCap ? targetCap : adjusted;
  }

  /// Border opacity adjustment so edge highlights remain visible with
  /// increased surface opacity.
  static double borderOpacity(double base, {bool emphasize = false}) {
    final boost = emphasize ? 0.07 : 0.05;
    final maxOpacity = emphasize ? 0.38 : 0.3;
    final adjusted = base + boost;
    return adjusted > maxOpacity ? maxOpacity : adjusted;
  }

  static List<BoxShadow> surfaceShadow({
    double blurRadius = 15.0,
    double yOffset = 4.0,
    double alpha = 0.1,
  }) {
    if (isLinuxDesktop) {
      return [
        BoxShadow(
          color: Colors.black.withValues(alpha: alpha * 0.75),
          blurRadius: blurRadius * 0.7,
          offset: Offset(0, yOffset * 0.75),
        ),
      ];
    }
    return [
      BoxShadow(
        color: Colors.black.withValues(alpha: alpha),
        blurRadius: blurRadius,
        offset: Offset(0, yOffset),
      ),
    ];
  }

  static List<BoxShadow>? interactiveShadow({
    bool enabled = true,
    double blurRadius = 20.0,
    double yOffset = 4.0,
    double alpha = 0.1,
  }) {
    if (!enabled) return null;
    if (isLinuxDesktop) {
      return [
        BoxShadow(
          color: Colors.black.withValues(alpha: alpha * 0.8),
          blurRadius: blurRadius * 0.65,
          offset: Offset(0, yOffset * 0.75),
        ),
      ];
    }
    return [
      BoxShadow(
        color: Colors.black.withValues(alpha: alpha),
        blurRadius: blurRadius,
        offset: Offset(0, yOffset),
      ),
    ];
  }

  static List<BoxShadow> selectionGlow({
    double blurRadius = 12.0,
    double alpha = 0.3,
  }) {
    if (isLinuxDesktop) {
      return [
        BoxShadow(
          color: Colors.white.withValues(alpha: alpha * 0.8),
          blurRadius: blurRadius * 0.7,
          offset: const Offset(0, 2),
        ),
      ];
    }
    return [
      BoxShadow(
        color: Colors.white.withValues(alpha: alpha),
        blurRadius: blurRadius,
        offset: const Offset(0, 4),
      ),
    ];
  }

  static TileMode get blurTileMode => TileMode.decal;
  static Clip get clipBehavior => Clip.antiAlias;
}

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

/// Provides adaptive configuration knobs for the glass widgets so that
/// expensive visual effects can be tuned per platform. The Linux desktop
/// renderer in particular struggles with multiple backdrop filters, so we
/// dampen the blur radius while slightly boosting opacity to preserve the
/// perceived look.
class GlassPlatformConfig {
  const GlassPlatformConfig._();

  /// Returns true when we are running on Flutter's Linux desktop target.
  static bool get isLinuxDesktop =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.linux;

  /// Returns a platform-tuned blur sigma.
  static double blurSigma(double base) {
    if (!isLinuxDesktop) {
      return base;
    }

    // Linux performs significantly better with a lower sigma. Adding a small
    // constant keeps the blur from looking too sharp on large surfaces.
    final adjusted = (base * 0.65) + 1.5;
    return adjusted.clamp(0.0, base).toDouble();
  }

  /// Normalises surface opacity for translucent fills. On Linux we boost the
  /// opacity a bit to compensate for the reduced blur strength.
  static double surfaceOpacity(double base, {bool emphasize = false}) {
    if (!isLinuxDesktop) {
      return base;
    }

    final boost = emphasize ? 0.08 : 0.06;
    final maxOpacity = emphasize ? 0.36 : 0.32;
    final adjusted = base + boost;
    return adjusted > maxOpacity ? maxOpacity : adjusted;
  }

  /// Adjusts border opacity so that edge highlights remain visible when we
  /// increase the surface opacity on Linux.
  static double borderOpacity(double base, {bool emphasize = false}) {
    if (!isLinuxDesktop) {
      return base;
    }

    final boost = emphasize ? 0.07 : 0.05;
    final maxOpacity = emphasize ? 0.38 : 0.3;
    final adjusted = base + boost;
    return adjusted > maxOpacity ? maxOpacity : adjusted;
  }

  /// Returns a shadow list suitable for surface elements such as cards.
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

  /// Returns shadow settings for elevated interactive elements (FABs, buttons).
  static List<BoxShadow>? interactiveShadow({
    bool enabled = true,
    double blurRadius = 20.0,
    double yOffset = 4.0,
    double alpha = 0.1,
  }) {
    if (!enabled) {
      return null;
    }

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

  /// Returns a soft glow for selected controls (chips, toggles, etc.).
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

  /// Tile mode used by blur filters. Using [TileMode.decal] prevents sampling
  /// beyond the clipped region which slightly improves performance.
  static TileMode get blurTileMode => TileMode.decal;

  /// Clip behaviour used by our glass surfaces. Keeping anti aliasing on
  /// avoids jagged edges without incurring the cost of saveLayer operations.
  static Clip get clipBehavior => Clip.antiAlias;
}

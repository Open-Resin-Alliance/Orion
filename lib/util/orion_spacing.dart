/*
* Orion - Shared Layout Spacing
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

/// Shared spacing tokens used by Orion screens.
///
/// This keeps top-level screen padding and common content gaps aligned across
/// the app so individual screens don't drift over time.
abstract final class OrionSpacing {
  // Home screen baseline:
  // - horizontal gutters: 20
  // - tight top offset: 5
  static const double screenHorizontal = 20.0;
  static const double screenTop = 5.0;
  static const double screenBottomNavClearance = 16.0;
  static const double controlGap = 20.0;
  static const double gridScreenHorizontal = screenHorizontal - 4.0;
  // Settings pages frequently use GlassCard's default 4px outer margin.
  // Compensate at the shell level so effective edge inset remains 20px.
  static const double settingsScreenHorizontal = screenHorizontal - 4.0;
  // For screens where card/button margins already contribute ~12px of edge
  // spacing, add this root padding so total edge inset equals screenHorizontal.
  static const double cardAwareScreenHorizontal = screenHorizontal - 12.0;

  static const EdgeInsets screenPadding = EdgeInsets.only(
    left: screenHorizontal,
    right: screenHorizontal,
    top: screenTop,
  );

  static const EdgeInsets screenPaddingWithBottomNav = EdgeInsets.only(
    left: screenHorizontal,
    right: screenHorizontal,
    top: screenTop,
    bottom: screenBottomNavClearance,
  );

  static const EdgeInsets screenPaddingNoTop = EdgeInsets.symmetric(
    horizontal: screenHorizontal,
  );

  static const EdgeInsets settingsScreenPadding = EdgeInsets.only(
    left: settingsScreenHorizontal,
    right: settingsScreenHorizontal,
    top: screenTop,
  );

  static const EdgeInsets settingsScreenPaddingNoTop = EdgeInsets.symmetric(
    horizontal: settingsScreenHorizontal,
  );

  static const double listGap = 8.0;
  static const double compactListGap = 4.0;

  static const EdgeInsets cardPadding = EdgeInsets.symmetric(
    horizontal: 14,
    vertical: 12,
  );

  static const EdgeInsets compactCardPadding = EdgeInsets.symmetric(
    horizontal: 12,
    vertical: 9,
  );
}

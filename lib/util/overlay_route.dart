/*
* Orion - Overlay Route
* Copyright (C) 2026 Open Resin Alliance
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

/// Presents a screen over the current one rather than replacing it: the flow
/// keeps its own full-screen surface, and the page behind it stays visible
/// through a dimmed barrier while it fades in.
///
/// This is how the leveling wizard and the calibration wizard are opened, so a
/// wizard is never squeezed into the shell's app bar and bottom navigation.
PageRouteBuilder<T> buildOverlayRoute<T>(Widget child) {
  return PageRouteBuilder<T>(
    opaque: false,
    barrierDismissible: false,
    barrierColor: Colors.black.withValues(alpha: 0.35),
    transitionDuration: const Duration(milliseconds: 300),
    reverseTransitionDuration: const Duration(milliseconds: 250),
    pageBuilder: (_, __, ___) => child,
    transitionsBuilder: (_, animation, __, child) {
      return FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
        child: child,
      );
    },
  );
}

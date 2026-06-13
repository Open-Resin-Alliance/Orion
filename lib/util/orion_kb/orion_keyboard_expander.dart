/*
* Orion - Orion Keyboard Expander
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

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:orion/util/orion_kb/orion_textfield_spawn.dart';

class OrionKbExpander extends StatelessWidget {
  /// For backwards compatibility: use textFieldKey if available
  final GlobalKey<SpawnOrionTextFieldState>? textFieldKey;
  /// Or pass notifiers directly for any keyboard input scenario
  final ValueNotifier<bool>? isKeyboardOpen;
  final ValueNotifier<double>? expandDistance;
  /// Optionally provide any widget key to auto-calculate expand distance
  /// Useful for inline editing scenarios like the zoom dialog
  final GlobalKey? widgetKey;

  const OrionKbExpander({
    super.key,
    this.textFieldKey,
    this.isKeyboardOpen,
    this.expandDistance,
    this.widgetKey,
  }) : assert(textFieldKey != null || (isKeyboardOpen != null && expandDistance != null) || widgetKey != null,
      'Either textFieldKey, both isKeyboardOpen and expandDistance, or widgetKey must be provided');

  @override
  Widget build(BuildContext context) {
    // Use provided notifiers or extract from textFieldKey
    final kbOpen = isKeyboardOpen ?? (textFieldKey?.currentState?.isKeyboardOpen ?? ValueNotifier<bool>(false));
    final expandDist = expandDistance ?? (textFieldKey?.currentState?.expandDistance ?? ValueNotifier<double>(0.0));

    return FutureBuilder(
      future: Future.delayed(Duration.zero),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          return ValueListenableBuilder<bool>(
            valueListenable: kbOpen,
            builder: (context, isKeyboardOpen, child) {
              return ValueListenableBuilder<double>(
                valueListenable: expandDist,
                builder: (context, expandDistanceValue, child) {
                  // If widgetKey provided and keyboard is open, calculate distance
                  double finalExpandDistance = expandDistanceValue;
                  if (isKeyboardOpen && widgetKey != null) {
                    finalExpandDistance = _calculateExpandDistance(context);
                  }

                  return AnimatedContainer(
                    curve: Curves.easeInOut,
                    duration: const Duration(milliseconds: 300),
                    height: isKeyboardOpen ? finalExpandDistance : 0,
                  );
                },
              );
            },
          );
        } else {
          return const SizedBox.shrink();
        }
      },
    );
  }

  /// Calculate the expand distance from the widget to the bottom of the screen
  double _calculateExpandDistance(BuildContext context) {
    if (widgetKey?.currentContext == null) return 0.0;

    try {
      final MediaQueryData mediaQuery = MediaQuery.of(context);
      final double screenHeight = mediaQuery.size.height;
      final double keyboardHeight =
          mediaQuery.orientation == Orientation.landscape
              ? screenHeight * 0.5
              : screenHeight * 0.4;

      RenderBox renderBox = widgetKey!.currentContext!.findRenderObject() as RenderBox;
      double widgetPosition = renderBox.localToGlobal(Offset.zero).dy;
      double widgetHeight = renderBox.size.height;
      double distanceFromWidgetToBottom =
          screenHeight - widgetPosition - widgetHeight;

      double distance = max(0.0, keyboardHeight);

      if (distanceFromWidgetToBottom < keyboardHeight) {
        distance = keyboardHeight -
            distanceFromWidgetToBottom +
            kBottomNavigationBarHeight;
      } else {
        distance = 0.0;
      }

      return distance;
    } catch (e) {
      return 0.0;
    }
  }
}

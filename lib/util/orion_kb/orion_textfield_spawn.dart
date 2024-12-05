/*
* Orion - Orion Textfield Spawner
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
import 'package:orion/util/orion_kb/orion_textfield.dart';

class SpawnOrionTextField extends StatefulWidget {
  final String keyboardHint;
  final String locale;
  final bool isHidden;
  final bool noShove;
  final Function(String) onChanged;
  final ScrollController? scrollController;
  final String presetText;

  const SpawnOrionTextField({
    super.key,
    required this.keyboardHint,
    required this.locale,
    this.isHidden = false,
    this.noShove = false,
    this.onChanged = _defaultOnChanged,
    this.scrollController,
    this.presetText = '',
  });

  // Do nothing
  static void _defaultOnChanged(String text) {}

  @override
  SpawnOrionTextFieldState createState() => SpawnOrionTextFieldState();
}

class SpawnOrionTextFieldState extends State<SpawnOrionTextField>
    with WidgetsBindingObserver {
  ValueNotifier<bool> isKeyboardOpen = ValueNotifier<bool>(false);
  ValueNotifier<double> expandDistance = ValueNotifier<double>(0.0);
  final TextEditingController _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.presetText != '') {
      _controller.text = '\u200B${widget.presetText}';
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    final bottomInset = WidgetsBinding
        .instance.platformDispatcher.views.first.viewInsets.bottom;
    final newValue = bottomInset > 0;
    if (isKeyboardOpen.value != newValue) {
      Future.microtask(() {
        isKeyboardOpen.value = newValue;
      });
    }
  }

  String getCurrentText() {
    String text = _controller.text;
    text = text
        .replaceAll('\u200B', '')
        .replaceAll('\u00A0', ' '); // Strip \u200B from the text
    return text;
  }

  void clearText() {
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    final MediaQueryData mediaQuery = MediaQuery.of(context);
    final double screenHeight = mediaQuery.size.height;
    final double keyboardHeight =
        MediaQuery.of(context).orientation == Orientation.landscape
            ? screenHeight * 0.5
            : screenHeight * 0.4; // Hardcoded keyboard height

    return ValueListenableBuilder<bool>(
      valueListenable: isKeyboardOpen,
      builder: (context, keyboardOpen, child) {
        WidgetsBinding.instance.addPostFrameCallback(
          (_) {
            if (keyboardOpen) {
              RenderBox renderBox = context.findRenderObject() as RenderBox;
              double textFieldPosition =
                  renderBox.localToGlobal(Offset.zero).dy;
              double textFieldHeight = renderBox.size.height;
              double distanceFromTextFieldToBottom =
                  screenHeight - textFieldPosition - textFieldHeight;

              double distance = max(0.0, keyboardHeight);

              if (distanceFromTextFieldToBottom < keyboardHeight) {
                distance = keyboardHeight -
                    distanceFromTextFieldToBottom +
                    kBottomNavigationBarHeight;
              } else {
                distance = 0.0;
              }

              expandDistance.value = widget.noShove ? 0.0 : distance;
            }
          },
        );

        return Stack(
          alignment: Alignment.centerRight,
          children: [
            OrionTextField(
              isKeyboardOpen: isKeyboardOpen,
              keyboardHint: widget.keyboardHint,
              controller: _controller,
              locale: widget.locale,
              isHidden: widget.isHidden,
              onChanged: widget.onChanged,
            ),
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: IconButton(
                onPressed: () {
                  _controller.clear();
                  widget.onChanged('');
                },
                icon: const Icon(Icons.clear_outlined),
              ),
            ),
          ],
        );
      },
    );
  }
}

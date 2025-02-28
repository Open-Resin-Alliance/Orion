/*
* Orion - Orion Keyboard
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

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:orion/util/localization.dart';

class OrionKeyboard extends StatefulWidget {
  final TextEditingController controller;
  final String locale;

  const OrionKeyboard({
    super.key,
    required this.controller,
    required this.locale,
  });

  @override
  OrionKeyboardState createState() => OrionKeyboardState();
}

class OrionKeyboardState extends State<OrionKeyboard> {
  final ValueNotifier<bool> _isShiftEnabled = ValueNotifier<bool>(false);
  final ValueNotifier<bool> _isCapsEnabled = ValueNotifier<bool>(false);
  final ValueNotifier<bool> _isSymbolKeyboardShown = ValueNotifier<bool>(false);
  final ValueNotifier<bool> _isSecondarySymbolKeyboardShown =
      ValueNotifier<bool>(false);

  late Map<String, String> _keyboardLayout;

  @override
  void initState() {
    super.initState();
    _keyboardLayout = OrionLocale.getLocale(widget.locale).keyboardLayout;
  }

  final Map<String, String> _symbolKeyboardLayout = {
    'row1': '1234567890',
    'row2': '-/\\:;()\$&',
    'row3': '.,?!\'@”',
    'bottomRow1': 'abc', // Add this line
    'bottomRow2': ' ',
    'bottomRow3': 'return',
  };

  final Map<String, String> _secondarySymbolKeyboardLayout = {
    'row1': '[]{}#%^*+=',
    'row2': '_|~<>€£¥•',
    'row3': '.,?!\'@”',
    'bottomRow1': 'abc',
    'bottomRow2': ' ',
    'bottomRow3': 'return',
  };

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: _isSecondarySymbolKeyboardShown,
      builder: (context, isSecondarySymbolKeyboardShown, child) {
        return ValueListenableBuilder<bool>(
          valueListenable: _isSymbolKeyboardShown,
          builder: (context, isSymbolKeyboardShown, child) {
            return ValueListenableBuilder<bool>(
              valueListenable: _isShiftEnabled,
              builder: (context, isShiftEnabled, child) {
                final keyboardLayout = _isSecondarySymbolKeyboardShown.value
                    ? _secondarySymbolKeyboardLayout
                    : _isSymbolKeyboardShown.value
                        ? _symbolKeyboardLayout
                        : _keyboardLayout;
                return SizedBox(
                  height: MediaQuery.of(context).size.height,
                  width: MediaQuery.of(context).size.width,
                  child: Column(
                    children: [
                      buildRow(keyboardLayout['row1']!),
                      buildRow(keyboardLayout['row2']!),
                      buildRow(keyboardLayout['row3']!,
                          hasShiftAndBackspace: true),
                      buildBottomRow(),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget buildRow(String rowCharacters, {bool hasShiftAndBackspace = false}) {
    return Expanded(
      child: Row(
        children: [
          SizedBox(width: hasShiftAndBackspace ? 10 : 0),
          if (hasShiftAndBackspace)
            Expanded(
              child: ValueListenableBuilder<bool>(
                valueListenable: _isCapsEnabled,
                builder: (context, isCapsEnabled, child) {
                  final shiftText = _isSecondarySymbolKeyboardShown.value
                      ? "123\u200B"
                      : _isSymbolKeyboardShown.value
                          ? "#+="
                          : _isCapsEnabled.value
                              ? "⇪"
                              : "⇧";
                  return KeyboardButton(
                    text: shiftText,
                    onPressed: () {
                      if (_isShiftEnabled.value == true) {
                        if (_isCapsEnabled.value == false) {
                          _isCapsEnabled.value = true;
                        } else {
                          _isCapsEnabled.value = false;
                          _isShiftEnabled.value = !_isShiftEnabled.value;
                        }
                      } else {
                        _isShiftEnabled.value = !_isShiftEnabled.value;
                      }
                      if (kDebugMode) {
                        print("ShiftState ${_isShiftEnabled.value}");
                        print("CapsState ${_isCapsEnabled.value}");
                      }
                    },
                    isShiftEnabled: _isShiftEnabled,
                    isCapsEnabled: _isCapsEnabled,
                    controller: widget.controller,
                    isSymbolKeyboardShown: _isSymbolKeyboardShown,
                    isSecondarySymbolKeyboardShown:
                        _isSecondarySymbolKeyboardShown,
                  );
                },
              ),
            ),
          const SizedBox(width: 10),
          ...rowCharacters
              .split('')
              .expand((char) => [
                    Expanded(
                      child: ValueListenableBuilder<bool>(
                        valueListenable: _isShiftEnabled,
                        builder: (context, isShiftEnabled, child) {
                          final buttonText =
                              isShiftEnabled ? char.toUpperCase() : char;
                          return KeyboardButton(
                            text: buttonText,
                            isShiftEnabled: _isShiftEnabled,
                            isCapsEnabled: _isCapsEnabled,
                            controller: widget.controller,
                            isSymbolKeyboardShown: _isSymbolKeyboardShown,
                            isSecondarySymbolKeyboardShown:
                                _isSecondarySymbolKeyboardShown,
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                  ])
              .toList()
            ..removeLast(),
          SizedBox(width: hasShiftAndBackspace ? 10 : 0),
          if (hasShiftAndBackspace)
            Expanded(
              child: KeyboardButton(
                text: "⌫",
                isShiftEnabled: _isShiftEnabled,
                isCapsEnabled: _isCapsEnabled,
                controller: widget.controller,
                isSymbolKeyboardShown: _isSymbolKeyboardShown,
                isSecondarySymbolKeyboardShown: _isSecondarySymbolKeyboardShown,
              ),
            ),
          const SizedBox(width: 10),
        ],
      ),
    );
  }

  Widget buildBottomRow() {
    final keyboardLayout =
        _isSymbolKeyboardShown.value ? _symbolKeyboardLayout : _keyboardLayout;
    return Expanded(
      child: Row(
        children: [
          const SizedBox(width: 10),
          Expanded(
            flex: 1,
            child: KeyboardButton(
              text: keyboardLayout['bottomRow1']!,
              isShiftEnabled: _isShiftEnabled,
              isCapsEnabled: _isCapsEnabled,
              controller: widget.controller,
              isSymbolKeyboardShown: _isSymbolKeyboardShown,
              isSecondarySymbolKeyboardShown: _isSecondarySymbolKeyboardShown,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 5,
            child: KeyboardButton(
              text: keyboardLayout['bottomRow2']!,
              isShiftEnabled: _isShiftEnabled,
              isCapsEnabled: _isCapsEnabled,
              controller: widget.controller,
              isSymbolKeyboardShown: _isSymbolKeyboardShown,
              isSecondarySymbolKeyboardShown: _isSecondarySymbolKeyboardShown,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 1,
            child: KeyboardButton(
              text: MediaQuery.of(context).orientation == Orientation.landscape
                  ? keyboardLayout['bottomRow3']!
                  : '↵',
              isShiftEnabled: ValueNotifier<bool>(false),
              isCapsEnabled: _isCapsEnabled,
              controller: widget.controller,
              isSymbolKeyboardShown: _isSymbolKeyboardShown,
              isSecondarySymbolKeyboardShown: _isSecondarySymbolKeyboardShown,
            ),
          ),
          const SizedBox(width: 10),
        ],
      ),
    );
  }
}

class KeyboardButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final TextEditingController controller;
  final ValueNotifier<bool> isShiftEnabled;
  final ValueNotifier<bool> isCapsEnabled;
  final ValueNotifier<bool> isSymbolKeyboardShown;
  final ValueNotifier<bool> isSecondarySymbolKeyboardShown;

  const KeyboardButton({
    super.key,
    required this.text,
    this.onPressed,
    required this.controller,
    required this.isShiftEnabled,
    required this.isCapsEnabled,
    required this.isSymbolKeyboardShown,
    required this.isSecondarySymbolKeyboardShown,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: SizedBox(
        height: double.infinity,
        child: TextButton(
          style: TextButton.styleFrom(
            backgroundColor: _getButtonBackgroundColor(context),
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(25)),
            ),
          ),
          onPressed: () {
            _handleKey(text, context);
          },
          child: Container(
            alignment: Alignment.center,
            child: ValueListenableBuilder<bool>(
              valueListenable: isShiftEnabled,
              builder: (context, isShiftEnabled, child) {
                if (text == "123" ||
                    text == "abc" ||
                    text == "return" ||
                    text == '↵' ||
                    text == "#+=" ||
                    text == "123\u200B") {
                  return FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      text,
                      style: const TextStyle(fontSize: 23),
                    ),
                  );
                }
                return FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    isShiftEnabled ? text.toUpperCase() : text.toLowerCase(),
                    style: const TextStyle(fontSize: 23),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  void _handleKey(String text, BuildContext context) {
    if (text == "123\u200B" || text == "#+=") {
      isSecondarySymbolKeyboardShown.value =
          !isSecondarySymbolKeyboardShown.value;
    } else if (text == "123") {
      isSecondarySymbolKeyboardShown.value = false;
      isSymbolKeyboardShown.value = !isSymbolKeyboardShown.value;
    } else if (text == "abc") {
      isSecondarySymbolKeyboardShown.value = false;
      isSymbolKeyboardShown.value = false;
    } else if (text == "⇧") {
      _handleShiftKey();
    } else if (text == "⇪") {
      _handleCapsLockKey();
    } else if (text == "⌫") {
      _handleBackspaceKey();
    } else if (text == "return" || text == '↵') {
      _handleReturnKey(context);
    } else if (text != "123" && text != "return" && text != "↵") {
      _handleAlphanumericKey(text);
    }
  }

  void _handleShiftKey() {
    if (isShiftEnabled.value) {
      isCapsEnabled.value = true;
    } else {
      isShiftEnabled.value = true;
    }
  }

  void _handleCapsLockKey() {
    if (isCapsEnabled.value) {
      isCapsEnabled.value = false;
      isShiftEnabled.value = false;
    } else {
      isCapsEnabled.value = true;
      isShiftEnabled.value = true;
    }
  }

  void _handleBackspaceKey() {
    if (controller.text.isNotEmpty && controller.text != '\u200B') {
      controller.text =
          controller.text.substring(0, controller.text.length - 1);
    }
  }

  void _handleReturnKey(BuildContext context) {
    Navigator.of(context).pop(controller.text);
  }

  void _handleAlphanumericKey(String text) {
    String key;
    if (isCapsEnabled.value || isShiftEnabled.value) {
      key = text.toUpperCase();
    } else {
      key = text.toLowerCase();
    }
    controller.text += key;
    // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
    controller.notifyListeners();
    if (!isCapsEnabled.value) {
      isShiftEnabled.value = false;
    }
  }

  // This method returns the background color for the keyboard button based on the text value.
  // The brightness of the color is determined by the theme mode.
  Color? _getButtonBackgroundColor(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    const lightBrightness = {
      'stdKey': 0.100,
      'altKey': 0.200,
      'highlight': 0.300,
    };

    const darkBrightness = {
      'stdKey': 0.080,
      'altKey': 0.050,
      'highlight': 0.200,
    };

    final brightnessMap = isDarkMode ? darkBrightness : lightBrightness;

    final lookupTable = {
      '⇧': isShiftEnabled.value
          ? brightnessMap['highlight']
          : brightnessMap['altKey'],
      '⇪': isCapsEnabled.value
          ? brightnessMap['highlight']
          : brightnessMap['altKey'],
      '⌫': brightnessMap['altKey'],
      '123': brightnessMap['altKey'],
      'abc': brightnessMap['altKey'],
      'return': brightnessMap['altKey'],
      '↵': brightnessMap['altKey'],
      '#+=': brightnessMap['altKey'],
      '123\u200B': brightnessMap['altKey'],
    };

    final brightness =
        (lookupTable[text] ?? brightnessMap['stdKey']!).clamp(0.0, 1.0);
    return Theme.of(context)
        .colorScheme
        .onPrimaryContainer
        .withValues(alpha: brightness);
  }
}

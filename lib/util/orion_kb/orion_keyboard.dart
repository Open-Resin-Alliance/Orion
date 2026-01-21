/*
* Orion - Orion Keyboard
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
import 'package:flutter/foundation.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'package:provider/provider.dart';

import 'package:orion/glasser/glasser.dart';
import 'package:orion/util/localization.dart';
import 'package:orion/util/providers/theme_provider.dart';

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
                text: "BACKSPACE",
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
                  : 'ENTER',
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

class KeyboardButton extends StatefulWidget {
  final String text;
  final VoidCallback? onPressed;
  final TextEditingController controller;
  final ValueNotifier<bool> isShiftEnabled;
  final ValueNotifier<bool> isCapsEnabled;
  final ValueNotifier<bool> isSymbolKeyboardShown;
  final ValueNotifier<bool> isSecondarySymbolKeyboardShown;

  static const Set<String> _functionKeyLabels = {
    '⇧',
    '⇪',
    'BACKSPACE',
    '123',
    'abc',
    'return',
    'ENTER',
    '#+=',
    '123\u200B',
  };

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
  State<KeyboardButton> createState() => _KeyboardButtonState();
}

class _KeyboardButtonState extends State<KeyboardButton> {
  DateTime? _lastShiftTapTime;
  static const _doubleTapWindow = Duration(milliseconds: 300);

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isGlassTheme = themeProvider.isGlassTheme;
    final borderRadius = BorderRadius.circular(16);

    // Match GlassButton visual parameters but disable blur to avoid many
    // expensive backdrop filter passes on small interactive keys.
    final double fillOpacity = GlassPlatformConfig.surfaceOpacity(
      0.14,
      emphasize: true,
    );
    final double borderWidth = 1.5;
    final bool borderEmphasis = true;
    final shadow = GlassPlatformConfig.interactiveShadow(
      enabled: true,
      blurRadius: 12.0,
      yOffset: 3.0,
      alpha: 0.12,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: SizedBox(
        height: double.infinity,
        child: isGlassTheme
            ? Container(
                decoration: BoxDecoration(
                  borderRadius: borderRadius,
                  boxShadow: shadow,
                ),
                child: GlassEffect(
                  borderRadius: borderRadius,
                  sigma: glassBlurSigma,
                  opacity: fillOpacity,
                  borderWidth: borderWidth,
                  emphasizeBorder: borderEmphasis,
                  interactiveSurface: true,
                  disableBlur: true,
                  child: Material(
                    color: Colors.transparent,
                    shape: RoundedRectangleBorder(borderRadius: borderRadius),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () => _handleKey(widget.text, context),
                      borderRadius: borderRadius,
                      splashColor: Colors.white.withValues(alpha: 0.18),
                      highlightColor: Colors.white.withValues(alpha: 0.1),
                      child: Center(
                        child: _buildLabel(
                          context,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              )
            : TextButton(
                style: TextButton.styleFrom(
                  backgroundColor: _getButtonBackgroundColor(context),
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.all(Radius.circular(15)),
                  ),
                ),
                onPressed: () {
                  _handleKey(widget.text, context);
                },
                child: Container(
                  alignment: Alignment.center,
                  child: _buildLabel(
                    context,
                    color: Theme.of(context).textTheme.bodyLarge?.color ??
                        Colors.black,
                    fontWeight: FontWeight.normal,
                  ),
                ),
              ),
      ),
    );
  }

  void _handleKey(String text, BuildContext context) {
    if (text == "123\u200B" || text == "#+=") {
      widget.isSecondarySymbolKeyboardShown.value =
          !widget.isSecondarySymbolKeyboardShown.value;
    } else if (text == "123") {
      widget.isSecondarySymbolKeyboardShown.value = false;
      widget.isSymbolKeyboardShown.value = !widget.isSymbolKeyboardShown.value;
    } else if (text == "abc") {
      widget.isSecondarySymbolKeyboardShown.value = false;
      widget.isSymbolKeyboardShown.value = false;
    } else if (text == "⇧") {
      _handleShiftKey();
    } else if (text == "⇪") {
      _handleCapsLockKey();
    } else if (text == "BACKSPACE") {
      _handleBackspaceKey();
    } else if (text == "return" || text == 'ENTER') {
      _handleReturnKey(context);
    } else if (text != "123" && text != "return" && text != "ENTER") {
      _handleAlphanumericKey(text);
    }
  }

  void _handleShiftKey() {
    final now = DateTime.now();
    
    // Check for double-tap: only if shift is currently enabled
    if (widget.isShiftEnabled.value && 
        !widget.isCapsEnabled.value &&
        _lastShiftTapTime != null && 
        now.difference(_lastShiftTapTime!) < _doubleTapWindow) {
      // Quick double-tap detected: enable caps lock
      widget.isCapsEnabled.value = true;
      widget.isShiftEnabled.value = true;
      _lastShiftTapTime = null; // Reset
    } else {
      // Single tap: toggle shift
      if (widget.isShiftEnabled.value && !widget.isCapsEnabled.value) {
        widget.isShiftEnabled.value = false;
        _lastShiftTapTime = null; // Reset when toggling off
      } else {
        widget.isShiftEnabled.value = true;
        _lastShiftTapTime = now; // Set timer when enabling
      }
    }
  }

  void _handleCapsLockKey() {
    if (widget.isCapsEnabled.value) {
      widget.isCapsEnabled.value = false;
      widget.isShiftEnabled.value = false;
      _lastShiftTapTime = null;
    } else {
      widget.isCapsEnabled.value = true;
      widget.isShiftEnabled.value = true;
      _lastShiftTapTime = null;
    }
  }

  void _handleBackspaceKey() {
    if (widget.controller.text.isNotEmpty && widget.controller.text != '\u200B') {
      widget.controller.text =
          widget.controller.text.substring(0, widget.controller.text.length - 1);
    }
  }

  void _handleReturnKey(BuildContext context) {
    Navigator.of(context).pop(widget.controller.text);
  }

  void _handleAlphanumericKey(String text) {
    String key;
    if (widget.isCapsEnabled.value || widget.isShiftEnabled.value) {
      key = text.toUpperCase();
    } else {
      key = text.toLowerCase();
    }
    widget.controller.text += key;
    // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
    widget.controller.notifyListeners();
    if (!widget.isCapsEnabled.value) {
      widget.isShiftEnabled.value = false;
      _lastShiftTapTime = null;
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
      '⇧': widget.isShiftEnabled.value
          ? brightnessMap['highlight']
          : brightnessMap['altKey'],
      '⇪': widget.isCapsEnabled.value
          ? brightnessMap['highlight']
          : brightnessMap['altKey'],
      'BACKSPACE': brightnessMap['altKey'],
      '123': brightnessMap['altKey'],
      'abc': brightnessMap['altKey'],
      'return': brightnessMap['altKey'],
      'ENTER': brightnessMap['altKey'],
      '#+=': brightnessMap['altKey'],
      '123\u200B': brightnessMap['altKey'],
    };

    final brightness =
        (lookupTable[widget.text] ?? brightnessMap['stdKey']!).clamp(0.0, 1.0);
    return Theme.of(context)
        .colorScheme
        .onPrimaryContainer
        .withValues(alpha: brightness);
  }

  Widget _buildLabel(
    BuildContext context, {
    required Color color,
    FontWeight fontWeight = FontWeight.w500,
  }) {
    // Use icons for special keys
    if (widget.text == 'BACKSPACE') {
      return Icon(
        PhosphorIconsFill.backspace,
        color: color,
        size: 24,
      );
    }
    if (widget.text == 'ENTER') {
      return Icon(
        PhosphorIcons.arrowBendDownLeft(),
        color: color,
        size: 24,
      );
    }
    if (widget.text == '⇧') {
      // Show different icons based on shift/caps state
      return ValueListenableBuilder<bool>(
        valueListenable: widget.isCapsEnabled,
        builder: (context, isCaps, _) {
          return ValueListenableBuilder<bool>(
            valueListenable: widget.isShiftEnabled,
            builder: (context, isShift, _) {
              if (isCaps) {
                // Caps lock engaged -> filled double caret
                return Icon(
                  PhosphorIcons.caretDoubleUp(PhosphorIconsStyle.fill),
                  color: color,
                  size: 24,
                );
              }

              if (isShift) {
                // Shift engaged -> double caret outline
                return Icon(
                  PhosphorIcons.caretDoubleUp(),
                  color: color,
                  size: 24,
                );
              }

              // Not engaged -> single caret outline
              return Icon(
                PhosphorIcons.caretUp(),
                color: color,
                size: 24,
              );
            },
          );
        },
      );
    }
    if (widget.text == '⇪') {
      // Caps lock key shows state (outline vs filled)
      return ValueListenableBuilder<bool>(
        valueListenable: widget.isCapsEnabled,
        builder: (context, isCaps, _) {
          return Icon(
            isCaps
                ? PhosphorIcons.caretDoubleUp(PhosphorIconsStyle.fill)
                : PhosphorIcons.caretDoubleUp(),
            color: color,
            size: 24,
          );
        },
      );
    }
    
    return ValueListenableBuilder<bool>(
      valueListenable: widget.isShiftEnabled,
      builder: (context, isShiftActive, child) {
        final bool lockCase = _isFunctionKey(widget.text);
        final String displayText = lockCase
            ? widget.text
            : (isShiftActive ? widget.text.toUpperCase() : widget.text.toLowerCase());
        return FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            displayText,
            style: TextStyle(
              fontSize: 23,
              color: color,
              fontWeight: fontWeight,
            ),
          ),
        );
      },
    );
  }

  bool _isFunctionKey(String keyLabel) => KeyboardButton._functionKeyLabels.contains(keyLabel);
}

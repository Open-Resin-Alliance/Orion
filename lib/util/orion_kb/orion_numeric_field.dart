/*
* Orion - Orion Numeric Input Field
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

import 'dart:math';

import 'package:flutter/material.dart';

/// Show numeric keyboard modal and return edited value
/// Useful for inline numeric editing without a dedicated textfield
Future<String?> showOrionNumericKeyboard(
  BuildContext context, {
  required double initialValue,
  bool allowNegative = false,
  bool allowDecimal = true,
  int decimalPlaces = 2,
  void Function(String)? onChanged,
}) {
  // Format initial value, stripping unnecessary trailing zeros
  String formattedValue = initialValue.toStringAsFixed(decimalPlaces);
  if (allowDecimal && decimalPlaces > 0) {
    formattedValue = formattedValue.replaceAll(RegExp(r'\.?0+$'), '');
    // Ensure we keep at least one digit
    if (formattedValue.isEmpty || formattedValue == '-') {
      formattedValue = '0';
    }
  }
  
  final textController = TextEditingController(text: formattedValue);
  return Navigator.of(context).push<String>(
    _NumericKeyboardModal(
      textController: textController,
      locale: Localizations.localeOf(context).toString(),
      allowNegative: allowNegative,
      allowDecimal: allowDecimal,
      decimalPlaces: decimalPlaces,
      onChanged: onChanged,
    ),
  );
}

class SpawnOrionNumericField extends StatefulWidget {
  final String keyboardHint;
  final String locale;
  final bool allowNegative;
  final bool allowDecimal;
  final int decimalPlaces;
  final Function(double) onChanged;
  final ScrollController? scrollController;
  final double presetValue;

  const SpawnOrionNumericField({
    super.key,
    required this.keyboardHint,
    required this.locale,
    this.allowNegative = false,
    this.allowDecimal = true,
    this.decimalPlaces = 2,
    this.onChanged = _defaultOnChanged,
    this.scrollController,
    this.presetValue = 0.0,
  });

  // Do nothing
  static void _defaultOnChanged(double value) {}

  @override
  SpawnOrionNumericFieldState createState() => SpawnOrionNumericFieldState();
}

class SpawnOrionNumericFieldState extends State<SpawnOrionNumericField>
    with WidgetsBindingObserver {
  ValueNotifier<bool> isKeyboardOpen = ValueNotifier<bool>(false);
  ValueNotifier<double> expandDistance = ValueNotifier<double>(0.0);
  final TextEditingController _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.presetValue != 0.0) {
      _controller.text = widget.presetValue
          .toStringAsFixed(widget.decimalPlaces)
          .replaceAll(RegExp(r'\.?0+$'), '');
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

  double? getCurrentValue() {
    String text = _controller.text.trim();
    if (text.isEmpty) return null;
    try {
      return double.parse(text);
    } catch (e) {
      return null;
    }
  }

  void clearValue() {
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    final MediaQueryData mediaQuery = MediaQuery.of(context);
    final double screenHeight = mediaQuery.size.height;
    final double keyboardHeight =
        MediaQuery.of(context).orientation == Orientation.landscape
            ? screenHeight * 0.5
            : screenHeight * 0.4;

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

              expandDistance.value = distance;
            }
          },
        );

        return Stack(
          alignment: Alignment.centerRight,
          children: [
            OrionNumericTextField(
              isKeyboardOpen: isKeyboardOpen,
              keyboardHint: widget.keyboardHint,
              controller: _controller,
              locale: widget.locale,
              allowNegative: widget.allowNegative,
              allowDecimal: widget.allowDecimal,
              decimalPlaces: widget.decimalPlaces,
              onChanged: (value) {
                if (value != null) {
                  widget.onChanged(value);
                }
              },
            ),
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: IconButton(
                onPressed: () {
                  _controller.clear();
                  widget.onChanged(0.0);
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

class OrionNumericTextField extends StatefulWidget {
  final ValueNotifier<bool> isKeyboardOpen;
  final String keyboardHint;
  final TextEditingController controller;
  final String locale;
  final bool allowNegative;
  final bool allowDecimal;
  final int decimalPlaces;
  final Function(double?) onChanged;

  const OrionNumericTextField({
    super.key,
    required this.isKeyboardOpen,
    required this.keyboardHint,
    required this.controller,
    required this.locale,
    required this.allowNegative,
    required this.allowDecimal,
    required this.decimalPlaces,
    required this.onChanged,
  });

  @override
  OrionNumericTextFieldState createState() => OrionNumericTextFieldState();
}

class OrionNumericTextFieldState extends State<OrionNumericTextField>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  Widget build(BuildContext context) {
    TextStyle style = const TextStyle(fontSize: 20);

    return GestureDetector(
      onTap: () {
        widget.isKeyboardOpen.value = true;
        Navigator.of(context)
            .push(
          _NumericKeyboardModal(
            textController: widget.controller,
            locale: widget.locale,
            allowNegative: widget.allowNegative,
            allowDecimal: widget.allowDecimal,
            decimalPlaces: widget.decimalPlaces,
          ),
        )
            .then(
          (result) {
            widget.isKeyboardOpen.value = false;
            if (result != null) {
              try {
                final parsed = double.parse(result);
                widget.controller.text =
                    parsed.toStringAsFixed(widget.decimalPlaces).replaceAll(RegExp(r'\.?0+$'), '');
                widget.onChanged(parsed);
              } catch (e) {
                widget.onChanged(null);
              }
            }
          },
        );
      },
      child: MouseRegion(
        cursor: SystemMouseCursors.text,
        child: AbsorbPointer(
          child: Padding(
            padding: const EdgeInsets.only(left: 0.0, right: 0.0, top: 0.0),
            child: Stack(
              alignment: Alignment.centerLeft,
              children: [
                ValueListenableBuilder<bool>(
                  valueListenable: widget.isKeyboardOpen,
                  builder: (context, isKeyboardOpen, child) {
                    return TextField(
                      controller: widget.controller,
                      readOnly: true,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16.0),
                          borderSide: BorderSide(
                            color: isKeyboardOpen
                                ? Colors.white.withValues(alpha: 0.8)
                                : Colors.white.withValues(alpha: 0.3),
                            width: isKeyboardOpen ? 2.0 : 1.0,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16.0),
                          borderSide: BorderSide(
                            color: Colors.white.withValues(alpha: 0.8),
                            width: 2.0,
                          ),
                        ),
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.1),
                        labelText: widget.keyboardHint,
                        labelStyle: TextStyle(
                          fontSize: 18,
                          color: Colors.white.withValues(alpha: 0.8),
                        ),
                      ),
                      style: style.copyWith(
                          color: Colors.transparent, fontSize: 28),
                    );
                  },
                ),
                Padding(
                  padding:
                      const EdgeInsets.only(left: 12.0, right: 12.0, top: 2),
                  child: AnimatedBuilder(
                    animation: _animController,
                    builder: (BuildContext context, Widget? child) {
                      return Text.rich(
                        TextSpan(
                          text: widget.controller.text,
                          style: style.copyWith(
                            color: widget.isKeyboardOpen.value
                                ? Theme.of(context)
                                    .textTheme
                                    .bodyLarge!
                                    .color!
                                    .withOpacity(0.9)
                                : Theme.of(context).textTheme.bodyLarge!.color!,
                          ),
                          children: [
                            const WidgetSpan(child: SizedBox(width: 1)),
                            WidgetSpan(
                              child: Opacity(
                                opacity: _animController.value,
                                child: Container(
                                  width: 1.5,
                                  height: 22,
                                  color: widget.isKeyboardOpen.value
                                      ? Theme.of(context)
                                          .textTheme
                                          .bodyLarge!
                                          .color!
                                      : Colors.transparent,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _animController.dispose();
    super.dispose();
  }
}

/// Numeric keyboard modal with input validation
class _NumericKeyboardModal extends ModalRoute<String> {
  final TextEditingController textController;
  final String locale;
  final bool allowNegative;
  final bool allowDecimal;
  final int decimalPlaces;
  final void Function(String)? onChanged;

  _NumericKeyboardModal({
    required this.textController,
    required this.locale,
    required this.allowNegative,
    required this.allowDecimal,
    required this.decimalPlaces,
    this.onChanged,
  });

  @override
  Duration get transitionDuration => const Duration(milliseconds: 300);

  @override
  bool get opaque => false;

  @override
  bool get barrierDismissible => true;

  @override
  Color get barrierColor => Colors.black.withValues(alpha: 0);

  @override
  String? get barrierLabel => null;

  @override
  bool get maintainState => true;

  @override
  Widget buildPage(BuildContext context, Animation<double> animation,
      Animation<double> secondaryAnimation) {
    final numericController = TextEditingController(text: textController.text);

    return Material(
      type: MaterialType.transparency,
      child: SafeArea(
        top: false,
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).canvasColor,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  spreadRadius: 2,
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 5.0),
              child: _NumericKeyboard(
                controller: numericController,
                allowNegative: allowNegative,
                allowDecimal: allowDecimal,
                decimalPlaces: decimalPlaces,
                onChanged: onChanged,
                onReturn: () {
                  Navigator.of(context).pop(numericController.text);
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget buildTransitions(BuildContext context, Animation<double> animation,
      Animation<double> secondaryAnimation, Widget child) {
    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0, 0.5),
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: animation,
        curve: Curves.easeOut,
      )),
      child: FractionallySizedBox(
        heightFactor:
            MediaQuery.of(context).orientation == Orientation.landscape
                ? 0.5
                : 0.4,
        alignment: Alignment.bottomCenter,
        child: child,
      ),
    );
  }
}

/// Numeric-only keyboard layout
class _NumericKeyboard extends StatelessWidget {
  final TextEditingController controller;
  final bool allowNegative;
  final bool allowDecimal;
  final int decimalPlaces;
  final VoidCallback onReturn;
  final void Function(String)? onChanged;

  const _NumericKeyboard({
    required this.controller,
    required this.allowNegative,
    required this.allowDecimal,
    required this.decimalPlaces,
    required this.onReturn,
    this.onChanged,
  });

  void _notifyChanged() {
    if (onChanged != null) {
      onChanged!(controller.text);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

    return SizedBox(
      height: MediaQuery.of(context).size.height,
      width: MediaQuery.of(context).size.width,
      child: isLandscape ? _buildLandscapeLayout() : _buildPortraitLayout(),
    );
  }

  Widget _buildPortraitLayout() {
    // Build fourth row buttons dynamically
    final fourthRowButtons = ['00', '0'];
    if (allowDecimal) fourthRowButtons.add('.');
    if (allowNegative) fourthRowButtons.add('−');

    return Column(
      children: [
        _buildRow(['1', '2', '3']),
        _buildRow(['4', '5', '6']),
        _buildRow(['7', '8', '9']),
        _buildRow(fourthRowButtons),
        _buildControlRow(),
      ],
    );
  }

  Widget _buildLandscapeLayout() {
    // Build bottom row buttons dynamically
    final bottomButtons = ['00'];
    if (allowNegative) bottomButtons.add('−');
    bottomButtons.add('0');
    if (allowDecimal) bottomButtons.add('.');

    return Row(
      children: [
        // Left section: 4 rows x 3 columns (or dynamic for bottom)
        Expanded(
          flex: 3,
          child: Column(
            children: [
              _buildRow(['1', '2', '3']),
              _buildRow(['4', '5', '6']),
              _buildRow(['7', '8', '9']),
              _buildRow(bottomButtons),
            ],
          ),
        ),
        const SizedBox(width: 10),
        // Right section: 2 tall buttons
        Expanded(
          flex: 1,
          child: Column(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 10, top: 5, bottom: 2.5),
                  child: _NumericKeyButton(
                    text: '⌫',
                    onPressed: _handleBackspace,
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 10, top: 2.5, bottom: 5),
                  child: _NumericKeyButton(
                    text: '↵',
                    isPrimary: true,
                    onPressed: onReturn,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRow(List<String> chars) {
    return Expanded(
      child: Row(
        children: [
          const SizedBox(width: 10),
          ...chars
              .expand((char) => [
                    Expanded(
                      child: _NumericKeyButton(
                        text: char,
                        onPressed: char.isEmpty
                            ? null
                            : () => _handleNumericKey(char),
                      ),
                    ),
                    const SizedBox(width: 10),
                  ])
              .toList()
            ..removeLast(),
          const SizedBox(width: 10),
        ],
      ),
    );
  }

  Widget _buildControlRow() {
    return Expanded(
      child: Row(
        children: [
          const SizedBox(width: 10),
          Expanded(
            child: _NumericKeyButton(
              text: '⌫',
              onPressed: _handleBackspace,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _NumericKeyButton(
              text: '↵',
              isPrimary: true,
              onPressed: onReturn,
            ),
          ),
          const SizedBox(width: 10),
        ],
      ),
    );
  }

  void _handleNumericKey(String char) {
    if (char == '.' && !allowDecimal) return;
    if (char == '−' && !allowNegative) return;

    final text = controller.text;
    final selection = controller.selection;

    if (char == '.') {
      if (text.contains('.')) return; // Already has decimal
      if (text.isEmpty) {
        controller.text = '0.';
        controller.selection =
            TextSelection.fromPosition(TextPosition(offset: 2));
        _notifyChanged();
        return;
      }
    }

    if (char == '−') {
      if (text.startsWith('−')) {
        // Remove negative sign
        controller.text = text.substring(1);
        controller.selection =
            TextSelection.fromPosition(TextPosition(offset: selection.start - 1));
      } else {
        // Add negative sign
        controller.text = '−$text';
        controller.selection =
            TextSelection.fromPosition(TextPosition(offset: selection.start + 1));
      }
      _notifyChanged();
      return;
    }

    // Handle regular digit or "00"
    controller.text = text + char;
    controller.selection =
        TextSelection.fromPosition(TextPosition(offset: controller.text.length));
    _notifyChanged();
  }

  void _handleBackspace() {
    final text = controller.text;
    if (text.isNotEmpty) {
      controller.text = text.substring(0, text.length - 1);
      _notifyChanged();
    }
  }
}

class _NumericKeyButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isPrimary;

  const _NumericKeyButton({
    required this.text,
    this.onPressed,
    this.isPrimary = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDisabled = onPressed == null;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Material(
        color: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        clipBehavior: Clip.antiAlias,
        child: Container(
          decoration: BoxDecoration(
            color: isPrimary
                ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.8)
                : Theme.of(context)
                    .colorScheme
                    .onPrimaryContainer
                    .withValues(alpha: isDisabled ? 0.05 : 0.12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isPrimary
                  ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.3)
                  : Colors.white.withValues(alpha: 0.1),
              width: 1.0,
            ),
          ),
          child: InkWell(
            onTap: isDisabled ? null : onPressed,
            splashColor:
                Colors.white.withValues(alpha: isDisabled ? 0 : 0.2),
            highlightColor:
                Colors.white.withValues(alpha: isDisabled ? 0 : 0.1),
            child: Center(
              child: Text(
                text,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w500,
                  color: isPrimary
                      ? Colors.white
                      : isDisabled
                          ? Colors.grey.shade600
                          : Colors.white,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

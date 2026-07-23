/*
* Orion - Orion Textfield
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

import 'package:orion/themes/themes.dart';
import 'package:orion/util/orion_kb/orion_keyboard_modal.dart';
import 'package:orion/util/providers/theme_provider.dart';

import 'package:provider/provider.dart';

class OrionTextField extends StatefulWidget {
  final ValueNotifier<bool> isKeyboardOpen;
  final String keyboardHint;
  final TextEditingController controller;
  final String locale;
  final bool isHidden;
  final Function(String) onChanged;

  const OrionTextField({
    super.key,
    required this.isKeyboardOpen,
    required this.keyboardHint,
    required this.controller,
    required this.locale,
    required this.isHidden,
    required this.onChanged,
  });

  @override
  OrionTextFieldState createState() => OrionTextFieldState();
}

class OrionTextFieldState extends State<OrionTextField>
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

  final focusNode = FocusNode();

  @override
  Widget build(BuildContext context) {
    TextStyle style = const TextStyle(fontSize: 20);

    return GestureDetector(
      onTap: () {
        widget.isKeyboardOpen.value = true;
        if (widget.controller.text.isEmpty) {
          widget.controller.text = '\u200B';
        }
        Navigator.of(context)
            .push(OrionKbModal(
                textController: widget.controller, locale: widget.locale))
            .then(
          (result) {
            widget.isKeyboardOpen.value = false;
            if (result != null) {
              widget.controller.text = result;
              widget.onChanged(
                  result.replaceAll('\u200B', '').replaceAll('\u00A0', ' '));
            }
            if (widget.controller.text == '\u200B') {
              widget.controller.text = '';
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
                    final themeProvider = Provider.of<ThemeProvider>(context);
                    final isGlassTheme = themeProvider.isGlassTheme;

                    return TextField(
                      controller: widget.controller,
                      readOnly: true,
                      decoration: InputDecoration(
                        enabledBorder: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(isGlassTheme ? 16.0 : 4.0),
                          borderSide: BorderSide(
                            color: isGlassTheme
                                ? isKeyboardOpen
                                    ? Colors.white.withValues(alpha: 0.8)
                                    : Colors.white.withValues(alpha: 0.3)
                                : isKeyboardOpen
                                    ? Theme.of(context)
                                        .colorScheme
                                        .primaryContainer
                                    : Theme.of(context)
                                        .textTheme
                                        .bodyLarge!
                                        .color!,
                            width: isGlassTheme
                                ? (isKeyboardOpen ? 2.0 : 1.0)
                                : 1.0,
                          ),
                        ),
                        focusedBorder: isGlassTheme
                            ? OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16.0),
                                borderSide: BorderSide(
                                  color: Colors.white.withValues(alpha: 0.8),
                                  width: 2.0,
                                ),
                              )
                            : null,
                        filled: isGlassTheme,
                        fillColor: isGlassTheme
                            ? Colors.white.withValues(alpha: 0.1)
                            : null,
                        labelText: widget.keyboardHint,
                        labelStyle: TextStyle(
                          fontSize: 18,
                          color: isGlassTheme
                              ? Colors.white.withValues(alpha: 0.8)
                              : null,
                        ),
                      ),
                      // Hide the original text, We overlay our own with an animated line (cursor)
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
                          text: !widget.isHidden
                              ? widget.controller.text.replaceAll(' ', '\u00A0')
                              : widget.controller.text
                                  .replaceAll(RegExp('[^\u200B]'), '•'),
                          style: style.copyWith(
                            color: widget.isKeyboardOpen.value
                                ? Theme.of(context)
                                    .textTheme
                                    .bodyLarge!
                                    .color!
                                    .withBrightness(1.2)
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
    widget.controller.dispose();
    _animController.dispose();
    super.dispose();
  }
}

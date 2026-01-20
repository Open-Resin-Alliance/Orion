/*
* Orion - Orion Keyboard Modal
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
import 'package:provider/provider.dart';

import 'package:orion/util/orion_kb/orion_keyboard.dart';
import 'package:orion/util/providers/theme_provider.dart';
import 'package:orion/glasser/glasser.dart';

class OrionKbModal extends ModalRoute<String> {
  final TextEditingController textController;
  final String locale;
  final Widget? floatingOverlay;

  OrionKbModal({
    required this.textController,
    required this.locale,
    this.floatingOverlay,
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
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;
    final keyboardHeightFactor = isLandscape ? 0.5 : 0.4;
    final keyboardHeight = MediaQuery.of(context).size.height * keyboardHeightFactor;

    final width = MediaQuery.of(context).size.width;
    final height = MediaQuery.of(context).size.height;
    final radius = (width > height) ? width / 30 : height / 30;
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isGlassTheme = themeProvider.isGlassTheme;
    final gradient = GlassGradientUtils.resolveGradient(
      themeProvider: themeProvider,
    );
    final modalGradient = GlassGradientUtils.darkenGradient(
      gradient,
      amount: 0.2,
    );
    final borderRadius = BorderRadius.only(
      topLeft: Radius.circular(radius),
      topRight: Radius.circular(radius),
    );

    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: [
          if (floatingOverlay != null)
            Positioned(
              left: 0,
              right: 0,
              bottom: keyboardHeight + 24,
              child: SafeArea(
                bottom: false,
                child: Center(child: floatingOverlay!),
              ),
            ),
          SafeArea(
            top: false,
            child: Align(
              alignment: Alignment.bottomCenter,
              child: isGlassTheme
                  ? Container(
                      decoration: BoxDecoration(
                        borderRadius: borderRadius,
                        boxShadow: GlassPlatformConfig.surfaceShadow(
                          blurRadius: 26,
                          yOffset: 12,
                          alpha: 0.24,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: borderRadius,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: borderRadius,
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: modalGradient,
                            ),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.12),
                              width: 1.2,
                            ),
                          ),
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.55),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 5.0),
                              child: OrionKeyboard(
                                controller: textController,
                                locale: locale,
                              ),
                            ),
                          ),
                        ),
                      ),
                    )
                  : Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).canvasColor,
                        borderRadius: borderRadius,
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
                        child: OrionKeyboard(
                          controller: textController,
                          locale: locale,
                        ),
                      ),
                    ),
            ),
          ),
        ],
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

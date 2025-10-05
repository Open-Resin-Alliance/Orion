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

  OrionKbModal({
    required this.textController,
    required this.locale,
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
    final width = MediaQuery.of(context).size.width;
    final height = MediaQuery.of(context).size.height;
    final radius = (width > height) ? width / 30 : height / 30;
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isGlassTheme = themeProvider.isGlassTheme;
    final borderRadius = BorderRadius.only(
      topLeft: Radius.circular(radius),
      topRight: Radius.circular(radius),
    );

    return Material(
      type: MaterialType.transparency,
      child: SafeArea(
        top: false,
        child: Align(
          alignment: Alignment.bottomCenter,
          child: isGlassTheme
              ? Container(
                  decoration: BoxDecoration(
                    borderRadius: borderRadius,
                    boxShadow: GlassPlatformConfig.surfaceShadow(
                      blurRadius: 22,
                      yOffset: 10,
                      alpha: 0.22,
                    ),
                  ),
                  child: GlassEffect(
                    borderRadius: borderRadius,
                    sigma: glassBlurSigma,
                    opacity: GlassPlatformConfig.surfaceOpacity(0.14,
                        emphasize: true),
                    borderWidth: 1.4,
                    emphasizeBorder: true,
                    interactiveSurface: true,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 5.0),
                      child: OrionKeyboard(
                        controller: textController,
                        locale: locale,
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

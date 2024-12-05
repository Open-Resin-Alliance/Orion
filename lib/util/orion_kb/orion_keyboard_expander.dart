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

import 'package:flutter/material.dart';
import 'package:orion/util/orion_kb/orion_textfield_spawn.dart';

class OrionKbExpander extends StatelessWidget {
  final GlobalKey<SpawnOrionTextFieldState> textFieldKey;

  const OrionKbExpander({super.key, required this.textFieldKey});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: Future.delayed(Duration.zero),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          return ValueListenableBuilder<bool>(
            valueListenable: textFieldKey.currentState?.isKeyboardOpen ??
                ValueNotifier<bool>(false),
            builder: (context, isKeyboardOpen, child) {
              return ValueListenableBuilder<double>(
                valueListenable: textFieldKey.currentState?.expandDistance ??
                    ValueNotifier<double>(0.0),
                builder: (context, expandDistance, child) {
                  return AnimatedContainer(
                    curve: Curves.easeInOut,
                    duration: const Duration(milliseconds: 300),
                    height: isKeyboardOpen ? expandDistance : 0,
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
}

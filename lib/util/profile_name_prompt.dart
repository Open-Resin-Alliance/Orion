/*
* Orion - Profile Name Prompt
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
import 'package:flutter_i18n/flutter_i18n.dart';
import 'package:orion/glasser/glasser.dart';
import 'package:orion/util/orion_kb/orion_keyboard_expander.dart';
import 'package:orion/util/orion_kb/orion_textfield_spawn.dart';

/// Asks for a profile name, with the on-screen keyboard every other text entry
/// in Orion uses.
///
/// [suggestedName] is what the profile is called when the user types nothing:
/// it shows as the field's hint, so there is nothing to clear out before
/// typing. Shared by the resin editor's clone/rename flows and by the
/// calibration wizard when it saves a calibrated template as a new profile.
///
/// Returns the typed name, or [suggestedName] when the field was left empty,
/// or null when the user cancels.
Future<String?> promptForProfileName(
  BuildContext context, {
  required String titleKey,
  required String hintKey,
  required String suggestedName,
}) {
  final nameKey = GlobalKey<SpawnOrionTextFieldState>();
  return showDialog<String>(
    context: context,
    builder: (dialogContext) => GlassAlertDialog(
      title: Text(FlutterI18n.translate(dialogContext, titleKey)),
      content: SizedBox(
        width: MediaQuery.of(dialogContext).size.width * 0.5,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SpawnOrionTextField(
                key: nameKey,
                keyboardHint: suggestedName.isEmpty
                    ? FlutterI18n.translate(dialogContext, hintKey)
                    : suggestedName,
                locale: Localizations.localeOf(dialogContext).toString(),
              ),
              OrionKbExpander(textFieldKey: nameKey),
            ],
          ),
        ),
      ),
      actions: [
        GlassButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          style: ElevatedButton.styleFrom(minimumSize: const Size(0, 60)),
          child: Text(FlutterI18n.translate(dialogContext, 'common.cancel'),
              style: const TextStyle(fontSize: 20)),
        ),
        GlassButton(
          tint: GlassButtonTint.positive,
          style: ElevatedButton.styleFrom(minimumSize: const Size(0, 60)),
          onPressed: () {
            final typed = nameKey.currentState?.getCurrentText().trim() ?? '';
            final name = typed.isEmpty ? suggestedName.trim() : typed;
            if (name.isEmpty) return;
            Navigator.of(dialogContext).pop(name);
          },
          child: Text(FlutterI18n.translate(dialogContext, 'common.save'),
              style: const TextStyle(fontSize: 20)),
        ),
      ],
    ),
  );
}

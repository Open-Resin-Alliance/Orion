/*
* Orion - List Tile
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
import 'package:phosphor_flutter/phosphor_flutter.dart';

class OrionListTile extends StatelessWidget {
  final String title;
  final dynamic icon;
  final bool value;
  final bool ignoreColor;
  final Function(bool) onChanged;

  const OrionListTile({
    super.key,
    required this.title,
    required this.icon,
    required this.value,
    this.ignoreColor = false,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(
        title,
        style:
            TextStyle(fontSize: 24.0, color: ignoreColor ? Colors.white : null),
      ),
      trailing: Transform.scale(
        scale: 1.2, // adjust this value to change the size of the Switch
        child: Switch(
          value: value,
          onChanged: onChanged,
        ),
      ),
      leading: icon is IconData
          ? Icon(icon, size: 24.0, color: ignoreColor ? Colors.white : null)
          : icon is Function
              ? PhosphorIcon(icon(PhosphorIconsStyle.bold),
                  size: 24.0, color: ignoreColor ? Colors.white : null)
              : null,
    );
  }
}

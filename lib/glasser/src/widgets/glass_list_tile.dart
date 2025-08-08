/*
* Glasser - Glass List Tile Widget
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

/// A generic glass-aware list tile that adapts to the glass theme.
///
/// This widget is a drop-in replacement for [ListTile]. When the glass theme is enabled,
/// it renders with a glassmorphic effect for visual consistency. Otherwise, it falls back to a normal list tile.
///
/// Example usage:
/// ```dart
/// GlassListTile(
///   title: Text('Title'),
///   subtitle: Text('Subtitle'),
///   leading: Icon(Icons.info),
///   trailing: Icon(Icons.chevron_right),
///   onTap: () {},
/// )
/// ```
///
/// See also:
///
///  * [GlassScaffold], for glass-aware scaffolds.
///  * [ListTile], the standard Flutter list tile.
class GlassListTile extends StatelessWidget {
  /// A generic glass-aware list tile that adapts to the glass theme.
  final Widget? title;
  final Widget? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;

  const GlassListTile({
    super.key,
    this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: title,
      subtitle: subtitle,
      leading: leading,
      trailing: trailing,
      onTap: onTap,
    );
  }
}

// Note: GlassAwareOrionListTile functionality is now built into OrionListTile
// Use OrionListTile directly instead of this alias

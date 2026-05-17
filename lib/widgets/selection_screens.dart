/*
* Orion - Selection Screens
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
import 'package:orion/glasser/glasser.dart';
import 'package:orion/util/widgets/system_status_widget.dart';
import 'package:orion/widgets/orion_app_bar.dart';

class DetailedSelectionScreen extends StatelessWidget {
  final String title;
  final Widget child;
  final EdgeInsetsGeometry padding;
  final List<Widget>? actions;

  const DetailedSelectionScreen({
    super.key,
    required this.title,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return GlassApp(
      child: Scaffold(
        appBar: OrionAppBar(
          title: Text(title),
          actions: actions ?? const [SystemStatusWidget()],
          toolbarHeight: Theme.of(context).appBarTheme.toolbarHeight,
        ),
        body: Padding(
          padding: padding,
          child: child,
        ),
      ),
    );
  }
}

class ListSelectionScreen<T> extends StatelessWidget {
  final String title;
  final List<T> items;
  final Widget Function(BuildContext context, T item) itemBuilder;
  final Widget Function(BuildContext context, int index)? separatorBuilder;
  final EdgeInsetsGeometry padding;
  final List<Widget>? actions;

  const ListSelectionScreen({
    super.key,
    required this.title,
    required this.items,
    required this.itemBuilder,
    this.separatorBuilder,
    this.padding = const EdgeInsets.all(16),
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return DetailedSelectionScreen(
      title: title,
      padding: padding,
      actions: actions,
      child: ListView.separated(
        itemCount: items.length,
        itemBuilder: (context, index) => itemBuilder(context, items[index]),
        separatorBuilder: separatorBuilder ??
            (context, index) {
              return const SizedBox(height: 8);
            },
      ),
    );
  }
}

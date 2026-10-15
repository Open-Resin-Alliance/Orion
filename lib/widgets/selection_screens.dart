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
import 'package:orion/backend_service/providers/resins_provider.dart';
import 'package:orion/glasser/glasser.dart';
import 'package:orion/util/orion_spacing.dart';
import 'package:orion/util/widgets/system_status_widget.dart';
import 'package:orion/widgets/orion_app_bar.dart';
import 'package:orion/widgets/resin_row.dart';

class DetailedSelectionScreen extends StatelessWidget {
  final String title;
  final Widget child;
  final EdgeInsetsGeometry padding;
  final List<Widget>? actions;

  const DetailedSelectionScreen({
    super.key,
    required this.title,
    required this.child,
    this.padding = OrionSpacing.screenPadding,
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
  final Widget? header;
  final EdgeInsetsGeometry padding;
  final List<Widget>? actions;

  const ListSelectionScreen({
    super.key,
    required this.title,
    required this.items,
    required this.itemBuilder,
    this.separatorBuilder,
    this.header,
    this.padding = OrionSpacing.screenPadding,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return DetailedSelectionScreen(
      title: title,
      padding: padding,
      actions: actions,
      child: header == null
          ? ListView.separated(
              itemCount: items.length,
              itemBuilder: (context, index) =>
                  itemBuilder(context, items[index]),
              separatorBuilder: separatorBuilder ??
                  (context, index) {
                    return const SizedBox(height: OrionSpacing.listGap);
                  },
            )
          : Column(
              children: [
                header!,
                const SizedBox(height: 12),
                Expanded(
                  child: ListView.separated(
                    itemCount: items.length,
                    itemBuilder: (context, index) =>
                        itemBuilder(context, items[index]),
                    separatorBuilder: separatorBuilder ??
                        (context, index) {
                          return const SizedBox(height: OrionSpacing.listGap);
                        },
                  ),
                ),
              ],
            ),
    );
  }
}

class ResinProfileSelectionScreen extends StatelessWidget {
  final String title;
  final List<ResinProfile> resins;
  final String? selectedResinKey;
  final ValueChanged<ResinProfile> onSelected;

  const ResinProfileSelectionScreen({
    super.key,
    required this.title,
    required this.resins,
    required this.selectedResinKey,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return ListSelectionScreen<ResinProfile>(
      title: title,
      items: resins,
      // Same shell as the materials list: it compensates for the cards' own
      // 4pt margin, so the rows land on the standard screen inset.
      padding: OrionSpacing.settingsScreenPaddingTightTop,
      separatorBuilder: (ctx, i) =>
          const SizedBox(height: OrionSpacing.compactListGap),
      itemBuilder: (context, resin) => ResinRow(
        resin: resin,
        highlighted: selectedResinKey == (resin.path ?? resin.name),
        onTap: () => onSelected(resin),
      ),
    );
  }
}

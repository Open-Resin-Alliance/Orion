/*
* Orion - About Dialog
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

import 'package:orion/glasser/src/widgets/glass_button.dart';
import 'package:orion/glasser/src/widgets/glass_card.dart';
import 'package:orion/glasser/src/widgets/glass_dialog.dart';

/// An about dialog for Orion.
class AboutDialog extends StatelessWidget {
  Widget _buildCloseButton(BuildContext context) {
    return Positioned(
      top: 8,
      right: 8,
      child: GlassButton(
        onPressed: () => Navigator.of(context).pop(),
        style: ButtonStyle(
          shape: WidgetStateProperty.all(const CircleBorder()),
          elevation: WidgetStateProperty.all(0),
          minimumSize: WidgetStateProperty.all(const Size(60, 60)),
          maximumSize: WidgetStateProperty.all(const Size(60, 60)),
          padding: WidgetStateProperty.all(
              EdgeInsets.zero), // Remove default padding
        ),
        child: const Center(
          // Explicitly center the icon
          child: Icon(
            Icons.close,
            size: 32,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  void _handleButtonTap(Widget child) {
    // Default: if the child is a button with an onPressed, call it. Otherwise, do nothing.
    if (child is Padding && child.child is GlassCard) {
      final glassCard = child.child as GlassCard;
      if (glassCard.child is ListTile) {
        final listTile = glassCard.child as ListTile;
        if (listTile.onTap != null) {
          listTile.onTap!();
        }
      }
    }
  }

  final String applicationName;
  final String applicationVersion;
  final String applicationLegalese;
  final Widget? applicationIcon;
  final List<Widget>? children;

  const AboutDialog({
    super.key,
    required this.applicationName,
    required this.applicationVersion,
    required this.applicationLegalese,
    this.applicationIcon,
    this.children,
  });

  @override
  Widget build(BuildContext context) {
    final orientation = MediaQuery.of(context).orientation;
    return GlassDialog(
      child: Stack(
        children: [
          if (orientation == Orientation.portrait)
            _buildPortraitContent(context)
          else
            _buildMainContent(context),
          _buildCloseButton(context),
        ],
      ),
    );
  }

  /// Portrait layout: logo on top, then name/version, then legal, then buttons, all centered and spaced vertically.
  Widget _buildPortraitContent(BuildContext context) {
    return Positioned.fill(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (applicationIcon != null) ...[
                _buildIconContainer(),
                const SizedBox(height: 18),
              ],
              Text(
                applicationName,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                applicationVersion,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              _buildLegalText(context),
              if (children != null && children!.isNotEmpty) ...[
                const SizedBox(height: 28),
                _buildPortraitActionButtons(context),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Portrait: stack buttons vertically with spacing.
  Widget _buildPortraitActionButtons(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (int i = 0; i < children!.length; i++) ...[
          // Remove Expanded for portrait buttons
          GlassButton(
            onPressed: () => _handleButtonTap(children![i]),
            style: ButtonStyle(
              padding: WidgetStateProperty.all(
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 16)),
              shape: WidgetStateProperty.all(RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              )),
            ),
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: _extractButtonContent(context, children![i]),
            ),
          ),
          if (i < children!.length - 1) const SizedBox(height: 16),
        ]
      ],
    );
  }

  Widget _buildMainContent(BuildContext context) {
    return Positioned.fill(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _buildHeader(context),
              const SizedBox(height: 24),
              _buildLegalText(context),
              if (children != null && children!.isNotEmpty) ...[
                const SizedBox(height: 24),
                _buildActionButtons(context),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        if (applicationIcon != null) ...[
          _buildIconContainer(),
          const SizedBox(width: 18),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                applicationName,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 2),
              Text(
                applicationVersion,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildIconContainer() {
    return GlassCard(
      outlined: true,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(10.0),
        child: SizedBox(
          height: 54,
          width: 54,
          child: FittedBox(
            fit: BoxFit.contain,
            child: applicationIcon!,
          ),
        ),
      ),
    );
  }

  Widget _buildLegalText(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: GlassCard(
            outlined: true,
            margin: EdgeInsets.zero,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                applicationLegalese,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      height: 3.0,
                      fontSize: 16,
                    ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    final buttonWidgets = <Widget>[];

    for (int i = 0; i < children!.length; i++) {
      buttonWidgets.add(_buildActionButton(context, children![i]));
      if (i < children!.length - 1) {
        // Add spacing between buttons, but not after the last one
        buttonWidgets.add(const SizedBox(width: 16));
      }
    }

    return Row(children: buttonWidgets);
  }

  Widget _buildActionButton(BuildContext context, Widget child) {
    final buttonContent = _extractButtonContent(context, child);
    return Expanded(
      child: GlassButton(
        onPressed: () => _handleButtonTap(child),
        style: ButtonStyle(
          padding: WidgetStateProperty.all(
              const EdgeInsets.symmetric(horizontal: 16, vertical: 16)),
          shape: WidgetStateProperty.all(RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          )),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: buttonContent,
        ),
      ),
    );
  }

  Widget _extractButtonContent(BuildContext context, Widget child) {
    if (child is! Padding || child.child is! GlassCard) {
      return const SizedBox.shrink();
    }

    final glassCard = child.child as GlassCard;
    if (glassCard.child is! ListTile) {
      return const SizedBox.shrink();
    }

    final listTile = glassCard.child as ListTile;
    return _buildButtonContentFromListTile(context, listTile);
  }

  Widget _buildButtonContentFromListTile(
      BuildContext context, ListTile listTile) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (listTile.leading != null)
          IconTheme(
            data: IconThemeData(
              color: Theme.of(context).colorScheme.primary,
              size: 28,
            ),
            child: listTile.leading!,
          ),
        if (listTile.title != null)
          DefaultTextStyle(
            style: Theme.of(context).textTheme.titleMedium!,
            child: listTile.title!,
          ),
        if (listTile.subtitle != null)
          DefaultTextStyle(
            style: Theme.of(context).textTheme.bodySmall!,
            child: listTile.subtitle!,
          ),
      ],
    );
  }
}

/// Shows the about dialog.
Future<void> showOrionAboutDialog({
  required BuildContext context,
  required String applicationName,
  required String applicationVersion,
  required String applicationLegalese,
  Widget? applicationIcon,
  List<Widget>? children,
}) {
  return showDialog(
    context: context,
    builder: (context) => AboutDialog(
      applicationName: applicationName,
      applicationVersion: applicationVersion,
      applicationLegalese: applicationLegalese,
      applicationIcon: applicationIcon,
      children: children,
    ),
  );
}

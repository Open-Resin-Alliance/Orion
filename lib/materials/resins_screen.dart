/*
* Orion - Resins Screen
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
import 'package:flutter_i18n/flutter_i18n.dart';
import 'package:orion/materials/edit_resin_screen.dart';
import 'package:provider/provider.dart';
import 'package:logging/logging.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'package:orion/glasser/glasser.dart';
import 'package:orion/widgets/resin_row.dart';
// error dialog util removed (delete flow not present); import kept out for now
import 'package:orion/backend_service/providers/resins_provider.dart';
import 'package:orion/util/orion_spacing.dart';

class ResinsScreen extends StatefulWidget {
  const ResinsScreen({super.key});

  @override
  ResinsScreenState createState() => ResinsScreenState();
}

class ResinsScreenState extends State<ResinsScreen> {
  final _logger = Logger('ResinsScreen');
  String? _selectedKey;
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // layout is responsive; orientation check removed as it's unused

    return ChangeNotifierProvider(
      create: (_) => ResinsProvider(),
      builder: (context, child) {
        final provider = Provider.of<ResinsProvider>(context);

        return Scaffold(
          backgroundColor: Colors.transparent,
          body: Padding(
            // Account for card margins: cards have 4px margin, so reduce padding
            padding: EdgeInsets.only(
              left: OrionSpacing.screenHorizontal - 4.0,
              right: OrionSpacing.screenHorizontal - 4.0,
              top: OrionSpacing.settingsScreenPaddingTightTop.top,
            ),
            child: Column(
              children: [
                // Content
                Expanded(
                  child: Builder(builder: (ctx) {
                    if (provider.isLoading) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (provider.error != null) {
                      return Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                                FlutterI18n.translate(
                                    context, 'resins.failedLoad'),
                                style: TextStyle(color: Colors.grey.shade300)),
                            const SizedBox(height: 12),
                            GlassButton(
                              onPressed: () => provider.refresh(),
                              child: Text(FlutterI18n.translate(
                                  context, 'resins.retry')),
                            ),
                          ],
                        ),
                      );
                    }

                    final items = provider.resins;
                    // If the provider determined an active resin key, apply it
                    // once after load so the UI highlights the default profile.
                    if (!provider.isLoading && _selectedKey == null) {
                      final key = provider.activeResinKey;
                      if (key != null && key.isNotEmpty) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (mounted) {
                            setState(() {
                              _selectedKey = key;
                            });
                          }
                        });
                      }
                    }
                    if (items.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                                FlutterI18n.translate(
                                    context, 'resins.noProfiles'),
                                style: TextStyle(color: Colors.grey.shade300)),
                            const SizedBox(height: 12),
                            GlassButton(
                              onPressed: () => _onAddResin(context),
                              child: Text(FlutterI18n.translate(
                                  context, 'resins.createProfile')),
                            ),
                          ],
                        ),
                      );
                    }

                    // Show the active/default resin pinned at the top (if present),
                    // followed by a subtle spacer and the remaining profiles.
                    return RefreshIndicator(
                      onRefresh: provider.refresh,
                      child: Builder(builder: (ctx) {
                        final selectedKey = provider.activeResinKey;
                        ResinProfile? selected;
                        if (selectedKey != null && selectedKey.isNotEmpty) {
                          for (final r in items) {
                            if ((r.path ?? r.name) == selectedKey) {
                              selected = r;
                              break;
                            }
                          }
                        }

                        if (selected != null) {
                          final otherItems = items
                              .where((r) => (r.path ?? r.name) != selectedKey)
                              .toList();
                          final total = 1 +
                              1 +
                              otherItems.length; // selected + spacer + others
                          return ListView.builder(
                            controller: _scrollController,
                            itemCount: total,
                            padding: EdgeInsets.zero,
                            itemBuilder: (context, index) {
                              if (index == 0) {
                                return _buildResinCard(selected!, provider);
                              }
                              if (index == 1) {
                                return const SizedBox(
                                    height: OrionSpacing.compactListGap);
                              }
                              final resin = otherItems[index - 2];
                              return Padding(
                                padding: const EdgeInsets.only(
                                    top: OrionSpacing.compactListGap),
                                child: _buildResinCard(resin, provider),
                              );
                            },
                          );
                        }

                        // No selected profile found — fall back to a simple list.
                        return ListView.separated(
                          controller: _scrollController,
                          itemCount: items.length,
                          separatorBuilder: (ctx, i) => const SizedBox(
                              height: OrionSpacing.compactListGap),
                          padding: EdgeInsets.zero,
                          itemBuilder: (context, index) {
                            final resin = items[index];
                            return _buildResinCard(resin, provider);
                          },
                        );
                      }),
                    );
                  }),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildResinCard(ResinProfile resin, ResinsProvider provider) {
    final key = resin.path ?? resin.name;
    final isDefault =
        provider.activeResinKey != null && provider.activeResinKey == key;

    return ResinRow(
      resin: resin,
      highlighted: isDefault,
      onTap: () => _onSelectResin(resin, provider),
      trailing: _buildEditAffordance(resin, provider),
    );
  }

  /// The materials list's edit affordance: edit in place, or offer to open a
  /// locked (manufacturer) profile as a clone instead.

  Widget _buildEditAffordance(ResinProfile resin, ResinsProvider provider) {
    final isLocked = resin.locked;
    // Edit affordance. Locked (manufacturer) profiles stay
    // tappable: tapping one explains the lock and offers to
    // open it as a clone instead of editing it in place.
    // No Tooltip wrapper here on purpose: Tooltip's OverlayPortal
    // semantics graft trips the Windows AXTree bug inside this
    // ListView (flutter/flutter#182444). The visible "Edit" text
    // and the icon's semantic label carry the meaning instead.
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: isLocked
          ? () => _showClonePrompt(resin, provider)
          : () => _onEditResin(resin, provider),
      child: SizedBox(
        width: 110,
        height: 46,
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              PhosphorIcon(
                PhosphorIcons.pencil(),
                size: 21,
                color: Colors.grey.shade200,
                semanticLabel: isLocked
                    ? FlutterI18n.translate(
                        context, 'resins.locked')
                    : FlutterI18n.translate(context, 'resins.edit'),
              ),
              const SizedBox(width: 7),
              Text(
                FlutterI18n.translate(context, 'resins.edit'),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade200,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _onAddResin(BuildContext context) {
    // Placeholder: open add resin dialog or screen
    showDialog(
      context: context,
      builder: (_) => GlassAlertDialog(
        title: Text(FlutterI18n.translate(context, 'resins.addResin')),
        content:
            Text(FlutterI18n.translate(context, 'resins.implementAddResin')),
        actions: [
          GlassButton(
              onPressed: () => Navigator.pop(context),
              child: Text(FlutterI18n.translate(context, 'resins.ok')))
        ],
      ),
    );
  }

  void _onSelectResin(ResinProfile resin, ResinsProvider provider) {
    _logger.info('Selected resin: ${resin.name}');

    // Optimistically update UI selection
    setState(() {
      _selectedKey = resin.path ?? resin.name;
    });

    provider.selectResin(resin).then((_) {
      // Success: scroll the list back to top so the newly selected default
      // (pinned) is visible at the top of the list. No snackbars — keep the
      // UX subtle and non-distracting.
      if (_scrollController.hasClients) {
        _scrollController.animateTo(0.0,
            duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    }).catchError((err) {
      // Revert optimistic change on failure. We intentionally do not show a
      // snackbar here; the caller can surface errors elsewhere if desired.
      setState(() {
        _selectedKey = provider.activeResinKey;
      });
      _logger.warning('Failed to set default profile: ${err.toString()}');
    });
  }

  void _onEditResin(ResinProfile resin, ResinsProvider provider) {
    _logger.info('Edit resin: ${resin.name}');
    // The edit screen refreshes the list itself once a save succeeds, so the
    // list is current by the time the user is back on this page.
    Navigator.of(context).push(MaterialPageRoute(builder: (_) {
      return EditResinScreen(resin: resin, onSaved: provider.refresh);
    })).then((result) {
      if (result is Map<String, dynamic>) {
        _logger.info('Edit result: $result');
      }
    });
  }

  /// Locked (manufacturer) profiles cannot be edited in place. Explain the
  /// lock and offer to open the profile as an editable clone instead.
  void _showClonePrompt(ResinProfile resin, ResinsProvider provider) {
    _logger.info('Clone prompt for locked resin: ${resin.name}');
    showDialog(
      context: context,
      builder: (dialogContext) => GlassAlertDialog(
        title: Text(FlutterI18n.translate(context, 'resins.cloneTitle')),
        content: Text(
          FlutterI18n.translate(context, 'resins.cloneMessage',
              translationParams: {'name': resin.name}),
          style: const TextStyle(fontSize: 20),
        ),
        actions: [
          GlassButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(0, 60),
            ),
            child: Text(FlutterI18n.translate(context, 'common.cancel'),
                style: const TextStyle(fontSize: 20)),
          ),
          GlassButton(
            tint: GlassButtonTint.positive,
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(0, 60),
            ),
            onPressed: () {
              Navigator.of(dialogContext).pop();
              _onEditResin(resin, provider);
            },
            child: Text(FlutterI18n.translate(context, 'resins.clone'),
                style: const TextStyle(fontSize: 20)),
          ),
        ],
      ),
    );
  }

  // Delete flow removed from UI; keep deletion logic out until needed.
}

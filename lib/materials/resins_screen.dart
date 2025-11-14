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
import 'package:orion/materials/edit_resin_screen.dart';
import 'package:provider/provider.dart';
import 'package:logging/logging.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'package:orion/glasser/glasser.dart';
// error dialog util removed (delete flow not present); import kept out for now
import 'package:orion/backend_service/providers/resins_provider.dart';

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
            // Match other screens: narrow horizontal padding to maximize usable area
            padding: const EdgeInsets.only(left: 16, right: 16, top: 8.0),
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
                            Text('Failed to load resins',
                                style: TextStyle(color: Colors.grey.shade300)),
                            const SizedBox(height: 12),
                            GlassButton(
                              onPressed: () => provider.refresh(),
                              child: const Text('Retry'),
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
                            Text('No resin profiles found',
                                style: TextStyle(color: Colors.grey.shade300)),
                            const SizedBox(height: 12),
                            GlassButton(
                              onPressed: () => _onAddResin(context),
                              child: const Text('Create Profile'),
                            ),
                          ],
                        ),
                      );
                    }

                    // Show the active/default resin pinned at the top (if present),
                    // followed by a divider and the remaining profiles. This gives
                    // clearer visual separation between the chosen/default profile
                    // and the rest.
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
                              otherItems.length; // selected + divider + others
                          return ListView.builder(
                            controller: _scrollController,
                            itemCount: total,
                            padding: EdgeInsets.zero,
                            itemBuilder: (context, index) {
                              if (index == 0) {
                                return _buildResinCard(selected!, provider);
                              }
                              if (index == 1) {
                                return const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 8.0),
                                  child: Divider(thickness: 1),
                                );
                              }
                              final resin = otherItems[index - 2];
                              return Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: _buildResinCard(resin, provider),
                              );
                            },
                          );
                        }

                        // No selected profile found — fall back to a simple list.
                        return ListView.separated(
                          controller: _scrollController,
                          itemCount: items.length,
                          separatorBuilder: (ctx, i) =>
                              const SizedBox(height: 8),
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
    final meta = resin.meta;
    final parts = <String>[];
    if (meta['viscosity'] != null) parts.add('Viscosity: ${meta['viscosity']}');
    if (meta['exposure'] != null) parts.add('Exposure: ${meta['exposure']}');
    // Determine a unique key for this resin (prefer path when available)
    final key = resin.path ?? resin.name;
    final isSelected = _selectedKey != null && _selectedKey == key;

    final borderRadius = BorderRadius.circular(14);
    final isDefault =
        provider.activeResinKey != null && provider.activeResinKey == key;
    final isLocked = resin.locked;

    // Build the card content as before
    final card = GlassCard(
      elevation: 2,
      outlined: isSelected,
      accentColor: isSelected ? Colors.green.shade400 : null,
      accentOpacity: 0.06,
      shape: RoundedRectangleBorder(borderRadius: borderRadius),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _onSelectResin(resin, provider),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 12.0),
          child: Row(
            children: [
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (isDefault)
                          GlassCard(
                            accentColor: Colors.green.shade400,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8.0, vertical: 5.0),
                              child: Text(
                                'Default',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.green.shade400,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        if (isLocked)
                          Padding(
                            padding:
                                EdgeInsets.only(left: isDefault ? 8.0 : 0.0),
                            child: PhosphorIcon(
                              PhosphorIconsFill.lockSimple,
                              size: 22,
                              color: Colors.grey.shade400,
                            ),
                          ),
                        const SizedBox(width: 10.0),
                        Expanded(
                          child: Text(resin.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: 24, color: Colors.grey.shade50)),
                        ),
                      ],
                    ),
                    if (parts.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 6.0),
                        child: Text(parts.join(' • '),
                            style: TextStyle(
                                fontSize: 14, color: Colors.grey.shade400)),
                      ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Always render the IconButton so layout height remains
                  // consistent. For locked profiles we visually dim it and
                  // disable interaction. Use partial opacity to hint disabled
                  // affordance while keeping layout stable.
                  Opacity(
                    opacity: resin.locked ? 0.28 : 1.0,
                    child: IconButton(
                      tooltip: resin.locked ? null : 'Edit',
                      icon: PhosphorIcon(PhosphorIcons.pencil()),
                      iconSize: 34,
                      color: resin.locked ? Colors.grey.shade400 : null,
                      onPressed:
                          resin.locked ? null : () => _onEditResin(resin),
                    ),
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );

    // Add a subtle scale animation on selection to indicate feedback.
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 1.0, end: isSelected ? 1.01 : 1.0),
      duration: const Duration(milliseconds: 180),
      builder: (context, scale, child) {
        return Transform.scale(scale: scale, child: child);
      },
      child: card,
    );
  }

  void _onAddResin(BuildContext context) {
    // Placeholder: open add resin dialog or screen
    showDialog(
      context: context,
      builder: (_) => GlassAlertDialog(
        title: const Text('Add Resin'),
        content: const Text('Implement Add Resin flow'),
        actions: [
          GlassButton(
              onPressed: () => Navigator.pop(context), child: Text('OK'))
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

  void _onEditResin(ResinProfile resin) {
    _logger.info('Edit resin: ${resin.name}');
    // Open the new edit screen which returns a map of edited values on save.
    Navigator.of(context).push(MaterialPageRoute(builder: (_) {
      return EditResinScreen(resin: resin);
    })).then((result) {
      if (result is Map<String, dynamic>) {
        _logger.info('Edit result: $result');
        // TODO: wire saving of edited fields to the provider/backend.
      }
    });
  }

  // Delete flow removed from UI; keep deletion logic out until needed.
}

/*
* Orion - Update Available Screen
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
import 'package:orion/util/providers/theme_provider.dart';
import 'package:orion/util/update_manager.dart';
import 'package:orion/widgets/version_comparison.dart';
import 'package:provider/provider.dart';

class UpdateAvailableScreen extends StatefulWidget {
  final VoidCallback onRemindLater;
  final VoidCallback onUpdateNow;

  const UpdateAvailableScreen({
    super.key,
    required this.onRemindLater,
    required this.onUpdateNow,
  });

  @override
  State<UpdateAvailableScreen> createState() => _UpdateAvailableScreenState();
}

class _UpdateAvailableScreenState extends State<UpdateAvailableScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  List<Color> _gradientColors = const [];
  Color _backgroundColor = Colors.black;
  bool _dontShowAgain = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    // Start animation shortly after screen appears
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final baseBackground = Theme.of(context).scaffoldBackgroundColor;
    _backgroundColor =
        Color.lerp(baseBackground, Colors.black, 0.6) ?? Colors.black;
    try {
      final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
      if (themeProvider.isGlassTheme) {
        final gradient = GlassGradientUtils.resolveGradient(
          themeProvider: themeProvider,
        );
        _gradientColors = gradient.isNotEmpty ? gradient : const [];
      } else {
        _gradientColors = const [];
        _backgroundColor = Color.lerp(Theme.of(context).scaffoldBackgroundColor,
                Colors.black, 0.35) ??
            _backgroundColor;
      }
    } catch (_) {
      _gradientColors = const [];
    }
  }

  Widget _buildAnimatedItem(Widget child, double start, double end) {
    final curve = CurvedAnimation(
      parent: _controller,
      curve: Interval(start, end, curve: Curves.easeOutQuart),
    );
    return FadeTransition(
      opacity: curve,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.3),
          end: Offset.zero,
        ).animate(curve),
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final updateManager = Provider.of<UpdateManager>(context, listen: false);
    final orion = updateManager.orionProvider;
    final athena = updateManager.athenaProvider;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Container(color: Colors.black),
          _gradientColors.length >= 2
              ? Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: _gradientColors,
                    ),
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.5),
                    ),
                  ),
                )
              : DecoratedBox(
                  decoration: BoxDecoration(
                    color: _backgroundColor.withValues(alpha: 1.0),
                  ),
                ),
          Center(
            child: Container(
              width: 600,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 32.0, vertical: 24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildAnimatedItem(
                      const Text(
                        'Update Available',
                        style: TextStyle(
                            fontSize: 28, fontWeight: FontWeight.bold),
                      ),
                      0.0,
                      0.5,
                    ),
                    const SizedBox(height: 24),
                    if (orion.isUpdateAvailable)
                      _buildAnimatedItem(
                        VersionComparison(
                          title: 'Orion',
                          branch: orion.release,
                          currentVersion: orion.currentVersion,
                          newVersion: orion.latestVersion,
                        ),
                        0.2,
                        0.7,
                      ),
                    if (orion.isUpdateAvailable && athena.updateAvailable)
                      const SizedBox(height: 16),
                    if (athena.updateAvailable)
                      _buildAnimatedItem(
                        VersionComparison(
                          title: 'AthenaOS',
                          branch: athena.channel,
                          currentVersion: athena.currentVersion,
                          newVersion: athena.latestVersion,
                        ),
                        0.3,
                        0.8,
                      ),
                    const SizedBox(height: 32),
                    _buildAnimatedItem(
                      const Text(
                        'Would you like to update now?',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      0.4,
                      0.9,
                    ),
                    const SizedBox(height: 24),
                    _buildAnimatedItem(
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          GlassButton(
                            tint: GlassButtonTint.neutral,
                            style: ElevatedButton.styleFrom(
                              minimumSize: const Size(200, 64),
                            ),
                            onPressed: () {
                              if (_dontShowAgain) {
                                // If user chose to ignore updates, set the flag.
                                // We still call onRemindLater to dismiss the screen.
                                updateManager.setIgnoreUpdates(true);
                              }
                              widget.onRemindLater();
                            },
                            child: const Text(
                              'Remind Later',
                              style: TextStyle(fontSize: 22),
                            ),
                          ),
                          const SizedBox(width: 24),
                          GlassButton(
                            tint: GlassButtonTint.positive,
                            style: ElevatedButton.styleFrom(
                              minimumSize: const Size(200, 64),
                            ),
                            onPressed: widget.onUpdateNow,
                            child: const Text(
                              'Update Now',
                              style: TextStyle(fontSize: 22),
                            ),
                          ),
                        ],
                      ),
                      0.5,
                      1.0,
                    ),
                    if (!(orion.isUpdateAvailable && athena.updateAvailable)) ...[
                      const SizedBox(height: 32),
                      _buildAnimatedItem(
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Transform.scale(
                              scale: 1.2,
                              child: GlassSwitch(
                                value: _dontShowAgain,
                                onChanged: (val) {
                                  setState(() {
                                    _dontShowAgain = val;
                                  });
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Text(
                              'Don\'t show update notifications',
                              style: TextStyle(
                                fontSize: 20,
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                        0.55,
                        1.05,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

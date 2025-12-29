/*
* Orion - UI Settings Screen
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
import 'package:provider/provider.dart';

import 'package:orion/glasser/glasser.dart';
import 'package:orion/util/orion_config.dart';
import 'package:orion/util/providers/theme_provider.dart';
import 'package:orion/util/theme_color_selector.dart';

class UIScreen extends StatefulWidget {
  const UIScreen({super.key});

  @override
  State<UIScreen> createState() => _UIScreenState();
}

class _UIScreenState extends State<UIScreen> {
  late OrionConfig config;
  late OrionThemeMode themeMode;

  @override
  void initState() {
    super.initState();
    config = OrionConfig();
    themeMode =
        Provider.of<ThemeProvider>(context, listen: false).orionThemeMode;
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return GlassApp(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('User Interface'),
        ),
        body: SingleChildScrollView(
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
            child: Column(
              children: [
                // Theme Mode Selector Card
                GlassCard(
                  outlined: true,
                  elevation: 1,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Theme Mode',
                          style: TextStyle(
                            fontSize: 24.0,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 20.0),
                        GlassThemeSelector(
                          selectedTheme: themeProvider.orionThemeMode,
                          onThemeChanged: (OrionThemeMode newMode) {
                            setState(() {
                              themeMode = newMode;
                            });
                            themeProvider.setThemeMode(newMode);
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16.0),

                // Theme Color Selector Card (only show if not mandated by vendor)
                if (!config.getFlag('mandateTheme', category: 'vendor'))
                  GlassCard(
                    outlined: true,
                    elevation: 1,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Theme Color',
                            style: TextStyle(
                              fontSize: 24.0,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 20.0),
                          ThemeColorSelector(
                            config: config,
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

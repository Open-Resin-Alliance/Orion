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

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:orion/util/widgets/system_status_widget.dart';
import 'package:orion/widgets/orion_app_bar.dart';
import 'package:provider/provider.dart';

import 'package:orion/glasser/glasser.dart';
import 'package:orion/util/orion_config.dart';
import 'package:orion/util/providers/theme_provider.dart';
import 'package:orion/util/theme_color_selector.dart';
import 'package:orion/util/orion_list_tile.dart';
import 'package:orion/backend_service/providers/standby_settings_provider.dart';

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
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return GlassApp(
      child: Scaffold(
        appBar: OrionAppBar(
          title: const Text('User Interface'),
          toolbarHeight: Theme.of(context).appBarTheme.toolbarHeight,
          actions: <Widget>[
            SystemStatusWidget(),
          ],
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
                            fontSize: 26.0,
                          ),
                        ),
                        const SizedBox(height: 16.0),
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
                              fontSize: 26.0,
                            ),
                          ),
                          const SizedBox(height: 16.0),
                          ThemeColorSelector(
                            config: config,
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 16.0),

                // Standby Screen Settings
                Consumer<StandbySettingsProvider>(
                  builder: (ctx, standbySettings, _) {
                    final standbyMinutes =
                        standbySettings.durationSeconds ~/ 60;
                    final standbySeconds = standbySettings.durationSeconds % 60;

                    return GlassCard(
                      outlined: true,
                      elevation: 1,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Standby Screen',
                              style: TextStyle(
                                fontSize: 26.0,
                              ),
                            ),
                            const SizedBox(height: 16.0),
                            OrionListTile(
                              title: 'Enable Standby Screen',
                              value: standbySettings.standbyEnabled,
                              onChanged: (bool value) {
                                standbySettings.setStandbyEnabled(value);
                              },
                              icon: null,
                            ),
                            if (standbySettings.standbyEnabled) ...[
                              const SizedBox(height: 16.0),
                              OrionListTile(
                                title: 'Dim Screen in Standby',
                                value: standbySettings.dimmingEnabled,
                                onChanged: (bool value) {
                                  standbySettings.setDimmingEnabled(value);
                                },
                                icon: null,
                              ),
                              const SizedBox(height: 16.0),
                            ],
                            if (standbySettings.standbyEnabled)
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Flexible(
                                        child: _buildDurationInput(
                                          suffix: 'm',
                                          value: standbyMinutes,
                                          onChanged: (val) {
                                            final newSeconds =
                                                (val * 60) + standbySeconds;
                                            standbySettings
                                                .setDurationSeconds(newSeconds);
                                          },
                                          max: 59,
                                        ),
                                      ),
                                      const SizedBox(width: 12.0),
                                      Flexible(
                                        child: _buildDurationInput(
                                          suffix: 's',
                                          value: standbySeconds,
                                          onChanged: (val) {
                                            final newSeconds =
                                                (standbyMinutes * 60) + val;
                                            standbySettings
                                                .setDurationSeconds(newSeconds);
                                          },
                                          max: 59,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8.0),
                                  Center(
                                    child: Text(
                                      'Screen will enter standby after ${standbyMinutes}m ${standbySeconds}s of inactivity',
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        fontSize: 14.0,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDurationInput({
    required String suffix,
    required int value,
    required Function(int) onChanged,
    required int max,
  }) {
    return GlassCard(
      outlined: true,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Minus button (left)
            _HoldToAccelerateButton(
              icon: Icons.remove,
              enabled: value > 0,
              onTap: () => onChanged(value - 1),
              onHold: (increment) {
                final newValue = (value - increment).clamp(0, max);
                onChanged(newValue);
              },
            ),
            // Number with suffix (center)
            Expanded(
              child: Text(
                '${value.toString().padLeft(2, '0')}$suffix',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 48.0,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            // Plus button (right)
            _HoldToAccelerateButton(
              icon: Icons.add,
              enabled: value < max,
              onTap: () => onChanged(value + 1),
              onHold: (increment) {
                final newValue = (value + increment).clamp(0, max);
                onChanged(newValue);
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Widget for selecting backlight device with auto-detection
class _BacklightDeviceSelector extends StatefulWidget {
  final StandbySettingsProvider standbySettings;

  const _BacklightDeviceSelector({required this.standbySettings});

  @override
  State<_BacklightDeviceSelector> createState() =>
      _BacklightDeviceSelectorState();
}

class _BacklightDeviceSelectorState extends State<_BacklightDeviceSelector> {
  late Future<List<String>> _devicesFuture;

  @override
  void initState() {
    super.initState();
    _devicesFuture = widget.standbySettings.detectBacklightDevices();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<String>>(
      future: _devicesFuture,
      builder: (context, snapshot) {
        final devices = snapshot.data ?? [];
        final currentDevice = widget.standbySettings.backlightDevice;
        final selectedDevice = devices.contains(currentDevice)
            ? currentDevice
            : (devices.isNotEmpty ? devices.first : null);

        return GlassCard(
          outlined: true,
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (snapshot.connectionState == ConnectionState.waiting)
                  const SizedBox(
                    height: 50,
                    child: Center(
                      child: CircularProgressIndicator(),
                    ),
                  )
                else if (devices.isEmpty)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'No backlight devices detected',
                        style: TextStyle(
                          fontSize: 14.0,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 12.0),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            setState(() {
                              _devicesFuture = widget.standbySettings
                                  .detectBacklightDevices();
                            });
                          },
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retry Detection'),
                        ),
                      ),
                    ],
                  )
                else
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      DropdownButton<String>(
                        isExpanded: true,
                        value: selectedDevice,
                        items: devices
                            .map((device) => DropdownMenuItem(
                                  value: device,
                                  child: Text(device),
                                ))
                            .toList(),
                        onChanged: (device) {
                          if (device != null) {
                            widget.standbySettings.setBacklightDevice(device);
                          }
                        },
                      ),
                      const SizedBox(height: 12.0),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            setState(() {
                              _devicesFuture = widget.standbySettings
                                  .detectBacklightDevices();
                            });
                          },
                          icon: const Icon(Icons.refresh),
                          label: const Text('Rescan Devices'),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// A button that accelerates when held down
class _HoldToAccelerateButton extends StatefulWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;
  final Function(int increment) onHold;

  const _HoldToAccelerateButton({
    required this.icon,
    required this.enabled,
    required this.onTap,
    required this.onHold,
  });

  @override
  State<_HoldToAccelerateButton> createState() =>
      _HoldToAccelerateButtonState();
}

class _HoldToAccelerateButtonState extends State<_HoldToAccelerateButton> {
  Timer? _holdTimer;
  int _holdTicks = 0;

  void _startHolding() {
    if (!widget.enabled) return;

    _holdTicks = 0;
    _holdTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      _holdTicks++;

      // Calculate increment with acceleration
      // Start at 1, then increase every 10 ticks
      int increment = 1;
      if (_holdTicks > 30) {
        increment = 5; // Fast after 3 seconds
      } else if (_holdTicks > 10) {
        increment = 2; // Medium after 1 second
      }

      widget.onHold(increment);
    });
  }

  void _stopHolding() {
    _holdTimer?.cancel();
    _holdTimer = null;
    _holdTicks = 0;
  }

  @override
  void dispose() {
    _stopHolding();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      width: 56,
      height: 56,
      child: GestureDetector(
        onTap: widget.enabled ? widget.onTap : null,
        onLongPressStart: (_) => _startHolding(),
        onLongPressEnd: (_) => _stopHolding(),
        onLongPressCancel: () => _stopHolding(),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: widget.enabled
                ? theme.colorScheme.primary.withOpacity(0.1)
                : Colors.transparent,
          ),
          child: Icon(
            widget.icon,
            size: 28,
            color: widget.enabled ? theme.iconTheme.color : theme.disabledColor,
          ),
        ),
      ),
    );
  }
}

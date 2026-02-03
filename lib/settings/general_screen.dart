/*
* Orion - General Config Screen
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

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:orion/settings/machine_settings_screen.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';

import 'package:orion/glasser/glasser.dart';
import 'package:orion/settings/settings_screen.dart';
import 'package:orion/settings/ui_screen.dart';
import 'package:orion/util/orion_config.dart';
import 'package:orion/util/orion_kb/orion_keyboard_expander.dart';
import 'package:orion/util/orion_kb/orion_textfield_spawn.dart';
import 'package:orion/util/orion_list_tile.dart';
import 'package:orion/util/providers/theme_provider.dart';
import 'package:orion/util/thumbnail_cache.dart';

class GeneralCfgScreen extends StatefulWidget {
  const GeneralCfgScreen({super.key});

  @override
  GeneralCfgScreenState createState() => GeneralCfgScreenState();
}

class GeneralCfgScreenState extends State<GeneralCfgScreen> {
  late OrionThemeMode themeMode;
  late bool useUsbByDefault;
  late bool overrideScreenRotation;
  late String screenRotation;
  late bool useCustomUrl;
  late String customUrl;
  late bool developerMode;
  late bool releaseOverride;
  late bool overrideUpdateCheck;
  late bool overrideRawForceSensorValues;
  late bool reuseCalibrationPlate;
  late String overrideRelease;
  late bool verboseLogging;
  late bool selfDestructMode;
  late String machineName;
  late String backendMode;

  late String originalRotation;

  final ScrollController _scrollController = ScrollController();

  final OrionConfig config = OrionConfig();

  final GlobalKey<SpawnOrionTextFieldState> urlTextFieldKey =
      GlobalKey<SpawnOrionTextFieldState>();

  final GlobalKey<SpawnOrionTextFieldState> branchTextFieldKey =
      GlobalKey<SpawnOrionTextFieldState>();

  List<String> _availableReleases = [];
  bool _isLoadingReleases = false;
  Map<String, String> _releaseDates = {};
  String? _loadError;

  @override
  void initState() {
    super.initState();
    final OrionConfig config = OrionConfig();
    // We'll set themeMode in didChangeDependencies
    themeMode = OrionThemeMode.light; // default, will be updated
    useUsbByDefault = config.getFlag('useUsbByDefault');
    useCustomUrl = config.getFlag('useCustomUrl', category: 'advanced');
    overrideScreenRotation =
        config.getFlag('overrideScreenRotation', category: 'advanced');
    screenRotation = config.getString('screenRotation', category: 'advanced');
    customUrl = config.getString('customUrl', category: 'advanced');
    developerMode = config.getFlag('developerMode', category: 'advanced');
    releaseOverride = config.getFlag('releaseOverride', category: 'developer');
    overrideUpdateCheck =
        config.getFlag('overrideUpdateCheck', category: 'developer');
    overrideRawForceSensorValues =
        config.getFlag('overrideRawForceSensorValues', category: 'developer');
    reuseCalibrationPlate =
        config.getFlag('reuseCalibrationPlate', category: 'developer');
    overrideRelease =
        config.getString('overrideRelease', category: 'developer');
    verboseLogging = config.getFlag('verboseLogging', category: 'developer');
    selfDestructMode =
        config.getFlag('selfDestructMode', category: 'topsecret');
    backendMode = config.getString('backend', category: 'advanced').isEmpty
        ? 'odyssey'
        : config.getString('backend', category: 'advanced').toLowerCase();
    screenRotation = screenRotation == '' ? '0' : screenRotation;
    config.setString('screenRotation', screenRotation, category: 'advanced');
    originalRotation = screenRotation;
    machineName = config.getString('machineName', category: 'machine');
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final themeProvider = context.watch<ThemeProvider>();
    themeMode = themeProvider.orionThemeMode;
  }

  bool shouldDestruct() {
    // Always make the Self-Destruct option rare to appear,
    // regardless of whether it has ever been toggled before.
    // Roughly ~0.1% chance on a given build of this screen.
    final rand = Random();
    return rand.nextInt(1000) == 0;
  }

  bool isJune() {
    final now = DateTime.now();
    return now.month == 6;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      child: Scaffold(
        body: Padding(
          padding: const EdgeInsets.only(left: 16, right: 16, top: 5),
          child: ListView(
            controller: _scrollController,
            children: <Widget>[
              if (isJune())
                Dismissible(
                  key: UniqueKey(),
                  direction: DismissDirection.horizontal,
                  onDismissed: (direction) {},
                  background: Container(color: Colors.transparent),
                  child: const GlassCard(
                    outlined: true,
                    elevation: 1,
                    child: Padding(
                      padding: EdgeInsets.only(
                          left: 16, right: 16, top: 10, bottom: 10),
                      child: ListTile(
                        title: Text(
                          'Happy Pride Month!',
                          style: TextStyle(fontSize: 24),
                        ),
                        leading: Icon(Icons.favorite, color: Colors.pink),
                      ),
                    ),
                  ),
                ),
              if (shouldDestruct())
                GlassCard(
                  elevation: 1,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(
                          10), // match this with your Card's border radius
                      gradient: LinearGradient(
                        colors: [
                          Colors.red,
                          Colors.orange,
                          Colors.yellow,
                          Colors.green,
                          Colors.blue,
                          Colors.indigo,
                          Colors.purple
                        ]
                            .map((color) =>
                                Color.lerp(color, Colors.black, 0.25))
                            .where((color) => color != null)
                            .cast<Color>()
                            .toList(),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: OrionListTile(
                        ignoreColor: true,
                        title: 'Self-Destruct Mode',
                        icon: PhosphorIcons.skull,
                        value: selfDestructMode,
                        onChanged: (bool value) {
                          setState(() {
                            selfDestructMode = value;
                            config.setFlag('selfDestructMode', selfDestructMode,
                                category: 'topsecret');
                            config.blowUp(context, 'assets/images/bsod.png');
                          });
                        },
                      ),
                    ),
                  ),
                ),
              // API Backend Selection - Developer Only
              GlassCard(
                accentColor: Colors.orangeAccent.shade100,
                outlined: true,
                elevation: 1,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Internal Settings',
                        style: TextStyle(
                            fontSize: 28.0, color: Colors.orangeAccent),
                      ),
                      const SizedBox(height: 12.0),
                      Text(
                        'Switch between NanoDLP and Odyssey API backends. Current: ${backendMode.toLowerCase()}. Requires restart.',
                        style: TextStyle(
                            fontSize: 20, color: Colors.orangeAccent.shade100),
                      ),
                      const SizedBox(height: 20.0),
                      Row(
                        children: [
                          Expanded(
                            child: GlassButton(
                              style: ElevatedButton.styleFrom(
                                minimumSize: const Size(0, 60),
                              ),
                              tint: GlassButtonTint.warn,
                              onPressed: backendMode == 'nanodlp'
                                  ? null
                                  : () async {
                                      final confirmed = await showDialog<bool>(
                                            context: context,
                                            builder: (ctx) => GlassAlertDialog(
                                              title: const Text(
                                                  'Switch to NanoDLP?'),
                                              content: const Text(
                                                  'This will switch to NanoDLP API backend. The app will restart automatically. Continue?',
                                                  style: TextStyle(
                                                      fontSize: 18.0)),
                                              actions: [
                                                GlassButton(
                                                    style: ElevatedButton
                                                        .styleFrom(
                                                      minimumSize:
                                                          const Size(0, 60),
                                                    ),
                                                    tint:
                                                        GlassButtonTint.neutral,
                                                    onPressed: () =>
                                                        Navigator.of(ctx)
                                                            .pop(false),
                                                    child: const Text('Cancel',
                                                        style: TextStyle(
                                                            fontSize: 22.0))),
                                                GlassButton(
                                                    tint: GlassButtonTint.warn,
                                                    style: ElevatedButton
                                                        .styleFrom(
                                                      minimumSize:
                                                          const Size(0, 60),
                                                    ),
                                                    onPressed: () =>
                                                        Navigator.of(ctx)
                                                            .pop(true),
                                                    child: const Text('Switch',
                                                        style: TextStyle(
                                                            fontSize: 22.0))),
                                              ],
                                            ),
                                          ) ??
                                          false;

                                      if (confirmed) {
                                        await _switchBackendService('nanodlp');
                                      }
                                    },
                              child: const Text(
                                'NanoDLP',
                                style: TextStyle(fontSize: 22),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12.0),
                          Expanded(
                            child: GlassButton(
                              style: ElevatedButton.styleFrom(
                                minimumSize: const Size(0, 60),
                              ),
                              tint: GlassButtonTint.positive,
                              onPressed: backendMode == 'odyssey'
                                  ? null
                                  : () async {
                                      final confirmed = await showDialog<bool>(
                                            context: context,
                                            builder: (ctx) => GlassAlertDialog(
                                              title: const Text(
                                                  'Switch to Odyssey?'),
                                              content: const Text(
                                                  'This will switch to Odyssey API backend. The app will restart automatically. Continue?',
                                                  style: TextStyle(
                                                      fontSize: 18.0)),
                                              actions: [
                                                GlassButton(
                                                    style: ElevatedButton
                                                        .styleFrom(
                                                      minimumSize:
                                                          const Size(0, 60),
                                                    ),
                                                    tint:
                                                        GlassButtonTint.neutral,
                                                    onPressed: () =>
                                                        Navigator.of(ctx)
                                                            .pop(false),
                                                    child: const Text('Cancel',
                                                        style: TextStyle(
                                                            fontSize: 22.0))),
                                                GlassButton(
                                                    tint: GlassButtonTint
                                                        .positive,
                                                    style: ElevatedButton
                                                        .styleFrom(
                                                      minimumSize:
                                                          const Size(0, 60),
                                                    ),
                                                    onPressed: () =>
                                                        Navigator.of(ctx)
                                                            .pop(true),
                                                    child: const Text('Switch',
                                                        style: TextStyle(
                                                            fontSize: 22.0))),
                                              ],
                                            ),
                                          ) ??
                                          false;

                                      if (confirmed) {
                                        await _switchBackendService('odyssey');
                                      }
                                    },
                              child: const Text(
                                'Odyssey',
                                style: TextStyle(fontSize: 22),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12.0),
              GlassCard(
                outlined: true,
                elevation: 1,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'General',
                        style: TextStyle(
                          fontSize: 28.0,
                        ),
                      ),
                      const SizedBox(height: 20.0),

                      // UI Settings Navigation
                      GlassCard(
                        outlined: true,
                        elevation: 1,
                        child: ListTile(
                          leading: Icon(Icons.palette),
                          title: const Text('User Interface',
                              style: TextStyle(fontSize: 20)),
                          subtitle: const Text('Theme and appearance settings',
                              style: TextStyle(fontSize: 16)),
                          trailing: Icon(Icons.arrow_forward_ios,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.6)),
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => const UIScreen(),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 20.0),
                      OrionListTile(
                        title: 'Use USB by Default',
                        icon: PhosphorIcons.usb,
                        value: useUsbByDefault,
                        onChanged: (bool value) {
                          setState(() {
                            useUsbByDefault = value;
                            config.setFlag('useUsbByDefault', useUsbByDefault);
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ),
              GlassCard(
                outlined: true,
                elevation: 1,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Advanced',
                        style: TextStyle(
                          fontSize: 28.0,
                        ),
                      ),
                      const SizedBox(height: 20.0),
                      GlassCard(
                        outlined: true,
                        elevation: 1,
                        child: ListTile(
                          leading: Icon(Icons.engineering),
                          title: const Text('Machine Settings',
                              style: TextStyle(fontSize: 20)),
                          subtitle: const Text('Configure machine features',
                              style: TextStyle(fontSize: 16)),
                          trailing: Icon(Icons.arrow_forward_ios,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.6)),
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) =>
                                    const MachineSettingsScreen(),
                              ),
                            );
                          },
                        ),
                      ),
                      if (Platform.isLinux) const SizedBox(height: 20.0),
                      if (Platform.isLinux)
                        OrionListTile(
                          title: 'Override Screen Rotation',
                          icon: PhosphorIcons.deviceRotate(),
                          value: overrideScreenRotation,
                          onChanged: (bool value) {
                            setState(() {
                              overrideScreenRotation = value;
                              config.setFlag('overrideScreenRotation',
                                  overrideScreenRotation,
                                  category: 'advanced');
                            });
                          },
                        ),
                      if (overrideScreenRotation && Platform.isLinux)
                        const SizedBox(height: 20.0),
                      if (overrideScreenRotation && Platform.isLinux)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: List.generate(4, (index) {
                            final value = [0, 90, 180, 270][index];
                            return Flexible(
                              child: Padding(
                                padding: const EdgeInsets.only(
                                    right: 10,
                                    left:
                                        10), // Add padding only if it's not the last item
                                child: ChoiceChip.elevated(
                                  label: SizedBox(
                                    width: double.infinity,
                                    child: Text(
                                      '$value°',
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(fontSize: 18),
                                    ),
                                  ),
                                  selected: screenRotation == '$value',
                                  onSelected: (selected) {
                                    setState(() {
                                      if (selected) screenRotation = '$value';
                                      config.setString(
                                          'screenRotation', screenRotation,
                                          category: 'advanced');
                                      if (screenRotation != originalRotation) {
                                        config.setFlag('needsRestart', true,
                                            category: 'internal');
                                        final settingsScreenState =
                                            context.findAncestorStateOfType<
                                                SettingsScreenState>();
                                        settingsScreenState
                                            ?.setRestartStatus(true);
                                      }
                                    });
                                  },
                                ),
                              ),
                            );
                          }),
                        ),
                      const SizedBox(height: 20.0),
                      OrionListTile(
                        title: 'Use Custom Backend URL',
                        icon: PhosphorIcons.network,
                        value: useCustomUrl,
                        onChanged: (bool value) {
                          setState(() {
                            useCustomUrl = value;
                            config.setFlag('useCustomUrl', useCustomUrl,
                                category: 'advanced');
                          });
                        },
                      ),
                      if (useCustomUrl) const SizedBox(height: 20.0),
                      if (useCustomUrl)
                        Row(
                          children: [
                            Expanded(
                              child: SizedBox(
                                height: 60,
                                child: GlassButton(
                                  style: ElevatedButton.styleFrom(
                                    elevation: 3,
                                    alignment:
                                        Alignment.center, // Center the content
                                  ),
                                  onPressed: () {
                                    showDialog(
                                      context: context,
                                      builder: (BuildContext context) {
                                        return GlassAlertDialog(
                                          title: const Center(
                                              child:
                                                  Text('Custom Backend URL')),
                                          content: SizedBox(
                                            width: MediaQuery.of(context)
                                                    .size
                                                    .width *
                                                0.5,
                                            child: SingleChildScrollView(
                                              child: Column(
                                                children: [
                                                  SpawnOrionTextField(
                                                    key: urlTextFieldKey,
                                                    keyboardHint: 'Enter URL',
                                                    locale:
                                                        Localizations.localeOf(
                                                                context)
                                                            .toString(),
                                                    scrollController:
                                                        _scrollController,
                                                    presetText: config
                                                        .getString('customUrl',
                                                            category:
                                                                'advanced'),
                                                  ),
                                                  OrionKbExpander(
                                                      textFieldKey:
                                                          urlTextFieldKey),
                                                ],
                                              ),
                                            ),
                                          ),
                                          actions: [
                                            GlassButton(
                                              tint: GlassButtonTint.neutral,
                                              onPressed: () {
                                                Navigator.of(context).pop();
                                              },
                                              style: ElevatedButton.styleFrom(
                                                  minimumSize:
                                                      const Size(0, 60)),
                                              child: const Text('Close',
                                                  style:
                                                      TextStyle(fontSize: 22)),
                                            ),
                                            GlassButton(
                                              tint: GlassButtonTint.positive,
                                              onPressed: () {
                                                setState(() {
                                                  customUrl = urlTextFieldKey
                                                      .currentState!
                                                      .getCurrentText();
                                                  config.setString(
                                                      'customUrl', customUrl,
                                                      category: 'advanced');
                                                });
                                                Navigator.of(context).pop();
                                              },
                                              style: ElevatedButton.styleFrom(
                                                  minimumSize:
                                                      const Size(0, 60)),
                                              child: const Text('Confirm',
                                                  style:
                                                      TextStyle(fontSize: 22)),
                                            ),
                                          ],
                                        );
                                      },
                                    );
                                  },
                                  child: Center(
                                    // Wrap in Center widget
                                    child: AutoSizeText(
                                      customUrl == ''
                                          ? 'Set URL'
                                          : customUrl.split('//').last,
                                      style: const TextStyle(fontSize: 22),
                                      minFontSize: 20,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      textAlign: TextAlign
                                          .center, // Center text alignment
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 20),
                            Expanded(
                              child: SizedBox(
                                height:
                                    60, // Increase height to prevent text cutoff
                                child: customUrl == ''
                                    ? GlassButton(
                                        style: ElevatedButton.styleFrom(
                                          elevation: 3,
                                          alignment: Alignment
                                              .center, // Center the content
                                        ),
                                        onPressed:
                                            () {}, // Empty callback for disabled state
                                        child: Opacity(
                                          opacity: 0.5, // Make it look disabled
                                          child: const Center(
                                            // Wrap in Center widget
                                            child: Text(
                                              'Clear URL',
                                              style: TextStyle(fontSize: 20),
                                              textAlign: TextAlign
                                                  .center, // Center text alignment
                                            ),
                                          ),
                                        ),
                                      )
                                    : GlassButton(
                                        style: ElevatedButton.styleFrom(
                                          elevation: 3,
                                          alignment: Alignment
                                              .center, // Center the content
                                        ),
                                        onPressed: () {
                                          setState(() {
                                            customUrl = '';
                                            config.setString(
                                                'customUrl', customUrl,
                                                category: 'advanced');
                                          });
                                        },
                                        child: const Center(
                                          // Wrap in Center widget
                                          child: Text(
                                            'Clear URL',
                                            style: TextStyle(fontSize: 20),
                                            textAlign: TextAlign
                                                .center, // Center text alignment
                                          ),
                                        ),
                                      ),
                              ),
                            ),
                          ],
                        ),
                      if (developerMode) const SizedBox(height: 20.0),
                      if (developerMode)
                        OrionListTile(
                          title: 'Developer Mode',
                          icon: PhosphorIcons.code,
                          value: developerMode,
                          onChanged: (bool value) {
                            setState(() {
                              developerMode = value;
                              config.setFlag('developerMode', developerMode,
                                  category: 'advanced');
                            });
                          },
                        ),
                    ],
                  ),
                ),
              ),

              /// Developer Section for build overrides.
              if (developerMode) _buildDeveloperSection(),
              const SizedBox(height: 12.0),
              // Danger Zone - critical actions
              GlassCard(
                accentColor: Colors.redAccent.shade100,
                outlined: true,
                elevation: 1,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Danger Zone',
                        style:
                            TextStyle(fontSize: 28.0, color: Colors.redAccent),
                      ),
                      const SizedBox(height: 12.0),
                      Text(
                        'Critical actions that may remove user data or change the device state. Use with caution.',
                        style: TextStyle(
                            fontSize: 20, color: Colors.redAccent.shade100),
                      ),
                      const SizedBox(height: 20.0),
                      Row(
                        children: [
                          Expanded(
                            child: GlassButton(
                              style: ElevatedButton.styleFrom(
                                minimumSize: const Size(0, 60),
                              ),
                              tint: GlassButtonTint.negative,
                              onPressed: () async {
                                final confirmed = await showDialog<bool>(
                                      context: context,
                                      builder: (ctx) => GlassAlertDialog(
                                        title: const Text('Reset User Config'),
                                        content: const Text(
                                            'Restore settings to factory defaults? If a factory preset is available it will be used. Otherwise your custom settings will be cleared. The device will restart immediately. Continue?',
                                            style: TextStyle(fontSize: 18.0)),
                                        actions: [
                                          GlassButton(
                                              style: ElevatedButton.styleFrom(
                                                minimumSize: const Size(0, 60),
                                              ),
                                              tint: GlassButtonTint.warn,
                                              onPressed: () =>
                                                  Navigator.of(ctx).pop(false),
                                              child: const Text('Cancel',
                                                  style: TextStyle(
                                                      fontSize: 22.0))),
                                          GlassButton(
                                              tint: GlassButtonTint.negative,
                                              style: ElevatedButton.styleFrom(
                                                minimumSize: const Size(0, 60),
                                              ),
                                              onPressed: () =>
                                                  Navigator.of(ctx).pop(true),
                                              child: const Text('Reset',
                                                  style: TextStyle(
                                                      fontSize: 22.0))),
                                        ],
                                      ),
                                    ) ??
                                    false;

                                if (confirmed) {
                                  try {
                                    final cfgPath = config.getConfigPath();
                                    final defaultFile =
                                        File('$cfgPath/orion.default.cfg');
                                    final targetFile =
                                        File('$cfgPath/orion.cfg');

                                    if (defaultFile.existsSync()) {
                                      // Overwrite orion.cfg with the default
                                      final contents =
                                          defaultFile.readAsStringSync();
                                      targetFile.writeAsStringSync(contents);
                                    } else {
                                      // No default provided: remove orion.cfg
                                      if (targetFile.existsSync()) {
                                        targetFile.deleteSync();
                                      }
                                    }

                                    // Decide a message based on whether a default exists
                                    final defaultFileExists =
                                        defaultFile.existsSync();
                                    final rebootMessage = defaultFileExists
                                        ? 'Restoring settings to factory defaults and restarting now.'
                                        : 'Clearing custom settings and restarting now.';

                                    // Show rebooting message then reboot
                                    showDialog(
                                      context: context,
                                      barrierDismissible: false,
                                      builder: (ctx) => GlassAlertDialog(
                                        title: const Text('Rebooting'),
                                        content: Text(rebootMessage),
                                      ),
                                    );

                                    // Flush and reboot
                                    await Process.run(
                                        'sudo', ['reboot', 'now']);
                                  } catch (e) {
                                    showDialog(
                                      context: context,
                                      builder: (ctx) => GlassAlertDialog(
                                        title: const Text('Error'),
                                        content: const Text(
                                            'Unable to reset settings. Please try again.'),
                                        actions: [
                                          GlassButton(
                                            onPressed: () =>
                                                Navigator.of(ctx).pop(),
                                            child: const Text('OK'),
                                          ),
                                        ],
                                      ),
                                    );
                                  }
                                }
                              },
                              child: const Text(
                                'Reset User Config',
                                style: TextStyle(fontSize: 22),
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (developerMode) const SizedBox(height: 12.0),
                      if (developerMode)
                        Row(
                          children: [
                            Expanded(
                              child: GlassButton(
                                style: ElevatedButton.styleFrom(
                                  minimumSize: const Size(0, 60),
                                ),
                                tint: GlassButtonTint.warn,
                                onPressed: () async {
                                  final confirmed = await showDialog<bool>(
                                        context: context,
                                        builder: (ctx) => GlassAlertDialog(
                                          title: const Text(
                                              'Prepare for Delivery'),
                                          content: const Text(
                                              'Prepare this device for shipping? The device will shut down now. On next start you will run the initial setup wizard. Use only when shipping the device. Continue?',
                                              style: TextStyle(fontSize: 18.0)),
                                          actions: [
                                            GlassButton(
                                                style: ElevatedButton.styleFrom(
                                                  minimumSize:
                                                      const Size(0, 60),
                                                ),
                                                tint: GlassButtonTint.warn,
                                                onPressed: () =>
                                                    Navigator.of(ctx)
                                                        .pop(false),
                                                child: const Text('Cancel',
                                                    style: TextStyle(
                                                        fontSize: 22.0))),
                                            GlassButton(
                                                tint: GlassButtonTint.negative,
                                                style: ElevatedButton.styleFrom(
                                                  minimumSize:
                                                      const Size(0, 60),
                                                ),
                                                onPressed: () =>
                                                    Navigator.of(ctx).pop(true),
                                                child: const Text('Prepare',
                                                    style: TextStyle(
                                                        fontSize: 22.0))),
                                          ],
                                        ),
                                      ) ??
                                      false;

                                  if (confirmed) {
                                    try {
                                      // Mark firstRun so onboarding will run on next boot
                                      config.setFlag('firstRun', true,
                                          category: 'machine');

                                      // Show immediate shutdown dialog then power off
                                      showDialog(
                                        context: context,
                                        barrierDismissible: false,
                                        builder: (ctx) => GlassAlertDialog(
                                          title: const Text('Shutting down'),
                                          content: const Text(
                                              'Shutting down now. On next start you will be guided through setup.'),
                                        ),
                                      );

                                      await Process.run(
                                          'sudo', ['shutdown', 'now']);
                                    } catch (e) {
                                      showDialog(
                                        context: context,
                                        builder: (ctx) => GlassAlertDialog(
                                          title: const Text('Error'),
                                          content: const Text(
                                              'Unable to prepare the device. Please try again.'),
                                          actions: [
                                            GlassButton(
                                              onPressed: () =>
                                                  Navigator.of(ctx).pop(),
                                              child: const Text('OK'),
                                            ),
                                          ],
                                        ),
                                      );
                                    }
                                  }
                                },
                                child: const Text(
                                  'Prepare for Delivery',
                                  style: TextStyle(fontSize: 22),
                                ),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  GlassCard _buildDeveloperSection() {
    return GlassCard(
      outlined: true,
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Developer',
              style: TextStyle(
                fontSize: 28.0,
              ),
            ),
            const SizedBox(height: 20.0),
            OrionListTile(
              title: 'Release Tag Override',
              icon: PhosphorIcons.download(),
              value: releaseOverride,
              onChanged: (bool value) {
                setState(() {
                  releaseOverride = value;
                  config.setFlag('releaseOverride', releaseOverride,
                      category: 'developer');
                });
              },
            ),
            if (releaseOverride) const SizedBox(height: 20.0),
            if (releaseOverride)
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 60,
                      child: GlassButton(
                        style: ElevatedButton.styleFrom(
                          elevation: 3,
                          alignment: Alignment.center, // Center the content
                        ),
                        onPressed: () {
                          _showReleaseDialog();
                        },
                        child: Center(
                          // Wrap in Center widget
                          child: AutoSizeText(
                            overrideRelease == ''
                                ? 'Select Release Tag'
                                : overrideRelease,
                            style: const TextStyle(fontSize: 22),
                            minFontSize: 20,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign:
                                TextAlign.center, // Center text alignment
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: SizedBox(
                      height: 60, // Increase height to prevent text cutoff
                      child: overrideRelease == ''
                          ? GlassButton(
                              style: ElevatedButton.styleFrom(
                                elevation: 3,
                                alignment:
                                    Alignment.center, // Center the content
                              ),
                              onPressed:
                                  () {}, // Empty callback for disabled state
                              child: Opacity(
                                opacity: 0.5, // Make it look disabled
                                child: const Center(
                                  // Wrap in Center widget
                                  child: Text(
                                    'Clear Release',
                                    style: TextStyle(fontSize: 18),
                                    textAlign: TextAlign
                                        .center, // Center text alignment
                                  ),
                                ),
                              ),
                            )
                          : GlassButton(
                              style: ElevatedButton.styleFrom(
                                elevation: 3,
                                alignment:
                                    Alignment.center, // Center the content
                              ),
                              onPressed: () {
                                setState(() {
                                  overrideRelease = '';
                                  config.setString(
                                      'overrideRelease', overrideRelease,
                                      category: 'developer');
                                });
                              },
                              child: const Center(
                                // Wrap in Center widget
                                child: AutoSizeText(
                                  'Clear Release Tag',
                                  style: TextStyle(
                                      fontSize: 18), // Reduce font size
                                  minFontSize: 16, // Reduce min font size
                                  maxLines: 1,
                                  textAlign:
                                      TextAlign.center, // Center text alignment
                                  overflowReplacement: Text(
                                    'Clear Tag',
                                    style: TextStyle(
                                        fontSize: 18), // Reduce font size
                                    textAlign: TextAlign
                                        .center, // Center text alignment
                                  ),
                                ),
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 20.0),
            OrionListTile(
              title: 'Force Update',
              icon: PhosphorIcons.warning(),
              value: overrideUpdateCheck,
              onChanged: (bool value) {
                setState(() {
                  overrideUpdateCheck = value;
                  config.setFlag('overrideUpdateCheck', overrideUpdateCheck,
                      category: 'developer');
                });
              },
            ),
            const SizedBox(height: 20.0),
            OrionListTile(
              title: 'Raw Force Sensor Values',
              icon: PhosphorIcons.scales(),
              value: overrideRawForceSensorValues,
              onChanged: (bool value) {
                setState(() {
                  overrideRawForceSensorValues = value;
                  config.setFlag('overrideRawForceSensorValues',
                      overrideRawForceSensorValues,
                      category: 'developer');
                });
              },
            ),
            const SizedBox(height: 20.0),
            OrionListTile(
              title: 'Reuse Calibration Plate (Debug)',
              icon: PhosphorIcons.flask(),
              value: reuseCalibrationPlate,
              onChanged: (bool value) {
                setState(() {
                  reuseCalibrationPlate = value;
                  config.setFlag('reuseCalibrationPlate', value,
                      category: 'developer');
                });
              },
            ),
            const SizedBox(height: 20.0),
            Row(
              children: [
                Expanded(
                  child: GlassButton(
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(0, 60),
                    ),
                    tint: GlassButtonTint.warn,
                    onPressed: () async {
                      final confirmed = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => GlassAlertDialog(
                              title: const Text('Clear Thumbnail Cache'),
                              content: const Text(
                                  'Clear all cached thumbnails from memory and disk? This will free up disk space and memory. Continue?',
                                  style: TextStyle(fontSize: 18.0)),
                              actions: [
                                GlassButton(
                                    style: ElevatedButton.styleFrom(
                                      minimumSize: const Size(0, 60),
                                    ),
                                    tint: GlassButtonTint.neutral,
                                    onPressed: () =>
                                        Navigator.of(ctx).pop(false),
                                    child: const Text('Cancel',
                                        style: TextStyle(fontSize: 22.0))),
                                GlassButton(
                                    tint: GlassButtonTint.warn,
                                    style: ElevatedButton.styleFrom(
                                      minimumSize: const Size(0, 60),
                                    ),
                                    onPressed: () =>
                                        Navigator.of(ctx).pop(true),
                                    child: const Text('Clear',
                                        style: TextStyle(fontSize: 22.0))),
                              ],
                            ),
                          ) ??
                          false;

                      if (confirmed) {
                        try {
                          // Show clearing message
                          showDialog(
                            context: context,
                            barrierDismissible: false,
                            builder: (ctx) => const GlassAlertDialog(
                              title: Text('Clearing Cache'),
                              content: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  CircularProgressIndicator(),
                                  SizedBox(height: 16),
                                  Text('Clearing thumbnail cache...',
                                      style: TextStyle(fontSize: 18)),
                                ],
                              ),
                            ),
                          );

                          // Clear the cache
                          await ThumbnailCache.instance.clearAll();

                          // Close progress dialog
                          if (mounted) Navigator.of(context).pop();

                          // Show success message
                          if (mounted) {
                            showDialog(
                              context: context,
                              builder: (ctx) => GlassAlertDialog(
                                title: const Text('Success'),
                                content: const Text(
                                    'Thumbnail cache cleared successfully.',
                                    style: TextStyle(fontSize: 18)),
                                actions: [
                                  GlassButton(
                                    style: ElevatedButton.styleFrom(
                                      minimumSize: const Size(0, 60),
                                    ),
                                    onPressed: () => Navigator.of(ctx).pop(),
                                    child: const Text('OK',
                                        style: TextStyle(fontSize: 22)),
                                  ),
                                ],
                              ),
                            );
                          }
                        } catch (e) {
                          // Close progress dialog if still showing
                          if (mounted) Navigator.of(context).pop();

                          // Show error message
                          if (mounted) {
                            showDialog(
                              context: context,
                              builder: (ctx) => GlassAlertDialog(
                                title: const Text('Error'),
                                content: Text(
                                    'Failed to clear thumbnail cache: $e',
                                    style: const TextStyle(fontSize: 18)),
                                actions: [
                                  GlassButton(
                                    style: ElevatedButton.styleFrom(
                                      minimumSize: const Size(0, 60),
                                    ),
                                    onPressed: () => Navigator.of(ctx).pop(),
                                    child: const Text('OK',
                                        style: TextStyle(fontSize: 22)),
                                  ),
                                ],
                              ),
                            );
                          }
                        }
                      }
                    },
                    child: const Text(
                      'Clear Thumbnail Cache',
                      style: TextStyle(fontSize: 22),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _switchBackendService(String target) async {
    if (!Platform.isLinux) {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (ctx) => GlassAlertDialog(
          title: const Text('Unsupported'),
          content: const Text(
              'Backend switching is only supported on Linux devices.'),
          actions: [
            GlassButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    setState(() {
      backendMode = target;
      config.setString('backend', target, category: 'advanced');
    });

    final stopService = target == 'nanodlp' ? 'odyssey' : 'nanodlp';
    final enableService = target;

    try {
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => const GlassAlertDialog(
          title: Text('Switching Backend'),
          content: Text('Applying service changes...'),
        ),
      );

      await Process.run('sudo', ['systemctl', 'disable', stopService]);
      await Process.run('sudo', ['systemctl', 'stop', stopService]);
      await Process.run('sudo', ['systemctl', 'enable', enableService]);
      await Process.run('sudo', ['systemctl', 'start', enableService]);

      if (mounted) Navigator.of(context).pop();

      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => const GlassAlertDialog(
          title: Text('Rebooting'),
          content: Text('Rebooting now to apply backend changes.'),
        ),
      );

      await Process.run('sudo', ['reboot', 'now']);
    } catch (e) {
      if (mounted) {
        try {
          Navigator.of(context).pop();
        } catch (_) {}
        showDialog(
          context: context,
          builder: (ctx) => GlassAlertDialog(
            title: const Text('Error'),
            content: Text('Failed to switch backend: $e'),
            actions: [
              GlassButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _isLoadingReleases = false;
    super.dispose();
  }

  void _showReleaseDialog() {
    // Reset state before showing dialog
    setState(() {
      _loadError = null;
      if (_availableReleases.isEmpty) {
        _isLoadingReleases = false;
      }
    });

    showDialog(
      barrierDismissible: true,
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            void fetchReleases() async {
              if (_availableReleases.isNotEmpty && _loadError == null) return;

              setState(() {
                _isLoadingReleases = true;
                _loadError = null;
              });

              try {
                final response = await http.get(
                  Uri.parse(
                      'https://api.github.com/repos/Open-Resin-Alliance/Orion/releases'),
                  headers: {'Accept': 'application/vnd.github.v3+json'},
                ).timeout(const Duration(seconds: 10));

                if (response.statusCode == 200) {
                  final List<dynamic> releases = json.decode(response.body);
                  List<String> regularReleases = [];
                  List<String> branchReleases = [];
                  Map<String, String> dates = {};

                  for (var release in releases) {
                    String tag = release['tag_name'] as String;
                    if (tag.startsWith('v')) {
                      tag = tag.substring(1);
                    }

                    String publishedAt = release['published_at'] as String;
                    DateTime releaseDate = DateTime.parse(publishedAt);
                    String formattedDate =
                        "${releaseDate.year}-${releaseDate.month.toString().padLeft(2, '0')}-${releaseDate.day.toString().padLeft(2, '0')}";

                    dates[tag] = formattedDate;

                    if (tag.startsWith('BRANCH_')) {
                      branchReleases.add(tag);
                    } else {
                      regularReleases.add(tag);
                    }
                  }

                  // Sort by date (newest first)
                  regularReleases
                      .sort((a, b) => dates[b]!.compareTo(dates[a]!));
                  branchReleases.sort((a, b) => dates[b]!.compareTo(dates[a]!));

                  setState(() {
                    _availableReleases = [
                      ...regularReleases,
                      ...branchReleases
                    ];
                    _releaseDates = dates;
                    _isLoadingReleases = false;
                  });
                } else {
                  setState(() {
                    _isLoadingReleases = false;
                    _loadError =
                        'Failed to fetch releases: HTTP ${response.statusCode}';
                  });
                }
              } catch (e) {
                setState(() {
                  _isLoadingReleases = false;
                  _loadError = e.toString();
                });
              }
            }

            // Fetch releases when dialog is built
            if (_availableReleases.isEmpty && !_isLoadingReleases) {
              fetchReleases();
            }

            return GlassDialog(
              padding: EdgeInsets.zero,
              child: SizedBox(
                width: MediaQuery.of(context).size.width * 0.9,
                height: MediaQuery.of(context).size.height * 0.8,
                child: Column(
                  children: [
                    // Compact Header Section
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 16),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: Theme.of(context)
                                .dividerColor
                                .withValues(alpha: 0.3),
                            width: 1,
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.download, size: 24),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'Select Release Version',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          if (overrideRelease.isNotEmpty) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Theme.of(context)
                                    .colorScheme
                                    .primaryContainer,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                overrideRelease,
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.primary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                          IconButton(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.close, size: 20),
                            padding: const EdgeInsets.all(4),
                            constraints: const BoxConstraints(
                                minWidth: 32, minHeight: 32),
                            tooltip: 'Close',
                          ),
                        ],
                      ),
                    ),

                    // Content Section
                    Expanded(
                      child: _isLoadingReleases
                          ? const Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  CircularProgressIndicator(),
                                  SizedBox(height: 24),
                                  Text(
                                    'Loading available releases...',
                                    style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w500),
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    'This may take a few seconds',
                                    style: TextStyle(
                                        fontSize: 14, color: Colors.grey),
                                  ),
                                ],
                              ),
                            )
                          : _loadError != null
                              ? Center(
                                  child: Padding(
                                    padding: const EdgeInsets.all(24),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.error_outline,
                                            size: 64, color: Colors.red),
                                        const SizedBox(height: 24),
                                        Text(
                                          'Failed to Load Releases',
                                          style: TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.red.shade300,
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        Text(
                                          _loadError!,
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(fontSize: 16),
                                        ),
                                        const SizedBox(height: 24),
                                        GlassButton(
                                          onPressed: fetchReleases,
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(Icons.refresh,
                                                  size: 20),
                                              const SizedBox(width: 8),
                                              const Text('Retry',
                                                  style:
                                                      TextStyle(fontSize: 18)),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                              : _availableReleases.isEmpty
                                  ? const Center(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.inbox_outlined,
                                              size: 64, color: Colors.grey),
                                          SizedBox(height: 24),
                                          Text(
                                            'No Releases Found',
                                            style: TextStyle(
                                                fontSize: 20,
                                                fontWeight: FontWeight.bold),
                                          ),
                                          SizedBox(height: 8),
                                          Text(
                                            'There are no releases available at this time',
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                                fontSize: 16,
                                                color: Colors.grey),
                                          ),
                                        ],
                                      ),
                                    )
                                  : Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          // Section headers and list
                                          Expanded(
                                            child: _buildReleasesList(),
                                          ),
                                        ],
                                      ),
                                    ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    ).then((_) {
      // Cleanup when dialog is closed
      if (mounted) {
        setState(() {
          _isLoadingReleases = false;
        });
      }
    });
  }

  /// Builds the modernized releases list with compact visual hierarchy
  Widget _buildReleasesList() {
    final regularReleases =
        _availableReleases.where((r) => !r.startsWith('BRANCH_')).toList();
    final branchReleases =
        _availableReleases.where((r) => r.startsWith('BRANCH_')).toList();

    return ListView(
      children: [
        if (regularReleases.isNotEmpty) ...[
          // Compact Stable Releases Section
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.verified, size: 14, color: Colors.green.shade300),
                  const SizedBox(width: 4),
                  Text(
                    'Stable Releases',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.green.shade300,
                    ),
                  ),
                ],
              ),
            ),
          ),
          ...regularReleases
              .map((release) => _buildReleaseItem(release, isStable: true)),
        ],
        if (branchReleases.isNotEmpty && regularReleases.isNotEmpty)
          const SizedBox(height: 16),
        if (branchReleases.isNotEmpty) ...[
          // Compact Development Branches Section
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.science, size: 14, color: Colors.orange.shade300),
                  const SizedBox(width: 4),
                  Text(
                    'Development Branches',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.orange.shade300,
                    ),
                  ),
                ],
              ),
            ),
          ),
          ...branchReleases
              .map((release) => _buildReleaseItem(release, isStable: false)),
        ],
      ],
    );
  }

  /// Builds an individual release item with compact styling
  Widget _buildReleaseItem(String release, {required bool isStable}) {
    final isSelected = overrideRelease == release;
    final releaseDate = _releaseDates[release] ?? 'Unknown date';

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      child: GlassCard(
        elevation: isSelected ? 2.0 : 1.0,
        outlined: true,
        color: isSelected
            ? Theme.of(context)
                .colorScheme
                .primaryContainer
                .withValues(alpha: 0.3)
            : null,
        child: InkWell(
          onTap: () {
            setState(() {
              overrideRelease = release;
              config.setString('overrideRelease', overrideRelease,
                  category: 'developer');
            });
            Navigator.of(context).pop();
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                // Compact Release Icon
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Theme.of(context)
                            .colorScheme
                            .primary
                            .withValues(alpha: 0.2)
                        : (isStable ? Colors.green : Colors.orange)
                            .withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(
                    isSelected
                        ? Icons.check_circle
                        : (isStable ? Icons.verified : Icons.science),
                    color: isSelected
                        ? Theme.of(context).colorScheme.primary
                        : (isStable
                            ? Colors.green.shade300
                            : Colors.orange.shade300),
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),

                // Compact Release Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        release,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: isSelected
                              ? Theme.of(context).colorScheme.primary
                              : null,
                        ),
                      ),
                      Text(
                        releaseDate,
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).textTheme.bodySmall?.color,
                        ),
                      ),
                    ],
                  ),
                ),

                // Compact Selection Indicator
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Theme.of(context).colorScheme.primary
                        : Colors.transparent,
                    border: isSelected
                        ? null
                        : Border.all(color: Theme.of(context).dividerColor),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: isSelected
                      ? const Icon(Icons.check, color: Colors.white, size: 14)
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

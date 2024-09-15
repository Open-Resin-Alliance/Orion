/*
* Orion - General Config Screen
* Copyright (C) 2024 TheContrappostoShop
*
* This program is free software: you can redistribute it and/or modify
* it under the terms of the GNU General Public License as published by
* the Free Software Foundation, either version 3 of the License, or
* (at your option) any later version.
*
* This program is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
* GNU General Public License for more details.
*
* You should have received a copy of the GNU General Public License
* along with this program.  If not, see <http://www.gnu.org/licenses/>.
*/

import 'dart:io';
import 'dart:math';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:orion/settings/settings_screen.dart';
import 'package:provider/provider.dart';

import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'package:orion/util/orion_config.dart';
import 'package:orion/util/orion_kb/orion_keyboard_expander.dart';
import 'package:orion/util/orion_kb/orion_textfield_spawn.dart';
import 'package:orion/util/orion_list_tile.dart';

class GeneralCfgScreen extends StatefulWidget {
  const GeneralCfgScreen({super.key});

  @override
  GeneralCfgScreenState createState() => GeneralCfgScreenState();
}

class GeneralCfgScreenState extends State<GeneralCfgScreen> {
  late ThemeMode themeMode;
  late bool useUsbByDefault;
  late bool overrideScreenRotation;
  late String screenRotation;
  late bool useCustomUrl;
  late String customUrl;
  late bool developerMode;
  late bool releaseOverride;
  late bool overrideUpdateCheck;
  late String overrideRelease;
  late bool verboseLogging;
  late bool selfDestructMode;

  late String originalRotation;

  final ScrollController _scrollController = ScrollController();

  final OrionConfig config = OrionConfig();

  final GlobalKey<SpawnOrionTextFieldState> urlTextFieldKey =
      GlobalKey<SpawnOrionTextFieldState>();

  final GlobalKey<SpawnOrionTextFieldState> branchTextFieldKey =
      GlobalKey<SpawnOrionTextFieldState>();

  @override
  void initState() {
    super.initState();
    final OrionConfig config = OrionConfig();
    themeMode = config.getThemeMode();
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
    overrideRelease =
        config.getString('overrideRelease', category: 'developer');
    verboseLogging = config.getFlag('verboseLogging', category: 'developer');
    selfDestructMode =
        config.getFlag('selfDestructMode', category: 'topsecret');

    screenRotation = screenRotation == '' ? '0' : screenRotation;
    config.setString('screenRotation', screenRotation, category: 'advanced');
    originalRotation = screenRotation;
  }

  bool shouldDestruct() {
    final rand = Random();
    if (selfDestructMode && rand.nextInt(1000) < 2) {
      setState(() {
        selfDestructMode = false;
      });
      return true;
    }
    return !selfDestructMode;
  }

  bool isJune() {
    final now = DateTime.now();
    return now.month == 6;
  }

  @override
  Widget build(BuildContext context) {
    final changeThemeMode = Provider.of<Function>(context);

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
                  child: const Card.outlined(
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
                Card(
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
              Card.outlined(
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
                      OrionListTile(
                        title: 'Dark Mode',
                        icon: PhosphorIcons.moonStars,
                        value: themeMode == ThemeMode.dark,
                        onChanged: (bool value) {
                          setState(() {
                            themeMode =
                                value ? ThemeMode.dark : ThemeMode.light;
                          });
                          changeThemeMode(themeMode);
                        },
                      ),
                      const SizedBox(height: 15.0),
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
              Card.outlined(
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
                        title: 'Use Custom Odyssey URL',
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
                                height: 55,
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(elevation: 3),
                                  onPressed: () {
                                    showDialog(
                                      context: context,
                                      builder: (BuildContext context) {
                                        return AlertDialog(
                                          title: const Center(
                                              child:
                                                  Text('Custom Odyssey URL')),
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
                                                  ),
                                                  OrionKbExpander(
                                                      textFieldKey:
                                                          urlTextFieldKey),
                                                ],
                                              ),
                                            ),
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () {
                                                Navigator.of(context).pop();
                                              },
                                              child: const Text('Close',
                                                  style:
                                                      TextStyle(fontSize: 20)),
                                            ),
                                            TextButton(
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
                                              child: const Text('Confirm',
                                                  style:
                                                      TextStyle(fontSize: 20)),
                                            ),
                                          ],
                                        );
                                      },
                                    );
                                  },
                                  child: AutoSizeText(
                                    customUrl == ''
                                        ? 'Set URL'
                                        : customUrl.split('//').last,
                                    style: const TextStyle(fontSize: 22),
                                    minFontSize: 18,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 20),
                            Expanded(
                              child: SizedBox(
                                height: 55,
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(elevation: 3),
                                  onPressed: customUrl == ''
                                      ? null
                                      : () {
                                          setState(() {
                                            customUrl = '';
                                            config.setString(
                                                'customUrl', customUrl,
                                                category: 'advanced');
                                          });
                                        },
                                  child: const Text(
                                    'Clear URL',
                                    style: TextStyle(fontSize: 22),
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
              if (developerMode)
                Card.outlined(
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
                                  height: 55,
                                  child: ElevatedButton(
                                    style:
                                        ElevatedButton.styleFrom(elevation: 3),
                                    onPressed: () {
                                      showDialog(
                                        context: context,
                                        builder: (BuildContext context) {
                                          return AlertDialog(
                                            title: const Center(
                                                child: Text('Override Branch')),
                                            content: SizedBox(
                                              width: MediaQuery.of(context)
                                                      .size
                                                      .width *
                                                  0.5,
                                              child: SingleChildScrollView(
                                                child: Column(
                                                  children: [
                                                    SpawnOrionTextField(
                                                      key: branchTextFieldKey,
                                                      keyboardHint:
                                                          'Enter Branch',
                                                      locale: Localizations
                                                              .localeOf(context)
                                                          .toString(),
                                                      scrollController:
                                                          _scrollController,
                                                    ),
                                                    OrionKbExpander(
                                                        textFieldKey:
                                                            branchTextFieldKey),
                                                  ],
                                                ),
                                              ),
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed: () {
                                                  Navigator.of(context).pop();
                                                },
                                                child: const Text('Close',
                                                    style: TextStyle(
                                                        fontSize: 20)),
                                              ),
                                              TextButton(
                                                onPressed: () {
                                                  setState(() {
                                                    overrideRelease =
                                                        branchTextFieldKey
                                                            .currentState!
                                                            .getCurrentText();
                                                    config.setString(
                                                        'overrideRelease',
                                                        overrideRelease,
                                                        category: 'developer');
                                                  });
                                                  Navigator.of(context).pop();
                                                },
                                                child: const Text('Confirm',
                                                    style: TextStyle(
                                                        fontSize: 20)),
                                              ),
                                            ],
                                          );
                                        },
                                      );
                                    },
                                    child: AutoSizeText(
                                      overrideRelease == ''
                                          ? 'Set Release Tag'
                                          : overrideRelease,
                                      style: const TextStyle(fontSize: 22),
                                      minFontSize: 18,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 20),
                              Expanded(
                                child: SizedBox(
                                  height: 55,
                                  child: ElevatedButton(
                                    style:
                                        ElevatedButton.styleFrom(elevation: 3),
                                    onPressed: overrideRelease == ''
                                        ? null
                                        : () {
                                            setState(() {
                                              overrideRelease = '';
                                              config.setString(
                                                  'overrideRelease',
                                                  overrideRelease,
                                                  category: 'developer');
                                            });
                                          },
                                    child: const AutoSizeText(
                                      'Clear Release Tag',
                                      style: TextStyle(fontSize: 22),
                                      minFontSize: 22,
                                      maxLines: 1,
                                      overflowReplacement: Text(
                                        'Clear Tag',
                                        style: TextStyle(fontSize: 22),
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
                              config.setFlag(
                                  'overrideUpdateCheck', overrideUpdateCheck,
                                  category: 'developer');
                            });
                          },
                        ),
                        /*const SizedBox(height: 20.0),
                      OrionListTile(
                        title: 'Verbose Logging [WIP]',
                        icon: PhosphorIcons.bug,
                        value: verboseLogging,
                        onChanged: (bool value) {
                          null;
                          setState(() {
                            verboseLogging = value;
                            config.setFlag('verboseLogging', developerMode,
                                category: 'developer');
                          });
                        },
                      ),*/
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
}

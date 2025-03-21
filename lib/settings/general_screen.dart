/*
* Orion - General Config Screen
* Copyright (C) 2024 Open Resin Alliance
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

import 'dart:io';
import 'dart:math';
import 'dart:convert';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:orion/settings/settings_screen.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;

import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'package:orion/util/orion_config.dart';
import 'package:orion/util/orion_kb/orion_keyboard_expander.dart';
import 'package:orion/util/orion_kb/orion_textfield_spawn.dart';
import 'package:orion/util/orion_list_tile.dart';
import 'package:orion/util/theme_color_selector.dart';

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
  late String machineName;

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

  // Class-level variables for API request handling
  bool _fetchCancelled = false;
  DateTime? _lastFetchAttempt;

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
    machineName = config.getString('machineName', category: 'machine');
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
    // Cast the provider function to the correct type
    final void Function(ThemeMode) changeThemeMode =
        Provider.of<Function>(context) as void Function(ThemeMode);

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
              ), // Add comma here
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
                                      _showReleaseDialog();
                                    },
                                    child: AutoSizeText(
                                      overrideRelease == ''
                                          ? 'Select Release Tag'
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
                      ],
                    ),
                  ),
                ),
              if (!config.getFlag('mandateTheme', category: 'vendor'))
                Card.outlined(
                  elevation: 1,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Theme Color',
                          style: TextStyle(
                            fontSize: 28.0,
                          ),
                        ),
                        const SizedBox(height: 20.0),
                        ThemeColorSelector(
                          config: config,
                          changeThemeMode: changeThemeMode,
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

  @override
  void dispose() {
    _isLoadingReleases = false;
    _fetchCancelled = true;
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

            return Dialog(
              child: Container(
                width: MediaQuery.of(context).size.width * 0.95,
                height: MediaQuery.of(context).size.height * 0.85,
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Center(
                      child: Text(
                        'Select Release Version',
                        style: TextStyle(
                          fontSize: 24,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (_isLoadingReleases)
                      const Expanded(
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircularProgressIndicator(),
                              SizedBox(height: 16),
                              Text(
                                'Loading available releases...',
                                style: TextStyle(fontSize: 18),
                              ),
                            ],
                          ),
                        ),
                      )
                    else if (_loadError != null)
                      Expanded(
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.error_outline,
                                  size: 48, color: Colors.red),
                              const SizedBox(height: 16),
                              Text(
                                _loadError!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 18),
                              ),
                              const SizedBox(height: 24),
                              ElevatedButton(
                                onPressed: fetchReleases,
                                child: const Text('Retry',
                                    style: TextStyle(fontSize: 18)),
                              ),
                            ],
                          ),
                        ),
                      )
                    else if (_availableReleases.isEmpty)
                      const Expanded(
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.info_outline, size: 48),
                              SizedBox(height: 16),
                              Text(
                                'No releases found',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 18),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      Expanded(
                        child: ListView.builder(
                          itemCount: _availableReleases.length + 1,
                          itemBuilder: (context, index) {
                            final regularReleasesCount = _availableReleases
                                .where((r) => !r.startsWith('BRANCH_'))
                                .length;

                            if (index == regularReleasesCount) {
                              return const Padding(
                                padding: EdgeInsets.symmetric(vertical: 8.0),
                                child: Column(
                                  children: [
                                    Divider(thickness: 2),
                                  ],
                                ),
                              );
                            }

                            final adjustedIndex = index > regularReleasesCount
                                ? index - 1
                                : index;
                            final release = _availableReleases[adjustedIndex];

                            return Card(
                              elevation: 1.0,
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              color: overrideRelease == release
                                  ? Theme.of(context)
                                      .colorScheme
                                      .primaryContainer
                                  : null,
                              child: ListTile(
                                contentPadding: const EdgeInsets.all(10),
                                title: Text(
                                  release,
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: overrideRelease == release
                                        ? Theme.of(context).colorScheme.primary
                                        : null,
                                  ),
                                ),
                                subtitle: Text(
                                  "Released: ${_releaseDates[release] ?? 'Unknown date'}",
                                  style: const TextStyle(
                                    fontSize: 16,
                                  ),
                                ),
                                onTap: () {
                                  this.setState(() {
                                    overrideRelease = release;
                                    config.setString(
                                        'overrideRelease', overrideRelease,
                                        category: 'developer');
                                  });
                                  Navigator.of(context).pop();
                                },
                              ),
                            );
                          },
                        ),
                      ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                          },
                          child: const Text(
                            'Close',
                            style: TextStyle(fontSize: 18),
                          ),
                        ),
                        const SizedBox(width: 16),
                        ElevatedButton(
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (BuildContext context) {
                                return AlertDialog(
                                  title: const Center(
                                    child: Text('Manual Entry'),
                                  ),
                                  content: SizedBox(
                                    width:
                                        MediaQuery.of(context).size.width * 0.5,
                                    child: SingleChildScrollView(
                                      child: Column(
                                        children: [
                                          SpawnOrionTextField(
                                            key: branchTextFieldKey,
                                            keyboardHint: 'Enter Release Tag',
                                            locale:
                                                Localizations.localeOf(context)
                                                    .toString(),
                                            scrollController: _scrollController,
                                            presetText: config.getString(
                                                'overrideRelease',
                                                category: 'developer'),
                                          ),
                                          OrionKbExpander(
                                              textFieldKey: branchTextFieldKey),
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
                                          style: TextStyle(fontSize: 20)),
                                    ),
                                    TextButton(
                                      onPressed: () {
                                        this.setState(() {
                                          overrideRelease = branchTextFieldKey
                                              .currentState!
                                              .getCurrentText();
                                          config.setString('overrideRelease',
                                              overrideRelease,
                                              category: 'developer');
                                        });
                                        // Close both dialogs
                                        Navigator.of(context)
                                            .pop(); // Close manual entry dialog
                                        Navigator.of(context)
                                            .pop(); // Close release selection dialog
                                      },
                                      child: const Text('Confirm',
                                          style: TextStyle(fontSize: 20)),
                                    ),
                                  ],
                                );
                              },
                            );
                          },
                          child: const Text(
                            'Manual Entry',
                            style: TextStyle(fontSize: 18),
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
      },
    ).then((_) {
      // Cleanup when dialog is closed
      if (mounted) {
        setState(() {
          _isLoadingReleases = false;
          _fetchCancelled = true;
        });
      }
    });
  }
}

/*
* Orion - Settings Screen
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

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:logging/logging.dart';
import 'package:orion/util/orion_config.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';
import 'package:path/path.dart' as path;

import 'package:about/about.dart';

import 'package:orion/pubspec.dart';
import 'package:orion/settings/about_screen.dart';
import 'package:orion/settings/debug_screen.dart';
import 'package:orion/settings/general_screen.dart';
import 'package:orion/settings/update_screen.dart';
import 'package:orion/settings/wifi_screen.dart';
import 'package:orion/util/markdown_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  SettingsScreenState createState() => SettingsScreenState();
}

class SettingsScreenState extends State<SettingsScreen> {
  int _selectedIndex = 0;
  OrionConfig config = OrionConfig();
  Logger logger = Logger('Settings');
  late bool needsRestart;
  final GlobalKey<WifiScreenState> _wifiScreenKey =
      GlobalKey<WifiScreenState>();
  final ValueNotifier<bool> isConnected = ValueNotifier(false);
  late Future<void> _wifiScreenFuture;
  bool _isLinuxPlatform = false;

  @override
  void initState() {
    super.initState();
    needsRestart = config.getFlag('needsRestart', category: 'internal');
    _wifiScreenFuture = _initializeWifiScreen();
  }

  Future<void> _initializeWifiScreen() async {
    final bool initialConnectionStatus = await _checkInitialConnectionStatus();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        isConnected.value = initialConnectionStatus;
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _isLinuxPlatform = Theme.of(context).platform == TargetPlatform.linux;
    if (_isLinuxPlatform) {
      _checkInitialConnectionStatus();
    }
  }

  Future<bool> _checkInitialConnectionStatus() async {
    if (!_isLinuxPlatform) return false;
    try {
      // Get the default gateway IP address
      final result = await Process.run('ip', ['route', 'show', 'default']);
      if (result.exitCode != 0) {
        logger.severe('Failed to get default gateway: ${result.stderr}');
        return false;
      }

      // Extract the gateway IP address from the command output
      final gateway =
          RegExp(r'default via (\S+)').firstMatch(result.stdout)?.group(1);
      if (gateway == null) {
        logger.severe('No default gateway found');
        return false;
      }

      // Ping the gateway
      final pingResult = await Process.run('ping', ['-c', '1', gateway]);
      return pingResult.exitCode == 0;
    } catch (e) {
      logger.severe('Failed to check initial connection status: $e');
      return false;
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  void launchConfirmationDialog(bool closeSettings) async {
    if (!needsRestart || !Platform.isLinux) return;
    bool shouldRestart = await showDialog(
      barrierDismissible: false,
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Finalize Settings'),
          content: const Text(
              'The Touch Interface needs to restart to apply changes.\nDo you want to restart now or later?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(false);
                if (closeSettings) Navigator.of(context).pop();
              },
              child: const Text('Later', style: TextStyle(fontSize: 20)),
            ),
            const SizedBox(width: 20),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(true);
              },
              child: const Text('Now', style: TextStyle(fontSize: 20)),
            ),
          ],
        );
      },
    );

    if (shouldRestart) {
      logger.info('Restarting Orion');
      config.setFlag('needsRestart', false, category: 'internal');
      setState(() {
        needsRestart = false;
      });
      restartOrion();
    }
  }

  Future<void> launchDisconnectDialog() async {
    bool shouldDisconnect = await showDialog(
      barrierDismissible: false,
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Disconnect from WiFi'),
          content: const Text(
              'Do you want to disconnect from the current WiFi network?\nThis may cause any ongoing print jobs to fail.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(false);
              },
              child:
                  const Text('Stay Connected', style: TextStyle(fontSize: 20)),
            ),
            const SizedBox(width: 20),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(true);
              },
              child: const Text('Disconnect', style: TextStyle(fontSize: 20)),
            ),
          ],
        );
      },
    );

    if (shouldDisconnect) {
      await _wifiScreenKey.currentState?.disconnect();
    }
  }

  void restartOrion() async {
    try {
      final String screenRotation =
          config.getString('screenRotation', category: 'advanced');
      final String baseUser = Platform.environment['BASE_USER'] ?? 'pi';

      // Load the bash script from assets
      final String bashScript =
          await rootBundle.loadString('assets/scripts/set_orion_config.sh');

      // Create a temporary directory
      final Directory tempDir = await Directory.systemTemp.createTemp();
      final String scriptPath = path.join(tempDir.path, 'set_orion_config.sh');

      // Write the bash script to the temporary file
      final File scriptFile = File(scriptPath);
      await scriptFile.writeAsString(bashScript);

      // Make the script executable
      await Process.run('chmod', ['+x', scriptPath]);

      // Execute the script with sudo
      final result =
          await Process.run('sudo', [scriptPath, screenRotation, baseUser]);

      if (result.exitCode != 0) {
        logger.severe('Failed to restart Orion: ${result.stderr}');
      } else {
        logger.info('Orion restarted successfully');
      }

      // Clean up the temporary file
      await scriptFile.delete();
    } catch (e) {
      logger.severe('Failed to restart Orion: $e');
    }
  }

  bool getRestartStatus() {
    if (!Platform.isLinux) return false;
    needsRestart = config.getFlag('needsRestart', category: 'internal');
    return needsRestart;
  }

  void setRestartStatus(bool status) {
    setState(() {
      needsRestart = status;
    });
  }

  @override
  Widget build(BuildContext context) {
    final changeThemeMode =
        Provider.of<Function>(context) as void Function(ThemeMode);

    return PopScope(
      canPop: !getRestartStatus(),
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (didPop) {
          return;
        }
        launchConfirmationDialog(true);
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Settings'),
          actions: <Widget>[
            Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: _selectedIndex == 2
                  ? IconButton(
                      icon: PhosphorIcon(PhosphorIcons.info(), size: 40),
                      iconSize: 40,
                      onPressed: () {
                        showAboutPage(
                          context: context,
                          values: {
                            'version': Pubspec.version,
                            'buildNumber': Pubspec.versionBuild.toString(),
                            'commit': Pubspec.versionFull
                                        .toString()
                                        .split('+')[1] ==
                                    'SELFCOMPILED'
                                ? 'Local Build'
                                : 'Commit ${Pubspec.versionFull.toString().split('+')[1]}',
                            'year': DateTime.now().year.toString(),
                          },
                          applicationVersion:
                              'Version {{ version }} - {{ commit }}',
                          applicationName: 'Orion',
                          applicationLegalese:
                              'Apache License 2.0 - Copyright © TheContrappostoShop {{ year }}',
                          children: <Widget>[
                            Padding(
                              padding:
                                  const EdgeInsets.only(left: 10, right: 10),
                              child: Card(
                                child: ListTile(
                                  leading: const Icon(Icons.list, size: 30),
                                  title: const Text('Changelog',
                                      style: _commonTextStyle),
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            const MarkdownScreen(
                                                filename: 'CHANGELOG.md'),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                            const Padding(
                              padding: EdgeInsets.all(10),
                              child: Card(
                                child: LicensesPageListTile(
                                  title: Text('Open-Source Licenses',
                                      style: _commonTextStyle),
                                  icon: Icon(Icons.favorite, size: 30),
                                ),
                              ),
                            ),
                          ],
                          applicationIcon: const FlutterLogo(size: 100),
                        );
                      },
                    )
                  : _selectedIndex == 1
                      ? ValueListenableBuilder<bool>(
                          valueListenable: isConnected,
                          builder: (context, value, child) {
                            return value
                                ? IconButton(
                                    onPressed: () {
                                      launchDisconnectDialog();
                                    },
                                    icon: PhosphorIcon(PhosphorIcons.xCircle(),
                                        size: 40),
                                  )
                                : const SizedBox.shrink();
                          },
                        )
                      : const SizedBox.shrink(),
            ),
          ],
        ),
        body: _selectedIndex == 0
            ? const GeneralCfgScreen()
            : _selectedIndex == 1
                ? FutureBuilder<void>(
                    future: _wifiScreenFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      } else {
                        return WifiScreen(
                          key: _wifiScreenKey,
                          isConnected: isConnected,
                        );
                      }
                    },
                  )
                : _selectedIndex == 2
                    ? const AboutScreen()
                    : _selectedIndex == 3
                        ? const UpdateScreen()
                        : DebugScreen(changeThemeMode: changeThemeMode),
        bottomNavigationBar: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          items: <BottomNavigationBarItem>[
            const BottomNavigationBarItem(
              icon: Icon(Icons.settings),
              label: 'General',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.network_wifi),
              label: 'WiFi',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.info),
              label: 'About',
            ),
            const BottomNavigationBarItem(
                icon: Icon(Icons.update), label: 'Updates'),
            if (config.getFlag('developerMode', category: 'advanced'))
              const BottomNavigationBarItem(
                icon: Icon(Icons.bug_report),
                label: 'Debug',
              ),
          ],
          currentIndex: _selectedIndex,
          selectedItemColor: Theme.of(context).colorScheme.primary,
          onTap: _onItemTapped,
          unselectedItemColor: Theme.of(context).colorScheme.secondary,
        ),
      ),
    );
  }
}

const TextStyle _commonTextStyle = TextStyle(fontSize: 24);

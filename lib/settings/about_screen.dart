/*
* Orion - About Screen
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

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:toastification/toastification.dart';

import 'package:orion/glasser/glasser.dart';
import 'package:orion/pubspec.dart';
import 'package:orion/themes/themes.dart';
import 'package:orion/util/orion_config.dart';
import 'package:orion/util/orion_kb/orion_keyboard_expander.dart';
import 'package:orion/util/orion_kb/orion_textfield_spawn.dart';

Logger _logger = Logger('AboutScreen');
OrionConfig config = OrionConfig();

Future<String> executeCommand(String command, List<String> arguments) async {
  final result = await Process.run(command, arguments);
  if (result.exitCode == 0) {
    return result.stdout.trim();
  } else {
    throw Exception(
        'Failed to execute command: $command ${arguments.join(" ")}\nError: ${result.stderr}');
  }
}

Future<String> getDeviceModel() async {
  if (!Platform.isLinux) {
    switch (Platform.operatingSystem) {
      case 'macos':
        return 'macOS Device';
      case 'android':
        return 'Android Device';
      case 'ios':
        return 'iOS Device';
      case 'windows':
        return 'Windows Device';
      default:
        return 'Unsupported Device';
    }
  }
  try {
    final model = await executeCommand('cat', ['/proc/device-tree/model']);
    return model.trim();
  } catch (e) {
    _logger.warning('Error getting Raspberry Pi model: $e');
    return 'Unknown Model';
  }
}

// TODO: Implement Odyssey version fetching, awaiting API
Future<String> getVersionNumber() async {
  return 'Orion ${Pubspec.version}' ' - Odyssey 1.0.0';
}

class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  AboutScreenState createState() => AboutScreenState();
}

class AboutScreenState extends State<AboutScreen> {
  int qrTapCount = 0;
  Toastification toastification = Toastification();

  late String customName;

  final ScrollController _scrollController = ScrollController();
  final GlobalKey<SpawnOrionTextFieldState> cNameTextFieldKey =
      GlobalKey<SpawnOrionTextFieldState>();

  @override
  Widget build(BuildContext context) {
    bool isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.only(left: 16.0, right: 16.0),
            child: isLandscape
                ? buildLandscapeLayout(context)
                : buildPortraitLayout(context),
          ),
        ),
      ),
    );
  }

  Widget buildPortraitLayout(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        buildNameCard(config.getString('machineName', category: 'machine')),
        buildInfoCard(
          'Serial Number',
          kDebugMode
              ? 'DBG-0001-001'
              : config.getString('machineSerial', category: 'machine'),
        ),
        buildVersionCard(),
        buildHardwareCard(),
        const SizedBox(height: 16),
        buildQrView(context),
      ],
    );
  }

  Widget buildLandscapeLayout(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              buildNameCard(
                  config.getString('machineName', category: 'machine')),
              buildInfoCard(
                'Serial Number',
                kDebugMode
                    ? 'DBG-0001-001'
                    : config.getString('machineSerial', category: 'machine'),
              ),
              buildVersionCard(),
              buildHardwareCard(),
            ],
          ),
        ),
        const SizedBox(width: 16),
        buildQrView(context),
      ],
    );
  }

  Widget buildInfoCard(String title, String subtitle) {
    return GlassCard(
      elevation: 1.0,
      outlined: true,
      child: ListTile(
        title: Text(title),
        subtitle: Text(subtitle),
      ),
    );
  }

  Widget buildVersionCard() {
    return GlassCard(
      elevation: 1.0,
      outlined: true,
      child: ListTile(
        title: const Text('UI & API Version'),
        subtitle: FutureBuilder<String>(
          future: getVersionNumber(),
          builder: (BuildContext context, AsyncSnapshot<String> snapshot) {
            return Text(snapshot.data ?? 'N/A');
          },
        ),
      ),
    );
  }

  Widget buildHardwareCard() {
    return GlassCard(
      elevation: 1.0,
      outlined: true,
      child: ListTile(
        title: const Text('Hardware (Local)'),
        subtitle: FutureBuilder<String>(
          future: getDeviceModel(),
          builder: (BuildContext context, AsyncSnapshot<String> snapshot) {
            // Sanitize the model string to remove non-printable characters before logging and displaying
            final sanitizedModel =
                snapshot.data?.replaceAll(RegExp(r'[^\x20-\x7E]'), '') ?? 'N/A';
            _logger.info('Device Model: $sanitizedModel');
            return Text(sanitizedModel);
          },
        ),
      ),
    );
  }

  Widget buildNameCard(String title) {
    return GlassCard(
      elevation: 1.0,
      outlined: true,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16.0),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary),
                overflow: TextOverflow.fade,
                softWrap: false,
              ),
            ),
            GlassButton(
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                minimumSize: const Size(90, 50), // Same width as Edit button
              ),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (BuildContext context) {
                    return GlassAlertDialog(
                      title: const Center(child: Text('Custom Machine Name')),
                      content: SizedBox(
                        width: MediaQuery.of(context).size.width * 0.5,
                        child: SingleChildScrollView(
                          child: Column(
                            children: [
                              SpawnOrionTextField(
                                key: cNameTextFieldKey,
                                keyboardHint: 'Enter a custom name',
                                locale:
                                    Localizations.localeOf(context).toString(),
                                scrollController: _scrollController,
                                presetText: config.getString('machineName',
                                    category: 'machine'),
                              ),
                              OrionKbExpander(textFieldKey: cNameTextFieldKey),
                            ],
                          ),
                        ),
                      ),
                      actions: [
                        GlassButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                          },
                          style: ElevatedButton.styleFrom(
                              minimumSize: const Size(0, 60)),
                          child: const Text('Close',
                              style: TextStyle(fontSize: 20)),
                        ),
                        GlassButton(
                          onPressed: () {
                            setState(() {
                              customName = cNameTextFieldKey.currentState!
                                  .getCurrentText();
                              config.setString('machineName', customName,
                                  category: 'machine');
                            });
                            Navigator.of(context).pop();
                          },
                          style: ElevatedButton.styleFrom(
                              minimumSize: const Size(0, 60)),
                          child: const Text('Confirm',
                              style: TextStyle(fontSize: 20)),
                        ),
                      ],
                    );
                  },
                );
              },
              child: Row(
                children: [
                  const Text(
                    'Edit',
                    style: TextStyle(
                      fontSize: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  PhosphorIcon(PhosphorIcons.notePencil()),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildQrView(BuildContext context) {
    return Center(
      child: GestureDetector(
        onTap: handleQrTap,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: GlassCard(
            elevation: 1.0,
            outlined: true,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: QrImageView(
                data: 'https://github.com/TheContrappostoShop/Orion',
                version: QrVersions.auto,
                size: 250,
                eyeStyle: QrEyeStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                dataModuleStyle: QrDataModuleStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  dataModuleShape: QrDataModuleShape.circle,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void handleQrTap() {
    setState(() {
      if (OrionConfig().getFlag('developerMode', category: 'advanced')) {
        toastification.show(
          context: context,
          type: ToastificationType.success,
          style: ToastificationStyle.fillColored,
          autoCloseDuration: const Duration(seconds: 2),
          title: const Text('You are already a developer',
              style: TextStyle(fontSize: 18)),
          alignment: Alignment.topCenter,
          primaryColor: Colors.green,
          backgroundColor:
              Theme.of(context).colorScheme.surface.withBrightness(1.35),
          foregroundColor: Theme.of(context).colorScheme.onSurface,
        );
      } else {
        qrTapCount++;
        if (qrTapCount >= 5) {
          OrionConfig().setFlag('developerMode', true, category: 'advanced');
          toastification.show(
            context: context,
            type: ToastificationType.success,
            style: ToastificationStyle.fillColored,
            autoCloseDuration: const Duration(seconds: 2),
            title: const Text(
                'Developer Mode Activated: You are now a developer!',
                style: TextStyle(fontSize: 18)),
            alignment: Alignment.topCenter,
            primaryColor: Colors.green,
            backgroundColor:
                Theme.of(context).colorScheme.surface.withBrightness(1.35),
            foregroundColor: Theme.of(context).colorScheme.onSurface,
          );
        } else {
          toastification.show(
            context: context,
            type: ToastificationType.info,
            style: ToastificationStyle.fillColored,
            autoCloseDuration: const Duration(seconds: 2),
            title: Text(
                'You are ${5 - qrTapCount} ${5 - qrTapCount == 1 ? 'tap' : 'taps'} away from becoming a developer',
                style: const TextStyle(fontSize: 18)),
            alignment: Alignment.topCenter,
            primaryColor: Theme.of(context).colorScheme.primary,
            backgroundColor:
                Theme.of(context).colorScheme.surface.withBrightness(1.35),
            foregroundColor: Theme.of(context).colorScheme.onSurface,
            showProgressBar: false,
          );
        }
      }
    });
  }
}

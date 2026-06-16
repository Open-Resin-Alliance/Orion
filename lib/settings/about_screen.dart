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

import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_i18n/flutter_i18n.dart';
import 'package:logging/logging.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:toastification/toastification.dart';

import 'package:orion/glasser/glasser.dart';
import 'package:orion/pubspec.dart';
import 'package:orion/themes/themes.dart';
import 'package:orion/util/orion_config.dart';
import 'package:orion/util/orion_spacing.dart';
import 'package:orion/util/orion_kb/orion_keyboard_expander.dart';
import 'package:orion/util/orion_kb/orion_textfield_spawn.dart';
import 'package:orion/backend_service/backend_service.dart';
import 'package:orion/settings/about_dialog.dart';
import 'package:orion/util/markdown_screen.dart';
import 'package:orion/settings/fancy_license_screen.dart';

Logger _logger = Logger('AboutScreen');
OrionConfig config = OrionConfig();
BackendService backend = BackendService();

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
      // These are top-level function return values without context.
      // They will be translated at the call site.
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

Future<String> getVersionNumber() async {
  try {
    final backendVersion = await backend.getBackendVersion();
    return 'Orion ${Pubspec.version} - $backendVersion';
  } catch (e) {
    _logger.warning('Failed to get backend version: $e');
    return 'Orion ${Pubspec.version} - N/A';
  }
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
            padding: EdgeInsets.only(
              left: OrionSpacing.settingsScreenPaddingTightTop.left,
              right: OrionSpacing.settingsScreenPaddingTightTop.right,
              top: OrionSpacing.settingsScreenPaddingTightTop.top,
              bottom: OrionSpacing.screenBottomNavClearance,
            ),
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
          FlutterI18n.translate(context, 'about.serialNumber'),
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final totalWidth = constraints.maxWidth;
        final qrColumnWidth = (totalWidth - 16) * 2 / 5;
        final qrSize = (qrColumnWidth - 32).clamp(80.0, 400.0);
        final columnHeight = qrSize + 32;

        final leftCards = [
          buildNameCard(config.getString('machineName', category: 'machine')),
          buildInfoCard(
            FlutterI18n.translate(context, 'about.serialNumber'),
            kDebugMode
                ? 'DBG-0001-001'
                : config.getString('machineSerial', category: 'machine'),
          ),
          buildVersionCard(),
          buildHardwareCard(),
        ];

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: SizedBox(
                height: columnHeight,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (int i = 0; i < leftCards.length; i++) ...[
                      Expanded(child: leftCards[i]),
                      if (i < leftCards.length - 1) const SizedBox(height: 0),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 2,
              child: buildQrView(context),
            ),
          ],
        );
      },
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
      child: InkWell(
        onTap: () {
          showOrionAboutDialog(
            context: context,
            applicationName: 'Orion',
            applicationVersion: FlutterI18n.translate(
                context, 'about.versionInfo',
                translationParams: {
                  '0': Pubspec.version,
                  '1': Pubspec.versionFull.toString().split('+')[1] ==
                          'SELFCOMPILED'
                      ? FlutterI18n.translate(context, 'about.localBuild')
                      : FlutterI18n.translate(context, 'about.commit',
                          translationParams: {
                              '0': Pubspec.versionFull.toString().split('+')[1]
                            }),
                }),
            applicationLegalese: FlutterI18n.translate(
                context, 'about.copyright',
                translationParams: {'0': DateTime.now().year.toString()}),
            applicationIcon: Image.asset(
              'assets/images/ora/open_resin_alliance_logo_darkmode.png',
              width: 100,
              height: 100,
              fit: BoxFit.contain,
            ),
            children: <Widget>[
              Padding(
                padding: EdgeInsets.only(
                    left: OrionSpacing.settingsScreenHorizontal,
                    right: OrionSpacing.settingsScreenHorizontal),
                child: GlassCard(
                  child: ListTile(
                    leading: const Icon(Icons.list, size: 30),
                    title:
                        Text(FlutterI18n.translate(context, 'about.changelog')),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              const MarkdownScreen(filename: 'CHANGELOG.md'),
                        ),
                      );
                    },
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(10),
                child: GlassCard(
                  child: ListTile(
                    title:
                        Text(FlutterI18n.translate(context, 'about.licenses')),
                    leading: const Icon(Icons.favorite, size: 30),
                    onTap: () {
                      showFancyLicensePage(
                        context: context,
                        applicationName: 'Orion',
                        applicationVersion: Pubspec.version,
                      );
                    },
                  ),
                ),
              ),
            ],
          );
        },
        child: ListTile(
          title: Text.rich(
            TextSpan(
              style: Theme.of(context).textTheme.titleMedium,
              children: [
                TextSpan(
                    text: FlutterI18n.translate(context, 'about.uiVersion')),
                const TextSpan(text: '  '),
                TextSpan(
                  text: FlutterI18n.translate(context, 'about.tapForInfo'),
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          subtitle: FutureBuilder<String>(
            future: getVersionNumber(),
            builder: (BuildContext context, AsyncSnapshot<String> snapshot) {
              return AutoSizeText(
                snapshot.data ?? FlutterI18n.translate(context, 'about.na'),
                maxLines: 1,
                minFontSize: 12,
              );
            },
          ),
        ),
      ),
    );
  }

  Widget buildHardwareCard() {
    return GlassCard(
      elevation: 1.0,
      outlined: true,
      child: ListTile(
        title: Text(FlutterI18n.translate(context, 'about.hardwareLocal')),
        subtitle: FutureBuilder<String>(
          future: getDeviceModel(),
          builder: (BuildContext context, AsyncSnapshot<String> snapshot) {
            // Sanitize the model string to remove non-printable characters before logging and displaying
            final rawModel = snapshot.data ?? '';
            // Map known English platform identifiers to translation keys
            final deviceModelMap = {
              'macOS Device': 'about.deviceMacos',
              'Android Device': 'about.deviceAndroid',
              'iOS Device': 'about.deviceIos',
              'Windows Device': 'about.deviceWindows',
              'Unsupported Device': 'about.deviceUnsupported',
              'Unknown Model': 'about.unknownModel',
            };
            final sanitizedModel =
                rawModel.replaceAll(RegExp(r'[^\x20-\x7E]'), '');
            final displayModel = deviceModelMap.containsKey(sanitizedModel)
                ? FlutterI18n.translate(
                    context, deviceModelMap[sanitizedModel]!)
                : sanitizedModel;
            _logger.info('Device Model: $sanitizedModel');
            return Text(displayModel);
          },
        ),
      ),
    );
  }

  Widget buildNameCard(String title) {
    return GlassCard(
      elevation: 1.0,
      outlined: true,
      child: Align(
        alignment: Alignment.centerLeft,
        child: Padding(
          padding: EdgeInsets.only(
              left: OrionSpacing.settingsScreenHorizontal,
              right: OrionSpacing.settingsScreenHorizontal,
              top: 8.0,
              bottom: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
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
              if (config.enableCustomName()) ...[
                GlassButton(
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    minimumSize:
                        const Size(90, 50), // Same width as Edit button
                  ),
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (BuildContext context) {
                        return GlassAlertDialog(
                          title: Center(
                              child: Text(FlutterI18n.translate(
                                  context, 'about.customName'))),
                          content: SizedBox(
                            width: MediaQuery.of(context).size.width * 0.5,
                            child: SingleChildScrollView(
                              child: Column(
                                children: [
                                  SpawnOrionTextField(
                                    key: cNameTextFieldKey,
                                    keyboardHint: FlutterI18n.translate(
                                        context, 'about.enterName'),
                                    locale: Localizations.localeOf(context)
                                        .toString(),
                                    scrollController: _scrollController,
                                    presetText: config.getString('machineName',
                                        category: 'machine'),
                                  ),
                                  OrionKbExpander(
                                      textFieldKey: cNameTextFieldKey),
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
                              child: Text(
                                  FlutterI18n.translate(
                                      context, 'common.close'),
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
                              child: Text(
                                  FlutterI18n.translate(
                                      context, 'common.confirm'),
                                  style: TextStyle(fontSize: 20)),
                            ),
                          ],
                        );
                      },
                    );
                  },
                  child: Row(
                    children: [
                      Text(
                        FlutterI18n.translate(context, 'common.edit'),
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
            ],
          ),
        ),
      ),
    );
  }

  Widget buildQrView(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final qrSize = (constraints.maxWidth - 32).clamp(80.0, 400.0);
        return GestureDetector(
          onTap: handleQrTap,
          child: GlassCard(
            elevation: 1.0,
            outlined: true,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: AspectRatio(
                aspectRatio: 1,
                child: QrImageView(
                  data: 'https://github.com/Open-Resin-Alliance/Orion',
                  version: QrVersions.auto,
                  size: qrSize,
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
        );
      },
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
          title: Text(FlutterI18n.translate(context, 'about.alreadyDeveloper'),
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
            title: Text(
                FlutterI18n.translate(context, 'about.developerActivated'),
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
                FlutterI18n.translate(context, 'about.tapsAway',
                    translationParams: {'0': (5 - qrTapCount).toString()}),
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

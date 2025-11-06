/*
* Orion - Home Screen
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
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:orion/backend_service/providers/manual_provider.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';
import 'package:orion/glasser/glasser.dart';
import 'package:orion/l10n/generated/app_localizations.dart';
import 'package:orion/util/hold_button.dart';
import 'package:orion/util/orion_config.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  HomeScreenState createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> {
  final OrionConfig _config = OrionConfig();
  bool isRemote = false;

  @override
  Widget build(BuildContext context) {
    Size homeBtnSize = const Size(double.infinity, double.infinity);
    final l10n = AppLocalizations.of(context)!;

    final theme = Theme.of(context).copyWith(
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ButtonStyle(
          shape: WidgetStateProperty.resolveWith<OutlinedBorder?>(
            (Set<WidgetState> states) {
              return RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              );
            },
          ),
          minimumSize: WidgetStateProperty.resolveWith<Size?>(
            (Set<WidgetState> states) {
              return homeBtnSize;
            },
          ),
        ),
      ),
    );

    return GlassApp(
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            _config.getString('machineName', category: 'machine'),
            textAlign: TextAlign.center,
          ),
          centerTitle: true,
          leadingWidth: 120,
          leading: const Center(
            child: Padding(
              padding: EdgeInsets.only(left: 15),
              child: LiveClock(),
            ),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 25),
              child: InkWell(
                onTap: () {
                  isRemote =
                      _config.getFlag('useCustomUrl', category: 'advanced');
                  showDialog(
                    context: context,
                    builder: (BuildContext context) {
                      return GlassDialog(
                        padding: const EdgeInsets.all(8), // Reduced padding
                        child: SizedBox(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              const SizedBox(height: 10),
                              Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Text(
                                  '${l10n.homePowerOptions} ${isRemote ? l10n.homePowerRemote : l10n.homePowerLocal}',
                                  style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                              const SizedBox(height: 10),
                              Padding(
                                padding:
                                    const EdgeInsets.only(left: 20, right: 20),
                                child: SizedBox(
                                  height: 65,
                                  width: 450,
                                  child: HoldButton(
                                    onPressed: () {
                                      Navigator.pop(context);
                                      // Use ManualProvider instead of direct ApiService
                                      try {
                                        final manual =
                                            Provider.of<ManualProvider>(context,
                                                listen: false);
                                        manual
                                            .manualCommand('FIRMWARE_RESTART');
                                      } catch (_) {
                                        // If provider isn't available, ignore
                                      }
                                    },
                                    child: Text(
                                      l10n.homeFirmwareRestart,
                                      style: const TextStyle(fontSize: 24),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(
                                  height:
                                      20), // Add some spacing between the buttons
                              if (!isRemote)
                                Padding(
                                  padding: const EdgeInsets.only(
                                      left: 20, right: 20),
                                  child: SizedBox(
                                    height: 65,
                                    width: 450,
                                    child: HoldButton(
                                      onPressed: () {
                                        Process.run('sudo', ['reboot', 'now']);
                                      },
                                      child: Text(
                                        l10n.homeRebootSystem,
                                        style: const TextStyle(fontSize: 24),
                                      ),
                                    ),
                                  ),
                                ),
                              if (!isRemote) const SizedBox(height: 20),
                              if (!isRemote)
                                Padding(
                                  padding: const EdgeInsets.only(
                                      left: 20, right: 20),
                                  child: SizedBox(
                                    height: 65,
                                    width: 450,
                                    child: HoldButton(
                                      onPressed: () {
                                        Process.run(
                                            'sudo', ['shutdown', 'now']);
                                      },
                                      child: Text(
                                        l10n.homeShutdownSystem,
                                        style: const TextStyle(fontSize: 24),
                                      ),
                                    ),
                                  ),
                                ),
                              if (!isRemote) const SizedBox(height: 20),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
                child: PhosphorIcon(PhosphorIcons.power(), size: 42),
              ),
            ),
          ],
        ),
        body: Center(
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  const SizedBox(height: 5),
                  Expanded(
                    child: Row(
                      children: [
                        const SizedBox(width: 20),
                        Expanded(
                          child: GlassButton(
                            style: theme.elevatedButtonTheme.style,
                            onPressed: () => context.go('/gridfiles'),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                PhosphorIcon(PhosphorIcons.printer(), size: 52),
                                Text(
                                  l10n.homeBtnPrint,
                                  style: const TextStyle(fontSize: 28),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 20),
                        if (_config.enableResinProfiles()) ...[
                          Expanded(
                            child: GlassButton(
                              style: theme.elevatedButtonTheme.style,
                              onPressed: () => context.go('/materials'),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  PhosphorIcon(PhosphorIcons.flask(), size: 52),
                                  Text(
                                    'Materials',
                                    style: const TextStyle(fontSize: 28),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 20),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: Row(
                      children: [
                        const SizedBox(width: 20),
                        Expanded(
                          child: GlassButton(
                            style: theme.elevatedButtonTheme.style,
                            onPressed: () => context.go('/tools'),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                PhosphorIcon(PhosphorIcons.toolbox(), size: 52),
                                Text(
                                  l10n.homeBtnTools,
                                  style: const TextStyle(fontSize: 28),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: GlassButton(
                            style: theme.elevatedButtonTheme.style,
                            onPressed: () => context.go('/settings'),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                PhosphorIcon(PhosphorIcons.gear(), size: 52),
                                Text(
                                  l10n.homeBtnSettings,
                                  style: const TextStyle(fontSize: 28),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 20),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// A live clock widget
class LiveClock extends StatefulWidget {
  const LiveClock({super.key});

  @override
  LiveClockState createState() => LiveClockState();
}

class LiveClockState extends State<LiveClock> {
  late Timer _timer;
  late DateTime _dateTime;

  @override
  void initState() {
    super.initState();
    _dateTime = DateTime.now();
    _timer = Timer.periodic(const Duration(seconds: 1), (Timer timer) {
      setState(() {
        _dateTime = DateTime.now();
      });
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Text(
        '${_dateTime.hour.toString().padLeft(2, '0')}:${_dateTime.minute.toString().padLeft(2, '0')}',
        style: const TextStyle(fontSize: 28));
  }
}

/*
* Orion - Home Screen
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
import 'package:go_router/go_router.dart';
import 'package:orion/api_services/api_services.dart';
import 'package:orion/settings/about_screen.dart';
import 'package:orion/util/hold_button.dart';
import 'package:orion/util/orion_config.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  HomeScreenState createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> {
  final ApiService _api = ApiService();
  final OrionConfig _config = OrionConfig();
  bool isRemote = false;

  @override
  Widget build(BuildContext context) {
    Size homeBtnSize = const Size(double.infinity, double.infinity);

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

    return Scaffold(
      appBar: AppBar(
        title: Text(
          config.getString('machineName', category: 'machine'),
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
                    return Dialog(
                      child: SizedBox(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            const SizedBox(height: 10),
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Text(
                                'Power Options ${isRemote ? '(Remote)' : '(Local)'}',
                                style: const TextStyle(
                                    fontSize: 24, fontWeight: FontWeight.bold),
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
                                    _api.manualCommand('FIRMWARE_RESTART');
                                  },
                                  child: const Text(
                                    'Firmware Restart',
                                    style: TextStyle(fontSize: 24),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(
                                height:
                                    20), // Add some spacing between the buttons
                            if (!isRemote)
                              Padding(
                                padding:
                                    const EdgeInsets.only(left: 20, right: 20),
                                child: SizedBox(
                                  height: 65,
                                  width: 450,
                                  child: HoldButton(
                                    onPressed: () {
                                      Process.run('sudo', ['reboot', 'now']);
                                    },
                                    child: const Text(
                                      'Reboot System',
                                      style: TextStyle(fontSize: 24),
                                    ),
                                  ),
                                ),
                              ),
                            if (!isRemote) const SizedBox(height: 20),
                            if (!isRemote)
                              Padding(
                                padding:
                                    const EdgeInsets.only(left: 20, right: 20),
                                child: SizedBox(
                                  height: 65,
                                  width: 450,
                                  child: HoldButton(
                                    onPressed: () {
                                      Process.run('sudo', ['shutdown', 'now']);
                                    },
                                    child: const Text(
                                      'Shutdown System',
                                      style: TextStyle(fontSize: 24),
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
              child: const Icon(Icons.power_settings_new_outlined, size: 38),
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
                        child: ElevatedButton(
                          style: theme.elevatedButtonTheme.style,
                          onPressed: () => context.go('/gridfiles'),
                          child: const Column(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.print_outlined, size: 52),
                              Text('Print', style: TextStyle(fontSize: 28)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 20),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: Row(
                    children: [
                      const SizedBox(width: 20),
                      Expanded(
                        child: ElevatedButton(
                          style: theme.elevatedButtonTheme.style,
                          onPressed: () => context.go('/tools'),
                          child: const Column(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.handyman_outlined, size: 52),
                              Text('Tools', style: TextStyle(fontSize: 28)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: ElevatedButton(
                          style: theme.elevatedButtonTheme.style,
                          onPressed: () => context.go('/settings'),
                          child: const Column(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.settings_outlined, size: 52),
                              Text('Settings', style: TextStyle(fontSize: 28)),
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

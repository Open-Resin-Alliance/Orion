/*
* Orion - Move Z Screen
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

import 'package:auto_size_text/auto_size_text.dart';
import 'package:logging/logging.dart';

import 'package:provider/provider.dart';
import 'package:orion/backend_service/providers/config_provider.dart';
import 'package:orion/backend_service/providers/manual_provider.dart';
import 'package:orion/backend_service/providers/status_provider.dart';
import 'package:orion/glasser/glasser.dart';
import 'package:orion/util/error_handling/error_dialog.dart';

class MoveZScreen extends StatefulWidget {
  const MoveZScreen({super.key});

  @override
  MoveZScreenState createState() => MoveZScreenState();
}

class MoveZScreenState extends State<MoveZScreen> {
  final _logger = Logger('MoveZScreen');
  // Use ConfigProvider for config data; ManualProvider for actions

  double maxZ = 0.0;
  double step = 0.1;
  double currentZ = 0.0;

  bool _apiErrorState = false;
  Map<String, dynamic>? status;

  Future<void> moveZ(double distance) async {
    try {
      _logger.info('Moving Z by $distance');
      final statusProvider =
          Provider.of<StatusProvider>(context, listen: false);
      final curZ = statusProvider.status?.physicalState.z ?? this.currentZ;

      final newZ = (curZ + distance).clamp(0.0, maxZ).toDouble();
      final manual = Provider.of<ManualProvider>(context, listen: false);
      final ok = await manual.move(newZ);
      if (!ok) {
        setState(() {
          _apiErrorState = true;
        });
        if (mounted) showErrorDialog(context, 'Failed to move Z');
      }
    } catch (e) {
      _logger.severe('Failed to move Z: $e');
      setState(() {
        _apiErrorState = true;
      });
      if (mounted) showErrorDialog(context, 'Failed to move Z');
    }
  }

  void getMaxZ() async {
    try {
      final provider = Provider.of<ConfigProvider>(context, listen: false);
      if (provider.config != null) {
        setState(() {
          maxZ = provider.config?.machine?['printer']?['max_z'] ?? maxZ;
        });
      } else {
        await provider.refresh();
        if (provider.config != null) {
          setState(() {
            maxZ = provider.config?.machine?['printer']?['max_z'] ?? maxZ;
          });
        }
      }
    } catch (e) {
      setState(() {
        _apiErrorState = true;
      });
      if (mounted) showErrorDialog(context, 'BLUE-BANANA');
      _logger.severe('Failed to get max Z: $e');
    }
  }

  @override
  void initState() {
    super.initState();
    getMaxZ();
  }

  @override
  Widget build(BuildContext context) {
    bool isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: isLandscape
            ? buildLandscapeLayout(context)
            : buildPortraitLayout(context),
      ),
    );
  }

  Widget buildLandscapeLayout(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: <Widget>[
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Expanded(child: buildMoveButtons(context)),
                    const SizedBox(width: 30),
                    Expanded(child: buildChoiceCards(context)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 30),
        Expanded(child: buildControlButtons(context)),
      ],
    );
  }

  Widget buildPortraitLayout(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: <Widget>[
        Expanded(
          child: Row(
            children: [
              Expanded(child: buildMoveButtons(context)),
              const SizedBox(width: 32),
              Expanded(child: buildControlButtons(context)),
            ],
          ),
        ),
        const SizedBox(height: 32),
        Expanded(child: buildChoiceCards(context)),
      ],
    );
  }

  Widget buildChoiceCards(BuildContext context) {
    final values = [0.1, 1.0, 10.0, 50.0];
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: List.generate(values.length, (index) {
        final value = values[index];
        return Flexible(
          child: Padding(
            padding: EdgeInsets.only(
                bottom: index < values.length - 1
                    ? 25.0
                    : 0.0), // Add padding only if it's not the last item
            child: GlassChoiceChip(
              label: SizedBox(
                width: double.infinity,
                child: Text(
                  '$value mm',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 22),
                ),
              ),
              selected: step == value,
              onSelected: _apiErrorState
                  ? null
                  : (selected) {
                      if (selected) {
                        setState(() {
                          step = value;
                        });
                      }
                    },
            ),
          ),
        );
      }),
    );
  }

  Widget buildMoveButtons(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        Expanded(
          child: GlassButton(
            onPressed: _apiErrorState ? null : () => moveZ(step),
            style: ElevatedButton.styleFrom(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15)),
              minimumSize: const Size(double.infinity, double.infinity),
            ),
            child: const Icon(Icons.arrow_upward, size: 50),
          ),
        ),
        const SizedBox(height: 30),
        Expanded(
          child: GlassButton(
            onPressed: _apiErrorState ? null : () => moveZ(-step),
            style: ElevatedButton.styleFrom(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15)),
              minimumSize: const Size(double.infinity, double.infinity),
            ),
            child: const Icon(Icons.arrow_downward, size: 50),
          ),
        ),
      ],
    );
  }

  Widget buildControlButtons(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: <Widget>[
        Expanded(
          child: Consumer<ManualProvider>(
            builder: (context, manual, _) {
              return GlassButton(
                onPressed: _apiErrorState || manual.busy
                    ? null
                    : () async {
                        _logger.info('Moving to ZMAX');
                        final ok = await manual.move(maxZ);
                        if (!ok && mounted)
                          showErrorDialog(context, 'Failed to move to top');
                      },
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15)),
                  minimumSize: const Size(double.infinity, double.infinity),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(width: 16),
                    const Icon(Icons.arrow_upward, size: 30),
                    const Expanded(
                      child: AutoSizeText(
                        'Move to Top Limit',
                        style: TextStyle(fontSize: 24),
                        minFontSize: 20,
                        maxLines: 1,
                        overflowReplacement: Padding(
                          padding: EdgeInsets.only(right: 20.0),
                          child: Center(
                            child: Text(
                              'Top',
                              style: TextStyle(fontSize: 24),
                            ),
                          ),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 25),
        Expanded(
          child: Consumer<ManualProvider>(
            builder: (context, manual, _) {
              return GlassButton(
                onPressed: _apiErrorState || manual.busy
                    ? null
                    : () async {
                        _logger.info('Moving to ZMIN');
                        final ok = await manual.manualHome();
                        if (!ok && mounted)
                          showErrorDialog(context, 'Failed to home');
                      },
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15)),
                  minimumSize: const Size(double.infinity, double.infinity),
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 16),
                    const Icon(Icons.home, size: 30),
                    const Expanded(
                      child: AutoSizeText(
                        'Return to Home',
                        style: TextStyle(fontSize: 24),
                        minFontSize: 20,
                        maxLines: 1,
                        overflowReplacement: Padding(
                          padding: EdgeInsets.only(right: 20.0),
                          child: Center(
                            child: Text(
                              'Home',
                              style: TextStyle(fontSize: 24),
                            ),
                          ),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 25),
        Expanded(
          child: Consumer<ManualProvider>(
            builder: (context, manual, _) {
              return GlassButton(
                onPressed: _apiErrorState || manual.busy
                    ? null
                    : () async {
                        _logger.severe('EMERGENCY STOP');
                        final ok = await manual.manualCommand('M112');
                        if (!ok && mounted)
                          showErrorDialog(context, 'Failed emergency stop');
                      },
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15)),
                  minimumSize: const Size(double.infinity, double.infinity),
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 16),
                    Icon(Icons.stop,
                        size: 30,
                        color: _apiErrorState
                            ? null
                            : Theme.of(context).colorScheme.onErrorContainer),
                    Expanded(
                      child: AutoSizeText(
                        'Emergency Stop',
                        style: TextStyle(
                          fontSize: 24,
                          color: _apiErrorState
                              ? null
                              : Theme.of(context).colorScheme.onErrorContainer,
                        ),
                        maxLines: 1,
                        minFontSize: 20,
                        overflowReplacement: Padding(
                          padding: EdgeInsets.only(right: 20.0),
                          child: Center(
                            child: Text(
                              'Stop',
                              style: TextStyle(
                                fontSize: 24,
                                color: _apiErrorState
                                    ? null
                                    : Theme.of(context)
                                        .colorScheme
                                        .onErrorContainer,
                              ),
                            ),
                          ),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

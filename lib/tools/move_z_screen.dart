/*
* Orion - Move Z Screen
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

import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:logging/logging.dart';

import 'package:orion/api_services/api_services.dart';
import 'package:orion/util/error_handling/error_dialog.dart';

class MoveZScreen extends StatefulWidget {
  const MoveZScreen({super.key});

  @override
  MoveZScreenState createState() => MoveZScreenState();
}

class MoveZScreenState extends State<MoveZScreen> {
  final _logger = Logger('MoveZScreen');
  final ApiService _api = ApiService();

  double maxZ = 0.0;
  double step = 0.1;
  double currentZ = 0.0;

  bool _apiErrorState = false;
  Map<String, dynamic>? status;

  Future<void> moveZ(double distance) async {
    try {
      _logger.info('Moving Z by $distance');
      final status = await _api.getStatus();
      final currentZ = status['physical_state']['z'];

      final newZ = (currentZ + distance).clamp(0, maxZ);
      await _api.move(newZ);
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
      Map<String, dynamic> config = await _api.getConfig();
      setState(() {
        maxZ = config['printer']['max_z'];
      });
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
            child: ChoiceChip.elevated(
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
              return const Size(double.infinity, double.infinity);
            },
          ),
        ),
      ),
    );

    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        Expanded(
          child: ElevatedButton(
            onPressed: _apiErrorState ? null : () => moveZ(step),
            style: theme.elevatedButtonTheme.style,
            child: const Icon(Icons.arrow_upward, size: 50),
          ),
        ),
        const SizedBox(height: 30),
        Expanded(
          child: ElevatedButton(
            onPressed: _apiErrorState ? null : () => moveZ(-step),
            style: theme.elevatedButtonTheme.style,
            child: const Icon(Icons.arrow_downward, size: 50),
          ),
        ),
      ],
    );
  }

  Widget buildControlButtons(BuildContext context) {
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
              return const Size(double.infinity, double.infinity);
            },
          ),
        ),
      ),
    );

    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: <Widget>[
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _apiErrorState
                ? null
                : () async {
                    _logger.info('Moving to ZMAX');

                    _api.move(maxZ);
                  },
            style: theme.elevatedButtonTheme.style,
            icon: const Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: EdgeInsets.only(left: 20),
                child: Icon(Icons.arrow_upward, size: 30),
              ),
            ),
            label: const Center(
              child: Padding(
                padding: EdgeInsets.only(right: 20),
                child: AutoSizeText(
                  'Move to Top Limit',
                  style: TextStyle(fontSize: 24),
                  minFontSize: 24,
                  maxLines: 1,
                  overflowReplacement: Text(
                    'Top',
                    style: TextStyle(fontSize: 24),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 25),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _apiErrorState
                ? null
                : () {
                    _logger.info('Moving to ZMIN');
                    _api.manualHome();
                  },
            style: theme.elevatedButtonTheme.style,
            icon: const Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: EdgeInsets.only(left: 20),
                child: Icon(Icons.home, size: 30),
              ),
            ),
            label: const Center(
              child: Padding(
                padding: EdgeInsets.only(right: 20),
                child: AutoSizeText(
                  'Return to Home',
                  style: TextStyle(fontSize: 24),
                  minFontSize: 24,
                  maxLines: 1,
                  overflowReplacement: Text(
                    'Home',
                    style: TextStyle(fontSize: 24),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 25),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _apiErrorState
                ? null
                : () {
                    _logger.severe('EMERGENCY STOP');
                    _api.manualCommand('M112');
                  },
            style: theme.elevatedButtonTheme.style,
            icon: Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(left: 20),
                child: Icon(Icons.stop,
                    size: 30,
                    color: _apiErrorState
                        ? null
                        : Theme.of(context).colorScheme.onErrorContainer),
              ),
            ),
            label: Center(
              child: Padding(
                padding: const EdgeInsets.only(right: 20),
                child: AutoSizeText(
                  'Emergency Stop',
                  style: TextStyle(
                    fontSize: 24,
                    color: _apiErrorState
                        ? null
                        : Theme.of(context).colorScheme.onErrorContainer,
                  ),
                  maxLines: 1,
                  minFontSize: 24,
                  overflowReplacement: Text('Stop',
                      style: TextStyle(
                        fontSize: 24,
                        color: _apiErrorState
                            ? null
                            : Theme.of(context).colorScheme.onErrorContainer,
                      )),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

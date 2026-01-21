/*
* Orion - Exposure Screen
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

import 'package:async/async.dart';
import 'package:flutter/material.dart';
import 'package:logging/logging.dart';

import 'package:orion/backend_service/providers/manual_provider.dart';
import 'package:orion/util/orion_config.dart';
import 'package:provider/provider.dart';
import 'package:orion/tools/exposure_util.dart' as exposure_util;
import 'package:orion/backend_service/providers/config_provider.dart';
import 'package:orion/glasser/glasser.dart';
import 'package:orion/util/error_handling/error_dialog.dart';

import 'package:phosphor_flutter/phosphor_flutter.dart';

class ExposureScreen extends StatefulWidget {
  const ExposureScreen({super.key});

  @override
  ExposureScreenState createState() => ExposureScreenState();
}

class ExposureScreenState extends State<ExposureScreen> {
  final _logger = Logger('Exposure');
  final _config = OrionConfig();
  CancelableOperation? _exposureOperation;
  Completer<void>? _exposureCompleter;

  int exposureTime = 3;
  bool _apiErrorState = false;

  Future<void> exposeScreen(String type) async {
    final manual = Provider.of<ManualProvider>(context, listen: false);
    await exposure_util.exposeScreen(context, manual, type, exposureTime);
  }



  @override
  void initState() {
    super.initState();
    // Defer to after first frame to avoid provider notifications during build.
    WidgetsBinding.instance.addPostFrameCallback((_) => getApiStatus());
  }

  Future<void> getApiStatus() async {
    try {
      final provider = Provider.of<ConfigProvider>(context, listen: false);
      if (provider.config == null) {
        try {
          await provider.refresh();
        } catch (e) {
          setState(() {
            _apiErrorState = true;
          });
          if (mounted) showErrorDialog(context, 'BLUE-BANANA');
          _logger.severe('Failed to refresh config: $e');
        }
      }
    } catch (e) {
      setState(() {
        _apiErrorState = true;
      });
      if (mounted) showErrorDialog(context, 'BLUE-BANANA');
      _logger.severe('Failed to get config: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;
    return Scaffold(
      backgroundColor: Colors.transparent,
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
      children: [
        Expanded(
          child: buildExposureButtons(context),
        ),
        const SizedBox(width: 32),
        Expanded(
          child: buildChoiceCards(context),
        ),
      ],
    );
  }

  Widget buildPortraitLayout(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: buildExposureButtons(context),
        ),
        const SizedBox(height: 32),
        Expanded(
          child: buildChoiceCards(context),
        ),
      ],
    );
  }

  Widget buildExposureButtons(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        Expanded(
          child: Column(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: GlassButton(
                        onPressed:
                            _apiErrorState ? null : () => exposeScreen('Grid'),
                        style: ElevatedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                          minimumSize:
                              const Size(double.infinity, double.infinity),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            PhosphorIcon(
                              PhosphorIconsFill.checkerboard,
                              size: 40,
                              color: _apiErrorState ? Colors.grey : null,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Grid',
                              style: TextStyle(
                                fontSize: 24,
                                color: _apiErrorState ? Colors.grey : null,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 30),
                    Expanded(
                      child: GlassButton(
                        onPressed:
                            _apiErrorState ? null : () => exposeScreen('Logo'),
                        style: ElevatedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                          minimumSize:
                              const Size(double.infinity, double.infinity),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            PhosphorIcon(
                              PhosphorIcons.linuxLogo(),
                              size: 40,
                              color: _apiErrorState ? Colors.grey : null,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Logo',
                              style: TextStyle(
                                fontSize: 24,
                                color: _apiErrorState ? Colors.grey : null,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 30),
        Expanded(
          child: Row(
            children: [
              Expanded(
                child: GlassButton(
                  onPressed:
                      _apiErrorState ? null : () => exposeScreen('Measure'),
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    minimumSize: const Size(double.infinity, double.infinity),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      PhosphorIcon(
                        PhosphorIcons.ruler(),
                        size: 40,
                        color: _apiErrorState ? Colors.grey : null,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Measure',
                        style: TextStyle(
                          fontSize: 24,
                          color: _apiErrorState ? Colors.grey : null,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 30),
              Expanded(
                child: GlassButton(
                  onPressed:
                      _apiErrorState ? null : () => exposeScreen('White'),
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    minimumSize: const Size(double.infinity, double.infinity),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      PhosphorIcon(
                        PhosphorIcons.broom(),
                        size: 40,
                        color: _apiErrorState ? Colors.grey : null,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Clean',
                        style: TextStyle(
                          fontSize: 24,
                          color: _apiErrorState ? Colors.grey : null,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget buildChoiceCards(BuildContext context) {
    final values = [3, 10, 30, 'Persistent'];
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
                  value is int ? '$value Seconds' : value as String,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 22, // Adjust the font size here.
                  ),
                ),
              ),
              selected: exposureTime ==
                  (value is int
                      ? value
                      : (value == 'Persistent'
                          ? 999999
                          : int.parse(value as String))),
              onSelected: _apiErrorState
                  ? null
                  : (selected) {
                      if (selected) {
                        setState(() {
                          exposureTime = value is int
                              ? value
                              : (value == 'Persistent'
                                  ? 999999
                                  : int.parse(value as String));
                        });
                      }
                    },
            ),
          ),
        );
      }),
    );
  }
}

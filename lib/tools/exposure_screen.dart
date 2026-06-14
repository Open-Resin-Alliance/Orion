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
import 'package:flutter_i18n/flutter_i18n.dart';
import 'package:logging/logging.dart';

import 'package:orion/backend_service/backend_registry.dart';
import 'package:orion/backend_service/backend_service.dart';
import 'package:orion/backend_service/providers/manual_provider.dart';
import 'package:provider/provider.dart';
import 'package:orion/backend_service/providers/config_provider.dart';
import 'package:orion/glasser/glasser.dart';
import 'package:orion/util/error_handling/error_dialog.dart';
import 'package:orion/util/orion_spacing.dart';

import 'package:phosphor_flutter/phosphor_flutter.dart';

class ExposureScreen extends StatefulWidget {
  const ExposureScreen({super.key});

  @override
  ExposureScreenState createState() => ExposureScreenState();
}

class ExposureScreenState extends State<ExposureScreen> {
  final _logger = Logger('Exposure');
  final BackendService _backendService = BackendService();
  CancelableOperation? _exposureOperation;
  Completer<void>? _exposureCompleter;

  int exposureTime = 3;
  bool _apiErrorState = false;

  Future<void> exposeScreen(String type) async {
    int delayTime = 1; // Odyssey requires a 1 second delay before exposure

    final supportsCalibration = _backendService
        .supportsCapability(BackendCapabilities.supportsCalibration);
    if (supportsCalibration) {
      delayTime = 0;
    }

    try {
      _logger.info('Testing exposure for $exposureTime seconds');
      final manual = Provider.of<ManualProvider>(context, listen: false);
      final nav = Navigator.of(context);

      final okDisplay = await manual.displayTest(type);
      if (!okDisplay) {
        setState(() {
          _apiErrorState = true;
        });
        if (mounted)
          showErrorDialog(
              context, FlutterI18n.translate(context, 'exposure.failedStart'));
        return;
      }

      final okCure = await manual.manualCure(true);
      if (!okCure) {
        setState(() {
          _apiErrorState = true;
        });
        if (mounted)
          showErrorDialog(
              context, FlutterI18n.translate(context, 'exposure.failedCure'));
        return;
      }

      final navCtx = nav.context;
      if (!navCtx.mounted) return;
      showExposureDialog(navCtx, exposureTime, delayTime, type: type);
      _exposureCompleter = Completer<void>();
      _exposureOperation = CancelableOperation.fromFuture(
        Future.any([
          Future.delayed(Duration(seconds: exposureTime)),
          _exposureCompleter!.future,
        ]).then((_) async {
          try {
            await manual.manualCure(false);
          } catch (e) {
            _logger.warning('Failed to disable cure after exposure: $e');
          }
        }),
      );
    } catch (e) {
      setState(() {
        _apiErrorState = true;
        showErrorDialog(context, 'BLUE-BANANA');
      });
      _logger.severe('Failed to test exposure: $e');
    }
  }

  void showExposureDialog(
      BuildContext context, int countdownTime, int delayTime,
      {String? type}) {
    _logger.info('Showing countdown dialog');

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return StreamBuilder<int>(
          stream: (() async* {
            await Future.delayed(Duration(seconds: delayTime));
            yield* Stream.periodic(const Duration(milliseconds: 1),
                    (i) => countdownTime * 1000 - i)
                .take((countdownTime * 1000) + 1);
          })(),
          initialData:
              countdownTime * 1000, // Provide an initial countdown value
          builder: (context, snapshot) {
            if (snapshot.data == 0) {
              Future.delayed(Duration.zero, () {
                // ignore: use_build_context_synchronously
                Navigator.of(context, rootNavigator: true).pop(true);
              });
              return Container(); // Return an empty container when the countdown is over
            } else {
              return SafeArea(
                child: _buildExposureDialog(
                    context, snapshot, countdownTime, type),
              );
            }
          },
        );
      },
    );
  }

  String _translateExposureType(BuildContext context, String type) {
    switch (type) {
      case 'Grid':
        return FlutterI18n.translate(context, 'exposure.grid');
      case 'Logo':
        return FlutterI18n.translate(context, 'exposure.logo');
      case 'Measure':
        return FlutterI18n.translate(context, 'exposure.measure');
      default:
        return type;
    }
  }

  GlassDialog _buildExposureDialog(BuildContext context,
      AsyncSnapshot<int> snapshot, int countdownTime, String? type) {
    return GlassDialog(
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: 20.0), // Padding inside the dialog
        child: Column(
          mainAxisSize:
              MainAxisSize.min, // To make the dialog as big as its children
          children: [
            Text(
              type == 'White'
                  ? FlutterI18n.translate(context, 'exposure.cleaning')
                  : type != null
                      ? '${FlutterI18n.translate(context, 'exposure.testing')} ${_translateExposureType(context, type)}'
                      : FlutterI18n.translate(context, 'exposure.exposing'),
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                fontFamily: 'AtkinsonHyperlegible',
              ),
            ),
            const SizedBox(
                height:
                    20), // Space between the title and the progress indicator
            Padding(
              padding: const EdgeInsets.only(
                  left: 20.0, right: 20.0, top: 15.0, bottom: 20.0),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    height: 180, // Make the progress indicator larger
                    width: 180, // Make the progress indicator larger
                    child: CircularProgressIndicator(
                      backgroundColor: Colors.grey.shade800,
                      value: snapshot.data! / (countdownTime * 1000),
                      strokeWidth: 12, // Make the progress indicator thicker
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(10.0),
                    child: (snapshot.data! / 1000) < 999
                        ? Text(
                            (snapshot.data! / 1000).toStringAsFixed(0),
                            style: const TextStyle(fontSize: 50),
                          )
                        : Text(
                            FlutterI18n.translate(context, 'exposure.testing_'),
                            style: TextStyle(fontSize: 30),
                          ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            GlassButton(
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(250, 70),
                maximumSize: const Size(250, 70),
              ),
              onPressed: () {
                try {
                  _exposureOperation?.cancel();
                  _exposureCompleter?.complete();
                } catch (e) {
                  _logger.severe('Failed to stop exposure: $e');
                }
                Navigator.of(context, rootNavigator: true).pop(true);
              },
              child: Text(
                FlutterI18n.translate(context, 'exposure.stop'),
                style: const TextStyle(fontSize: 24),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    // Defer to after first frame to avoid provider notifications during build.
    WidgetsBinding.instance.addPostFrameCallback((_) => getApiStatus());
  }

  @override
  void dispose() {
    _backendService.dispose();
    super.dispose();
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
        padding: OrionSpacing.screenPaddingWithBottomNav,
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
        const SizedBox(width: OrionSpacing.controlGap),
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
        const SizedBox(height: OrionSpacing.controlGap),
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
                              FlutterI18n.translate(context, 'exposure.grid'),
                              style: TextStyle(
                                fontSize: 24,
                                color: _apiErrorState ? Colors.grey : null,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: OrionSpacing.controlGap),
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
                              FlutterI18n.translate(context, 'exposure.logo'),
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
        const SizedBox(height: OrionSpacing.controlGap),
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
                        FlutterI18n.translate(context, 'exposure.measure'),
                        style: TextStyle(
                          fontSize: 24,
                          color: _apiErrorState ? Colors.grey : null,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: OrionSpacing.controlGap),
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
                        FlutterI18n.translate(context, 'exposure.clean'),
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
    final values = [3, 10, 30, 'persistent'];
    return Column(
      children: [
        for (int index = 0; index < values.length; index++) ...[
          Expanded(
            child: Builder(builder: (context) {
              final value = values[index];
              return GlassChoiceChip(
                label: SizedBox(
                  width: double.infinity,
                  child: Text(
                    value is int
                        ? '${value} ${FlutterI18n.translate(context, 'exposure.unitSec')}'
                        : (value == 'persistent'
                            ? FlutterI18n.translate(
                                context, 'exposure.persistent')
                            : value as String),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 22,
                    ),
                  ),
                ),
                selected: exposureTime ==
                    (value is int
                        ? value
                        : (value == 'persistent'
                            ? 999999
                            : int.parse(value as String))),
                onSelected: _apiErrorState
                    ? null
                    : (selected) {
                        if (selected) {
                          setState(() {
                            exposureTime = value is int
                                ? value
                                : (value == 'persistent'
                                    ? 999999
                                    : int.parse(value as String));
                          });
                        }
                      },
              );
            }),
          ),
          if (index < values.length - 1)
            const SizedBox(height: OrionSpacing.controlGap),
        ],
      ],
    );
  }
}

/*
* Orion - Exposure Screen
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
import 'package:async/async.dart';
import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:orion/api_services/api_services.dart';
import 'package:orion/util/error_handling/error_dialog.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

class ExposureScreen extends StatefulWidget {
  const ExposureScreen({super.key});

  @override
  ExposureScreenState createState() => ExposureScreenState();
}

class ExposureScreenState extends State<ExposureScreen> {
  final _logger = Logger('Exposure');
  final ApiService _api = ApiService();
  CancelableOperation? _exposureOperation;
  Completer<void>? _exposureCompleter;

  int exposureTime = 3;
  bool _apiErrorState = false;

  void exposeScreen(String type) {
    try {
      _logger.info('Testing exposure for $exposureTime seconds');
      _api.displayTest(type);
      _api.manualCure(true);
      showExposureDialog(context, exposureTime, type: type);
      _exposureCompleter = Completer<void>();
      _exposureOperation = CancelableOperation.fromFuture(
        Future.any([
          Future.delayed(Duration(seconds: exposureTime)),
          _exposureCompleter!.future,
        ]).then((_) {
          _api.manualCure(false);
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

  void showExposureDialog(BuildContext context, int countdownTime,
      {String? type}) {
    _logger.info('Showing countdown dialog');

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return StreamBuilder<int>(
          stream: (() async* {
            await Future.delayed(const Duration(seconds: 1));
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
                child: Dialog(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ), // Rounded corners for the dialog
                  insetPadding:
                      const EdgeInsets.all(20), // Padding around the dialog
                  child: Padding(
                    padding:
                        const EdgeInsets.all(20.0), // Padding inside the dialog
                    child: Column(
                      mainAxisSize: MainAxisSize
                          .min, // To make the dialog as big as its children
                      children: [
                        Text(
                          type == 'White'
                              ? 'Cleaning'
                              : type != null
                                  ? 'Testing $type'
                                  : 'Exposing',
                          style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight
                                  .bold), // Title with larger, bold text
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
                                height:
                                    180, // Make the progress indicator larger
                                width:
                                    180, // Make the progress indicator larger
                                child: CircularProgressIndicator(
                                  value:
                                      snapshot.data! / (countdownTime * 1000),
                                  strokeWidth:
                                      12, // Make the progress indicator thicker
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(10.0),
                                child: (snapshot.data! / 1000) < 999
                                    ? Text(
                                        (snapshot.data! / 1000)
                                            .toStringAsFixed(0),
                                        style: const TextStyle(fontSize: 50),
                                      )
                                    : const Text(
                                        'Testing',
                                        style: TextStyle(fontSize: 30),
                                      ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton(
                          onPressed: () {
                            try {
                              _exposureOperation?.cancel();
                              _exposureCompleter?.complete();
                            } catch (e) {
                              _logger.severe('Failed to stop exposure: $e');
                            }
                            Navigator.of(context, rootNavigator: true)
                                .pop(true);
                          },
                          child: const Padding(
                            padding: EdgeInsets.all(15.0),
                            child: Text(
                              'Stop Exposure',
                              style: TextStyle(fontSize: 24),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }
          },
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();
    getApiStatus();
  }

  Future<void> getApiStatus() async {
    try {
      await _api.getConfig();
    } catch (e) {
      setState(() {
        _apiErrorState = true;
        showErrorDialog(context, 'BLUE-BANANA');
      });
      _logger.severe('Failed to get config: $e');
    }
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
    final theme = Theme.of(context).copyWith(
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ButtonStyle(
          shape: WidgetStateProperty.resolveWith<OutlinedBorder?>(
            (Set<WidgetState> states) {
              return RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                  side: const BorderSide(color: Colors.transparent));
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
          child: Column(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed:
                            _apiErrorState ? null : () => exposeScreen('Grid'),
                        style: theme.elevatedButtonTheme.style,
                        child: const Column(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            PhosphorIcon(
                              PhosphorIconsFill.checkerboard,
                              size: 40,
                            ),
                            SizedBox(
                                height:
                                    8), // Add some space between the icon and the label
                            Text(
                              'Grid',
                              style: TextStyle(
                                fontSize: 24,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 30),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _apiErrorState
                            ? null
                            : () => exposeScreen('Dimensions'),
                        style: theme.elevatedButtonTheme.style,
                        child: const Column(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            PhosphorIcon(
                              PhosphorIconsFill.ruler,
                              size: 40,
                            ),
                            SizedBox(
                                height:
                                    8), // Add some space between the icon and the label
                            Text(
                              'Measure',
                              style: TextStyle(
                                fontSize: 24,
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
                child: ElevatedButton(
                  onPressed:
                      _apiErrorState ? null : () => exposeScreen('Blank'),
                  style: theme.elevatedButtonTheme.style,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      PhosphorIcon(
                        PhosphorIcons.square(),
                        size: 40,
                      ),
                      const SizedBox(
                          height:
                              8), // Add some space between the icon and the label
                      const Text(
                        'Blank',
                        style: TextStyle(
                          fontSize: 24,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 30),
              Expanded(
                child: ElevatedButton(
                  onPressed:
                      _apiErrorState ? null : () => exposeScreen('White'),
                  style: theme.elevatedButtonTheme.style,
                  child: const Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.cleaning_services,
                        size: 40,
                      ),
                      SizedBox(
                          height:
                              8), // Add some space between the icon and the label
                      Text(
                        'Clean',
                        style: TextStyle(
                          fontSize: 24,
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
            child: ChoiceChip.elevated(
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

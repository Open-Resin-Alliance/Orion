/*
* Orion - Exposure Screen
* Copyright (C) 2024 TheContrappostoShop
*
* This program is free software: you can redistribute it and/or modify
* it under the terms of the GNU General Public License as published by
* the Free Software Foundation, either version 3 of the License, or
* (at your option) any later version.
*
* This program is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
* GNU General Public License for more details.
*
* You should have received a copy of the GNU General Public License
* along with this program.  If not, see <http://www.gnu.org/licenses/>.
*/

import 'dart:async';
import 'package:async/async.dart';

import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:orion/api_services/api_services.dart';
import 'package:orion/util/error_handling/error_dialog.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

class ExposureScreen extends StatefulWidget {
  final bool isBusy;
  const ExposureScreen({super.key, this.isBusy = false});

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
        showErrorDialog(context, 'PINK-CARROT');
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
          stream: Stream.periodic(const Duration(milliseconds: 10),
              (i) => countdownTime * 100 - i).take((countdownTime * 100) + 1),
          initialData:
              countdownTime * 100, // Provide an initial countdown value
          builder: (context, snapshot) {
            if (snapshot.data == 0) {
              Future.delayed(Duration.zero, () {
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
                                  value: snapshot.data! / (countdownTime * 100),
                                  strokeWidth:
                                      12, // Make the progress indicator thicker
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(10.0),
                                child: (snapshot.data! / 100) < 99
                                    ? Text(
                                        (snapshot.data! / 100)
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
    if (widget.isBusy) {
      _apiErrorState = true;
    }
    super.initState();
    getApiStatus();
  }

  Future<void> getApiStatus() async {
    try {
      await _api.getConfig();
      if (widget.isBusy) {
        setState(() {
          _apiErrorState = true;
        });
      }
    } catch (e) {
      setState(() {
        _apiErrorState = true;
        showErrorDialog(context, 'PINK-CARROT');
      });
      _logger.severe('Failed to get config: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).copyWith(
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ButtonStyle(
          shape: MaterialStateProperty.resolveWith<OutlinedBorder?>(
            (Set<MaterialState> states) {
              return RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                  side: const BorderSide(color: Colors.transparent));
            },
          ),
          minimumSize: MaterialStateProperty.resolveWith<Size?>(
            (Set<MaterialState> states) {
              return const Size(double.infinity, double.infinity);
            },
          ),
        ),
      ),
    );

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: <Widget>[
            // ...
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Expanded(
                    child: Card.outlined(
                      elevation: 1,
                      child: Column(
                        children: [
                          const Padding(
                            padding: EdgeInsetsDirectional.all(2),
                            child: Text(
                              'Test Patterns',
                              style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight
                                      .bold), // Adjust the style as needed
                            ),
                          ),
                          const Divider(height: 1),
                          Expanded(
                            child: Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: _apiErrorState
                                        ? null
                                        : () => exposeScreen('Grid'),
                                    style: theme.elevatedButtonTheme.style
                                        ?.copyWith(
                                      shape: MaterialStateProperty.resolveWith<
                                          OutlinedBorder?>(
                                        (Set<MaterialState> states) {
                                          return const RoundedRectangleBorder(
                                            borderRadius: BorderRadius.only(
                                              bottomLeft: Radius.circular(15),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                    child: const PhosphorIcon(
                                        PhosphorIconsFill.checkerboard,
                                        size: 40),
                                  ),
                                ),
                                const VerticalDivider(
                                  width: 1,
                                ),
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: _apiErrorState
                                        ? null
                                        : () => exposeScreen('Dimensions'),
                                    style: theme.elevatedButtonTheme.style
                                        ?.copyWith(
                                      shape: MaterialStateProperty.resolveWith<
                                          OutlinedBorder?>(
                                        (Set<MaterialState> states) {
                                          return RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(0));
                                        },
                                      ),
                                    ),
                                    child: const PhosphorIcon(
                                        PhosphorIconsFill.ruler,
                                        size: 40),
                                  ),
                                ),
                                const VerticalDivider(
                                  width: 1,
                                ),
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: _apiErrorState
                                        ? null
                                        : () => exposeScreen('Blank'),
                                    style: theme.elevatedButtonTheme.style
                                        ?.copyWith(
                                      shape: MaterialStateProperty.resolveWith<
                                          OutlinedBorder?>(
                                        (Set<MaterialState> states) {
                                          return const RoundedRectangleBorder(
                                            borderRadius: BorderRadius.only(
                                              bottomRight: Radius.circular(15),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                    child: PhosphorIcon(PhosphorIcons.square(),
                                        size: 40),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: Card.outlined(
                      elevation: 1,
                      child: ElevatedButton(
                        onPressed:
                            _apiErrorState ? null : () => exposeScreen('White'),
                        style: theme.elevatedButtonTheme.style,
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.cleaning_services),
                            SizedBox(width: 10),
                            Text(
                              'Clean Vat',
                              style: TextStyle(
                                fontSize: 26,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // ...
            const SizedBox(width: 30),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  const Text(
                    'Exposure Time',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 5),
                  ...[3, 10, 30, 'Persistent'].expand((value) {
                    return [
                      Flexible(
                        child: ChoiceChip(
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
                      const SizedBox(height: 10),
                    ];
                  }).toList()
                    ..removeLast(),
                ],
              ),
            ),
            const SizedBox(
              height: 10,
            ),
          ],
        ),
      ),
    );
  }
}

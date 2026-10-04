/*
* Orion - Exposure Countdown Dialog
* Copyright (C) 2026 Open Resin Alliance
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

import 'package:flutter/material.dart';
import 'package:flutter_i18n/flutter_i18n.dart';
import 'package:orion/glasser/glasser.dart';

/// The countdown shown while the projector is exposing: title, ring with the
/// seconds remaining, and a Stop button.
///
/// Shared by the Exposure screen and the Tank Clean run so both read the same.
/// Completes when the countdown reaches zero or the operator stops it; [onStop]
/// runs first, for the caller's own teardown.
Future<void> showExposureCountdownDialog(
  BuildContext context, {
  required int countdownSeconds,
  required String title,
  int delaySeconds = 0,
  String? idleLabel,
  String stopLabelKey = 'exposure.stop',
  VoidCallback? onStop,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext context) {
      return StreamBuilder<int>(
        stream: (() async* {
          await Future.delayed(Duration(seconds: delaySeconds));
          yield* Stream.periodic(const Duration(milliseconds: 1),
                  (i) => countdownSeconds * 1000 - i)
              .take((countdownSeconds * 1000) + 1);
        })(),
        initialData: countdownSeconds * 1000,
        builder: (context, snapshot) {
          if (snapshot.data == 0) {
            Future.delayed(Duration.zero, () {
              // ignore: use_build_context_synchronously
              Navigator.of(context, rootNavigator: true).pop();
            });
            // Empty while the route pops.
            return Container();
          }
          return SafeArea(
            child: GlassDialog(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'AtkinsonHyperlegible',
                      ),
                    ),
                    const SizedBox(height: 20),
                    Padding(
                      padding: const EdgeInsets.only(
                          left: 20.0, right: 20.0, top: 15.0, bottom: 20.0),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox(
                            height: 180,
                            width: 180,
                            child: CircularProgressIndicator(
                              backgroundColor: Colors.grey.shade800,
                              value:
                                  snapshot.data! / (countdownSeconds * 1000),
                              strokeWidth: 12,
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
                                    idleLabel ?? '',
                                    style: const TextStyle(fontSize: 30),
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
                        onStop?.call();
                        Navigator.of(context, rootNavigator: true).pop();
                      },
                      child: Text(
                        FlutterI18n.translate(context, stopLabelKey),
                        style: const TextStyle(fontSize: 24),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    },
  );
}

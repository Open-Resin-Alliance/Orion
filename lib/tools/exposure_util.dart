/*
* Orion - Exposure Utility
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
import 'package:logging/logging.dart';
import 'package:orion/backend_service/providers/manual_provider.dart';
import 'package:orion/glasser/glasser.dart';
import 'package:orion/util/orion_config.dart';

final _logger = Logger('ExposureUtil');

Future<void> exposeScreen(
  BuildContext context,
  ManualProvider manual,
  String type,
  int exposureTime,
) async {
  final config = OrionConfig();
  int delayTime = 1; // Odyssey requires a 1 second delay before exposure

  if (config.isNanoDlpMode()) {
    delayTime = 0;
  }

  try {
    _logger.info('Testing exposure for $exposureTime seconds');

    final okDisplay = await manual.displayTest(type);
    if (!okDisplay) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to start display test')),
        );
      }
      return;
    }

    final okCure = await manual.manualCure(true);
    if (!okCure) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to enable cure')),
        );
      }
      return;
    }

    showExposureDialog(context, manual, exposureTime, delayTime, type: type);
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to test exposure: $e')),
      );
    }
    _logger.severe('Failed to test exposure: $e');
  }
}

void showExposureDialog(
  BuildContext context,
  ManualProvider manual,
  int countdownTime,
  int delayTime, {
  String? type,
}) {
  _logger.info('Showing countdown dialog');

  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext context) {
      return StreamBuilder<int>(
        stream: (() async* {
          await Future.delayed(Duration(seconds: delayTime));
          yield* Stream.periodic(
            const Duration(milliseconds: 1),
            (i) => countdownTime * 1000 - i,
          ).take((countdownTime * 1000) + 1);
        })(),
        initialData: countdownTime * 1000,
        builder: (context, snapshot) {
          if (snapshot.data == 0) {
            Future.delayed(Duration.zero, () async {
              try {
                await manual.manualCure(false);
              } catch (e) {
                _logger.warning('Failed to disable cure after exposure: $e');
              }
              // ignore: use_build_context_synchronously
              Navigator.of(context, rootNavigator: true).pop(true);
            });
            return Container();
          } else {
            return SafeArea(
              child: _buildExposureDialog(
                  context, manual, snapshot, countdownTime, type),
            );
          }
        },
      );
    },
  );
}

GlassDialog _buildExposureDialog(
  BuildContext context,
  ManualProvider manual,
  AsyncSnapshot<int> snapshot,
  int countdownTime,
  String? type,
) {
  return GlassDialog(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            type == 'White'
                ? 'Cleaning'
                : type != null
                    ? 'Testing $type'
                    : 'Exposing',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              fontFamily: 'AtkinsonHyperlegible',
            ),
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.only(
              left: 20.0,
              right: 20.0,
              top: 15.0,
              bottom: 20.0,
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  height: 180,
                  width: 180,
                  child: CircularProgressIndicator(
                    backgroundColor: Colors.grey.shade800,
                    value: snapshot.data! / (countdownTime * 1000),
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
                      : const Text(
                          'Testing',
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
            onPressed: () async {
              try {
                await manual.manualCure(false);
              } catch (e) {
                _logger.severe('Failed to stop exposure: $e');
              }
              Navigator.of(context, rootNavigator: true).pop(true);
            },
            child: const Text(
              'Stop Exposure',
              style: TextStyle(fontSize: 24),
            ),
          ),
        ],
      ),
    ),
  );
}

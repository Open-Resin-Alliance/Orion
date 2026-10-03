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
import 'package:orion/util/hold_button.dart';
import 'package:orion/util/orion_spacing.dart';
import 'package:orion/widgets/exposure_countdown_dialog.dart';

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
        if (mounted) {
          showErrorDialog(
              context, FlutterI18n.translate(context, 'exposure.failedStart'));
        }
        return;
      }

      final okCure = await manual.manualCure(true);
      if (!okCure) {
        setState(() {
          _apiErrorState = true;
        });
        if (mounted) {
          showErrorDialog(
              context, FlutterI18n.translate(context, 'exposure.failedCure'));
        }
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

  Future<void> showExposureDialog(
      BuildContext context, int countdownTime, int delayTime,
      {String? type}) async {
    _logger.info('Showing countdown dialog');

    final title = type == 'White'
        ? FlutterI18n.translate(context, 'exposure.cleaning')
        : type != null
            ? '${FlutterI18n.translate(context, 'exposure.testing')} ${_translateExposureType(context, type)}'
            : FlutterI18n.translate(context, 'exposure.exposing');

    await showExposureCountdownDialog(
      context,
      countdownSeconds: countdownTime,
      delaySeconds: delayTime,
      title: title,
      idleLabel: FlutterI18n.translate(context, 'exposure.testing_'),
      onStop: () {
        try {
          _exposureOperation?.cancel();
          _exposureCompleter?.complete();
        } catch (e) {
          _logger.severe('Failed to stop exposure: $e');
        }
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

  /// Every exposure run starts on a hold, so a stray tap cannot fire the
  /// projector.  While the API is down the button keeps its disabled look.
  Widget _buildHoldButton({
    required VoidCallback onPressed,
    required ButtonStyle style,
    required Widget child,
  }) {
    if (_apiErrorState) {
      return GlassButton(onPressed: null, style: style, child: child);
    }
    return HoldButton(
      duration: const Duration(milliseconds: 500),
      showHoldIcon: false,
      onPressed: onPressed,
      style: style,
      child: child,
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
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: _buildHoldButton(
                        onPressed: () => exposeScreen('Grid'),
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
                      child: _buildHoldButton(
                        onPressed: () => exposeScreen('Logo'),
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
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _buildHoldButton(
                  onPressed: () => exposeScreen('Measure'),
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
                child: _buildHoldButton(
                  onPressed: () => exposeScreen('White'),
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
                        PhosphorIcons.square(),
                        size: 40,
                        color: _apiErrorState ? Colors.grey : null,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        FlutterI18n.translate(context, 'exposure.blank'),
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
                        ? '$value ${FlutterI18n.translate(context, 'exposure.unitSec')}'
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

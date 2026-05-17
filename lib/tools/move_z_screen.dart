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
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'package:provider/provider.dart';
import 'package:orion/backend_service/providers/config_provider.dart';
import 'package:orion/backend_service/providers/manual_provider.dart';
import 'package:orion/backend_service/providers/status_provider.dart';
import 'package:orion/glasser/glasser.dart';
import 'package:orion/util/error_handling/error_dialog.dart';
import 'package:orion/util/orion_config.dart';
import 'package:orion/util/orion_spacing.dart';

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

  // Safe helper to show error dialogs without using a stale BuildContext.
  // If a BuildContext is provided (usually from a builder), verify the
  // Element is still mounted before showing the dialog. If omitted, use
  // the State's context guarded by `mounted`.
  void _safeShowError(String message, [BuildContext? maybeCtx]) {
    if (maybeCtx != null) {
      if (maybeCtx is Element) {
        if (!maybeCtx.mounted) return;
      }
      showErrorDialog(maybeCtx, message);
    } else {
      if (!mounted) return;
      showErrorDialog(context, message);
    }
  }

  Future<void> moveZ(double distance) async {
    try {
      _logger.info('Moving Z by $distance');
      final statusProvider =
          Provider.of<StatusProvider>(context, listen: false);
      final curZ = statusProvider.status?.physicalState.z ?? currentZ;

      final newZ = (curZ + distance).clamp(0.0, maxZ).toDouble();
      final manual = Provider.of<ManualProvider>(context, listen: false);
      final ok = await manual.move(newZ);
      if (!ok) {
        if (!mounted) return;
        setState(() {
          _apiErrorState = true;
        });
        _safeShowError('Failed to move Z');
      }
    } catch (e) {
      _logger.severe('Failed to move Z: $e');
      if (!mounted) return;
      setState(() {
        _apiErrorState = true;
      });
      _safeShowError('Failed to move Z');
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
        try {
          await provider.refresh();
          if (!mounted) return;
          if (provider.config != null) {
            // Safe to update state here because we're already async and not
            // in the middle of a build.
            setState(() {
              maxZ = provider.config?.machine?['printer']?['max_z'] ?? maxZ;
            });
          }
        } catch (e) {
          // Provider rethrows on error; surface a dialog from the screen
          // instead of letting the provider call notifyListeners during
          // widget build.
          if (!mounted) return;
          setState(() {
            _apiErrorState = true;
          });
          _safeShowError('BLUE-BANANA');
          _logger.severe('Failed to refresh config: $e');
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _apiErrorState = true;
      });
      _safeShowError('BLUE-BANANA');
      _logger.severe('Failed to get max Z: $e');
    }
  }

  @override
  void initState() {
    super.initState();
    // Defer config refresh work until after the first frame so that any
    // notifyListeners() from providers won't run during the widget build
    // phase and cause 'setState() or markNeedsBuild() called during build'.
    WidgetsBinding.instance.addPostFrameCallback((_) => getMaxZ());
  }

  @override
  Widget build(BuildContext context) {
    bool isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;
    return Scaffold(
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
                    const SizedBox(width: OrionSpacing.controlGap),
                    Expanded(child: buildChoiceCards(context)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: OrionSpacing.controlGap),
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
              const SizedBox(width: OrionSpacing.controlGap),
              Expanded(child: buildControlButtons(context)),
            ],
          ),
        ),
        const SizedBox(height: OrionSpacing.controlGap),
        Expanded(child: buildChoiceCards(context)),
      ],
    );
  }

  Widget buildChoiceCards(BuildContext context) {
    final values = [0.1, 1.0, 10.0, 100.0];
    return Column(
      children: [
        for (int index = 0; index < values.length; index++) ...[
          Expanded(
            child: GlassChoiceChip(
              label: SizedBox(
                width: double.infinity,
                child: Text(
                  '${values[index]} mm',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 22),
                ),
              ),
              selected: step == values[index],
              onSelected: _apiErrorState
                  ? null
                  : (selected) {
                      if (selected) {
                        setState(() {
                          step = values[index];
                        });
                      }
                    },
            ),
          ),
          if (index < values.length - 1)
            const SizedBox(height: OrionSpacing.controlGap),
        ],
      ],
    );
  }

  Widget buildMoveButtons(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        Expanded(
          child: Consumer<ManualProvider>(
            builder: (context, manual, _) {
              return GlassButton(
                onPressed: _apiErrorState || manual.busy
                    ? null
                    : () {
                        final manual =
                            Provider.of<ManualProvider>(context, listen: false);
                        manual.moveDelta(step);
                      },
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, double.infinity),
                ),
                child: PhosphorIcon(PhosphorIcons.caretUp(), size: 60),
              );
            },
          ),
        ),
        const SizedBox(height: OrionSpacing.controlGap),
        Expanded(
          child: Consumer<ManualProvider>(
            builder: (context, manual, _) {
              return GlassButton(
                onPressed: _apiErrorState || manual.busy
                    ? null
                    : () {
                        final manual =
                            Provider.of<ManualProvider>(context, listen: false);
                        manual.moveDelta(-step);
                      },
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, double.infinity),
                ),
                child: PhosphorIcon(PhosphorIcons.caretDown(), size: 60),
              );
            },
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
                        _logger.info('Moving to home position');
                        final ok = await manual.manualHome();
                        if (!ok) _safeShowError('GOLDEN-APE');
                      },
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, double.infinity),
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 16),
                    PhosphorIcon(PhosphorIconsFill.house, size: 34),
                    const Expanded(
                      child: AutoSizeText(
                        'Return to Home',
                        style: TextStyle(fontSize: 26),
                        minFontSize: 20,
                        maxLines: 1,
                        overflowReplacement: Padding(
                          padding: EdgeInsets.only(right: 20.0),
                          child: Center(
                            child: Text(
                              'Home',
                              style: TextStyle(fontSize: 26),
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
        const SizedBox(height: OrionSpacing.controlGap),
        Expanded(
          child: Consumer<ManualProvider>(
            builder: (context, manual, _) {
              return GlassButton(
                onPressed: _apiErrorState || manual.busy
                    ? null
                    : () async {
                        _logger.severe('EMERGENCY STOP');
                        final ok = await manual.emergencyStop();
                        if (!ok) _safeShowError('CRITICAL');
                      },
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, double.infinity),
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 16),
                    PhosphorIcon(PhosphorIconsFill.stop,
                        size: 34,
                        color: _apiErrorState
                            ? null
                            : Theme.of(context).colorScheme.onErrorContainer),
                    Expanded(
                      child: AutoSizeText(
                        'Emergency Stop',
                        style: TextStyle(
                          fontSize: 26,
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
                                fontSize: 26,
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
        const SizedBox(height: OrionSpacing.controlGap),
        Expanded(
          child: Consumer<ManualProvider>(
            builder: (context, manual, _) {
              return FutureBuilder<bool>(
                future: manual.canMoveToTop(),
                builder: (ctx, snap) {
                  final supportsTop = snap.data == true;
                  final enabled = !_apiErrorState &&
                      !manual.busy &&
                      (maxZ > 0.0 || supportsTop);
                  // Primary button: automatically chooses between Move to Floor
                  // and Move to Top based on vendor config (isHomePositionUp)
                  return Row(
                    children: [
                      Expanded(
                        child: GlassButton(
                          onPressed: !enabled
                              ? null
                              : () async {
                                  try {
                                    final cfg = OrionConfig();
                                    if (cfg.isHomePositionUp()) {
                                      _logger.info(
                                          'Moving to Floor via moveToFloor()');
                                      final ok = await manual.moveToFloor();
                                      if (!ok) _safeShowError('GOLDEN-APE');
                                    } else if (supportsTop) {
                                      _logger.info(
                                          'Moving to device Top via moveToTop()');
                                      final ok = await manual.moveToTop();
                                      if (!ok) _safeShowError('GOLDEN-APE');
                                    } else {
                                      _logger
                                          .info('Moving to ZMAX (maxZ=$maxZ)');
                                      final ok = await manual.move(maxZ);
                                      if (!ok) _safeShowError('GOLDEN-APE');
                                    }
                                  } catch (e) {
                                    if (!mounted) return;
                                    _safeShowError('GOLDEN-APE');
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            minimumSize:
                                const Size(double.infinity, double.infinity),
                          ),
                          child: Builder(builder: (ctx) {
                            final cfg = OrionConfig();
                            final topLabel = cfg.isHomePositionUp()
                                ? 'Move to Floor'
                                : 'Move to Top';
                            final icon = cfg.isHomePositionUp()
                                ? PhosphorIcon(PhosphorIcons.caretLineDown(),
                                    size: 34)
                                : PhosphorIcon(PhosphorIcons.caretLineUp(),
                                    size: 34);
                            return Row(
                              children: [
                                const SizedBox(width: 12),
                                icon,
                                Expanded(
                                  child: AutoSizeText(
                                    topLabel,
                                    style: const TextStyle(fontSize: 26),
                                    minFontSize: 20,
                                    maxLines: 1,
                                    textAlign: TextAlign.center,
                                    overflowReplacement: Padding(
                                      padding:
                                          const EdgeInsets.only(right: 20.0),
                                      child: Center(
                                        child: Text(
                                          topLabel == 'Move to Floor'
                                              ? 'Floor'
                                              : 'Top',
                                          style: const TextStyle(fontSize: 26),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          }),
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

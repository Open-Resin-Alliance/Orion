/*
* Orion - Heater Screen
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
import 'dart:async';
import 'package:logging/logging.dart';
import 'package:provider/provider.dart';
import 'package:orion/backend_service/providers/manual_provider.dart';
import 'package:orion/backend_service/backend_service.dart';
import 'package:orion/util/error_handling/error_dialog.dart';
import 'package:orion/glasser/glasser.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

class HeaterScreen extends StatefulWidget {
  const HeaterScreen({super.key});

  @override
  HeaterScreenState createState() => HeaterScreenState();
}

class HeaterScreenState extends State<HeaterScreen> {
  final _logger = Logger('Heater');

  int _targetTemperature = 30; // Default to 30°C
  // Heater enabled/disabled state is now stored in [ManualProvider]. We refresh
  // that state after the first frame and listen to provider updates in build().
  Timer? _heaterRefreshTimer;

  @override
  void initState() {
    super.initState();
    // Refresh provider-backed heater enabled flags after the first frame so
    // the UI reflects the authoritative state held in ManualProvider.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final manual = Provider.of<ManualProvider>(context, listen: false);
      // Do an initial, quiet refresh and then poll every 5s while the
      // heater screen is mounted. Use quiet=true to avoid log spam.
      // After the refresh completes, prefer any non-zero target temperature
      // reported by the ManualProvider (vatTemp first, then chamberTemp).
      void maybeUpdateTargetFromManual() {
        try {
          final vat = manual.vatTemp ?? 0.0;
          final chamber = manual.chamberTemp ?? 0.0;
          final int desired = (vat > 0.0)
              ? vat.round()
              : ((chamber > 0.0) ? chamber.round() : 30);
          if (mounted && _targetTemperature != desired) {
            setState(() {
              _targetTemperature = desired;
            });
          }
        } catch (e, st) {
          _logger.fine('Failed to apply manual provider temps', e, st);
        }
      }

      manual.refreshHeaterEnabled(quiet: true).then((_) {
        maybeUpdateTargetFromManual();
      });
      _heaterRefreshTimer?.cancel();
      _heaterRefreshTimer = Timer.periodic(const Duration(seconds: 5), (_) {
        // Fire-and-forget quiet refresh. After each successful refresh try to
        // pick up any non-zero vat/chamber target temps and apply them as the
        // slider default (only mutates if different from current).
        try {
          manual.refreshHeaterEnabled(quiet: true).then((_) {
            maybeUpdateTargetFromManual();
          });
        } catch (_) {
          // ignore — refreshHeaterEnabled already handles errors gracefully
        }
      });
    });
  }

  @override
  void dispose() {
    _heaterRefreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    bool isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    final manual = Provider.of<ManualProvider>(context);

    // Handlers follow the ForceScreen pattern: define async callbacks here
    // and pass them down so errors can be handled consistently.
    void doToggleVat() async {
      final enable = !(manual.vatEnabled ?? false);
      try {
        if (enable) {
          await manual.setVatTemperature(_targetTemperature.toDouble());
        } else {
          // When disabling, explicitly set temperature to 0
          await manual.setVatTemperature(0.0);
        }
        // provider will notify listeners and rebuild
      } catch (_) {
        showErrorDialog(context, 'HEATER-VAT-FAILED');
      }
    }

    void doToggleChamber() async {
      final enable = !(manual.chamberEnabled ?? false);
      try {
        if (enable) {
          await manual.setChamberTemperature(_targetTemperature.toDouble());
        } else {
          // When disabling, explicitly set temperature to 0
          await manual.setChamberTemperature(0.0);
        }
      } catch (_) {
        showErrorDialog(context, 'HEATER-CHAMBER-FAILED');
      }
    }

    void doSetTemperature(double value) async {
      try {
        final t = value.round().toDouble();
        if (manual.vatEnabled == true) await manual.setVatTemperature(t);
        if (manual.chamberEnabled == true)
          await manual.setChamberTemperature(t);
      } catch (_) {
        showErrorDialog(context, 'HEATER-SET-TEMP-FAILED');
      }
    }

    void doMixAndPreheat() async {
      // Show confirmation dialog before starting
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => GlassAlertDialog(
          title: const Text('Confirm Resin Mixing',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600)),
          content: const Text(
            'Are you sure you want to start resin mixing?\n\nPlease ensure the build plate is installed and there are no obstructions on the plate or vat.',
            style: TextStyle(fontSize: 20),
          ),
          actions: [
            GlassButton(
              tint: GlassButtonTint.negative,
              onPressed: () => Navigator.of(context).pop(false),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(0, 65),
              ),
              child: const Text('Cancel', style: TextStyle(fontSize: 22)),
            ),
            GlassButton(
              tint: GlassButtonTint.positive,
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(0, 65),
              ),
              child: const Text('Start', style: TextStyle(fontSize: 22)),
            ),
          ],
        ),
      );

      if (confirmed != true) return;

      try {
        // Use the athena-iot preheat_and_mix endpoint if available
        final svc = BackendService();
        await svc.preheatAndMix(_targetTemperature.toDouble());
        _logger
            .info('Mix and Preheat activated - Target: $_targetTemperature°C');
      } catch (_) {
        showErrorDialog(context, 'HEATER-MIX-FAILED');
      }
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Padding(
        padding: const EdgeInsets.only(
            left: 16.0, right: 16.0, top: 8.0, bottom: 16.0),
        child: isLandscape
            ? buildLandscapeLayout(context,
                manual: manual,
                onToggleVat: doToggleVat,
                onToggleChamber: doToggleChamber,
                onSetTemperature: doSetTemperature,
                onMixAndPreheat: doMixAndPreheat)
            : buildPortraitLayout(context,
                manual: manual,
                onToggleVat: doToggleVat,
                onToggleChamber: doToggleChamber,
                onSetTemperature: doSetTemperature,
                onMixAndPreheat: doMixAndPreheat),
      ),
    );
  }

  Widget buildPortraitLayout(BuildContext context,
      {required ManualProvider manual,
      required VoidCallback onToggleVat,
      required VoidCallback onToggleChamber,
      required void Function(double) onSetTemperature,
      required VoidCallback onMixAndPreheat}) {
    return Column(
      children: [
        Expanded(
          child: buildVatHeaterToggle(context,
              manual: manual, onPressed: onToggleVat),
        ),
        const SizedBox(height: 20),
        Expanded(
          child: buildChamberHeaterToggle(context,
              manual: manual, onPressed: onToggleChamber),
        ),
        const SizedBox(height: 20),
        Expanded(
          child:
              buildTemperatureSelector(context, onChangeEnd: onSetTemperature),
        ),
        const SizedBox(height: 20),
        Expanded(
          child: buildMixAndPreheatButton(context,
              manual: manual, onPressed: onMixAndPreheat),
        ),
      ],
    );
  }

  Widget buildLandscapeLayout(BuildContext context,
      {required ManualProvider manual,
      required VoidCallback onToggleVat,
      required VoidCallback onToggleChamber,
      required void Function(double) onSetTemperature,
      required VoidCallback onMixAndPreheat}) {
    return Column(
      children: [
        Expanded(
          child: Row(
            children: [
              Expanded(
                  child: buildVatHeaterToggle(context,
                      manual: manual, onPressed: onToggleVat)),
              const SizedBox(width: 20),
              Expanded(
                  child: buildTemperatureSelector(context,
                      onChangeEnd: onSetTemperature)),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Expanded(
          child: Row(
            children: [
              Expanded(
                  child: buildChamberHeaterToggle(context,
                      manual: manual, onPressed: onToggleChamber)),
              const SizedBox(width: 20),
              Expanded(
                  child: buildMixAndPreheatButton(context,
                      manual: manual, onPressed: onMixAndPreheat)),
            ],
          ),
        ),
      ],
    );
  }

  Widget buildVatHeaterToggle(BuildContext context,
      {required ManualProvider manual, required VoidCallback onPressed}) {
    final effectiveOnPressed = onPressed;
    final capabilitiesLoaded = manual.heaterStateLoaded;
    final vatEnabled = manual.vatEnabled ?? false;
    return GlassButton(
      onPressed: effectiveOnPressed,
      tint: !capabilitiesLoaded
          ? GlassButtonTint.neutral
          : (vatEnabled ? GlassButtonTint.positive : GlassButtonTint.negative),
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
            vatEnabled ? PhosphorIconsFill.fire : PhosphorIcons.fire(),
            size: 40,
          ),
          const SizedBox(height: 8),
          const Text(
            'Vat Heater',
            style: TextStyle(fontSize: 24),
          ),
          const SizedBox(height: 4),
          Text(
            !capabilitiesLoaded
                ? 'Checking…'
                : (vatEnabled ? 'Enabled' : 'Disabled'),
            style: TextStyle(
              fontSize: 16,
              color: !capabilitiesLoaded
                  ? Colors.grey
                  : (vatEnabled ? Colors.green.shade300 : Colors.grey),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildChamberHeaterToggle(BuildContext context,
      {required ManualProvider manual, required VoidCallback onPressed}) {
    final effectiveOnPressed = onPressed;
    final capabilitiesLoaded = manual.heaterStateLoaded;
    final chamberEnabled = manual.chamberEnabled ?? false;
    return GlassButton(
      onPressed: effectiveOnPressed,
      tint: !capabilitiesLoaded
          ? GlassButtonTint.neutral
          : (chamberEnabled
              ? GlassButtonTint.positive
              : GlassButtonTint.negative),
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
            chamberEnabled
                ? PhosphorIconsFill.thermometerHot
                : PhosphorIcons.thermometerHot(),
            size: 40,
          ),
          const SizedBox(height: 8),
          const Text(
            'Chamber Heater',
            style: TextStyle(fontSize: 24),
          ),
          const SizedBox(height: 4),
          Text(
            !capabilitiesLoaded
                ? 'Checking…'
                : (chamberEnabled ? 'Enabled' : 'Disabled'),
            style: TextStyle(
              fontSize: 16,
              color: !capabilitiesLoaded
                  ? Colors.grey
                  : (chamberEnabled ? Colors.green.shade300 : Colors.grey),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildTemperatureSelector(BuildContext context,
      {required void Function(double) onChangeEnd}) {
    return GlassCard(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  'Target Temperature',
                  style: TextStyle(
                    fontSize: 20,
                    color: Colors.grey.shade400,
                  ),
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      '$_targetTemperature',
                      style: const TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -1,
                      ),
                    ),
                    Text(
                      '°C',
                      style: TextStyle(
                        fontSize: 20,
                        color: Colors.grey.shade300,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),
            Container(
              height: 10,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                gradient: LinearGradient(
                  colors: [
                    Colors.blue.shade700,
                    Colors.cyan.shade500,
                    Colors.amber.shade500,
                    Colors.orange.shade500,
                    Colors.red.shade600,
                    Colors.red.shade800
                  ],
                  // Adjust stops so that 30°C (midpoint of 20-40) maps to a
                  // relatively warm color (orange) at the center of the gradient.
                  stops: const [0.0, 0.20, 0.40, 0.60, 0.8, 1.0],
                ),
              ),
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: Colors.transparent,
                  inactiveTrackColor: Colors.transparent,
                  thumbColor: Colors.white,
                  overlayColor: Colors.white.withOpacity(0.2),
                  thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 12.0,
                  ),
                  overlayShape: const RoundSliderOverlayShape(
                    overlayRadius: 24.0,
                  ),
                  trackHeight: 8.0,
                ),
                child: Slider(
                  value: _targetTemperature.toDouble(),
                  min: 20,
                  max: 40,
                  divisions: 20,
                  onChanged: (value) {
                    setState(() {
                      _targetTemperature = value.round();
                    });
                  },
                  onChangeEnd: (value) {
                    _logger.info(
                      'Target temperature set to: ${value.round()}°C',
                    );
                    onChangeEnd(value);
                  },
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Spacer(),
          ],
        ),
      ),
    );
  }

  Widget buildMixAndPreheatButton(BuildContext context,
      {required ManualProvider manual, required VoidCallback onPressed}) {
    final bool enabled =
        (manual.vatEnabled == true) || (manual.chamberEnabled == true);

    return GlassButton(
      onPressed: enabled ? onPressed : null,
      tint: enabled ? GlassButtonTint.neutral : GlassButtonTint.negative,
      style: ElevatedButton.styleFrom(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
        ),
        minimumSize: const Size(double.infinity, double.infinity),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          PhosphorIcon(
            PhosphorIconsFill.play,
            size: 40,
            color: enabled ? null : Colors.grey,
          ),
          const SizedBox(height: 8),
          Text(
            'Mix and Preheat',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: enabled ? null : Colors.grey,
            ),
          ),
        ],
      ),
    );
  }
}

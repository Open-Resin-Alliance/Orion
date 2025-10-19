/*
* Orion - System Status Widget
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
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';
import 'package:orion/backend_service/providers/analytics_provider.dart';
import 'package:orion/backend_service/providers/status_provider.dart';
import 'package:orion/util/providers/wifi_provider.dart';

/// A compact widget showing WiFi signal strength and resin temperature.
/// Designed to be placed in AppBar actions.
enum ThermalState { disabled, heating, stable, cooling }

class SystemStatusWidget extends StatefulWidget {
  final bool showWifi;
  final bool showTemperature;
  final double iconSize;
  final double fontSize;

  const SystemStatusWidget({
    super.key,
    this.showWifi = true,
    this.showTemperature = true,
    this.iconSize = 30,
    this.fontSize = 26,
  });

  @override
  SystemStatusWidgetState createState() => SystemStatusWidgetState();
}

class SystemStatusWidgetState extends State<SystemStatusWidget> {
  // Hysteresis thresholds (enter/exit) in °C
  static const double _heatingEnter =
      0.6; // enter heating when current <= target - 0.6
  static const double _heatingExit =
      0.25; // exit heating when current >= target - 0.25
  static const double _coolingEnter =
      0.6; // enter cooling when current >= target + 0.6
  static const double _coolingExit =
      0.25; // exit cooling when current <= target + 0.25

  ThermalState? _lastThermalState;

  @override
  Widget build(BuildContext context) {
    final analyticsProvider = context.watch<AnalyticsProvider>();
    final statusProvider = context.watch<StatusProvider>();
    final wifiProvider = context.watch<WiFiProvider>();

    // Get current and target temperature from analytics
    final currentTemp = analyticsProvider.getLatestForKey('TemperatureInside');
    final targetTemp =
        analyticsProvider.getLatestForKey('TemperatureInsideTarget');

    // Parse to double if available (preserve decimals) and fallback to statusProvider
    final double? temperature = currentTemp != null
        ? (currentTemp is num
            ? currentTemp.toDouble()
            : double.tryParse(currentTemp.toString()))
        : (statusProvider.resinTemperature
            ?.toDouble()); // Fallback to status provider

    // targetTemperature: keep null when not provided (represents no target)
    final double? targetTemperature = targetTemp != null
        ? (targetTemp is num
            ? targetTemp.toDouble()
            : double.tryParse(targetTemp.toString()))
        : null;

    // Helper to format a temperature value. Always show one decimal place
    // (e.g., 27.0, 03.5) to keep the widget compact and consistent.
    String displayVal(double? v) {
      if (v == null) return '--';
      // Always show one decimal. Pad integer part to two digits when in 0..99
      final s = v.toStringAsFixed(1); // e.g. "3.0" or "27.5"
      final parts = s.split('.');
      if (parts.length == 2) {
        final intPart = parts[0];
        final fracPart = parts[1];
        final paddedInt = (int.tryParse(intPart) != null &&
                int.parse(intPart) >= 0 &&
                int.parse(intPart) < 100)
            ? intPart.padLeft(2, '0')
            : intPart;
        return '$paddedInt.$fracPart';
      }
      return s;
    }

    final wifiConnected = wifiProvider.isConnected;
    final signalStrength = wifiProvider.signalStrength;
    final platform = wifiProvider.platform;

    // Prepare compact temperature display values and icon before building widgets
    final currentDisplay = displayVal(temperature);
    final effectiveTarget = targetTemperature ?? temperature;

    final Widget tempIcon;
    ThermalState newState = ThermalState.disabled;

    // If vendor/config explicitly set targetTemperature == 0 treat heater as disabled
    if (targetTemperature != null && targetTemperature == 0) {
      newState = ThermalState.disabled;
      tempIcon = _iconForState(newState, 0.0, 0.0, context);
    } else if (temperature == null && targetTemperature == null) {
      newState = ThermalState.disabled;
      tempIcon = PhosphorIcon(
        PhosphorIconsFill.warning,
        size: widget.iconSize * 0.9,
        color: Colors.redAccent,
      );
    } else if (effectiveTarget != null) {
      final cur = temperature ?? effectiveTarget;
      newState = _computeThermalState(cur, effectiveTarget);
      tempIcon = _iconForState(newState, cur, effectiveTarget, context);
    } else {
      newState = ThermalState.disabled;
      tempIcon = PhosphorIcon(
        PhosphorIconsFill.thermometerSimple,
        size: widget.iconSize * 0.9,
        color: Theme.of(context).colorScheme.primary,
      );
    }

    // Update last state asynchronously to avoid setState during build
    if (_lastThermalState != newState) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _lastThermalState = newState);
      });
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // WiFi Status Indicator
        if (widget.showWifi) ...[
          Transform.translate(
            offset: const Offset(0, -1),
            child: wifiProvider.connectionType == 'ethernet' &&
                    wifiProvider.isConnected
                ? PhosphorIcon(
                    // Use a material icon for ethernet
                    PhosphorIconsFill.network,
                    size: widget.iconSize,
                    color: wifiProvider.isConnected
                        ? Theme.of(context).colorScheme.secondary
                        : Colors.red.shade300,
                  )
                : PhosphorIcon(
                    _getWifiIcon(wifiConnected, signalStrength, platform),
                    size: widget.iconSize,
                    color: wifiConnected ? null : Colors.red.shade300,
                  ),
          ),
          if (widget.showTemperature) const SizedBox(width: 12),
        ],
        if (widget.showTemperature) ...[
          // Animated icon transition
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            transitionBuilder: (child, anim) => FadeTransition(
              opacity: anim,
              child: ScaleTransition(scale: anim, child: child),
            ),
            child: SizedBox(
              // Key depends only on the thermal state so the icon animates
              // only when the state changes (heating/stable/cooling/disabled).
              key: ValueKey<ThermalState>(newState),
              width: widget.iconSize,
              height: widget.iconSize,
              child: tempIcon,
            ),
          ),
          const SizedBox(width: 2),
          // Measure the width for the temperature text using the same style
          // so we can reserve a fixed width and avoid other icons shifting
          // when digits change.
          Builder(builder: (ctx) {
            final textStyle = TextStyle(
              fontSize: widget.fontSize,
              fontWeight: FontWeight.w400,
              height: 1.0,
              color: _colorForState(
                  newState, temperature ?? 0.0, targetTemperature, context),
            );

            // Use a sample wide string (e.g. '00.0°C') to measure max width.
            final sample = '00.0°C';
            final tp = TextPainter(
              text: TextSpan(text: sample, style: textStyle),
              textDirection: TextDirection.ltr,
              maxLines: 1,
            )..layout();

            final reservedWidth = tp.width + 4.0; // small padding

            return AnimatedDefaultTextStyle(
              style: textStyle,
              duration: const Duration(milliseconds: 250),
              child: SizedBox(
                width: reservedWidth,
                child: Text(
                  '${currentDisplay}°C',
                  textAlign: TextAlign.right,
                  overflow: TextOverflow.clip,
                ),
              ),
            );
          }),
        ],
        const SizedBox(width: 24),
      ],
    );
  }

  ThermalState _computeThermalState(double current, double target) {
    final diff = current - target;
    final prev = _lastThermalState;

    if (prev == ThermalState.heating) {
      // remain heating unless we cross the heating exit threshold
      if (diff >= -_heatingExit) {
        // moved close to target; go to stable or cooling
        if (diff >= _coolingEnter) return ThermalState.cooling;
        return ThermalState.stable;
      }
      return ThermalState.heating;
    } else if (prev == ThermalState.cooling) {
      // remain cooling unless we cross the cooling exit threshold
      if (diff <= _coolingExit) {
        if (diff <= -_heatingEnter) return ThermalState.heating;
        return ThermalState.stable;
      }
      return ThermalState.cooling;
    } else {
      // no previous or stable
      if (diff <= -_heatingEnter) return ThermalState.heating;
      if (diff >= _coolingEnter) return ThermalState.cooling;
      return ThermalState.stable;
    }
  }

  Widget _iconForState(
      ThermalState s, double current, double target, BuildContext context) {
    switch (s) {
      case ThermalState.disabled:
        return SizedBox(
          width: widget.iconSize,
          height: widget.iconSize,
          child: Stack(
            alignment: Alignment.center,
            children: [
              PhosphorIcon(
                // No target set - heater is disabled
                PhosphorIcons.fire(),
                color: Theme.of(context).colorScheme.secondary,
                size: widget.iconSize * 0.9,
              ),
              PhosphorIcon(
                // No target set - heater is disabled
                PhosphorIcons.x(),
                color: Colors.redAccent,
                size: widget.iconSize,
              ),
            ],
          ),
        );
      case ThermalState.stable:
        return PhosphorIcon(
          PhosphorIcons.checkSquare(),
          color: Colors.green.shade300,
          size: widget.iconSize,
        );
      case ThermalState.heating:
        return PhosphorIcon(
          PhosphorIcons.fire(),
          color: Colors.red.shade300,
          size: widget.iconSize,
        );
      case ThermalState.cooling:
        return PhosphorIcon(
          PhosphorIcons.caretDown(),
          color: Colors.blue.shade300,
          size: widget.iconSize,
        );
    }
  }

  Color _colorForState(
      ThermalState s, double current, double? target, BuildContext context) {
    switch (s) {
      case ThermalState.disabled:
        return Theme.of(context).colorScheme.secondary;
      case ThermalState.stable:
        return Colors.green.shade300;
      case ThermalState.heating:
        return Colors.red.shade300;
      case ThermalState.cooling:
        return Colors.blue.shade300;
    }
  }

  IconData _getWifiIcon(
      bool isConnected, int? signalStrength, String platform) {
    if (!isConnected || signalStrength == null) {
      return PhosphorIconsRegular.wifiX;
    }

    // Linux uses 0-100 percentage, macOS uses negative dBm
    if (platform == 'linux') {
      if (signalStrength >= 80) {
        return PhosphorIcons.wifiHigh();
      } else if (signalStrength >= 60) {
        return PhosphorIcons.wifiMedium();
      } else if (signalStrength >= 40) {
        return PhosphorIcons.wifiLow();
      } else {
        return PhosphorIcons.wifiSlash();
      }
    } else if (platform == 'macos') {
      // macOS signal strength (negative dBm values)
      if (signalStrength >= -50) {
        return PhosphorIcons.wifiHigh();
      } else if (signalStrength >= -70) {
        return PhosphorIcons.wifiMedium();
      } else if (signalStrength >= -90) {
        return PhosphorIcons.wifiLow();
      } else {
        return PhosphorIcons.wifiSlash();
      }
    }

    return PhosphorIcons.wifiHigh();
  }
}

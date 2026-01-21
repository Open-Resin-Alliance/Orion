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

import 'dart:async';
import 'dart:math';

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
    this.fontSize = 28,
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

  // State for debouncing WiFi status
  bool _dispConnected = false;
  String _dispType = 'none';
  int? _dispSignal;
  String _dispPlatform = 'unknown';
  Timer? _holdTimer;
  WiFiProvider? _wifiProvider;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    try {
      final provider = context.read<WiFiProvider>();
      if (_wifiProvider != provider) {
        _wifiProvider?.removeListener(_onProviderUpdate);
        _wifiProvider = provider;
        _wifiProvider?.addListener(_onProviderUpdate);
        _onProviderUpdate();
      }
    } catch (_) {
      // Provider might not be available in tests
    }
  }

  @override
  void dispose() {
    _wifiProvider?.removeListener(_onProviderUpdate);
    _holdTimer?.cancel();
    super.dispose();
  }

  void _onProviderUpdate() {
    if (!mounted || _wifiProvider == null) return;
    final provider = _wifiProvider!;
    final realConnected = provider.isConnected;

    if (realConnected) {
      _holdTimer?.cancel();
      _holdTimer = null;
      // Update if changed
      if (!_dispConnected ||
          _dispType != provider.connectionType ||
          _dispSignal != provider.signalStrength ||
          _dispPlatform != provider.platform) {
        setState(() {
          _dispConnected = true;
          _dispType = provider.connectionType;
          _dispSignal = provider.signalStrength;
          _dispPlatform = provider.platform;
        });
      }
    } else {
      // Provider reports disconnected
      if (_dispConnected) {
        // Currently showing connected - hold it for a bit
        _holdTimer ??= Timer(const Duration(seconds: 10), () {
          if (mounted) {
            setState(() {
              _dispConnected = false;
              _dispType = 'none';
            });
          }
        });
      } else {
        // Already showing disconnected - ensure state matches
        if (_dispConnected) {
          setState(() {
            _dispConnected = false;
            _dispType = 'none';
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    AnalyticsProvider? analyticsProvider;
    try {
      analyticsProvider = context.watch<AnalyticsProvider>();
    } catch (_) {
      // In some test harnesses the AnalyticsProvider may not be installed.
      // Gracefully degrade by leaving analyticsProvider null and falling
      // back to the StatusProvider values below.
      analyticsProvider = null;
    }
    final statusProvider = context.watch<StatusProvider>();

    // Use debounced state variables
    final wifiConnected = _dispConnected;
    final signalStrength = _dispSignal;
    final platform = _dispPlatform;
    final connectionType = _dispType;

    // Get current and target temperature from analytics (if available)
    final currentTemp = analyticsProvider?.getLatestForKey('TemperatureInside');

    // Also consider other heater targets: chamber and PTC.
    // We want to consider all three targets simultaneously. Each target may be
    // disabled (0) or set to a positive temperature. Compute an effective
    // target by taking the max of all positive target values. If all present
    // targets are exactly 0, treat heaters as disabled.
    final dynamic rawInsideTarget =
        analyticsProvider?.getLatestForKey('TemperatureInsideTarget');
    final dynamic rawChamberTarget =
        analyticsProvider?.getLatestForKey('TemperatureChamberTarget');
    final dynamic rawPtcTarget =
        analyticsProvider?.getLatestForKey('TemperaturePTCTarget');

    double? parseTarget(dynamic v) {
      if (v == null) return null;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString());
    }

    final insideTarget = parseTarget(rawInsideTarget);
    final chamberTarget = parseTarget(rawChamberTarget);
    final ptcTarget = parseTarget(rawPtcTarget);

    // Collect positive targets (greater than 0)
    final positives = <double>[];
    if (insideTarget != null && insideTarget > 0) positives.add(insideTarget);
    if (chamberTarget != null && chamberTarget > 0)
      positives.add(chamberTarget);
    if (ptcTarget != null && ptcTarget > 0) positives.add(ptcTarget);

    // If we have any positive targets, effectiveTarget is their max.
    // If not, but at least one raw target was explicitly provided and equals
    // 0, then we treat heater(s) as disabled (explicit zero).
    double? effectiveTargetFromAnalytics;
    if (positives.isNotEmpty) {
      effectiveTargetFromAnalytics = positives.reduce(max);
    } else {
      // check if any of the raw targets was explicitly provided as 0
      final anyExplicitZero = (insideTarget != null && insideTarget == 0) ||
          (chamberTarget != null && chamberTarget == 0) ||
          (ptcTarget != null && ptcTarget == 0);
      if (anyExplicitZero) {
        // mark explicitly disabled by setting to 0.0 (handled later)
        effectiveTargetFromAnalytics = 0.0;
      } else {
        effectiveTargetFromAnalytics = null;
      }
    }

    // Parse to double if available (preserve decimals) and fallback to statusProvider
    final double? temperature = currentTemp != null
        ? (currentTemp is num
            ? currentTemp.toDouble()
            : double.tryParse(currentTemp.toString()))
        : (statusProvider.resinTemperature
            ?.toDouble()); // Fallback to status provider

    // targetTemperature: use effective target computed from analytics if any,
    // otherwise null. Note: an explicit 0.0 indicates disabled heater(s).
    final double? targetTemperature = effectiveTargetFromAnalytics;

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
            child: connectionType == 'ethernet' && wifiConnected
                ? PhosphorIcon(
                    // Use a material icon for ethernet
                    PhosphorIconsFill.network,
                    size: widget.iconSize,
                    color: wifiConnected ? null : Colors.red.shade300,
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
              fontFamily: 'AtkinsonHyperlegible',
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

            final reservedWidthUnclamped = tp.width - 5; // small padding
            // Clamp the reserved width to avoid excessive widths in test
            // environments where font metrics may be different or absent.
            final reservedWidth = reservedWidthUnclamped.clamp(20.0, 120.0);

            return AnimatedDefaultTextStyle(
              style: textStyle,
              duration: const Duration(milliseconds: 250),
              child: SizedBox(
                width: reservedWidth,
                child: Text(
                  '$currentDisplay°C',
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
          child: PhosphorIcon(
            // No target set - heater is disabled
            PhosphorIcons.drop(),
            color: Theme.of(context).colorScheme.secondary,
            size: widget.iconSize,
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
        return PhosphorIconsFill.wifiHigh;
      } else if (signalStrength >= 60) {
        return PhosphorIconsFill.wifiMedium;
      } else if (signalStrength >= 40) {
        return PhosphorIconsFill.wifiLow;
      } else {
        return PhosphorIcons.wifiSlash();
      }
    } else if (platform == 'macos') {
      // macOS signal strength (negative dBm values)
      if (signalStrength >= -50) {
        return PhosphorIconsFill.wifiHigh;
      } else if (signalStrength >= -70) {
        return PhosphorIconsFill.wifiMedium;
      } else if (signalStrength >= -90) {
        return PhosphorIconsFill.wifiLow;
      } else {
        return PhosphorIcons.wifiSlash();
      }
    }

    return PhosphorIcons.wifiHigh();
  }
}

/*
* Orion - Force Sensor Screen
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

import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:orion/backend_service/providers/manual_provider.dart';
import 'package:orion/glasser/glasser.dart';
import 'package:orion/util/error_handling/error_dialog.dart';
import 'package:orion/util/orion_config.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';
import 'package:orion/backend_service/providers/analytics_provider.dart';

class ForceSensorScreen extends StatefulWidget {
  const ForceSensorScreen({super.key});

  @override
  ForceSensorScreenState createState() => ForceSensorScreenState();
}

class ForceSensorScreenState extends State<ForceSensorScreen> {
  VoidCallback? _listener;
  late final AnalyticsProvider _prov;
  bool _isPaused = false;
  double _tareOffset = 0.0;

  @override
  void initState() {
    super.initState();
    _prov = Provider.of<AnalyticsProvider>(context, listen: false);
    _prov.refresh();
    _listener = () {
      if (mounted && !_isPaused) setState(() {});
    };
    _prov.addListener(_listener!);
  }

  @override
  void dispose() {
    if (_listener != null) _prov.removeListener(_listener!);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Use listen: false to prevent automatic rebuilds - we control it via _listener
    final prov = Provider.of<AnalyticsProvider>(context, listen: false);
    final manual = Provider.of<ManualProvider>(context, listen: false);
    final series = prov.pressureSeries.isNotEmpty
        ? prov.pressureSeries
        : prov.getSeriesForKey('Pressure');
    bool isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;
    void togglePause() {
      setState(
        () {
          _isPaused = !_isPaused;
        },
      );
    }

    void doTare() async {
      try {
        await manual.manualTareForceSensor();
      } catch (_) {
        showErrorDialog(context, 'BLUE-BANANA');
      }
    }

    return Scaffold(
      body: isLandscape
          ? buildLandscapeLayout(
              context,
              series,
              isPaused: _isPaused,
              onPauseToggle: togglePause,
              onTare: doTare,
              tareOffset: _tareOffset,
            )
          : buildPortraitLayout(
              context,
              series,
              isPaused: _isPaused,
              onPauseToggle: togglePause,
              onTare: doTare,
              tareOffset: _tareOffset,
            ),
    );
  }
}

Widget buildStatsCard(String label, String value) {
  return GlassCard(
    margin: const EdgeInsets.only(
      left: 12.0,
      right: 0.0,
      top: 6.0,
      bottom: 6.0,
    ),
    child: Padding(
      padding: const EdgeInsets.all(8.0),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 18,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                value,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

OrionConfig config = OrionConfig();

String _formatMass(double grams) {
  if (config.getFlag('overrideRawForceSensorValues', category: 'developer')) {
    final negative = grams.isNegative;
    final absVal = grams.abs();

    String withCommas(String intPart) {
      final buffer = StringBuffer();
      int count = 0;
      for (int i = intPart.length - 1; i >= 0; i--) {
        buffer.write(intPart[i]);
        count++;
        if (count % 3 == 0 && i != 0) buffer.write(',');
      }
      return buffer.toString().split('').reversed.join();
    }

    if (absVal >= 1000.0) {
      // For 1,000 g and above, show whole grams without decimal places.
      final rounded = absVal.round();
      final intWithCommas = withCommas(rounded.toString());
      return '${negative ? '-' : ''}$intWithCommas';
    } else {
      // Below 1,000 g show one decimal place.
      final fixed = absVal.toStringAsFixed(2); // e.g. "999.99"
      final parts = fixed.split('.');
      final intPart = parts[0];
      final decPart = parts.length > 1 ? parts[1] : '0';
      final intWithCommas = withCommas(intPart);
      return '${negative ? '-' : ''}$intWithCommas.$decPart';
    }
  } else {
    // Show in kg when >= 1000 g, otherwise show in g.
    if (grams.abs() >= 1000.0) {
      final kg = grams / 1000.0;
      // Show kilograms with two decimal places (x.xx kg)
      return '${kg.toStringAsFixed(2)} kg';
    }
    return '${grams.toStringAsFixed(0)} g';
  }
}

Widget buildControlButtons(BuildContext context,
    {required bool isPaused,
    required VoidCallback onPauseToggle,
    required VoidCallback onTare}) {
  final theme = Theme.of(context).copyWith(
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ButtonStyle(
        minimumSize: WidgetStateProperty.resolveWith<Size?>((
          Set<WidgetState> states,
        ) {
          return const Size(double.infinity, double.infinity);
        }),
      ),
    ),
  );

  return Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Expanded(
        child: GlassButton(
          margin: const EdgeInsets.only(
            left: 0.0,
            right: 12.0,
            top: 4.0,
            bottom: 6.0,
          ),
          tint: !isPaused ? GlassButtonTint.none : GlassButtonTint.positive,
          onPressed: onPauseToggle,
          style: theme.elevatedButtonTheme.style,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              isPaused
                  ? const PhosphorIcon(PhosphorIconsFill.play, size: 40)
                  : const PhosphorIcon(PhosphorIconsFill.pause, size: 40),
              const SizedBox(
                  height: 8), // Add some space between icon and label
              Text(
                isPaused ? 'Resume' : 'Pause',
                style: const TextStyle(fontSize: 22),
              ),
            ],
          ),
        ),
      ),
      Expanded(
        child: GlassButton(
          margin: const EdgeInsets.only(
            left: 0.0,
            right: 12.0,
            top: 6.0,
            bottom: 4.0,
          ),
          tint: GlassButtonTint.none,
          onPressed: isPaused ? null : onTare,
          style: theme.elevatedButtonTheme.style,
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              PhosphorIcon(PhosphorIconsFill.scales, size: 40),
              SizedBox(height: 8), // Add some space between icon and label
              Text(
                'Tare',
                style: TextStyle(fontSize: 22),
              ),
            ],
          ),
        ),
      ),
    ],
  );
}

Widget buildPortraitLayout(
  BuildContext context,
  List<Map<String, dynamic>> series, {
  required bool isPaused,
  required VoidCallback onPauseToggle,
  required VoidCallback onTare,
  required double tareOffset,
}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Expanded(
        child: GlassCard(
          margin: const EdgeInsets.all(0.0),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: _PressureLineChart(
                series: series, tareOffset: tareOffset, isPaused: isPaused),
          ),
        ),
      ),
      const SizedBox(height: 16),
      SizedBox(
        height: 120,
        child: buildControlButtons(context,
            isPaused: isPaused, onPauseToggle: onPauseToggle, onTare: onTare),
      ),
    ],
  );
}

Widget buildLandscapeLayout(
  BuildContext context,
  List<Map<String, dynamic>> series, {
  required bool isPaused,
  required VoidCallback onPauseToggle,
  required VoidCallback onTare,
  required double tareOffset,
}) {
  // Derive numeric stats from the series to show in the stat cards.
  final values = series
      .map((m) {
        final vRaw = m['v'];
        if (vRaw is num) return vRaw.toDouble();
        return double.tryParse(vRaw?.toString() ?? '');
      })
      .where((v) => v != null)
      .cast<double>()
      .toList(growable: false);

  final bool hasData = values.isNotEmpty;
  final double currentVal = hasData ? values.last : 0.0;
  final double maxVal = hasData ? values.reduce(max) : 0.0;
  final double minVal = hasData ? values.reduce(min) : 0.0;
  return Row(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      SizedBox(
        width: 140,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(
              child: SizedBox(
                width: 140,
                child: buildStatsCard(
                  'Maximum',
                  _formatMass(maxVal),
                ),
              ),
            ),
            Expanded(
              child: SizedBox(
                width: 140,
                child: buildStatsCard(
                  'Current',
                  _formatMass(currentVal),
                ),
              ),
            ),
            Expanded(
              child: SizedBox(
                width: 140,
                child: buildStatsCard(
                  'Minimum',
                  _formatMass(minVal),
                ),
              ),
            ),
          ],
        ),
      ),
      Expanded(
        flex: 3,
        child: GlassCard(
          margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 12.0),
          child: _PressureLineChart(series: series, tareOffset: tareOffset),
        ),
      ),
      SizedBox(
        width: 140,
        child: buildControlButtons(context,
            isPaused: isPaused, onPauseToggle: onPauseToggle, onTare: onTare),
      ),
    ],
  );
}

class _PressureLineChart extends StatefulWidget {
  final List<Map<String, dynamic>> series;
  final double tareOffset;
  final bool isPaused;
  const _PressureLineChart(
      {required this.series, this.tareOffset = 0.0, this.isPaused = false});

  @override
  State<_PressureLineChart> createState() => _PressureLineChartState();
}

class _PressureLineChartState extends State<_PressureLineChart> {
  static const int _windowSize = 900; // stable X-axis window, 15Hz * 60s
  double? _displayMin;
  double? _displayMax;
  double _windowMaxX = 0.0;
  // Persistent mapping from sample id -> X coordinate so older points keep
  // their X positions and the chart appears to scroll rather than redraw.
  final Map<Object, double> _idToX = {};
  double _lastX = -1.0;

  // _isPaused removed; pausing is handled by the controls section where needed.

  List<FlSpot> _toSpots(List<Map<String, dynamic>> serie) {
    final last = serie.length;
    final start = last - _windowSize < 0 ? 0 : last - _windowSize;
    final window = serie.sublist(start, last);
    final spots = <FlSpot>[];
    final currentIds = <Object>{};
    for (var i = 0; i < window.length; i++) {
      final item = window[i];
      final idRaw = item['id'] ?? i; // fallback to index if no id
      final key = idRaw is Object ? idRaw : idRaw.toString();
      currentIds.add(key);

      final vRaw = item['v'];
      final v = vRaw is num
          ? vRaw.toDouble()
          : double.tryParse(vRaw?.toString() ?? '');
      if (v == null) continue;

      double x;
      if (_idToX.containsKey(key)) {
        x = _idToX[key]!;
      } else {
        _lastX = _lastX + 1.0;
        x = _lastX;
        _idToX[key] = x;
      }
      spots.add(FlSpot(x, v));
    }

    // Trim mapping to current window to keep memory bounded.
    final toRemove = <Object>[];
    _idToX.forEach((k, v) {
      if (!currentIds.contains(k)) toRemove.add(k);
    });
    for (final k in toRemove) {
      _idToX.remove(k);
    }

    // Window max X is the last assigned X (or fallback)
    _windowMaxX = _lastX <= 0 ? (_windowSize - 1).toDouble() : _lastX;
    // To keep the grid fixed we render the chart in a stationary X range
    // [0, _windowSize-1] and shift the sample X positions into that range.
    final windowStart = _windowMaxX <= 0
        ? 0.0
        : max(0.0, _windowMaxX - (_windowSize - 1).toDouble());

    final remapped = spots
        .map((s) => FlSpot(s.x - windowStart, s.y))
        .toList(growable: false);
    return remapped;
  }

  void _updateDisplayRange(List<FlSpot> spots) {
    if (spots.isEmpty) return;
    final minY = spots.map((s) => s.y).reduce(min);
    final maxY = spots.map((s) => s.y).reduce(max);
    final span = maxY - minY;
    final pad = span == 0 ? (maxY.abs() * 0.05 + 1.0) : (span * 0.05);

    // Default safe range is [-100, 100]. Expand only when data goes outside
    // that range, up to +/-60000 (60kg).
    // If you manage to exceed that, well, may your printer find peace.
    double targetMin;
    double targetMax;
    const double hardLimit = 60000.0;

    if (minY >= -100.0 && maxY <= 100.0) {
      // Data within default bounds: keep the simple default range
      targetMin = -100.0;
      targetMax = 100.0;
    } else {
      // Expand to include data with a small padding, but clamp to hard limits
      targetMin = max(minY - pad, -hardLimit);
      targetMax = min(maxY + pad, hardLimit);
      // Ensure we always include zero if data is near zero-ish to keep chart centered
      if (targetMin > 0) targetMin = 0;
      if (targetMax < 0) targetMax = 0;
    }

    // If the incoming data lies significantly outside the current display
    // range, expand immediately to avoid clipping spikes. Otherwise interpolate
    // more quickly than before so the chart follows changes responsively.
    const double immediateFraction =
        0.25; // fraction of current span to trigger immediate jump
    const double immediateAbs =
        200.0; // absolute threshold to trigger immediate jump
    const double smoothAlpha = 0.6; // faster smoothing than before

    if (_displayMin == null || _displayMax == null) {
      _displayMin = targetMin;
      _displayMax = targetMax;
    } else {
      final curSpan = (_displayMax! - _displayMin!).abs();
      final needImmediate = (minY <
              _displayMin! - max(immediateAbs, curSpan * immediateFraction)) ||
          (maxY >
              _displayMax! + max(immediateAbs, curSpan * immediateFraction));

      if (needImmediate) {
        // Jump immediately to include outlier(s).
        _displayMin = targetMin;
        _displayMax = targetMax;
      } else {
        // Smoothly move towards the target but faster than before.
        _displayMin = _displayMin! + (targetMin - _displayMin!) * smoothAlpha;
        _displayMax = _displayMax! + (targetMax - _displayMax!) * smoothAlpha;
      }
    }
  }

  @override
  void didUpdateWidget(covariant _PressureLineChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    final spots = _toSpots(widget.series);
    // Only update display range when not paused
    if (!widget.isPaused) {
      _updateDisplayRange(spots);
    }
  }

  @override
  Widget build(BuildContext context) {
    final spots = _toSpots(widget.series);
    if (spots.isEmpty) return const Center(child: Text('No data'));

    // Only update display range when not paused
    if (!widget.isPaused) {
      _updateDisplayRange(spots);
    }
    final displayMin = _displayMin ?? spots.map((s) => s.y).reduce(min) - 1.0;
    final displayMax = _displayMax ?? spots.map((s) => s.y).reduce(max) + 1.0;

    return LineChart(
      duration: Duration.zero,
      LineChartData(
        borderData: FlBorderData(
          border: Border.all(
            color: Colors.transparent,
          ),
        ),
        gridData: FlGridData(show: true),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        minY: displayMin,
        maxY: displayMax,
        // Fixed screen range so the grid remains stationary while the data
        // moves underneath. X runs from 0 to _windowSize-1.
        maxX: (_windowSize + 10.0).toDouble(),
        minX: -10.0,
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            gradient: LinearGradient(
              colors: [
                Colors.greenAccent,
                Colors.redAccent,
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            isCurved: true,
            isStrokeCapRound: true,
            dotData: FlDotData(show: false),
            color: Theme.of(context).colorScheme.primary,
            barWidth: 1.5,
          )
        ],
      ),
    );
  }
}

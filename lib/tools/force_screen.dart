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
import 'package:orion/glasser/glasser.dart';
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
    final prov = Provider.of<AnalyticsProvider>(context);
    final series = prov.pressureSeries.isNotEmpty
        ? prov.pressureSeries
        : prov.getSeriesForKey('Pressure');
    bool isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;
    void togglePause() {
      setState(() {
        _isPaused = !_isPaused;
      });
    }

    void doTare() {
      // Tare to the latest sample value if available
      final values = series
          .map((m) {
            final vRaw = m['v'];
            if (vRaw is num) return vRaw.toDouble();
            return double.tryParse(vRaw?.toString() ?? '');
          })
          .where((v) => v != null)
          .cast<double>()
          .toList(growable: false);
      setState(() {
        _tareOffset = values.isNotEmpty ? values.last : 0.0;
      });
    }

    return Scaffold(
      body: Padding(
        padding:
            const EdgeInsets.only(left: 12.0, right: 12.0, bottom: 6, top: 6),
        child: isLandscape
            ? buildLandscapeLayout(context, series,
                isPaused: _isPaused,
                onPauseToggle: togglePause,
                onTare: doTare,
                tareOffset: _tareOffset)
            : buildPortraitLayout(context, series,
                isPaused: _isPaused,
                onPauseToggle: togglePause,
                onTare: doTare,
                tareOffset: _tareOffset),
      ),
    );
  }
}

Widget buildStatsCard(String label, String value) {
  return GlassCard(
    child: Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 16,
                color: Colors.white70,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

String _formatMass(double grams) {
  // Show in kg when >= 1000 g, otherwise show in g.
  if (grams.abs() >= 1000.0) {
    final kg = grams / 1000.0;
    // Show kilograms with two decimal places (x.xx kg)
    return '${kg.toStringAsFixed(2)} kg';
  }
  return '${grams.toStringAsFixed(0)} g';
}

Widget buildControlButtons(BuildContext context,
    {required bool isPaused,
    required VoidCallback onPauseToggle,
    required VoidCallback onTare}) {
  final theme = Theme.of(context).copyWith(
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ButtonStyle(
        shape: WidgetStateProperty.resolveWith<OutlinedBorder?>((
          Set<WidgetState> states,
        ) {
          return RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
            side: const BorderSide(color: Colors.transparent),
          );
        }),
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
              Text(isPaused ? 'Resume' : 'Pause',
                  style: const TextStyle(fontSize: 22)),
            ],
          ),
        ),
      ),
      const SizedBox(height: 16),
      Expanded(
        child: GlassButton(
          tint: GlassButtonTint.none,
          onPressed: onTare,
          style: theme.elevatedButtonTheme.style,
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              PhosphorIcon(PhosphorIconsFill.scales, size: 40),
              SizedBox(height: 8), // Add some space between icon and label
              Text('Tare', style: TextStyle(fontSize: 24)),
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
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: _PressureLineChart(series: series, tareOffset: tareOffset),
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
        width: 130,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(
              child: SizedBox(
                width: 130,
                child: buildStatsCard(
                  'Current',
                  _formatMass(currentVal),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: SizedBox(
                width: 130,
                child: buildStatsCard(
                  'Max',
                  _formatMass(maxVal),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: SizedBox(
                width: 130,
                child: buildStatsCard(
                  'Min',
                  _formatMass(minVal),
                ),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        flex: 3,
        child: GlassCard(
          child: Padding(
            padding: const EdgeInsets.all(2.0),
            child: _PressureLineChart(series: series, tareOffset: tareOffset),
          ),
        ),
      ),
      const SizedBox(width: 12),
      SizedBox(
        width: 130,
        child: buildControlButtons(context,
            isPaused: isPaused, onPauseToggle: onPauseToggle, onTare: onTare),
      ),
    ],
  );
}

class _PressureLineChart extends StatefulWidget {
  final List<Map<String, dynamic>> series;
  final double tareOffset;
  const _PressureLineChart({required this.series, this.tareOffset = 0.0});

  @override
  State<_PressureLineChart> createState() => _PressureLineChartState();
}

class _PressureLineChartState extends State<_PressureLineChart> {
  static const int _windowSize = 600; // stable X-axis window
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
    _updateDisplayRange(spots);
  }

  Widget leftTitleWidgets(double value, TitleMeta meta) {
    const style = TextStyle(
      fontSize: 20,
    );
    String text;
    if (value == 0) {
      text = '0';
    } else if (value == _displayMin) {
      text = _displayMin!.toStringAsFixed(0);
    } else if (value == _displayMax) {
      text = _displayMax!.toStringAsFixed(0);
    } else {
      return const SizedBox.shrink();
    }

    return Text(text, style: style, textAlign: TextAlign.left);
  }

  @override
  Widget build(BuildContext context) {
    final spots = _toSpots(widget.series);
    if (spots.isEmpty) return const Center(child: Text('No data'));

    _updateDisplayRange(spots);
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
          /*leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 60,
              getTitlesWidget: leftTitleWidgets,
            ),
          ),*/
          leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        minY: displayMin,
        maxY: displayMax,
        // Fixed screen range so the grid remains stationary while the data
        // moves underneath. X runs from 0 to _windowSize-1.
        maxX: (_windowSize - 1).toDouble(),
        minX: 0.0,
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
            barWidth: 2,
          )
        ],
      ),
    );
  }
}

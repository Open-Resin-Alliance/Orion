/*
* Orion - Force Sensor Screen
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
import 'dart:math';
import 'package:async/async.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:orion/api_services/api_services.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

class ForceSensorScreen extends StatefulWidget {
  const ForceSensorScreen({super.key});

  @override
  ForceSensorScreenState createState() => ForceSensorScreenState();
}

class ForceSensorScreenState extends State<ForceSensorScreen> {
  final _logger = Logger('ForceSensor');

  final List<FlSpot> _dataPoints = [];
  Timer? _timer;
  double _xValue = 0;
  bool _isPaused = false;
  double _minY = -4;
  double _maxY = 4;
  double minBase = -0.2;
  double maxBase = 0.2;
  double minForce = -4;
  double maxForce = 4;
  double _minX = 0;
  double _maxX = 100; // Adjust this value based on the desired visible range

  @override
  void initState() {
    super.initState();
    _startUpdatingData();
  }

  /// Starts the timer to periodically update the data points.
  void _startUpdatingData() {
    _logger.info('Start data acquisition');
    _timer = Timer.periodic(const Duration(milliseconds: 200), (timer) {
      if (!_isPaused) {
        setState(() {
          _xValue += 1;
          double y = Random().nextDouble() * 0.4 -
              0.2; // Base calm line between -0.2 and 0.2
          if (_xValue % 20 == 0) {
            y = 3.2 +
                Random().nextDouble() *
                    0.6; // Occasional spikes between 3.2 and 3.8
          }
          if (_xValue % 40 == 0) {
            y = -3.2 -
                Random().nextDouble() *
                    0.6; // Occasional dips between -3.2 and -3.8
          }
          if (_dataPoints.length > 100) {
            _dataPoints.removeAt(0); // Keep the list size constant
          }
          _dataPoints.add(FlSpot(_xValue, y));
          _updateYAxisRange();
          _updateXAxisRange();
        });
      }
    });
  }

  /// Clears the chart data and resets the x-axis values.
  void _clearChart() {
    setState(() {
      _dataPoints.clear();
      _xValue = 0;
      _minX = 0;
      _maxX = 100; // Reset to initial values
    });
  }

  /// Toggles the pause state of the data update.
  void _togglePause() {
    setState(() {
      _isPaused = !_isPaused;
    });
  }

  /// Updates the y-axis range based on the current data points.
  void _updateYAxisRange() {
    if (_dataPoints.isNotEmpty) {
      _minY = _dataPoints.map((spot) => spot.y).reduce(min) - 0.5;
      _maxY = _dataPoints.map((spot) => spot.y).reduce(max) + 0.5;
    }
  }

  /// Updates the x-axis range to keep the latest data points visible.
  void _updateXAxisRange() {
    if (_xValue > _maxX) {
      _minX = _xValue - 100;
      _maxX = _xValue;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  /// Builds the left title widgets for the y-axis.
  Widget leftTitleWidgets(double value, TitleMeta meta) {
    const style = TextStyle(
      fontSize: 22,
    );

    String text;

    value = double.parse(value.toStringAsFixed(1));

    if (value == 0 ||
        (value == double.parse(maxForce.toStringAsFixed(1)) &&
            value > maxBase + 0.1) ||
        (value == double.parse(minForce.toStringAsFixed(1)) &&
            value < minBase - 0.1)) {
      text = '${value.toStringAsFixed(1)}N';
    } else {
      return Container();
    }

    return Text(text, style: style, textAlign: TextAlign.left);
  }

  @override
  Widget build(BuildContext context) {
    bool isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.only(left: 16.0, right: 16.0),
        child: isLandscape
            ? buildLandscapeLayout(context)
            : buildPortraitLayout(context),
      ),
    );
  }

  /// Builds the layout for landscape orientation.
  Widget buildLandscapeLayout(BuildContext context) {
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: buildGraphCard(context),
        ),
        const SizedBox(width: 16),
        Expanded(
          flex: 1,
          child: buildControlButtons(context),
        ),
      ],
    );
  }

  /// Builds the layout for portrait orientation.
  Widget buildPortraitLayout(BuildContext context) {
    return Column(
      children: [
        Expanded(
          flex: 1,
          child: buildGraphCard(context),
        ),
        const SizedBox(height: 16),
        Expanded(
          flex: 1,
          child: buildControlButtons(context),
        ),
      ],
    );
  }

  /// Builds the graph card widget.
  Widget buildGraphCard(BuildContext context) {
    if (_dataPoints.isNotEmpty) {
      minBase = _dataPoints
          .where((spot) => spot.y >= -0.2 && spot.y <= 0.2)
          .map((spot) => spot.y)
          .reduce((value, element) => value < element ? value : element);
      maxBase = _dataPoints
          .where((spot) => spot.y >= -0.2 && spot.y <= 0.2)
          .map((spot) => spot.y)
          .reduce((value, element) => value > element ? value : element);
      minForce = _dataPoints.isNotEmpty
          ? min(_dataPoints.map((spot) => spot.y).reduce(min), minBase)
          : -4;
      maxForce = _dataPoints.isNotEmpty
          ? max(_dataPoints.map((spot) => spot.y).reduce(max), maxBase)
          : 4;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: LineChart(
          LineChartData(
            lineBarsData: [
              LineChartBarData(
                spots:
                    _dataPoints.isNotEmpty ? _dataPoints : [const FlSpot(0, 0)],
                isCurved: true,
                barWidth: 2,
                isStrokeCapRound: true,
                dotData: const FlDotData(show: false),
                gradient: LinearGradient(
                  colors: [
                    Colors.greenAccent,
                    Theme.of(context).colorScheme.secondary,
                    Colors.redAccent,
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ],
            titlesData: FlTitlesData(
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 60,
                  interval: 0.1,
                  getTitlesWidget: leftTitleWidgets,
                ),
              ),
              rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              bottomTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
            ),
            borderData: FlBorderData(
                show: true,
                border: Border.all(
                  color: Theme.of(context).colorScheme.secondaryContainer,
                  width: 2,
                )),
            gridData: const FlGridData(show: true),
            minX: _minX,
            maxX: _maxX,
            minY: _minY,
            maxY: _maxY,
            extraLinesData: ExtraLinesData(
              horizontalLines: [
                // Lower Base Line
                if (_dataPoints.isNotEmpty &&
                    _dataPoints.any((spot) => spot.y >= -0.2 && spot.y <= 0.2))
                  HorizontalLine(
                    y: minBase,
                    color: Theme.of(context)
                        .colorScheme
                        .secondary
                        .withOpacity(0.65),
                    strokeWidth: 2,
                    dashArray: [5, 5],
                  ),
                // Upper Base Line
                if (_dataPoints.isNotEmpty &&
                    _dataPoints.any((spot) => spot.y >= -0.2 && spot.y <= 0.2))
                  HorizontalLine(
                    y: maxBase,
                    color: Theme.of(context)
                        .colorScheme
                        .secondary
                        .withOpacity(0.65),
                    strokeWidth: 2,
                    dashArray: [5, 5],
                  ),
                // Pull Line
                if (_dataPoints.isNotEmpty)
                  HorizontalLine(
                    y: maxForce,
                    color: Colors.greenAccent.withOpacity(0.65),
                    strokeWidth: 2,
                    dashArray: [5, 5],
                  ),
                // Push Line
                if (_dataPoints.isNotEmpty)
                  HorizontalLine(
                    y: minForce,
                    color: Colors.redAccent.withOpacity(0.65),
                    strokeWidth: 2,
                    dashArray: [5, 5],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Builds the control buttons widget.
  Widget buildControlButtons(BuildContext context) {
    final theme = Theme.of(context).copyWith(
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ButtonStyle(
          shape: WidgetStateProperty.resolveWith<OutlinedBorder?>(
            (Set<WidgetState> states) {
              return RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                  side: const BorderSide(color: Colors.transparent));
            },
          ),
          minimumSize: WidgetStateProperty.resolveWith<Size?>(
            (Set<WidgetState> states) {
              return const Size(double.infinity, double.infinity);
            },
          ),
        ),
      ),
    );

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Expanded(
          child: ElevatedButton(
            onPressed: _togglePause,
            style: theme.elevatedButtonTheme.style,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _isPaused
                    ? const PhosphorIcon(
                        PhosphorIconsFill.play,
                        size: 40,
                      )
                    : const PhosphorIcon(
                        PhosphorIconsFill.pause,
                        size: 40,
                      ),
                const SizedBox(
                    height: 8), // Add some space between the icon and the label
                Text(
                  _isPaused ? 'Resume' : 'Pause',
                  style: const TextStyle(
                    fontSize: 24,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: ElevatedButton(
            onPressed: _clearChart,
            style: theme.elevatedButtonTheme.style,
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                PhosphorIcon(
                  PhosphorIconsFill.trashSimple,
                  size: 40,
                ),
                SizedBox(
                    height: 8), // Add some space between the icon and the label
                Text(
                  'Clear',
                  style: TextStyle(
                    fontSize: 24,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// Clean AnalyticsProvider implementation
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:orion/backend_service/backend_client.dart';
import 'package:orion/backend_service/backend_service.dart';
import 'package:orion/util/orion_config.dart';
import 'package:orion/backend_service/nanodlp/helpers/nano_analytics_config.dart';

class AnalyticsProvider extends ChangeNotifier {
  final BackendClient _client;
  final Logger _log = Logger('AnalyticsProvider');

  AnalyticsProvider({BackendClient? client})
      : _client = client ?? BackendService() {
    _start();
  }

  Map<String, dynamic>? _analytics;
  Map<String, dynamic>? get analytics => _analytics;

  bool _loading = true;
  bool get isLoading => _loading;

  Object? _error;
  Object? get error => _error;

  static const int _pressureId = 6;

  final List<Map<String, dynamic>> _pressureSeries = [];
  List<Map<String, dynamic>> get pressureSeries =>
      List.unmodifiable(_pressureSeries);

  // Cache for other analytics values (non-pressure)
  final Map<int, dynamic> _otherAnalyticsCache = {};

  // High-frequency polling for pressure sensor
  int pressurePollIntervalHertz = 15; // 15 Hz for pressure
  double get _pressurePollIntervalMs => 1000.0 / pressurePollIntervalHertz;
  int get _maxPressureSamples => (60 * pressurePollIntervalHertz); // 1 minute

  // Low-frequency polling for other analytics (temperature, etc.)
  int otherAnalyticsPollIntervalHertz =
      2; // 2 Hz for temperatures and other metrics

  int _otherAnalyticsCounter = 0;

  bool _disposed = false;
  bool _polling = false;

  void _start() {
    if (_polling || _disposed) return;
    _polling = true;
    () async {
      while (!_disposed && _polling) {
        final before = DateTime.now();
        await _pollOnce();
        final took = DateTime.now().difference(before).inMilliseconds;
        final wait = _pressurePollIntervalMs - took;
        if (wait > 0) {
          try {
            await Future.delayed(Duration(milliseconds: wait.toInt()));
          } catch (_) {}
        }
      }
      _polling = false;
    }();
  }

  /// Public trigger to immediately refresh analytics once.
  Future<void> refresh() async {
    if (_disposed) return;
    await _pollOnce();
  }

  Future<void> _pollOnce() async {
    if (_disposed) return;
    _loading = true;
    try {
      final cfg = OrionConfig();
      if (cfg.isNanoDlpMode()) {
        // Always fetch pressure at high frequency
        final Map<int, dynamic> fetchedValues = {};

        try {
          final pressureVal = await _client.getAnalyticValue(_pressureId);
          if (pressureVal != null) {
            fetchedValues[_pressureId] = pressureVal;
          }
        } catch (e) {
          _log.fine('Failed to fetch pressure value', e);
        }

        // Fetch other analytics at lower frequency (every Nth poll)
        _otherAnalyticsCounter++;
        final shouldFetchOthers = _otherAnalyticsCounter >=
            (pressurePollIntervalHertz / otherAnalyticsPollIntervalHertz)
                .round();

        if (shouldFetchOthers) {
          _otherAnalyticsCounter = 0;

          // Fetch all available analytics via batch endpoint
          try {
            final list = await _client.getAnalytics(20);
            for (final item in list) {
              final tRaw = item['T'];
              final tid =
                  tRaw is int ? tRaw : int.tryParse(tRaw?.toString() ?? '');
              if (tid == null || tid == _pressureId) {
                continue; // Skip pressure, we fetch it separately
              }

              final vRaw = item['V'];
              final num? v =
                  vRaw is num ? vRaw : double.tryParse(vRaw?.toString() ?? '');
              if (v != null) {
                _otherAnalyticsCache[tid] = v; // Cache the value
              }
            }
          } catch (e) {
            _log.fine('Failed to fetch other analytics', e);
          }
        }

        // Process pressure value for series
        if (fetchedValues.containsKey(_pressureId)) {
          final val = fetchedValues[_pressureId];
          final num? v = (val is num) ? val : double.tryParse(val.toString());
          if (v != null) {
            final id = DateTime.now().millisecondsSinceEpoch;
            _pressureSeries.add({'id': id, 'v': v});
            if (_pressureSeries.length > _maxPressureSamples) {
              _pressureSeries.removeRange(
                  0, _pressureSeries.length - _maxPressureSamples);
            }
          }
        }

        // Build analytics map with all fetched values
        final nanoAnalytics = <int, dynamic>{};

        // Add pressure series (always updated)
        if (_pressureSeries.isNotEmpty) {
          nanoAnalytics[_pressureId] =
              List<Map<String, dynamic>>.from(_pressureSeries);
        }

        // Add all cached analytics values as single-item arrays for consistency
        _otherAnalyticsCache.forEach((id, val) {
          final num? v = (val is num) ? val : double.tryParse(val.toString());
          if (v != null) {
            nanoAnalytics[id] = [
              {'id': DateTime.now().millisecondsSinceEpoch, 'v': v}
            ];
          }
        });

        // Always update analytics if we have any data
        if (nanoAnalytics.isNotEmpty) {
          _analytics = {'nano_analytics': nanoAnalytics};
          _error = null;
        }

        _loading = false;
        if (!_disposed) notifyListeners();
        return;
      } else {
        final raw = await _client.getStatus();
        _analytics = raw;
        _error = null;
        _loading = false;
        if (!_disposed) notifyListeners();
        return;
      }
    } catch (e, st) {
      _log.fine('Analytics poll failed', e, st);
      _error = e;
      _loading = false;
      if (!_disposed) notifyListeners();
    }
  }

  Map<String, List<Map<String, dynamic>>> get analyticsByKey {
    final a = _analytics;
    if (a == null) return {};
    if (a.containsKey('nano_analytics')) {
      try {
        final Map<int, List<Map<String, dynamic>>> byId =
            Map<int, List<Map<String, dynamic>>>.from(a['nano_analytics']);
        final mapped = <String, List<Map<String, dynamic>>>{};
        byId.forEach((id, list) {
          final key = idToKey(id) ?? id.toString();
          mapped[key] = List<Map<String, dynamic>>.from(list);
        });
        return mapped;
      } catch (_) {
        return {};
      }
    }
    return {};
  }

  List<Map<String, dynamic>> getSeriesForKey(String key) =>
      analyticsByKey[key] ?? [];

  dynamic getLatestForKey(String key) {
    final s = getSeriesForKey(key);
    if (s.isEmpty) return null;
    return s.last['v'];
  }

  @override
  void dispose() {
    _disposed = true;
    _polling = false;
    super.dispose();
  }
}

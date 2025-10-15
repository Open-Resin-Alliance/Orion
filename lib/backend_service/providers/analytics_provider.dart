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

  int pollIntervalHertz = 10; // 10 Hz
  double get pollIntervalMilliseonds => 1000.0 / pollIntervalHertz;
  int get _maxPressureSamples => (60 * pollIntervalHertz); // 1 minute

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
        final wait = pollIntervalMilliseonds - took;
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
        // Fast path: scalar endpoint
        try {
          final val = await _client.getAnalyticValue(_pressureId);
          if (val != null) {
            final num? v = (val is num) ? val : double.tryParse(val.toString());
            if (v != null) {
              final id = DateTime.now().millisecondsSinceEpoch;
              _pressureSeries.add({'id': id, 'v': v});
              if (_pressureSeries.length > _maxPressureSamples) {
                _pressureSeries.removeRange(
                    0, _pressureSeries.length - _maxPressureSamples);
              }
              _analytics = {
                'nano_analytics': {
                  _pressureId: List<Map<String, dynamic>>.from(_pressureSeries)
                }
              };
              _error = null;
              _loading = false;
              if (!_disposed) notifyListeners();
              return;
            }
          }
        } catch (e, st) {
          _log.fine('getAnalyticValue failed', e, st);
        }

        // Fallback: batch analytics
        try {
          final list = await _client.getAnalytics(20);
          final newPressure = <Map<String, dynamic>>[];
          for (final item in list) {
            final tRaw = item['T'];
            final tid =
                tRaw is int ? tRaw : int.tryParse(tRaw?.toString() ?? '');
            if (tid != _pressureId) continue;
            final idRaw = item['ID'];
            final vRaw = item['V'];
            final id = idRaw is int
                ? idRaw
                : int.tryParse(idRaw?.toString() ?? '') ??
                    DateTime.now().millisecondsSinceEpoch;
            final num? v =
                vRaw is num ? vRaw : double.tryParse(vRaw?.toString() ?? '');
            if (v == null) continue;
            newPressure.add({'id': id, 'v': v});
          }
          if (newPressure.isNotEmpty) {
            _pressureSeries.clear();
            _pressureSeries.addAll(newPressure);
            _analytics = {
              'nano_analytics': {
                _pressureId: List<Map<String, dynamic>>.from(_pressureSeries)
              }
            };
            _error = null;
            _loading = false;
            if (!_disposed) notifyListeners();
            return;
          }
        } catch (e, st) {
          _log.fine('getAnalytics fallback failed', e, st);
        }

        _loading = false;
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

/*
 * Orion - Analytics Provider
 *
 * Lightweight provider that fetches recent analytics/telemetry snapshots
 * from the backend. For NanoDLP we poll at a fixed interval (polling-only
 * backends). For Odyssey we attempt to subscribe to an SSE-style stream
 * and fall back to polling on error.
 */
import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:orion/backend_service/backend_service.dart';
import 'package:orion/backend_service/backend_client.dart';
import 'package:orion/util/orion_config.dart';
import 'package:orion/backend_service/nanodlp/helpers/nano_analytics_config.dart';

class AnalyticsProvider extends ChangeNotifier {
  final BackendClient _client;
  final _log = Logger('AnalyticsProvider');

  Map<String, dynamic>? _analytics;
  Map<String, dynamic>? get analytics => _analytics;

  /// Convenience map: when NanoDLP analytics are present this contains a
  /// mapping from metric key (e.g. 'Pressure') to list of {id, v} entries.
  Map<String, List<Map<String, dynamic>>> get analyticsByKey {
    final a = _analytics;
    if (a == null) return {};
    if (a.containsKey('nano_analytics')) {
      try {
        final Map<int, List<Map<String, dynamic>>> byId =
            Map<int, List<Map<String, dynamic>>>.from(a['nano_analytics']);
        final Map<String, List<Map<String, dynamic>>> mapped = {};
        byId.forEach((id, list) {
          final key = idToKey(id) ?? id.toString();
          mapped[key] = list;
        });
        return mapped;
      } catch (_) {
        return {};
      }
    }
    return {};
  }

  List<Map<String, dynamic>> getSeriesForKey(String key) {
    return analyticsByKey[key] ?? [];
  }

  dynamic getLatestForKey(String key) {
    final series = getSeriesForKey(key);
    if (series.isEmpty) return null;
    final last = series.last;
    return last['v'];
  }

  bool _loading = true;
  bool get isLoading => _loading;

  Object? _error;
  Object? get error => _error;

  bool _disposed = false;

  // Polling state
  bool _polling = false;
  int _pollIntervalSeconds = 5;
  static const int _minPollIntervalSeconds = 2;
  static const int _maxPollIntervalSeconds = 60;
  int _consecutiveErrors = 0;
  bool _fetchInFlight = false;

  // SSE state
  bool _sseConnected = false;
  StreamSubscription<Map<String, dynamic>>? _sseSub;

  AnalyticsProvider({BackendClient? client})
      : _client = client ?? BackendService() {
    // Try SSE when appropriate; NanoDLP is polling-only so it will skip.
    _tryStartSse();
  }

  void _startPolling() {
    if (_polling || _sseConnected || _disposed) return;
    _polling = true;
    Future(() async {
      try {
        await refresh();
        while (!_disposed && _polling && !_sseConnected) {
          try {
            await Future.delayed(Duration(seconds: _pollIntervalSeconds));
          } catch (_) {}
          if (_disposed || !_polling || _sseConnected) break;
          await refresh();
        }
      } finally {
        _polling = false;
      }
    });
  }

  Future<void> _tryStartSse() async {
    if (_sseConnected || _disposed) return;
    try {
      final cfg = OrionConfig();
      final isNano = cfg.isNanoDlpMode();
      if (isNano) {
        _log.fine('NanoDLP mode: AnalyticsProvider using polling');
        _startPolling();
        return;
      }
    } catch (_) {
      // ignore and attempt SSE as a best-effort
    }

    _log.fine(
        'Attempting Analytics SSE subscription via BackendClient.getStatusStream');
    try {
      final stream = _client.getStatusStream();
      _sseConnected = true;
      _sseSub = stream.listen((raw) {
        try {
          // The status stream may include periodic telemetry; treat the
          // incoming status object as the latest analytics snapshot.
          _analytics = raw;
          _error = null;
          _loading = false;
        } catch (e) {
          _log.warning('Failed to handle analytics SSE payload', e);
        }
        if (!_disposed) notifyListeners();
      }, onError: (err, st) {
        _log.warning(
            'Analytics SSE stream error, falling back to polling', err, st);
        _closeSse();
        if (!_disposed) _startPolling();
      }, onDone: () {
        _log.info(
            'Analytics SSE stream closed by server; falling back to polling');
        _closeSse();
        if (!_disposed) _startPolling();
      }, cancelOnError: true);
    } catch (e) {
      _log.info('Analytics SSE subscription failed; using polling', e);
      _sseConnected = false;
      if (!_disposed) _startPolling();
    }
  }

  void _closeSse() {
    _sseConnected = false;
    try {
      _sseSub?.cancel();
    } catch (_) {}
    _sseSub = null;
  }

  Future<void> refresh() async {
    if (_fetchInFlight || _disposed) return;
    _fetchInFlight = true;
    final startedAt = DateTime.now();
    try {
      // If configured for NanoDLP, use the NanoDLP-specific analytics
      // endpoint which returns a list of recent analytic samples.
      try {
        final cfg = OrionConfig();
        if (cfg.isNanoDlpMode()) {
          final list = await _client.getAnalytics(200);
          // Normalize into a map keyed by the metric id (T) -> list of
          // {id: timestamp, v: value} entries for easier consumption.
          final Map<int, List<Map<String, dynamic>>> grouped = {};
          for (final item in list) {
            try {
              final t = item['T'];
              final id = item['ID'];
              final v = item['V'];
              final tid = t is int ? t : int.tryParse(t?.toString() ?? '');
              if (tid == null) continue;
              grouped.putIfAbsent(tid, () => []).add({'id': id, 'v': v});
            } catch (_) {
              continue;
            }
          }
          _analytics = {'nano_analytics': grouped};
        } else {
          final raw = await _client.getStatus();
          _analytics = raw;
        }
      } catch (e) {
        // Fall back to status snapshot if analytics endpoint fails.
        final raw = await _client.getStatus();
        _analytics = raw;
      }
      _error = null;
      _loading = false;
      _consecutiveErrors = 0;
      _pollIntervalSeconds = _minPollIntervalSeconds;
      if (!_disposed) notifyListeners();
    } catch (e) {
      _log.warning('Analytics refresh failed', e);
      _error = e;
      _loading = false;
      _consecutiveErrors = min(_consecutiveErrors + 1, 1000);
      final backoff = _computeBackoff(_consecutiveErrors,
          base: _minPollIntervalSeconds, max: _maxPollIntervalSeconds);
      _pollIntervalSeconds = backoff;
      _log.fine(
          'Backing off analytics polling for ${backoff}s (attempt $_consecutiveErrors)');
    } finally {
      _fetchInFlight = false;
      if (!_disposed) {
        final elapsed = DateTime.now().difference(startedAt);
        _log.finer('Analytics refresh took ${elapsed.inMilliseconds}ms');
      }
    }
  }

  int _computeBackoff(int attempts, {required int base, required int max}) {
    final raw = base * pow(2, attempts);
    int secs = raw.toInt();
    if (secs > max) secs = max;
    final rand = Random();
    final jitter = rand.nextInt((secs ~/ 2) + 1);
    secs = secs + jitter;
    if (secs > max) secs = max;
    return secs;
  }

  @override
  void dispose() {
    _disposed = true;
    _closeSse();
    _polling = false;
    super.dispose();
  }
}

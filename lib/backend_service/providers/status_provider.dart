/*
* Orion - Status Provider
* Centralized state management & polling for printer status.
* Converts raw API maps into strongly-typed models and exposes
* derived UI-friendly properties & transition flags.
*/

import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:orion/backend_service/odyssey/odyssey_client.dart';
import 'package:orion/backend_service/backend_service.dart';
import 'package:orion/util/orion_config.dart';
import 'package:orion/backend_service/odyssey/models/status_models.dart';
import 'package:orion/util/sl1_thumbnail.dart';

/// Polls the backend printer `/status` endpoint and exposes a typed [StatusModel].
///
/// Handles:
/// * 1 Hz polling with simple re-entrancy guard
/// * Transitional UI flags (pause / cancel) to avoid flicker between user action
///   and backend state acknowledgment
/// * Lazy thumbnail extraction for current print file
/// * Derived convenience accessors used by UI widgets
class StatusProvider extends ChangeNotifier {
  final OdysseyClient _client;
  final _log = Logger('StatusProvider');

  StatusModel? _status;
  StatusModel? get status => _status;

  bool _loading = true;
  bool get isLoading => _loading;

  Object? _error;
  Object? get error => _error;

  bool _isCanceling =
      false; // UI transitional state until backend reflects cancel
  bool get isCanceling => _isCanceling;
  bool _isPausing =
      false; // UI transitional state until backend reflects pause/resume
  bool get isPausing => _isPausing;

  // Awaiting state: after a cancel/finish & reset, we keep the UI in a loading
  // spinner until we observe a NEW active print (Printing or Paused) AND the
  // thumbnail is considered ready. We do not attempt to guess by filename so
  // re-printing the same file still forces a clean re-wait.
  bool _awaitingNewPrintData = false;
  DateTime? _awaitingSince; // timestamp we began waiting for coherent data
  bool get awaitingNewPrintData => _awaitingNewPrintData;
  static const Duration _awaitingTimeout = Duration(seconds: 12);
  // We deliberately removed expected file name gating; re-printing the same
  // file should still show a clean loading phase.

  String? _thumbnailPath;
  String? get thumbnailPath => _thumbnailPath;
  bool _thumbnailReady =
      false; // becomes true once we have a path OR decide none needed
  bool get thumbnailReady => _thumbnailReady;

  /// Readiness for displaying a new print after a reset.
  /// Requirements:
  /// * Printer is actively printing or paused (job started)
  /// * We have printData with fileData (metadata populated)
  /// * Thumbnail attempt completed (success OR failed => _thumbnailReady true)
  bool get newPrintReady {
    final s = _status;
    if (s == null) return false;
    final active = s.isPrinting || s.isPaused;
    final hasFile = s.printData?.fileData != null;
    return active && hasFile && _thumbnailReady;
  }

  Timer? _timer;
  bool _polling = false;
  int _pollIntervalSeconds = 1;
  static const int _minPollIntervalSeconds = 1;
  static const int _maxPollIntervalSeconds = 15;
  // SSE reconnect tuning: aggressive base retry for local devices + small jitter.
  static const int _sseReconnectBaseSeconds = 3;
  static const int _sseReconnectJitterSeconds = 2; // +/- jitter window
  bool _fetchInFlight = false;
  bool _disposed = false;

  // SSE (Server-Sent Events) client state. When streaming is active we
  // rely on incoming events instead of the periodic polling loop.
  bool _sseConnected = false;
  StreamSubscription<Map<String, dynamic>>? _sseStreamSub;

  StatusProvider({OdysseyClient? client})
      : _client = client ?? BackendService() {
    // Prefer an SSE subscription when the backend supports it. If the
    // connection fails we fall back to the existing polling loop.
    _tryStartSse();
  }

  void _startPolling() {
    // Start an async polling loop that adapts interval on errors.
    // The loop is cancelable via [_polling] so that when an SSE stream
    // becomes active we can stop polling to avoid duplicate requests.
    if (_polling || _sseConnected || _disposed) return;
    _polling = true;
    Future<void>(() async {
      try {
        await refresh();
        while (!_disposed && _polling && !_sseConnected) {
          try {
            await Future.delayed(Duration(seconds: _pollIntervalSeconds));
          } catch (_) {
            // ignore
          }
          if (_disposed || !_polling || _sseConnected) break;
          await refresh();
        }
      } finally {
        // Ensure flag is cleared when the loop exits for any reason.
        _polling = false;
      }
    });
  }

  /// Attempt to connect to the SSE status stream at `/status/stream`.
  /// If successful we listen for events and update state from incoming
  /// JSON payloads. On failure we fall back to polling and schedule a
  /// reconnection attempt after [_maxPollIntervalSeconds].
  Future<void> _tryStartSse() async {
    if (_sseConnected || _disposed) return;
    // If configured for NanoDLP (developer override or backend config) the
    // NanoDLP adapter is polling-only and does not support SSE. Avoid
    // attempting to establish an SSE subscription in that case.
    try {
      final cfg = OrionConfig();
      final backend = cfg.getString('backend', category: 'advanced');
      final devNano = cfg.getFlag('nanoDLPmode', category: 'developer');
      if (backend == 'nanodlp' || devNano) {
        _log.info(
            'Backend is NanoDLP; skipping SSE subscription and using polling');
        _startPolling();
        return;
      }
    } catch (_) {
      // If config read fails, proceed to attempt SSE as a best-effort.
    }

    _log.info('Attempting SSE subscription via OdysseyClient.getStatusStream');
    try {
      final stream = _client.getStatusStream();
      // When SSE becomes active, cancel any existing polling loop so we rely
      // on the event stream instead of periodic polling.
      _sseConnected = true;
      _polling = false;

      _sseStreamSub = stream.listen((raw) async {
        try {
          final parsed = StatusModel.fromJson(raw);

          // Lazy thumbnail acquisition (same rules as refresh)
          if (parsed.isPrinting && _thumbnailPath == null && !_thumbnailReady) {
            final fileData = parsed.printData?.fileData;
            if (fileData != null) {
              final path = fileData.path;
              // Use empty string for default (root) directory. Previously we
              // used '/', which resulted in '/filename' being requested from
              // the API and caused thumbnail fetches to fail for root files.
              String subdir = '';
              if (path.contains('/')) {
                subdir = path.substring(0, path.lastIndexOf('/'));
              }
              try {
                _thumbnailPath = await ThumbnailUtil.extractThumbnail(
                  fileData.locationCategory ?? 'Local',
                  subdir,
                  fileData.name,
                  size: 'Large',
                );
                _thumbnailReady = true;
              } catch (e, st) {
                _log.warning('Thumbnail fetch failed (SSE)', e, st);
                _thumbnailReady = true;
              }
            }
          }

          _status = parsed;
          _error = null;
          _loading = false;
          _pollIntervalSeconds = _minPollIntervalSeconds;
        } catch (e, st) {
          _log.warning('Failed to handle SSE payload', e, st);
        }
        if (!_disposed) notifyListeners();
      }, onError: (err, st) {
        _log.warning('SSE stream error, falling back to polling', err, st);
        _closeSse();
        if (!_disposed) _startPolling();
        // Schedule aggressive reconnection attempts with jitter while we
        // continue polling.
        final rand = Random();
        final jitter = rand.nextInt(_sseReconnectJitterSeconds + 1);
        final delaySec = _sseReconnectBaseSeconds + jitter;
        Future.delayed(Duration(seconds: delaySec), () {
          if (!_sseConnected && !_disposed) _tryStartSse();
        });
      }, onDone: () {
        _log.info('SSE stream closed by server; falling back to polling');
        _closeSse();
        if (!_disposed) _startPolling();
        // Schedule aggressive reconnection attempts with jitter while we
        // continue polling.
        final rand = Random();
        final jitter = rand.nextInt(_sseReconnectJitterSeconds + 1);
        final delaySec = _sseReconnectBaseSeconds + jitter;
        Future.delayed(Duration(seconds: delaySec), () {
          if (!_sseConnected && !_disposed) _tryStartSse();
        });
      }, cancelOnError: true);
    } catch (e, st) {
      _log.info('SSE subscription failed; using polling', e, st);
      _sseConnected = false;
      if (!_disposed) _startPolling();
      // Schedule an aggressive reconnect attempt with jitter. For a local
      // printer API we expect very few clients, so retry quickly.
      final rand = Random();
      final jitter = rand.nextInt(_sseReconnectJitterSeconds + 1);
      final delaySec = _sseReconnectBaseSeconds + jitter;
      Future.delayed(Duration(seconds: delaySec), () {
        if (!_sseConnected && !_disposed) _tryStartSse();
      });
    }
  }

  void _closeSse() {
    _sseConnected = false;
    try {
      _sseStreamSub?.cancel();
    } catch (_) {}
    _sseStreamSub = null;
    // Event buffer removed; nothing to clear here.
  }

  /// Fetch latest status from backend. Re-entrancy guarded with [_fetchInFlight]
  Future<void> refresh() async {
    if (_fetchInFlight) return; // simple re-entrancy guard
    _fetchInFlight = true;
    try {
      final raw = await _client.getStatus();
      final parsed = StatusModel.fromJson(raw);

      // Attempt lazy thumbnail acquisition (only while printing and not yet fetched)
      if (parsed.isPrinting && _thumbnailPath == null && !_thumbnailReady) {
        final fileData = parsed.printData?.fileData;
        if (fileData != null) {
          final path = fileData.path;
          // Use empty string for default (root) directory to match how
          // ThumbnailUtil expects an absent subdirectory.
          String subdir = '';
          if (path.contains('/')) {
            subdir = path.substring(0, path.lastIndexOf('/'));
          }
          try {
            _thumbnailPath = await ThumbnailUtil.extractThumbnail(
              fileData.locationCategory ?? 'Local',
              subdir,
              fileData.name,
              size: 'Large',
            );
            _thumbnailReady = true;
          } catch (e, st) {
            _log.warning('Thumbnail fetch failed', e, st);
            // Even on failure we mark ready to avoid indefinite spinner.
            _thumbnailReady = true;
          }
        }
      }
      // NOTE: We no longer mark thumbnail ready when not printing; we explicitly
      // wait for an active job (printing/paused) so a reprint of the same file
      // still forces a clean spinner until the job restarts.

      _status = parsed;
      _error = null;
      _loading = false;

      // Successful refresh -> shorten polling interval
      _pollIntervalSeconds = _minPollIntervalSeconds;

      if (_awaitingNewPrintData) {
        final timedOut = _awaitingSince != null &&
            DateTime.now().difference(_awaitingSince!) > _awaitingTimeout;
        if (newPrintReady || timedOut) {
          _awaitingNewPrintData = false;
          _awaitingSince = null;
        }
      }

      // Clear transitional flags when backend state matches
      if (_isPausing && parsed.isPaused) _isPausing = false;
      if (_isCanceling && parsed.isCanceled) _isCanceling = false;
    } catch (e, st) {
      _log.severe('Status refresh failed', e, st);
      _error = e;
      _loading = false;
      // On failure, back off polling frequency
      _pollIntervalSeconds = _maxPollIntervalSeconds;
    } finally {
      _fetchInFlight = false;
      if (!_disposed) notifyListeners();
    }
  }

  // --- Derived UI convenience ---
  String get displayStatus =>
      _status?.displayLabel(
        transitionalCancel: _isCanceling,
        transitionalPause: _isPausing,
      ) ??
      'Unknown';

  double get progress => _status?.progress ?? 0.0;

  Color statusColor(BuildContext context) =>
      _status?.statusColor(
        context,
        transitionalPause: _isPausing,
        transitionalCancel: _isCanceling,
      ) ??
      Colors.grey;

  // --- Actions ---
  /// Toggle between pause and resume depending on current backend state.
  Future<void> pauseOrResume() async {
    final s = _status;
    if (s == null) return;
    if (s.isPaused) {
      // resume
      if (_isPausing) return; // already in transition
      _isPausing = true;
      notifyListeners();
      try {
        await _client.resumePrint();
      } catch (e, st) {
        _log.severe('Resume failed', e, st);
        _isPausing = false; // revert transitional flag
      } finally {
        refresh();
      }
    } else {
      // pause
      if (_isPausing) return;
      _isPausing = true;
      notifyListeners();
      try {
        await _client.pausePrint();
      } catch (e, st) {
        _log.severe('Pause failed', e, st);
        _isPausing = false;
      } finally {
        refresh();
      }
    }
  }

  /// Initiate print cancel action. Transitional flag cleared once backend reflects.
  Future<void> cancel() async {
    if (_isCanceling) return;
    _isCanceling = true;
    notifyListeners();
    try {
      await _client.cancelPrint();
    } catch (e, st) {
      _log.severe('Cancel failed', e, st);
      // keep flag (still canceling) to avoid flicker; will clear when API reflects
    } finally {
      refresh();
    }
  }

  /// Clear current status so UI shows a neutral/loading state prior to the
  /// next print starting. Polling continues and will repopulate on refresh.
  void resetStatus() {
    _status = null;
    _thumbnailPath = null;
    _thumbnailReady = false;
    _error = null;
    _loading = true; // so consumer screens can show a spinner if they mount
    _isCanceling = false;
    _isPausing = false;
    _awaitingNewPrintData = true; // begin awaiting active print
    _awaitingSince = DateTime.now();
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    super.dispose();
  }
}

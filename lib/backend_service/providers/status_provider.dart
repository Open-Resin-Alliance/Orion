/*
* Orion - Status Provider
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
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:orion/backend_service/odyssey/odyssey_client.dart';
import 'package:orion/backend_service/backend_service.dart';
import 'package:orion/util/orion_config.dart';
import 'package:orion/backend_service/odyssey/models/status_models.dart';
import 'dart:typed_data';
import 'package:orion/util/thumbnail_cache.dart';
import 'package:orion/util/orion_api_filesystem/orion_api_file.dart';

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
  String? _deviceStatusMessage;

  /// Optional raw device-provided status message (e.g. NanoDLP "Status"
  /// field). When present this may be used to override the app bar title
  /// on the `StatusScreen` so device-provided messages like
  /// "Peel Detection Started" are surfaced directly.
  String? get deviceStatusMessage => _deviceStatusMessage;
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

  Uint8List? _thumbnailBytes;
  Uint8List? get thumbnailBytes => _thumbnailBytes;
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
  static const int _maxPollIntervalSeconds = 60;
  // SSE reconnect tuning: aggressive base retry for local devices + small jitter.
  static const int _sseReconnectBaseSeconds = 3;
  // Don't attempt SSE if polling is repeatedly failing. If polling shows
  // consecutive errors above this threshold, skip SSE reconnect attempts
  // until polls recover.
  static const int _ssePollErrorThreshold = 3;
  int _sseConsecutiveErrors = 0;

  /// SSE support tri-state: null = unknown, true = supported, false = unsupported
  bool? _sseSupported;

  /// True once we've successfully established an SSE subscription at least once
  bool _sseEverConnected = false;

  /// True once we've attempted an SSE subscription (even if it failed)
  // bool _sseAttempted = false; // reserved for future introspection
  // Exponential backoff counters
  int _consecutiveErrors = 0;
  static const int _maxReconnectAttempts = 20;
  DateTime? _nextPollRetryAt;
  DateTime? _nextSseRetryAt;
  // int _sseConsecutiveErrors = 0; // reserved for future use
  bool _fetchInFlight = false;
  bool _disposed = false;

  // SSE (Server-Sent Events) client state. When streaming is active we
  // rely on incoming events instead of the periodic polling loop.
  bool _sseConnected = false;
  StreamSubscription<Map<String, dynamic>>? _sseStreamSub;

  // Exposed getters for UI/dialogs to present attempt counters and next retry
  // timestamps.
  int get pollAttemptCount => _consecutiveErrors;
  int get sseAttemptCount => _sseConsecutiveErrors;
  int get maxReconnectAttempts => _maxReconnectAttempts;
  DateTime? get nextPollRetryAt => _nextPollRetryAt;
  DateTime? get nextSseRetryAt => _nextSseRetryAt;
  DateTime? get nextRetryAt {
    if (_nextPollRetryAt == null) return _nextSseRetryAt;
    if (_nextSseRetryAt == null) return _nextPollRetryAt;
    return _nextPollRetryAt!.isBefore(_nextSseRetryAt!)
        ? _nextPollRetryAt
        : _nextSseRetryAt;
  }

  bool? get sseSupported => _sseSupported;

  StatusProvider({OdysseyClient? client})
      : _client = client ?? BackendService() {
    // Prefer an SSE subscription when the backend supports it. If the
    // connection fails we fall back to the existing polling loop. See
    // comments in _tryStartSse for detailed reconnect / fallback behavior.
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
    // If we've determined SSE is unsupported, don't retry it.
    if (_sseSupported == false) {
      _log.info('SSE previously determined unsupported; skipping SSE attempts');
      _startPolling();
      return;
    }
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
      // If polling has been failing repeatedly, avoid attempting SSE until
      // polls recover. This prevents wasting SSE attempts while API is
      // clearly unreachable.
      if (_consecutiveErrors >= _ssePollErrorThreshold) {
        _log.info(
            'Skipping SSE attempt because polling has $_consecutiveErrors consecutive errors');
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
      _sseEverConnected = true;
      _sseSupported = true;
      _polling = false;

      // Reset SSE error counter on successful subscription
      _sseConsecutiveErrors = 0;
      _sseStreamSub = stream.listen((raw) async {
        try {
          // Capture any raw device status text (mapper sets 'device_status_message')
          try {
            _deviceStatusMessage =
                (raw['device_status_message'] ?? raw['Status'] ?? raw['status'])
                    ?.toString();
          } catch (_) {
            _deviceStatusMessage = null;
          }
          final parsed = StatusModel.fromJson(raw);
          // (previous snapshot removed) transitional clears now rely on the
          // parsed payload directly.

          // Lazy thumbnail acquisition (same rules as refresh)
          if (parsed.isPrinting &&
              _thumbnailBytes == null &&
              !_thumbnailReady) {
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
                final file = OrionApiFile(
                  path: path,
                  name: fileData.name,
                  parentPath: subdir,
                  lastModified: 0,
                  locationCategory: fileData.locationCategory,
                );
                _thumbnailBytes = await ThumbnailCache.instance.getThumbnail(
                  location: fileData.locationCategory ?? 'Local',
                  subdirectory: subdir,
                  fileName: fileData.name,
                  file: file,
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
          _consecutiveErrors = 0;
          _pollIntervalSeconds = _minPollIntervalSeconds;
          // If we were previously awaiting a new print, consider the print
          // started as soon as the backend reports an active job (printing
          // or paused). Waiting for file metadata or thumbnails can cause
          // long spinners on some backends that populate those fields
          // asynchronously; prefer showing the status immediately and
          // update metadata when it becomes available.
          if (_awaitingNewPrintData) {
            _awaitingNewPrintData = false;
            _awaitingSince = null;
          }

          // Clear transitional flags when backend reflects the requested
          // change. We clear regardless of previous snapshot so cases where
          // the pre-action status was null/stale still resolve the UI.
          if (_isPausing && parsed.isPaused) {
            _isPausing = false;
          }
          if (_isCanceling &&
              (parsed.isCanceled ||
                  !parsed.isPrinting ||
                  (parsed.isIdle && parsed.layer != null))) {
            _isCanceling = false;
          }
        } catch (e, st) {
          _log.warning('Failed to handle SSE payload', e, st);
        }
        if (!_disposed) notifyListeners();
      }, onError: (err, st) {
        _log.warning('SSE stream error, falling back to polling', err, st);
        _closeSse();
        if (!_disposed) _startPolling();
        // If we previously had a working SSE subscription, retry with
        // exponential backoff because we know the backend supported SSE.
        if (_sseEverConnected) {
          _sseConsecutiveErrors =
              min(_sseConsecutiveErrors + 1, _maxReconnectAttempts);
          final delaySec = _computeBackoff(_sseConsecutiveErrors,
              base: _sseReconnectBaseSeconds, max: _maxPollIntervalSeconds);
          _log.warning(
              'SSE stream error; scheduling reconnect in ${delaySec}s (attempt $_sseConsecutiveErrors)');
          _nextSseRetryAt = DateTime.now().add(Duration(seconds: delaySec));
          Future.delayed(Duration(seconds: delaySec), () {
            _nextSseRetryAt = null;
            if (!_sseConnected && !_disposed) _tryStartSse();
          });
        } else {
          // We never established SSE successfully. Decide whether to mark
          // SSE unsupported or to keep trying later. If polling is healthy
          // (no recent consecutive poll errors) then the server likely
          // doesn't support SSE and we should not keep retrying.
          // mark that we've attempted SSE (implicit via logs)
          if (_consecutiveErrors < _ssePollErrorThreshold) {
            _sseSupported = false;
            _log.info(
                'SSE appears unsupported (stream error while polling healthy); disabling SSE attempts');
          } else {
            // Polling currently unhealthy; we'll continue polling and let
            // refresh() attempt SSE after polls recover.
            _log.info(
                'SSE stream error while polls unhealthy; will retry SSE after poll recovery');
          }
        }
      }, onDone: () {
        _log.info('SSE stream closed by server; falling back to polling');
        _closeSse();
        if (!_disposed) _startPolling();
        if (_sseEverConnected) {
          _sseConsecutiveErrors =
              min(_sseConsecutiveErrors + 1, _maxReconnectAttempts);
          final delaySec = _computeBackoff(_sseConsecutiveErrors,
              base: _sseReconnectBaseSeconds, max: _maxPollIntervalSeconds);
          _log.warning(
              'SSE stream closed by server; scheduling reconnect in ${delaySec}s (attempt $_sseConsecutiveErrors)');
          _nextSseRetryAt = DateTime.now().add(Duration(seconds: delaySec));
          Future.delayed(Duration(seconds: delaySec), () {
            _nextSseRetryAt = null;
            if (!_sseConnected && !_disposed) _tryStartSse();
          });
        } else {
          // mark that we've attempted SSE (implicit via logs)
          if (_consecutiveErrors < _ssePollErrorThreshold) {
            _sseSupported = false;
            _log.info(
                'SSE appears unsupported (stream closed while polling healthy); disabling SSE attempts');
          } else {
            _log.info(
                'SSE closed while polls unhealthy; will retry SSE after poll recovery');
          }
        }
      }, cancelOnError: true);
    } catch (e, st) {
      _log.info('SSE subscription failed; using polling', e, st);
      _sseConnected = false;
      // mark that we've attempted SSE (implicit via logs)
      if (!_disposed) _startPolling();
      // If polling is healthy, the server likely doesn't support SSE;
      // otherwise schedule reconnects because network may be flaky.
      if (_consecutiveErrors < _ssePollErrorThreshold) {
        _sseSupported = false;
        _log.info(
            'SSE appears unsupported (subscription failed while polls healthy); disabling SSE attempts');
      } else {
        _sseConsecutiveErrors =
            min(_sseConsecutiveErrors + 1, _maxReconnectAttempts);
        final delaySec = _computeBackoff(_sseConsecutiveErrors,
            base: _sseReconnectBaseSeconds, max: _maxPollIntervalSeconds);
        _log.warning(
            'SSE subscription failed; scheduling reconnect in ${delaySec}s (attempt $_sseConsecutiveErrors)');
        _nextSseRetryAt = DateTime.now().add(Duration(seconds: delaySec));
        Future.delayed(Duration(seconds: delaySec), () {
          _nextSseRetryAt = null;
          if (!_sseConnected && !_disposed) _tryStartSse();
        });
      }
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
    final startedAt = DateTime.now();
    // Snapshot fields to avoid emitting notifications on every successful
    // polling refresh when nothing meaningful changed. This reduces churn
    // for listeners (e.g., ConnectionErrorWatcher) in polling-only backends
    // like NanoDLP. Also snapshot transitional flags so clearing them will
    // reliably cause a UI update even when the backend payload is otherwise
    // identical.
    final prevError = _error;
    final prevConsecutive = _consecutiveErrors;
    final prevLoading = _loading;
    final prevSseSupported = _sseSupported;
    final prevIsPausing = _isPausing;
    final prevIsCanceling = _isCanceling;
    // Capture previous status JSON so we can detect meaningful payload changes
    // (e.g. z position, progress) and notify UI even if other counters are
    // unchanged. Use JSON encoding of the model's toJson for a stable compare.
    final prevStatusJson = _status?.toJson();
    // Helper to compute a small fingerprint capturing the fields that
    // usually change while a print is active. This avoids noisy full-JSON
    // comparisons and ensures the UI updates when z/progress/layer change.
    String fingerprint(StatusModel? s) {
      if (s == null) return '';
      final z = s.physicalState.z.toStringAsFixed(3);
      final layer = s.layer?.toString() ?? '';
      final total = s.printData?.layerCount.toString() ?? '';
      final paused = s.isPaused ? '1' : '0';
      final status = s.status;
      return '$status|$paused|$layer|$total|$z';
    }

    final prevFingerprint = fingerprint(_status);
    bool statusChangedByFingerprint = false;
    try {
      final raw = await _client.getStatus();
      // Capture device message if present
      try {
        _deviceStatusMessage =
            (raw['device_status_message'] ?? raw['Status'] ?? raw['status'])
                ?.toString();
      } catch (_) {
        _deviceStatusMessage = null;
      }
      final parsed = StatusModel.fromJson(raw);
      // Compute fingerprint difference to detect meaningful changes that
      // should update the UI (z/layer/progress/etc.). This allows the
      // UI to update every poll while printing without requiring full JSON
      // equality checks that can hide small numeric changes.
      final nowFingerprint = fingerprint(parsed);
      statusChangedByFingerprint = prevFingerprint != nowFingerprint;
      // If a print is active (printing or paused) treat the poll as a
      // meaningful update so the UI refreshes every interval. Some
      // NanoDLP installs report minimal numeric changes that may be lost
      // by strict comparisons; forcing updates during active prints keeps
      // the UI responsive and in sync with the device.
      if (parsed.isPrinting || parsed.isPaused) {
        statusChangedByFingerprint = true;
      }
      // Transitional clears will be based on the freshly parsed payload.

      // Attempt lazy thumbnail acquisition (only while printing and not yet fetched)
      if (parsed.isPrinting && _thumbnailBytes == null && !_thumbnailReady) {
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
            final file = OrionApiFile(
              path: path,
              name: fileData.name,
              parentPath: subdir,
              lastModified: 0,
              locationCategory: fileData.locationCategory,
            );
            _thumbnailBytes = await ThumbnailCache.instance.getThumbnail(
              location: fileData.locationCategory ?? 'Local',
              subdirectory: subdir,
              fileName: fileData.name,
              file: file,
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
      // Reset polling error counter; when polls are healthy we may try to
      // opportunistically establish an SSE subscription.
      final wasErroring = _consecutiveErrors > 0;
      _consecutiveErrors = 0;
      if (wasErroring) {
        _log.fine('Status refresh succeeded; consecutive error counter reset');
      }
      if (wasErroring && !_sseConnected && !_disposed) {
        // Defer SSE attempt slightly so any racing logic in _tryStartSse can
        // act after the current refresh completes.
        Future.delayed(const Duration(milliseconds: 250), () {
          if (!_sseConnected && !_disposed) _tryStartSse();
        });
      }

      if (_awaitingNewPrintData) {
        final timedOut = _awaitingSince != null &&
            DateTime.now().difference(_awaitingSince!) > _awaitingTimeout;
        // If backend reports active printing/paused we clear awaiting early
        // (do not strictly require file metadata or thumbnail). Additionally,
        // if the backend reports a finished snapshot (idle with layer data)
        // or a canceled snapshot we should also clear awaiting so the UI
        // doesn't remain stuck on a spinner for backends (like NanoDLP)
        // that may briefly lose the 'printing' flag during transition.
        if (newPrintReady ||
            parsed.isPrinting ||
            parsed.isPaused ||
            // Treat a finished snapshot (idle but with layers) as valid
            // to clear awaiting so the UI can present the final state.
            (parsed.isIdle && parsed.layer != null) ||
            // Canceled snapshots should also clear awaiting.
            parsed.isCanceled ||
            timedOut) {
          _awaitingNewPrintData = false;
          _awaitingSince = null;
        }
      }

      // Clear transitional flags when the backend's paused/canceled state
      // changes compared to our previous snapshot. This handles both
      // pause->resume and resume->pause transitions and avoids leaving the
      // UI stuck in a spinner.
      // Clear transitional flags when backend reflects the requested change
      // (e.g., resume -> paused=false or cancel -> layer==null).
      if (_isPausing && parsed.isPaused) {
        _isPausing = false;
      }
      if (_isCanceling &&
          (parsed.isCanceled ||
              !parsed.isPrinting ||
              (parsed.isIdle && parsed.layer != null))) {
        _isCanceling = false;
      }
    } catch (e, st) {
      _log.severe('Status refresh failed', e, st);
      _error = e;
      _loading = false;
      // On failure, increase consecutive error count and back off polling
      _consecutiveErrors = min(_consecutiveErrors + 1, _maxReconnectAttempts);
      final backoff = _computeBackoff(_consecutiveErrors,
          base: _minPollIntervalSeconds, max: _maxPollIntervalSeconds);
      _pollIntervalSeconds = backoff;
      _nextPollRetryAt = DateTime.now().add(Duration(seconds: backoff));
      // Clear timestamp when timer expires
      Future.delayed(Duration(seconds: backoff), () {
        _nextPollRetryAt = null;
      });
      final elapsed = DateTime.now().difference(startedAt);
      final millis = elapsed.inMilliseconds;
      final elapsedStr = millis >= 1000
          ? '${(millis / 1000).toStringAsFixed(1)}s'
          : '${millis}ms';
      _log.warning(
          'Status refresh failed after $elapsedStr; backing off polling for ${_pollIntervalSeconds}s (attempt $_consecutiveErrors)');
    } finally {
      _fetchInFlight = false;
      if (!_disposed) {
        // Only notify listeners if one of the meaningful observable fields
        // actually changed. This avoids spamming watchers with identical
        // state on each poll when the backend is healthy. Additionally,
        // compare the previous status model JSON so UI will update when
        // backend fields (z/progress/layer) change between polls.
        final nowError = _error;
        final nowConsecutive = _consecutiveErrors;
        final nowLoading = _loading;
        final nowSseSupported = _sseSupported;
        final nowIsPausing = _isPausing;
        final nowIsCanceling = _isCanceling;
        final nowStatusJson = _status?.toJson();
        // Prefer fingerprint-based change detection for performance and to
        // ensure per-second updates while printing. Fall back to full JSON
        // comparison if necessary.
        bool statusChanged = statusChangedByFingerprint;
        if (!statusChanged) {
          try {
            final p = json.encode(prevStatusJson);
            final n = json.encode(nowStatusJson);
            statusChanged = p != n;
          } catch (_) {
            statusChanged = true;
          }
        }

        var shouldNotify = (prevError != nowError) ||
            (prevConsecutive != nowConsecutive) ||
            (prevLoading != nowLoading) ||
            (prevSseSupported != nowSseSupported) ||
            (prevIsPausing != nowIsPausing) ||
            (prevIsCanceling != nowIsCanceling) ||
            statusChanged;
        // If configured for NanoDLP (developer override or backend config),
        // we poll frequently. Some NanoDLP setups report only tiny numeric
        // changes which can be normalized away; ensure active printing/paused
        // always triggers UI updates on each poll so the status screen stays
        // visually responsive.
        try {
          final cfg = OrionConfig();
          final backend = cfg.getString('backend', category: 'advanced');
          final devNano = cfg.getFlag('nanoDLPmode', category: 'developer');
          final isNano = backend == 'nanodlp' || devNano;
          if (!shouldNotify &&
              isNano &&
              (_status?.isPrinting == true || _status?.isPaused == true)) {
            shouldNotify = true;
          }
        } catch (_) {
          // If config read fails, don't change shouldNotify.
        }
        if (shouldNotify) notifyListeners();
      }
    }
  }

  int _computeBackoff(int attempts, {required int base, required int max}) {
    // Exponential: base * 2^attempts with cap, plus random jitter up to 50%.
    final raw = base * pow(2, attempts);
    int secs = raw.toInt();
    if (secs > max) secs = max;
    // Add jitter up to 50% of the computed backoff to avoid thundering herd.
    final rand = Random();
    final jitter = rand.nextInt((secs ~/ 2) + 1);
    secs = secs + jitter;
    if (secs > max) secs = max;
    return secs;
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
        // Clear transitional flag proactively on success so the UI doesn't
        // remain in a spinning 'resuming' state while the backend takes a
        // moment to reflect the new paused=false status.
        _isPausing = false;
        if (!_disposed) notifyListeners();
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
  /// Reset the provider to a neutral/loading state. Optionally provide an
  /// initial thumbnail (bytes) and file path or plate id so the UI can
  /// immediately render a cached preview while the backend populates
  /// active job metadata. This is useful when starting a print from the
  /// DetailsScreen where the thumbnail is already available.
  void resetStatus({
    Uint8List? initialThumbnailBytes,
    String? initialFilePath,
    int? initialPlateId,
  }) {
    _status = null;
    _thumbnailBytes = initialThumbnailBytes;
    _thumbnailReady = initialThumbnailBytes != null;
    _error = null;
    _loading = true; // so consumer screens can show a spinner if they mount
    _isCanceling = false;
    _isPausing = false;
    _awaitingNewPrintData = true; // begin awaiting active print
    _awaitingSince = DateTime.now();
    // If an initial file path or plate id is provided we may use it to
    // resolve thumbnails faster in NanoDLP adapters; store on status
    // model is not needed here but provider consumers can access
    // _thumbnailBytes immediately.
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    super.dispose();
  }
}

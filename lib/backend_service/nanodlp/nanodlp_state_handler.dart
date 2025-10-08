/*
* Orion - NanoDLP State Handler
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

import 'package:logging/logging.dart';
import 'package:orion/backend_service/nanodlp/models/nano_status.dart';

/// NanoDLP state handler with simple latching for transient states.
///
/// NanoDLP `State` codes (observed):
/// 0 = Idle
/// 1 = Starting/ending a print (transient)
/// 2 = Pause-request (transient)
/// 3 = Paused (stable)
/// 4 = Cancel-request (transient but must be latched)
/// 5 = Active print (stable)
///
/// This handler keeps a small in-memory latch for an active cancel-request
/// so that once State==4 is observed the client will remember that a
/// cancellation is in-flight until the device returns to State==0 (idle),
/// at which point the latch clears. The latch also clears when a new print
/// begins (State moves from 0->1) — i.e., a successful new-print unlatches.
class NanoDlpStateHandler {
  // Singleton-like instance is fine for the provider-level lifecycle.
  NanoDlpStateHandler();

  bool _cancelLatched = false;
  int _prevStateCode = -1;
  int _lastReportedStateCode = -999;
  String? _lastReportedStatus;
  bool? _lastReportedCancelLatched;
  bool? _lastReportedPauseLatched;
  bool? _lastReportedFinished;
  final Logger _log = Logger('NanoDlpStateHandler');

  /// Reset internal latches (useful for new-session or explicit reset).
  void reset() {
    _cancelLatched = false;
  }

  /// Update the handler with the latest observed NanoStatus and return a
  /// canonical mapping describing whether the device should be considered
  /// printing, paused, or in a cancel-request.
  ///
  /// The returned map contains:
  /// - 'status': String one of 'Printing'|'Paused'|'Idle'|'Canceling'
  /// - 'paused': bool, authoritative paused flag
  /// - 'cancel_latched': bool, whether a cancel request is currently latched
  Map<String, dynamic> canonicalize(NanoStatus ns) {
    // Prefer numeric state code when present. If missing, infer a numeric
    // code from other convenience fields so we can reason about transitions
    // deterministically (avoids logging -1/unobserved states).
    final sc = ns.stateCode;
    int stateCode;
    if (sc != null) {
      stateCode = sc;
    } else {
      // Map textual state or booleans to approximate numeric codes:
      // 'printing' -> 5, 'paused' -> 3, 'idle' -> 0.
      final text = ns.state.toLowerCase();
      if (text == 'printing' || ns.printing == true) {
        stateCode = 5;
      } else if (text == 'paused' || ns.paused == true) {
        stateCode = 3;
      } else if (text == 'idle') {
        stateCode = 0;
      } else {
        stateCode = -1;
      }
    }

    // Update latches based on observed state code/value
    // Latching rules:
    // - When we observe state==4, latch cancel until we see state==0 (idle)
    //   which indicates the cancel completed. The latch should survive
    //   transient transitions (e.g., 4 -> 1).
    // - If we observe a new print starting from idle (prev==0 && state==1),
    //   this is a fresh job and we should clear the cancel latch.
    if (stateCode == 4) {
      _cancelLatched = true;
    }

    if (_prevStateCode == 0 && stateCode == 1) {
      // New print started from idle — clear any previous cancel latch.
      _cancelLatched = false;
    }

    // If device returns to idle and we had a cancel latched, report Idle with
    // the latch indicated. Do NOT clear the latch here — we only clear the
    // cancel latch when a new print starts (0 -> 1). Keeping the latch
    // through repeated idle snapshots allows callers to reliably detect
    // that a cancel completed until a fresh job begins.
    // If we return to idle and a cancel is latched, report Idle with the
    // latch indicated. However, transitions from transient 1->0 (start->idle)
    // can mean a normal print finish; only consider the snapshot canceled
    // (latched) if we previously observed an explicit cancel request (4).
    if (stateCode == 0 && _cancelLatched) {
      final result = {
        'status': 'Idle',
        'paused': false,
        'cancel_latched': true,
        'finished': false,
      };
      // Log only when something changed
      _reportIfChanged(
          stateCode, result['status'] as String, true, false, false);
      _prevStateCode = stateCode;
      return result;
    }

    // Now map to canonical status. Rules:
    // - If cancel latch is set -> status 'Canceling' and paused=false
    // - State 3 -> Paused
    // - State 1 or 5 -> Printing
    // - State 2 -> treat as Printing but not paused (it's a request)
    // - Fallback: use ns.paused or ns.printing
    if (_cancelLatched) {
      final result = {
        'status': 'Canceling',
        'paused': false,
        'cancel_latched': true,
        'pause_latched': false,
        'finished': false,
      };
      _reportIfChanged(
          stateCode, result['status'] as String, true, false, false);
      _prevStateCode = stateCode;
      return result;
    }

    // Update previous state for next call.
    _prevStateCode = stateCode;

    if (stateCode == 3) {
      final result = {
        'status': 'Paused',
        'paused': true,
        'cancel_latched': false,
        'finished': false,
      };
      _reportIfChanged(
          stateCode, result['status'] as String, false, false, false);
      return result;
    }

    if (stateCode == 1 || stateCode == 5) {
      final result = {
        'status': 'Printing',
        'paused': false,
        'cancel_latched': false,
        'finished': false,
      };
      _reportIfChanged(
          stateCode, result['status'] as String, false, false, false);
      return result;
    }

    if (stateCode == 2) {
      // Pause requested — report as pausing (transitional). We expose a
      // pause_latched flag so callers can show a pausing spinner.
      final result = {
        'status': 'Pausing',
        'paused': false,
        'cancel_latched': false,
        'pause_latched': true,
        'finished': false,
      };
      _reportIfChanged(
          stateCode, result['status'] as String, false, true, false);
      return result;
    }

    // Fallback: use existing flags
    if (ns.paused == true) {
      final result = {
        'status': 'Paused',
        'paused': true,
        'cancel_latched': false,
        'finished': false,
      };
      _reportIfChanged(
          stateCode, result['status'] as String, false, false, false);
      return result;
    }

    if (ns.printing == true) {
      final result = {
        'status': 'Printing',
        'paused': false,
        'cancel_latched': false,
        'finished': false,
      };
      _reportIfChanged(
          stateCode, result['status'] as String, false, false, false);
      return result;
    }

    // Fallback: treat as Idle. We may be able to infer 'finished' if the
    // snapshot contains information suggesting a completed job (layer info
    // or layersCount or file metadata). This hint helps the mapper decide
    // whether to present a green finished state or a canceled appearance.
    final bool inferFinished =
        ns.layerId != null || ns.layersCount != null || ns.file != null;
    final result = {
      'status': 'Idle',
      'paused': false,
      'cancel_latched': false,
      'pause_latched': false,
      'finished': inferFinished,
    };
    _reportIfChanged(
        stateCode, result['status'] as String, false, false, inferFinished);
    return result;
  }

  void _reportIfChanged(int stateCode, String status, bool cancelLatched,
      bool pauseLatched, bool finished) {
    final changed = stateCode != _lastReportedStateCode ||
        status != _lastReportedStatus ||
        cancelLatched != _lastReportedCancelLatched ||
        pauseLatched != _lastReportedPauseLatched ||
        finished != _lastReportedFinished;
    if (!changed) return;

    // Human-friendly single-line log. Use info level so it's visible by
    // default but configurable by the app's logging setup.
    final prevState = _lastReportedStateCode == -999
        ? 'unknown'
        : _lastReportedStateCode.toString();
    final curState = stateCode < 0 ? 'unknown' : stateCode.toString();
    _log.info(
        'state $prevState -> $curState | status ${_lastReportedStatus ?? 'unknown'} -> $status | cancel_latched: $cancelLatched | pause_latched: $pauseLatched | finished: $finished');

    _lastReportedStateCode = stateCode;
    _lastReportedStatus = status;
    _lastReportedCancelLatched = cancelLatched;
    _lastReportedPauseLatched = pauseLatched;
    _lastReportedFinished = finished;
  }
}

// Provide a package-level shared handler for simple use by mappers/providers.
final NanoDlpStateHandler nanoDlpStateHandler = NanoDlpStateHandler();

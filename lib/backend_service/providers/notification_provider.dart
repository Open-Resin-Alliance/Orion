/*
* Orion - Notification Provider
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
import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:orion/backend_service/backend_service.dart';
import 'package:orion/backend_service/backend_client.dart';
import 'package:orion/util/orion_config.dart';

/// A simple notification model used locally.
class NotificationItem {
  final int? timestamp;
  final String? type;
  final int? duration;
  final String? text;

  NotificationItem.fromJson(Map<String, dynamic> j)
      : timestamp = j['Timestamp'] is int
            ? j['Timestamp']
            : (j['timestamp'] is int ? j['timestamp'] : null),
        type = j['Type']?.toString() ?? j['type']?.toString(),
        duration = j['Duration'] is int
            ? j['Duration']
            : (j['duration'] is int ? j['duration'] : null),
        text = j['Text']?.toString() ?? j['text']?.toString();
}

class NotificationProvider extends ChangeNotifier {
  final BackendClient _client;
  final _log = Logger('NotificationProvider');

  Timer? _timer;
  bool _disposed = false;
  final int _pollIntervalSeconds = 1;
  final Set<String> _seen = {}; // track seen notifications by text+ts
  final List<NotificationItem> _pending = [];
  // Keys present on the server in the most recent poll. Each key is
  // '<timestamp>:<type>:<text>'. Watchers can read this to determine if a
  // currently-shown notification still exists server-side.
  Set<String> _lastServerKeys = {};

  /// Pending notifications that have not yet been handled by a watcher.
  List<NotificationItem> get pendingNotifications =>
      List.unmodifiable(_pending);

  /// Consume and return pending notifications, clearing the pending list.
  List<NotificationItem> popPendingNotifications() {
    final copy = List<NotificationItem>.from(_pending);
    _pending.clear();
    return copy;
  }

  NotificationProvider({BackendClient? client})
      : _client = client ?? BackendService() {
    _start();
  }

  void _start() {
    try {
      final cfg = OrionConfig();
      final isNano = cfg.isNanoDlpMode();
      if (!isNano) return; // placeholder: only NanoDLP implemented
    } catch (_) {
      // if config read fails, default to not starting
      return;
    }

    // Start a periodic poller
    _timer = Timer.periodic(Duration(seconds: _pollIntervalSeconds), (_) {
      _pollOnce();
    });
    // run an initial poll
    _pollOnce();
  }

  Future<void> _pollOnce() async {
    if (_disposed) return;
    try {
      final raw = await _client.getNotifications();
      if (raw.isEmpty) {
        // If server returned no notifications, clear any pending items and
        // forget seen non-timestamped entries that cannot be reconciled.
        // Also, remove any seen keys that referenced timestamped items which
        // are no longer present on the server (they were acked elsewhere).
        // Build an empty server set and prune below.
      }

      // Parse server items into NotificationItem so we can build consistent keys
      final serverItems = <NotificationItem>[];
      for (final r in raw) {
        try {
          serverItems.add(NotificationItem.fromJson(r));
        } catch (_) {}
      }

      // Build set of keys present on server
      final serverKeys = <String>{};
      for (final item in serverItems) {
        final k = '${item.timestamp}:${item.type}:${item.text}';
        serverKeys.add(k);
      }

      // Publish last seen server keys for watchers.
      _lastServerKeys = serverKeys;

      // Prune _seen entries that are for timestamped notifications no longer
      // present on server: they were likely acknowledged elsewhere.
      final toRemove = <String>[];
      for (final s in _seen) {
        // Only consider keys which include a timestamp (non-null prefix)
        final parts = s.split(':');
        if (parts.isEmpty) continue;
        final tsPart = parts[0];
        if (tsPart == 'null' || tsPart.isEmpty) continue;
        if (!serverKeys.contains(s)) {
          toRemove.add(s);
        }
      }
      if (toRemove.isNotEmpty) {
        for (final r in toRemove) {
          _seen.remove(r);
        }
        // Also drop any pending NotificationItems which match the removed keys
        _pending.removeWhere((p) {
          final k = '${p.timestamp}:${p.type}:${p.text}';
          return toRemove.contains(k);
        });
      }

      // Add new items that we haven't seen yet
      var added = false;
      for (final item in serverItems) {
        final key = '${item.timestamp}:${item.type}:${item.text}';
        if (_seen.contains(key)) continue;
        _seen.add(key);
        _pending.add(item);
        added = true;
      }

      if (added) notifyListeners();
    } catch (e, st) {
      _log.fine('Notification poll failed', e, st);
    }
  }

  /// Returns an unmodifiable view of the last-known server notification keys.
  Set<String> get serverKeys => Set.unmodifiable(_lastServerKeys);

  // Attempt to find a top-level context. This simple approach relies on
  // WidgetsBinding having a current root view; it mirrors other usages in
  // main.dart where a nav context is used. If unavailable, notification
  // dialogs will be skipped.
  // No direct UI responsibilities: watchers should listen to this provider
  // and display dialogs using an appropriate BuildContext.

  @override
  void dispose() {
    _disposed = true;
    try {
      _timer?.cancel();
    } catch (_) {}
    super.dispose();
  }
}

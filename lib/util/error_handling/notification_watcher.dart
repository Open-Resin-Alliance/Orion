/*
* Orion - Notification Watcher
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
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';

import 'package:orion/backend_service/providers/notification_provider.dart';
import 'package:orion/glasser/glasser.dart';
import 'package:orion/backend_service/backend_service.dart';
import 'package:orion/backend_service/nanodlp/models/nano_notification_types.dart';

/// Installs a watcher that will show a GlassAlertDialog for each new
/// notification reported by [NotificationProvider]. The provided [context]
/// must be attached to a Navigator (top-level app context).
class NotificationWatcher {
  final BuildContext _context;
  late final NotificationProvider _provider;
  bool _listening = false;
  final Set<String> _locallyAcked = {};

  NotificationWatcher._(this._context) {
    _provider = Provider.of<NotificationProvider>(_context, listen: false);
  }

  static NotificationWatcher? install(BuildContext context) {
    try {
      final watcher = NotificationWatcher._(context);
      watcher._start();
      return watcher;
    } catch (_) {
      return null;
    }
  }

  void _start() {
    if (_listening) return;
    _listening = true;
    _provider.addListener(_onProviderChange);
    _onProviderChange();
  }

  void _onProviderChange() {
    try {
      var items = _provider.popPendingNotifications();
      if (items.isEmpty) return;
      // Keep only the highest-priority notifications (lower number = higher priority).
      if (items.length > 1) {
        final prios = items.map((i) => getNanoTypePriority(i.type));
        final minPrio = prios.reduce((a, b) => a < b ? a : b);
        items = items
            .where((i) => getNanoTypePriority(i.type) == minPrio)
            .toList(growable: false);
      }
      // Sort the remaining items deterministically by priority (should be same) and timestamp (newest first)
      items.sort((a, b) {
        final p =
            getNanoTypePriority(a.type).compareTo(getNanoTypePriority(b.type));
        if (p != 0) return p;
        return (b.timestamp ?? 0).compareTo(a.timestamp ?? 0);
      });
      // Show dialogs for each pending notification on next frame.
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        for (final item in items) {
          try {
            await _showNotificationDialog(_context, item);
          } catch (_) {}
        }
      });
    } catch (_) {}
  }

  /// Show a notification dialog safely: retry a few times until a Navigator
  /// and MaterialLocalizations are available on the provided [context].
  Future<void> _showNotificationDialog(
      BuildContext context, NotificationItem item) async {
    final completer = Completer<void>();

    void attemptShow(int triesLeft) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final hasNavigator = Navigator.maybeOf(context) != null;
        final hasMaterialLocs = Localizations.of<MaterialLocalizations>(
                context, MaterialLocalizations) !=
            null;
        if (!hasNavigator || !hasMaterialLocs) {
          if (triesLeft > 0) {
            Future.delayed(const Duration(milliseconds: 300), () {
              attemptShow(triesLeft - 1);
            });
          } else {
            if (!completer.isCompleted) completer.complete();
          }
          return;
        }

        try {
          final cfg = getNanoTypeConfig(item.type);
          final actions = (cfg['actions'] as List<dynamic>)
              .map((e) => e.toString())
              .toList(growable: false);
          // Build the dialog and capture its inner BuildContext so we can
          // programmatically dismiss it if the server-side notification
          // disappears.
          BuildContext? dialogCtx;
          final key = '${item.timestamp}:${item.type}:${item.text}';

          final dialogFuture = showDialog(
            context: context,
            barrierDismissible: true,
            useRootNavigator: true,
            builder: (BuildContext ctx) {
              dialogCtx = ctx;
              // Build action buttons from config
              final buttons = actions.map<Widget>((act) {
                final label = act[0].toUpperCase() + act.substring(1);

                Future<void> onPressed() async {
                  try {
                    // Map actions to backend calls. Keep failures isolated.
                    if (act == 'stop') {
                      try {
                        await BackendService().resumePrint();
                        // Give a moment for the state to update before canceling.
                        await Future.delayed(const Duration(milliseconds: 500));
                        await BackendService().cancelPrint();
                      } catch (_) {}
                    } else if (act == 'pause') {
                      try {
                        await BackendService().pausePrint();
                      } catch (_) {}
                    } else if (act == 'resume' || act == 'continue') {
                      try {
                        await BackendService().resumePrint();
                      } catch (_) {}
                    } else if (act == 'confirm' ||
                        act == 'ack' ||
                        act == 'acknowledge') {
                      // Acknowledge this notification on the server when possible.
                      if (item.timestamp != null) {
                        final k = key;
                        try {
                          await BackendService()
                              .disableNotification(item.timestamp!);
                          _locallyAcked.add(k);
                        } catch (_) {}
                      }
                    } else {
                      // Unknown action - no-op for safety.
                    }
                  } finally {
                    try {
                      Navigator.of(ctx).pop();
                    } catch (_) {}
                  }
                }

                final GlassButtonTint tint;
                if (act == 'stop') {
                  tint = GlassButtonTint.negative;
                } else if (act == 'pause') {
                  tint = GlassButtonTint.warn;
                } else if (act == 'resume' ||
                    act == 'close' ||
                    act == 'confirm' ||
                    act == 'ack' ||
                    act == 'acknowledge' ||
                    act == 'continue') {
                  tint = GlassButtonTint.neutral;
                } else {
                  tint = GlassButtonTint.none;
                }

                final style = ElevatedButton.styleFrom(
                  minimumSize: Size(0, act == 'stop' ? 56 : 60),
                );

                return Flexible(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 6.0),
                    child: GlassButton(
                      onPressed: onPressed,
                      tint: tint,
                      style: style,
                      child: Text(label, style: const TextStyle(fontSize: 22)),
                    ),
                  ),
                );
              }).toList(growable: false);

              return GlassAlertDialog(
                title: Row(
                  children: [
                    PhosphorIcon(
                      PhosphorIcons.warning(),
                      color: Colors.orangeAccent,
                      size: 28,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        getNanoTypeTitle(item.type),
                        style: const TextStyle(
                            fontSize: 24, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 12),
                    Text(item.text ?? '(no text)',
                        style: const TextStyle(
                            fontSize: 22, color: Colors.white70),
                        textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                  ],
                ),
                actions: [
                  Row(children: buttons),
                ],
              );
            },
          );

          // Start a periodic watcher that will auto-close the dialog if the
          // server no longer reports the notification key. Cancel the timer
          // when the dialog completes.
          Timer? autoCloseTimer;
          autoCloseTimer =
              Timer.periodic(const Duration(milliseconds: 500), (_) {
            try {
              final serverHas = _provider.serverKeys.contains(key);
              if (!serverHas && dialogCtx != null) {
                try {
                  Navigator.of(dialogCtx!, rootNavigator: true).pop();
                } catch (_) {}
                autoCloseTimer?.cancel();
              }
            } catch (_) {}
          });

          dialogFuture.then((_) async {
            // Dialog dismissed (either by user or auto-close). If the server
            // still contains the notification key at this moment, assume the
            // user dismissed it and send disableNotification. If the server
            // no longer contains it, it was acked elsewhere and no network
            // call is necessary.
            try {
              final serverHas = _provider.serverKeys.contains(key);
              if (serverHas && item.timestamp != null) {
                try {
                  await BackendService().disableNotification(item.timestamp!);
                } catch (_) {}
              }
            } catch (_) {}

            try {
              autoCloseTimer?.cancel();
            } catch (_) {}

            if (!completer.isCompleted) completer.complete();
          }).catchError((err, st) {
            try {
              autoCloseTimer?.cancel();
            } catch (_) {}
            if (!completer.isCompleted) completer.complete();
          });
        } catch (e) {
          if (triesLeft > 0) {
            Future.delayed(const Duration(milliseconds: 300), () {
              attemptShow(triesLeft - 1);
            });
          } else {
            if (!completer.isCompleted) completer.complete();
          }
        }
      });
    }

    attemptShow(5);
    return completer.future;
  }

  void dispose() {
    if (_listening) {
      _provider.removeListener(_onProviderChange);
      _listening = false;
    }
  }

  // Use centralized NanoDLP notification lookup utilities in
  // `lib/backend_service/nanodlp/nanodlp_notification_types.dart`.
}

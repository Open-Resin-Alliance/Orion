/*
* Orion - Connection Error Watcher
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

import 'package:flutter/widgets.dart';
import 'package:logging/logging.dart';
import 'package:provider/provider.dart';

import 'package:orion/backend_service/providers/status_provider.dart';
import 'package:orion/util/error_handling/connection_error_dialog.dart';

/// Installs a watcher that will show the ConnectionErrorDialog when
/// [StatusProvider.error] becomes non-null and will dismiss it when
/// [StatusProvider.error] returns to null. The provided [context] must be
/// attached to a Navigator (e.g., top-level app context). Multiple calls will
/// replace the previous watcher for the same context.
class ConnectionErrorWatcher {
  final BuildContext _context;
  late final StatusProvider _provider;
  bool _dialogVisible = false;
  bool _listening = false;
  Object? _lastProviderError;
  bool? _lastDialogVisible;

  // Optional callbacks invoked on connection state transitions.
  final VoidCallback? onReconnect;
  final VoidCallback? onDisconnect;

  ConnectionErrorWatcher._(this._context,
      {this.onReconnect, this.onDisconnect}) {
    _provider = Provider.of<StatusProvider>(_context, listen: false);
  }

  /// Install the watcher and begin listening immediately.
  ///
  /// Optional callbacks can be provided to react to reconnect/disconnect
  /// events. By default the watcher only shows/dismisses the modal dialog
  /// (no toast/banners are shown).
  static ConnectionErrorWatcher install(BuildContext context,
      {VoidCallback? onReconnect, VoidCallback? onDisconnect}) {
    final watcher = ConnectionErrorWatcher._(context,
        onReconnect: onReconnect, onDisconnect: onDisconnect);
    watcher._start();
    return watcher;
  }

  void _start() {
    if (_listening) return;
    _listening = true;
    _provider.addListener(_onProviderChange);
    // Immediately evaluate initial state
    _onProviderChange();
  }

  void _onProviderChange() async {
    final log = Logger('ConnErrorWatcher');
    try {
      final providerError = _provider.error;
      final hasError = providerError != null;
      // If we have never successfully connected yet, suppress showing a
      // connection error dialog. During initial boot/startup the app shows
      // a branded startup overlay and transient network failures are
      // expected; showing the modal in that phase is noisy and confusing.
      // We still record the provider error state but avoid presenting UI
      // until the provider reports at least one successful status.
      final hasEverConnected = _provider.hasEverConnected;

      // Determine previous state from cached value
      final hadError = _lastProviderError != null;

      // Only log transitions or when there's something noteworthy to report
      final shouldLog = (providerError != _lastProviderError) ||
          (_dialogVisible != _lastDialogVisible) ||
          (providerError != null) ||
          _dialogVisible;
      if (shouldLog) {
        log.info(
            'provider error=${providerError != null} dialogVisible=$_dialogVisible');
        _lastProviderError = providerError;
        _lastDialogVisible = _dialogVisible;
      }

      // Callbacks for transitions: null->error (disconnect), error->null (reconnect)
      if (!hadError && hasError) {
        // Transition: connected -> disconnected
        if (onDisconnect != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            try {
              onDisconnect!();
            } catch (_) {}
          });
        }
      } else if (hadError && !hasError) {
        // Transition: disconnected -> reconnected
        if (onReconnect != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            try {
              onReconnect!();
            } catch (_) {}
          });
        }
      }

      if (hasError && !_dialogVisible) {
        // If we've never successfully connected yet (startup), do not show
        // the modal dialog — the StartupGate/StartupScreen handles the
        // initial wait UX. Record the state but return early.
        if (!hasEverConnected) {
          log.info(
              'Suppressing connection error dialog during startup (hasEverConnected=false)');
          return;
        }
        // Only show the modal after the provider has accumulated several
        // consecutive failures. Networks can be flaky; avoid spamming users
        // with a modal on the first hiccup. Use provider.pollAttemptCount
        // which reflects consecutive poll failures.
        final attempts = _provider.pollAttemptCount;
        const minAttemptsBeforeDialog = 3;
        if (attempts < minAttemptsBeforeDialog) {
          log.info(
              'Suppressing connection error dialog until $minAttemptsBeforeDialog failed attempts (current=$attempts)');
          return;
        }
        _dialogVisible = true;
        // Show the dialog; this Future completes when the dialog is dismissed
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          try {
            await showConnectionErrorDialog(_context);
          } catch (_) {}
          // Dialog was dismissed by user or programmatically
          _dialogVisible = false;
        });
      } else if (!hasError && _dialogVisible) {
        // Dismiss the dialog if it's visible and the error cleared.
        try {
          Navigator.of(_context, rootNavigator: true).maybePop();
        } catch (_) {}
      }
    } catch (_) {}
  }

  void dispose() {
    if (_listening) {
      _provider.removeListener(_onProviderChange);
      _listening = false;
    }
  }
}

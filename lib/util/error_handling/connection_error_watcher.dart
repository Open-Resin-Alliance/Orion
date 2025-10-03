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

  ConnectionErrorWatcher._(this._context) {
    _provider = Provider.of<StatusProvider>(_context, listen: false);
  }

  /// Install the watcher and begin listening immediately.
  static ConnectionErrorWatcher install(BuildContext context) {
    final watcher = ConnectionErrorWatcher._(context);
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
    final _log = Logger('ConnErrorWatcher');
    try {
      final hasError = _provider.error != null;
      // Only log transitions or when there's something noteworthy to report
      final providerError = _provider.error;
      final shouldLog = (providerError != _lastProviderError) ||
          (_dialogVisible != _lastDialogVisible) ||
          (providerError != null) ||
          _dialogVisible;
      if (shouldLog) {
        _log.info(
            'provider error=${providerError != null} dialogVisible=$_dialogVisible');
        _lastProviderError = providerError;
        _lastDialogVisible = _dialogVisible;
      }
      if (hasError && !_dialogVisible) {
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

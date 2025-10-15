import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';

import 'package:orion/backend_service/backend_client.dart';
import 'package:orion/backend_service/backend_service.dart';

/// Provider to encapsulate print-related actions (start, cancel, pause, resume)
/// and expose simple busy/error state for UI wiring.
class PrintProvider extends ChangeNotifier {
  final BackendClient _client;
  final _log = Logger('PrintProvider');

  bool _busy = false;
  bool get busy => _busy;

  Object? _error;
  Object? get error => _error;

  PrintProvider({BackendClient? client}) : _client = client ?? BackendService();

  Future<bool> startPrint(String location, String filePath) async {
    _log.info('startPrint: $location/$filePath');
    if (_busy) return false;
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      await _client.startPrint(location, filePath);
      _busy = false;
      notifyListeners();
      return true;
    } catch (e, st) {
      _log.severe('startPrint failed', e, st);
      _error = e;
      _busy = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> cancelPrint() async {
    _log.info('cancelPrint');
    if (_busy) return false;
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      await _client.cancelPrint();
      _busy = false;
      notifyListeners();
      return true;
    } catch (e, st) {
      _log.severe('cancelPrint failed', e, st);
      _error = e;
      _busy = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> pausePrint() async {
    _log.info('pausePrint');
    if (_busy) return false;
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      await _client.pausePrint();
      _busy = false;
      notifyListeners();
      return true;
    } catch (e, st) {
      _log.severe('pausePrint failed', e, st);
      _error = e;
      _busy = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> resumePrint() async {
    _log.info('resumePrint');
    if (_busy) return false;
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      await _client.resumePrint();
      _busy = false;
      notifyListeners();
      return true;
    } catch (e, st) {
      _log.severe('resumePrint failed', e, st);
      _error = e;
      _busy = false;
      notifyListeners();
      return false;
    }
  }
}

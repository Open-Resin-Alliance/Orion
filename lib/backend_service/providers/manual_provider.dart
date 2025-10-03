import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';

import 'package:orion/backend_service/odyssey/odyssey_client.dart';
import 'package:orion/backend_service/backend_service.dart';

/// Provider that exposes manual hardware controls (move, home, cure, commands,
/// and display test) using the `OdysseyClient` abstraction so screens do not
/// depend on the concrete ApiService implementation.
class ManualProvider extends ChangeNotifier {
  final OdysseyClient _client;
  final _log = Logger('ManualProvider');

  bool _busy = false;
  bool get busy => _busy;

  Object? _error;
  Object? get error => _error;

  ManualProvider({OdysseyClient? client})
      : _client = client ?? BackendService();

  Future<bool> move(double height) async {
    _log.info('move: $height');
    if (_busy) return false;
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      await _client.move(height);
      _busy = false;
      notifyListeners();
      return true;
    } catch (e, st) {
      _log.severe('move failed', e, st);
      _error = e;
      _busy = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> moveDelta(double deltaMm) async {
    _log.info('moveDelta: $deltaMm');
    if (_busy) return false;
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      await _client.moveDelta(deltaMm);
      _busy = false;
      notifyListeners();
      return true;
    } catch (e, st) {
      _log.severe('moveDelta failed', e, st);
      _error = e;
      _busy = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> manualHome() async {
    _log.info('manualHome');
    if (_busy) return false;
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      await _client.manualHome();
      _busy = false;
      notifyListeners();
      return true;
    } catch (e, st) {
      _log.severe('manualHome failed', e, st);
      _error = e;
      _busy = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> manualCure(bool cure) async {
    _log.info('manualCure: $cure');
    if (_busy) return false;
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      await _client.manualCure(cure);
      _busy = false;
      notifyListeners();
      return true;
    } catch (e, st) {
      _log.severe('manualCure failed', e, st);
      _error = e;
      _busy = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> manualCommand(String command) async {
    _log.info('manualCommand: $command');
    if (_busy) return false;
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      await _client.manualCommand(command);
      _busy = false;
      notifyListeners();
      return true;
    } catch (e, st) {
      _log.severe('manualCommand failed', e, st);
      _error = e;
      _busy = false;
      notifyListeners();
      return false;
    }
  }

  /// Whether the backend supports a direct move-to-top operation.
  Future<bool> canMoveToTop() async {
    try {
      return await _client.canMoveToTop();
    } catch (_) {
      return false;
    }
  }

  Future<bool> moveToTop() async {
    _log.info('moveToTop');
    if (_busy) return false;
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      await _client.moveToTop();
      _busy = false;
      notifyListeners();
      return true;
    } catch (e, st) {
      _log.severe('moveToTop failed', e, st);
      _error = e;
      _busy = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> displayTest(String test) async {
    _log.info('displayTest: $test');
    if (_busy) return false;
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      await _client.displayTest(test);
      _busy = false;
      notifyListeners();
      return true;
    } catch (e, st) {
      _log.severe('displayTest failed', e, st);
      _error = e;
      _busy = false;
      notifyListeners();
      return false;
    }
  }
}

/*
* Orion - Manual Hardware Control Provider
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

import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:orion/backend_service/backend_client.dart';
import 'package:orion/backend_service/backend_service.dart';

/// Provider that exposes manual hardware controls (move, home, cure, commands,
/// and display test) using the `BackendClient` abstraction so screens do not
/// depend on the concrete ApiService implementation.
class ManualProvider extends ChangeNotifier {
  final BackendClient _client;
  final _log = Logger('ManualProvider');

  bool _busy = false;
  bool get busy => _busy;

  Object? _error;
  Object? get error => _error;

  ManualProvider({BackendClient? client})
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

  /// Whether the backend supports a direct move-to-floor operation.
  Future<bool> canMoveToFloor() async {
    try {
      return await _client.canMoveToFloor();
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

  Future<bool> moveToFloor() async {
    _log.info('moveToFloor');
    if (_busy) return false;
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      await _client.moveToFloor();
      _busy = false;
      notifyListeners();
      return true;
    } catch (e, st) {
      _log.severe('moveToFloor failed', e, st);
      _error = e;
      _busy = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> emergencyStop() async {
    _log.info('emergencyStop');
    if (_busy) return false;
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      await _client.emergencyStop();
      _busy = false;
      notifyListeners();
      return true;
    } catch (e, st) {
      _log.severe('emergencyStop failed', e, st);
      _error = e;
      _busy = false;
      notifyListeners();
      return true; // Return true even on error to avoid blocking UI
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

  Future<bool> manualTareForceSensor() async {
    _log.info('tareForceSensor');
    if (_busy) return false;
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      await _client.tareForceSensor();
      _busy = false;
      notifyListeners();
      return true;
    } catch (e, st) {
      _log.severe('tareForceSensor failed', e, st);
      _error = e;
      _busy = false;
      notifyListeners();
      return true; // Return true even on error to avoid blocking UI
    }
  }
}

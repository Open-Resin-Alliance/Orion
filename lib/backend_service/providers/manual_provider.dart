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

  // Cached heater enabled state. These are nullable until loaded from the
  // backend via [refreshHeaterEnabled]. When non-null they reflect whether the
  // heater is currently enabled (true) or disabled (false).
  bool? _vatEnabled;
  bool? get vatEnabled => _vatEnabled;
  double? _vatTemp;
  double? get vatTemp => _vatTemp;

  bool? _chamberEnabled;
  bool? get chamberEnabled => _chamberEnabled;
  double? _chamberTemp;
  double? get chamberTemp => _chamberTemp;

  bool _heaterStateLoaded = false;
  bool get heaterStateLoaded => _heaterStateLoaded;

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
    // Emergency stop should override busy state
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

  Future<bool> setVatTemperature(double temperature) async {
    _log.info('setVatTemperature: $temperature');
    if (_busy) return false;
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      await _client.setVatTemperature(temperature);
      // only update cached state after a successful call
      _vatEnabled = temperature > 0.0;
      _busy = false;
      notifyListeners();
      return true;
    } catch (e, st) {
      _log.severe('setVatTemperature failed', e, st);
      _error = e;
      _busy = false;
      notifyListeners();
      return true; // We do not receive confirmation from backend
    }
  }

  Future<bool> setChamberTemperature(double temperature) async {
    _log.info('setChamberTemperature: $temperature');
    if (_busy) return false;
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      await _client.setChamberTemperature(temperature);
      // only update cached state after a successful call
      _chamberEnabled = temperature > 0.0;
      _busy = false;
      notifyListeners();
      return true;
    } catch (e, st) {
      _log.severe('setChamberTemperature failed', e, st);
      _error = e;
      _busy = false;
      notifyListeners();
      return true; // We do not receive confirmation from backend
    }
  }

  /// Refresh the cached heater enabled/disabled state from the backend.
  ///
  /// Returns true on success, false if the backend call failed. After this
  /// returns the public getters [vatEnabled], [chamberEnabled] and
  /// [heaterStateLoaded] will be updated and listeners notified.
  Future<bool> refreshHeaterEnabled({bool quiet = false}) async {
    if (!quiet) _log.info('refreshHeaterEnabled');
    bool anySuccess = false;
    // Call each backend check independently so one failing client doesn't
    // prevent the other from being used. Treat missing/unimplemented
    // methods as simply unavailable rather than fatal.
    try {
      final vat = await _client.isVatTemperatureControlEnabled();
      final vatTemp = await _client.getVatTemperature();
      _vatEnabled = vat;
      _vatTemp = vatTemp;
      anySuccess = true;
    } catch (e, st) {
      _log.fine('isVatTemperatureControlEnabled failed', e, st);
      _vatEnabled = null;
      _vatTemp = 0;
    }

    try {
      final chamber = await _client.isChamberTemperatureControlEnabled();
      final chamberTemp = await _client.getChamberTemperature();
      _chamberEnabled = chamber;
      _chamberTemp = chamberTemp;
      anySuccess = true;
    } catch (e, st) {
      _log.fine('isChamberTemperatureControlEnabled failed', e, st);
      _chamberEnabled = null;
      _chamberTemp = 0;
    }

    _heaterStateLoaded = true;
    notifyListeners();

    if (!anySuccess) {
      // If neither check succeeded, emit a warning so callers know refresh
      // didn't retrieve any state. If at least one succeeded, prefer the
      // partial state and avoid noisy warnings.
      if (!quiet)
        _log.warning('refreshHeaterEnabled failed: no backend responses');
      return false;
    }
    return true;
  }

  /// Convenience helpers to enable/disable the heaters. When enabling without
  /// specifying a temperature a small non-zero temperature (1.0) is used so the
  /// backend receives a non-zero value. In practice callers normally enable
  /// the heater and then set a target temperature via [setVatTemperature] or
  /// [setChamberTemperature].
  Future<bool> setVatEnabled(bool enabled, {double? temperature}) async {
    final temp = enabled ? (temperature ?? 1.0) : 0.0;
    return await setVatTemperature(temp);
  }

  Future<bool> setChamberEnabled(bool enabled, {double? temperature}) async {
    final temp = enabled ? (temperature ?? 1.0) : 0.0;
    return await setChamberTemperature(temp);
  }

  /// Set Z offset to the specified value in millimeters.
  /// Returns true on success, false on failure.
  Future<bool> setZOffset(double offset) async {
    _log.info('setZOffset: $offset');
    if (_busy) return false;
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      final ok = await _client.setZOffset(offset);
      _busy = false;
      notifyListeners();
      return ok;
    } catch (e, st) {
      _log.severe('setZOffset failed', e, st);
      _error = e;
      _busy = false;
      notifyListeners();
      return false;
    }
  }

  /// Reset Z offset to default (typically 0).
  /// Returns true on success, false on failure.
  Future<bool> resetZOffset() async {
    _log.info('resetZOffset');
    if (_busy) return false;
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      final ok = await _client.resetZOffset();
      _busy = false;
      notifyListeners();
      return ok;
    } catch (e, st) {
      _log.severe('resetZOffset failed', e, st);
      _error = e;
      _busy = false;
      notifyListeners();
      return false;
    }
  }
}

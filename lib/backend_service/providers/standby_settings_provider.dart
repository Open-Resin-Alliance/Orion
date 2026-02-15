/*
* Orion - Standby Settings Provider
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

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:orion/util/orion_config.dart';

/// Provider for standby screen settings with change notifications.
/// Allows UI and standby overlay to stay in sync with configuration changes.
class StandbySettingsProvider extends ChangeNotifier {
  final OrionConfig _config = OrionConfig();

  bool _standbyEnabled = true;
  bool _dimmingEnabled = false;
  int _durationSeconds = 150; // Default: 2m30s
  String _backlightDevice = '';
  String _standbyMode = 'clock'; // 'clock' or 'logo'

  bool get standbyEnabled => _standbyEnabled;
  bool get dimmingEnabled => _dimmingEnabled;
  int get durationSeconds => _durationSeconds;
  String get backlightDevice => _backlightDevice;
  String get standbyMode => _standbyMode;

  StandbySettingsProvider() {
    _loadSettings();
    // Auto-detect backlight device on first run if dimming is enabled
    if (_dimmingEnabled && _backlightDevice.isEmpty) {
      autoSelectBacklightDevice();
    }
  }

  void _loadSettings() {
    _standbyEnabled = _config.getFlag('standbyEnabled', category: 'ui');
    _dimmingEnabled = _config.getFlag('standbyDimmingEnabled', category: 'ui');
    _durationSeconds = int.tryParse(
            _config.getString('standbyDurationSeconds', category: 'ui')) ??
        150;
    _backlightDevice = _config.getString('backlightDevice', category: 'ui');
    final mode = _config.getString('standbyMode', category: 'ui');
    _standbyMode = (mode == 'logo') ? 'logo' : 'clock';
  }

  void setStandbyEnabled(bool value) {
    if (_standbyEnabled != value) {
      _standbyEnabled = value;
      _config.setFlag('standbyEnabled', value, category: 'ui');
      notifyListeners();
    }
  }

  void setDimmingEnabled(bool value) {
    if (_dimmingEnabled != value) {
      _dimmingEnabled = value;
      _config.setFlag('standbyDimmingEnabled', value, category: 'ui');
      notifyListeners();
    }
  }

  void setDurationSeconds(int value) {
    if (_durationSeconds != value) {
      _durationSeconds = value;
      _config.setString('standbyDurationSeconds', value.toString(),
          category: 'ui');
      notifyListeners();
    }
  }

  void setBacklightDevice(String value) {
    if (_backlightDevice != value) {
      _backlightDevice = value;
      _config.setString('backlightDevice', value, category: 'ui');
      notifyListeners();
    }
  }

  void setStandbyMode(String value) {
    if (_standbyMode != value) {
      _standbyMode = value;
      _config.setString('standbyMode', value, category: 'ui');
      notifyListeners();
    }
  }

  /// Refresh all settings from config (useful after app resume)
  void refreshSettings() {
    _loadSettings();
    notifyListeners();
  }

  /// Auto-detect available backlight devices by scanning /sys/class/backlight/
  /// Returns a list of device names that have a brightness property
  Future<List<String>> detectBacklightDevices() async {
    try {
      final backlightDir = Directory('/sys/class/backlight');
      if (!await backlightDir.exists()) {
        return [];
      }

      final devices = <String>[];
      await for (final entry in backlightDir.list()) {
        if (entry is Directory) {
          final deviceName = entry.path.split('/').last;
          final brightnessFile = File('${entry.path}/brightness');
          if (await brightnessFile.exists()) {
            devices.add(deviceName);
          }
        }
      }
      return devices;
    } catch (e) {
      print('Error detecting backlight devices: $e');
      return [];
    }
  }

  /// Auto-select the first available backlight device if none is set
  Future<void> autoSelectBacklightDevice() async {
    if (_backlightDevice.isNotEmpty) {
      return; // Already configured
    }

    final devices = await detectBacklightDevices();
    if (devices.isNotEmpty) {
      setBacklightDevice(devices.first);
    }
  }
}

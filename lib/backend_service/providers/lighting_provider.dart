/*
* Orion - Lighting Provider
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
import 'package:orion/backend_service/backend_client.dart';
import 'package:orion/backend_service/backend_registry.dart';
import 'package:orion/backend_service/backend_service.dart';
import 'package:orion/util/orion_config.dart';

/// Provider for controlling printer LEDs.
///
/// This is intentionally config-driven so each vendor/backend can define the
/// exact command format without changing app code.
///
/// Supported config keys (category: `ui`):
/// - `standbyLedDimmingEnabled` (bool)
/// - `ledBrightnessCommandTemplate` (String, e.g. `SET_LED_BRIGHTNESS VALUE={value}`)
/// - `ledStandbyCommandTemplate` (String, e.g. `SET_LED_EFFECT EFFECT=standby BRIGHTNESS={percent}`)
/// - `ledWakeCommandTemplate` (String, e.g. `SET_LED_EFFECT EFFECT=standby STOP=1`)
/// - `ledMaxBrightness` (String/int, default 255)
/// - `ledStandbyMinBrightness` (String/int, default 0)
///
/// Supported template placeholders:
/// - `{value}`: brightness value in configured range
/// - `{percent}`: brightness percent 0..100
/// - `{progress}`: standby dim progress 0..1
/// - `{normalized}`: brightness normalized 0..1
/// - `{r}`, `{g}`, `{b}`: Orion theme color channels as 0..255 ints
/// - `{rf}`, `{gf}`, `{bf}`: Orion theme color channels as 0..1 floats
class LightingProvider extends ChangeNotifier {
  final BackendClient _client;
  final OrionConfig _config;
  final _log = Logger('LightingProvider');

  static const Duration _commandThrottle = Duration(milliseconds: 120);
  static const Duration _duplicateCommandWindow = Duration(milliseconds: 350);
  static String? _globalLastCommand;
  static DateTime _globalLastCommandAt = DateTime.fromMillisecondsSinceEpoch(0);
  static final Set<String> _inFlightCommands = <String>{};

  bool _standbyLedDimmingEnabled = false;
  bool _standbyLedUseEffects = false;
  bool _standbyEffectStarted = false;
  bool _supportsRgbLighting = false;
  String _ledBrightnessCommandTemplate = '';
  String _ledStandbyCommandTemplate = '';
  String _ledWakeCommandTemplate = '';
  int _ledMaxBrightness = 255;
  int _ledStandbyMinBrightness = 0;

  int _lastSentBrightness = -1;
  DateTime _lastCommandAt = DateTime.fromMillisecondsSinceEpoch(0);
  String? _lastCommand;
  Timer? _flushTimer;
  int? _queuedBrightness;

  bool _temporarilyDisabled = false;

  bool get standbyLedDimmingEnabled => _standbyLedDimmingEnabled;
  bool get hasLedCommandTemplate => _activeProgressTemplate.isNotEmpty;
  int get ledMaxBrightness => _ledMaxBrightness;
  int get ledStandbyMinBrightness => _ledStandbyMinBrightness;

  String get _activeProgressTemplate {
    if (_ledBrightnessCommandTemplate.isNotEmpty) {
      return _ledBrightnessCommandTemplate;
    }
    // Backends that support RGB lighting can use direct Klipper/led_effects
    // style command templates for standby effects.
    if (_supportsRgbLighting && _ledStandbyCommandTemplate.isNotEmpty) {
      return _ledStandbyCommandTemplate;
    }
    return _ledStandbyCommandTemplate;
  }

  LightingProvider({BackendClient? client, OrionConfig? config})
      : _client = client ?? BackendService(),
        _config = config ?? OrionConfig() {
    _loadSettings();
    OrionConfig.addChangeListener(_handleConfigChange);
  }

  @override
  void dispose() {
    OrionConfig.removeChangeListener(_handleConfigChange);
    _flushTimer?.cancel();
    super.dispose();
  }

  void _handleConfigChange() {
    refreshSettings();
  }

  void refreshSettings() {
    _loadSettings();
    _temporarilyDisabled = false;
    _standbyEffectStarted = false;
    notifyListeners();
  }

  void setStandbyLedDimmingEnabled(bool value) {
    if (_standbyLedDimmingEnabled == value) return;
    _standbyLedDimmingEnabled = value;
    _config.setFlag('standbyLedDimmingEnabled', value, category: 'ui');
    if (!value) {
      _flushTimer?.cancel();
      _flushTimer = null;
      _queuedBrightness = null;
      _standbyEffectStarted = false;
    }
    _temporarilyDisabled = false;
    notifyListeners();
  }

  void _loadSettings() {
    final backendId = _config.getString('backend', category: 'advanced');
    final registry = BackendRegistry();
    _supportsRgbLighting = registry.supportsCapability(
            backendId, BackendCapabilities.supportsRgbLighting) ??
        false;

    _standbyLedDimmingEnabled =
        _config.getFlag('standbyLedDimmingEnabled', category: 'ui');
    _standbyLedUseEffects =
        _config.getFlag('standbyLedUseEffects', category: 'ui');

    _ledBrightnessCommandTemplate = _config
        .getString('ledBrightnessCommandTemplate', category: 'ui')
        .trim();

    _ledStandbyCommandTemplate =
        _config.getString('ledStandbyCommandTemplate', category: 'ui').trim();

    _ledWakeCommandTemplate =
        _config.getString('ledWakeCommandTemplate', category: 'ui').trim();

    final maxRaw = int.tryParse(
          _config.getString('ledMaxBrightness', category: 'ui'),
        ) ??
        255;
    _ledMaxBrightness = maxRaw.clamp(1, 4095);

    final minRaw = int.tryParse(
          _config.getString('ledStandbyMinBrightness', category: 'ui'),
        ) ??
        0;
    _ledStandbyMinBrightness = minRaw.clamp(0, _ledMaxBrightness);
  }

  Future<void> applyStandbyProgress(double progress) async {
    if (!_standbyLedDimmingEnabled || _temporarilyDisabled) return;
    if (_activeProgressTemplate.isEmpty) return;

    final p = progress.clamp(0.0, 1.0);
    final target =
        (_ledMaxBrightness * (1.0 - p) + _ledStandbyMinBrightness * p).round();

    // Effect mode: trigger standby animation once and let Klipper animate.
    final useEffects = _standbyLedUseEffects ||
        (_ledWakeCommandTemplate.isNotEmpty &&
            _ledStandbyCommandTemplate.isNotEmpty &&
            _ledBrightnessCommandTemplate.isEmpty);
    if (useEffects) {
      if (_standbyEffectStarted) return;
      _standbyEffectStarted = true;
      await _sendBrightness(target, progress: p, force: true);
      return;
    }

    _throttledSetBrightness(target, progress: p);
  }

  Future<void> setFullBrightness() async {
    if (_temporarilyDisabled) return;
    _standbyEffectStarted = false;

    // If a dedicated wake command is configured (typical with led_effects), use it.
    if (_ledWakeCommandTemplate.isNotEmpty) {
      await _sendWithTemplate(
        _ledWakeCommandTemplate,
        _ledMaxBrightness,
        progress: 0.0,
        force: true,
      );
      return;
    }

    if (_activeProgressTemplate.isEmpty) return;
    await _sendBrightness(_ledMaxBrightness, progress: 0.0, force: true);
  }

  void _throttledSetBrightness(int level, {required double progress}) {
    final target = level.clamp(0, _ledMaxBrightness);
    final sinceLast = DateTime.now().difference(_lastCommandAt);

    if (sinceLast >= _commandThrottle) {
      _flushTimer?.cancel();
      _flushTimer = null;
      _queuedBrightness = null;
      unawaited(_sendBrightness(target, progress: progress));
      return;
    }

    _queuedBrightness = target;
    _flushTimer?.cancel();
    _flushTimer = Timer(_commandThrottle - sinceLast, () {
      final queued = _queuedBrightness;
      _queuedBrightness = null;
      if (queued != null) {
        final p =
            (1.0 - (queued / _ledMaxBrightness)).clamp(0.0, 1.0).toDouble();
        unawaited(_sendBrightness(queued, progress: p));
      }
    });
  }

  Future<void> _sendBrightness(int level,
      {required double progress, bool force = false}) async {
    final target = level.clamp(0, _ledMaxBrightness);

    if (!force && target == _lastSentBrightness) {
      return;
    }

    final template = _activeProgressTemplate;
    if (template.isEmpty) {
      return;
    }

    await _sendWithTemplate(template, target, progress: progress, force: force);
  }

  Future<void> _sendWithTemplate(
    String template,
    int target, {
    required double progress,
    bool force = false,
  }) async {
    if (template.isEmpty) return;
    if (!force && target == _lastSentBrightness) return;

    final percent = ((target / _ledMaxBrightness) * 100).round().clamp(0, 100);
    final normalized = (target / _ledMaxBrightness).clamp(0.0, 1.0);
    final theme = _resolveThemeColor();
    final r = (theme.r * 255).round().clamp(0, 255);
    final g = (theme.g * 255).round().clamp(0, 255);
    final b = (theme.b * 255).round().clamp(0, 255);
    final command = template
        .replaceAll('{value}', '$target')
        .replaceAll('{percent}', '$percent')
        .replaceAll('{progress}', progress.toStringAsFixed(4))
        .replaceAll('{normalized}', normalized.toStringAsFixed(4))
        .replaceAll('{r}', '$r')
        .replaceAll('{g}', '$g')
        .replaceAll('{b}', '$b')
        .replaceAll('{rf}', theme.r.toStringAsFixed(4))
        .replaceAll('{gf}', theme.g.toStringAsFixed(4))
        .replaceAll('{bf}', theme.b.toStringAsFixed(4));

    final now = DateTime.now();
    if (_lastCommand == command &&
        now.difference(_lastCommandAt) < _duplicateCommandWindow) {
      return;
    }

    // Cross-instance dedupe safety (in case multiple callers/providers fire).
    if (_globalLastCommand == command &&
        now.difference(_globalLastCommandAt) < _duplicateCommandWindow) {
      return;
    }

    if (_inFlightCommands.contains(command)) {
      return;
    }

    _inFlightCommands.add(command);
    _globalLastCommand = command;
    _globalLastCommandAt = now;

    try {
      await _client.manualCommand(command);
      _lastSentBrightness = target;
      _lastCommandAt = now;
      _lastCommand = command;
    } catch (e, st) {
      _log.warning('LED brightness command failed: "$command"', e, st);
      // Avoid spamming backend/logs if command isn't supported on this printer.
      _temporarilyDisabled = true;
    } finally {
      _inFlightCommands.remove(command);
    }
  }

  Color _resolveThemeColor() {
    try {
      final seed =
          _config.getString('colorSeed', category: 'general').toLowerCase();
      switch (seed) {
        case 'purple':
          return Colors.deepPurple;
        case 'blue':
          return Colors.blue;
        case 'green':
          return Colors.green;
        case 'red':
          return Colors.red;
        case 'orange':
          return Colors.orange;
        case 'vendor':
          final vendorTheme = _config.getThemeSeed('vendor');
          final hasVendorColor = vendorTheme.r != 0 ||
              vendorTheme.g != 0 ||
              vendorTheme.b != 0 ||
              vendorTheme.a != 0;
          return hasVendorColor ? vendorTheme : Colors.blue;
        default:
          return Colors.blue;
      }
    } catch (_) {
      return const Color(0xFF00FA00);
    }
  }
}

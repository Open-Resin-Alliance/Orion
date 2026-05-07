/*
* Orion - NanoDLP Simulated Backend Client
* Copyright (C) 2025 Open Resin Alliance
*
* Licensed under the Apache License, Version 2.0 (the "License");
* you may not use this file except in compliance with the License.
* You may obtain a copy of the License at
*
*     http://www.apache.org/licenses/LICENSE-2.0
*/

import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:orion/backend_service/backend_client.dart';
import 'package:orion/backend_service/domain/models.dart';
import 'package:orion/backend_service/nanodlp/helpers/nano_thumbnail_generator.dart';
import 'package:orion/backend_service/nanodlp/models/nano_status.dart';
import 'package:orion/backend_service/nanodlp/nanodlp_mappers.dart';

/// Printerless, deterministic NanoDLP simulator for development/testing.
///
/// Intentionally avoids background timers to keep tests stable.
class NanoDlpSimulatedClient implements BackendClient {
  NanoDlpSimulatedClient({int totalLayers = 200, double layerSeconds = 2.5})
      : _totalLayers = max(1, totalLayers),
        _layerSeconds = layerSeconds <= 0 ? 2.5 : layerSeconds {
    _seedProfiles();
  }

  final int _totalLayers;
  final double _layerSeconds;

  final StreamController<Map<String, dynamic>> _statusController =
      StreamController<Map<String, dynamic>>.broadcast();

  bool _printing = false;
  bool _paused = false;
  bool _cancelLatched = false;
  int _currentLayer = 0;

  String _currentFilePath = '/sim/demo_print.gcode';
  String _currentFileName = 'demo_print.gcode';

  DateTime? _startedAt;
  DateTime? _pausedAt;
  Duration _pauseAccumulated = Duration.zero;

  int? _defaultProfileId = 1;
  double _zOffset = 0.0;
  double _zHeightMm = 0.0;
  double _vatTemp = 23.0;
  double _chamberTemp = 24.0;
  // Hardware presence is static in the simulator.
  final bool _vatHeaterPresent = true;
  final bool _chamberHeaterPresent = true;

  // Runtime enabled-state should reflect user actions.
  bool _vatControlEnabled = false;
  bool _chamberControlEnabled = false;

  final List<Map<String, dynamic>> _files = [];
  final Map<int, Map<String, dynamic>> _profiles = {};

  void _seedProfiles() {
    for (var i = 1; i <= 3; i++) {
      _profiles[i] = {
        'ResinID': i,
        'ProfileID': i,
        'Title': 'Sim Resin #$i',
        'Desc': 'Simulated profile',
        'normal_cure_time': 2.0 + i,
        'burn_in_cure_time': 12.0,
        'lift_after_print': 5.0,
        'burn_in_count': 4,
        'wait_after_cure': 1.5,
        'wait_after_life': 1.5,
        'CustomValues': {
          'normal_cure_time': '${2.0 + i}',
          'burn_in_cure_time': '12.0',
          'lift_after_print': '5.0',
          'burn_in_count': '4',
          'wait_after_cure': '1.5',
          'wait_after_life': '1.5',
        }
      };
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    _files.addAll([
      {
        'name': 'demo_print.gcode',
        'path': '/sim/demo_print.gcode',
        'last_modified': now,
      },
      {
        'name': 'calibration_plate.gcode',
        'path': '/sim/calibration_plate.gcode',
        'last_modified': now - 5000,
      }
    ]);
  }

  void _syncProgress() {
    if (!_printing || _paused || _startedAt == null) return;
    final now = DateTime.now();
    final elapsed = now.difference(_startedAt!).inMilliseconds / 1000.0;
    final active = elapsed - _pauseAccumulated.inMilliseconds / 1000.0;
    final layer = min(_totalLayers, max(0, active ~/ _layerSeconds));
    if (layer != _currentLayer) _currentLayer = layer;

    if (_currentLayer >= _totalLayers) {
      _printing = false;
      _paused = false;
      _pausedAt = null;
    }
  }

  Map<String, dynamic> _nanoStatus() {
    _syncProgress();
    return {
      'Printing': _printing,
      'Paused': _paused,
      'Status': _printing
          ? (_paused ? 'Paused' : 'Printing')
          : (_cancelLatched ? 'Canceled' : 'Idle'),
      'State': _printing ? (_paused ? 6 : 5) : 0,
      'LayerID': _currentLayer,
      'LayersCount': _totalLayers,
      'CurrentHeight': (_zHeightMm * 6400).round(),
      'PrevLayerTime': (_layerSeconds * 1e9).round(),
      'resin': _vatTemp,
      'temp': _chamberTemp,
      'mcu': 46.0,
      'file': {
        'name': _currentFileName,
        'path': _currentFilePath,
        'layer_count': _totalLayers,
      },
      'cancel_latched': _cancelLatched,
      'pause_latched': _paused,
    };
  }

  Map<String, dynamic> _mappedStatus() {
    final raw = _nanoStatus();
    try {
      final ns = NanoStatus.fromJson(Map<String, dynamic>.from(raw));
      return nanoStatusToOdysseyMap(ns);
    } catch (_) {
      return raw;
    }
  }

  void _emitStatus() {
    if (!_statusController.isClosed) {
      _statusController.add(_mappedStatus());
    }
  }

  @override
  Future<Map<String, dynamic>> listItems(
      String location, int pageSize, int pageIndex, String subdirectory) async {
    if (location.toLowerCase() == 'resins') {
      final profileItems = _profiles.values.map((p) {
        final id = p['ProfileID'] ?? p['ResinID'];
        final title = (p['Title'] ?? p['title'] ?? 'Sim Resin').toString();
        return <String, dynamic>{
          'id': id,
          'ProfileID': id,
          'ResinID': p['ResinID'] ?? id,
          'title': title,
          'name': title,
          'path': '/sim/resins/$id',
          'locked': false,
        };
      }).toList(growable: false);

      final start = pageIndex * pageSize;
      final end = min(profileItems.length, start + pageSize);
      final page = (start >= 0 && start < profileItems.length)
          ? profileItems.sublist(start, end)
          : <Map<String, dynamic>>[];
      return {
        'resins': page,
        'files': page,
        'dirs': <Map<String, dynamic>>[],
        'page_index': pageIndex,
        'page_size': pageSize,
        'total': profileItems.length,
      };
    }

    final start = pageIndex * pageSize;
    final end = min(_files.length, start + pageSize);
    final page = (start >= 0 && start < _files.length)
        ? _files.sublist(start, end)
        : <Map<String, dynamic>>[];
    return {
      'files': page,
      'dirs': <Map<String, dynamic>>[],
      'page_index': pageIndex,
      'page_size': pageSize,
      'total': _files.length,
    };
  }

  @override
  Future<bool> usbAvailable() async => true;

  @override
  Future<Map<String, dynamic>> getFileMetadata(
      String location, String filePath) async {
    return {
      'file_data': {
        'path': filePath,
        'name': filePath.split('/').last,
        'last_modified': DateTime.now().millisecondsSinceEpoch,
        'parent_path': '/sim',
      }
    };
  }

  @override
  Future<Map<String, dynamic>> getConfig() async => {
        'general': {'hostname': 'sim-nanodlp'},
        'advanced': {'backend': 'nanodlp', 'simulated': true},
      };

  @override
  Future<String> getBackendVersion() async => 'nanodlp-sim-3.0';

  @override
  Future<Uint8List> getFileThumbnail(
      String location, String filePath, String size) async {
    if (size == 'thumb') {
      return NanoDlpThumbnailGenerator.generatePlaceholder(160, 96);
    }
    return NanoDlpThumbnailGenerator.generatePlaceholder(
      NanoDlpThumbnailGenerator.largeWidth,
      NanoDlpThumbnailGenerator.largeHeight,
    );
  }

  @override
  Future<void> startPrint(String location, String filePath) async {
    _currentFilePath = filePath.trim().isEmpty ? _currentFilePath : filePath;
    _currentFileName = _currentFilePath.split('/').last;
    _printing = true;
    _paused = false;
    _cancelLatched = false;
    _currentLayer = 0;
    _startedAt = DateTime.now();
    _pausedAt = null;
    _pauseAccumulated = Duration.zero;
    _emitStatus();
  }

  @override
  Future<Map<String, dynamic>> deleteFile(
      String location, String filePath) async {
    _files.removeWhere((f) => f['path'] == filePath);
    return {'deleted': true};
  }

  @override
  Future<void> invalidateCache() async {}

  @override
  Future<int?> importFile(FileImportRequest request) async {
    final id = _files.length + 1;
    final name = request.jobName.trim().isNotEmpty
        ? request.jobName.trim()
        : 'imported_$id.gcode';
    _files.insert(0, {
      'name': name,
      'path': '/sim/$name',
      'last_modified': DateTime.now().millisecondsSinceEpoch,
    });
    return id;
  }

  @override
  Future<ResinSettings?> getResinSettings(int profileId) async {
    final p = await getProfileJson(profileId);
    return ResinSettings.fromNormalizedMap(p);
  }

  @override
  Future<void> saveResinExposure(int profileId, double normalCureTime) async {
    await editProfile(profileId, {'normal_cure_time': normalCureTime});
  }

  @override
  Future<void> saveResinSettings(int profileId, ResinSettings settings) async {
    await editProfile(profileId, settings.toNormalizedMap());
  }

  @override
  Future<Map<String, dynamic>> getStatus() async => _mappedStatus();

  @override
  Stream<Map<String, dynamic>> getStatusStream() {
    Future.microtask(_emitStatus);
    return _statusController.stream;
  }

  @override
  Future<List<Map<String, dynamic>>> getNotifications() async => [];

  @override
  Future<Map<String, dynamic>?> getKinematicStatus() async => {
        'homed': true,
        'offset': _zOffset,
        'position': _zHeightMm,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };

  @override
  Future<void> disableNotification(int timestamp) async {}

  @override
  Future<void> cancelPrint() async {
    _printing = false;
    _paused = false;
    _cancelLatched = true;
    _currentLayer = 0;
    _emitStatus();
  }

  @override
  Future<void> pausePrint() async {
    if (!_printing || _paused) return;
    _paused = true;
    _pausedAt = DateTime.now();
    _emitStatus();
  }

  @override
  Future<void> resumePrint() async {
    if (!_printing || !_paused) return;
    if (_pausedAt != null) {
      _pauseAccumulated += DateTime.now().difference(_pausedAt!);
    }
    _paused = false;
    _pausedAt = null;
    _emitStatus();
  }

  @override
  Future<Map<String, dynamic>> move(double height) async {
    _zHeightMm = height;
    return {'ok': true, 'z': _zHeightMm};
  }

  @override
  Future<Map<String, dynamic>> moveDelta(double deltaMm) async {
    _zHeightMm += deltaMm;
    return {'ok': true, 'z': _zHeightMm};
  }

  @override
  Future<bool> canMoveToTop() async => true;

  @override
  Future<bool> canMoveToFloor() async => true;

  @override
  Future<Map<String, dynamic>> moveToTop() async {
    _zHeightMm = 200;
    return {'ok': true, 'z': _zHeightMm};
  }

  @override
  Future<Map<String, dynamic>> moveToFloor() async {
    _zHeightMm = 0;
    return {'ok': true, 'z': _zHeightMm};
  }

  @override
  Future<Map<String, dynamic>> manualCure(bool cure) async => {'ok': true};

  @override
  Future<Map<String, dynamic>> manualHome() async {
    _zHeightMm = 0;
    return {'ok': true};
  }

  @override
  Future<Map<String, dynamic>> manualCommand(String command) async => {
        'ok': true,
        'command': command,
      };

  @override
  Future<Map<String, dynamic>> emergencyStop() async {
    await cancelPrint();
    return {'stopped': true};
  }

  @override
  Future<void> displayTest(String test) async {}

  @override
  Future<Uint8List> getPlateLayerImage(int plateId, int layer) async {
    return NanoDlpThumbnailGenerator.generatePlaceholder(320, 200);
  }

  @override
  Future<List<Map<String, dynamic>>> getAnalytics(int n) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final rows = [
      {'T': 7, 'V': _chamberTemp, 'id': now},
      {'T': 12, 'V': _chamberTemp, 'id': now},
      {'T': 23, 'V': _chamberTemp, 'id': now},
      {'T': 25, 'V': _vatTemp, 'id': now},
      {'T': 31, 'V': _currentLayer, 'id': now},
    ];
    return rows.take(max(0, n)).toList();
  }

  @override
  Future<dynamic> getAnalyticValue(int id) async {
    switch (id) {
      case 7:
      case 12:
      case 23:
        return _chamberTemp;
      case 25:
        return _vatTemp;
      default:
        return Random().nextDouble() * 10;
    }
  }

  @override
  Future<Map<String, dynamic>> getMachine() async => {
        'Name': 'NanoDLP-Sim',
        'UUID': 'sim-uuid',
        'DefaultProfile': _defaultProfileId,
        'CustomValues': {
          'VatHeaterPresent': _vatHeaterPresent ? '1' : '0',
          'ChamberHeaterPresent': _chamberHeaterPresent ? '1' : '0',
        },
      };

  @override
  Future<Map<String, dynamic>> getProfileJson(int id) async {
    return Map<String, dynamic>.from(
      _profiles[id] ??
          {
            'ProfileID': id,
            'Title': 'Sim Resin #$id',
            'Desc': 'Auto-generated profile',
            'normal_cure_time': 3.0,
            'burn_in_cure_time': 12.0,
            'lift_after_print': 5.0,
            'burn_in_count': 4,
            'wait_after_cure': 1.5,
            'wait_after_life': 1.5,
            'CustomValues': {
              'normal_cure_time': '3.0',
              'burn_in_cure_time': '12.0',
              'lift_after_print': '5.0',
              'burn_in_count': '4',
              'wait_after_cure': '1.5',
              'wait_after_life': '1.5',
            },
          },
    );
  }

  @override
  Future<Map<String, dynamic>> editProfile(
      int id, Map<String, dynamic> fields) async {
    final base = await getProfileJson(id);
    final merged = Map<String, dynamic>.from(base);
    final custom = merged['CustomValues'] is Map
        ? Map<String, dynamic>.from(merged['CustomValues'])
        : <String, dynamic>{};

    fields.forEach((k, v) {
      merged[k] = v;
      custom[k] = '$v';
    });

    merged['CustomValues'] = custom;
    _profiles[id] = merged;
    return merged;
  }

  @override
  Future<int?> getDefaultProfileId() async => _defaultProfileId;

  @override
  Future<void> setDefaultProfileId(int id) async {
    _defaultProfileId = id;
  }

  @override
  Future<dynamic> tareForceSensor() async => true;

  @override
  Future<dynamic> updateBackend() async => true;

  @override
  Future setChamberTemperature(double temperature) async {
    _chamberTemp = temperature;
    _chamberControlEnabled = temperature > 0.0;
    return true;
  }

  @override
  Future setVatTemperature(double temperature) async {
    _vatTemp = temperature;
    _vatControlEnabled = temperature > 0.0;
    return true;
  }

  @override
  Future<bool> isChamberTemperatureControlEnabled() async =>
      _chamberControlEnabled;

  @override
  Future<bool> isVatTemperatureControlEnabled() async => _vatControlEnabled;

  @override
  Future getChamberTemperature() async => _chamberTemp;

  @override
  Future getVatTemperature() async => _vatTemp;

  @override
  Future<void> preheatAndMix(double temperature) async {
    await setVatTemperature(temperature);
  }

  @override
  Future<void> preheatAndMixStandalone() async {}

  @override
  Future<String?> getCalibrationImageUrl(int modelId) async {
    return 'http://localhost/static/shots/calibration-images/$modelId.png';
  }

  @override
  Future<List<Map<String, dynamic>>> getCalibrationModels() async {
    return [
      {
        'id': 1,
        'name': 'J3D Calibration RERF',
        'models': 6,
        'info': {'resinRequired': 21, 'height': 3700},
      },
      {
        'id': 2,
        'name': 'J3D Calibration Boxes of Calibration',
        'models': 6,
        'info': {'resinRequired': 9, 'height': 10100},
      },
    ];
  }

  @override
  Future<bool> startCalibrationPrint({
    required int calibrationModelId,
    required List<double> exposureTimes,
    required int profileId,
  }) async {
    await startPrint('Local', '/sim/calibration_$calibrationModelId.gcode');
    return true;
  }

  @override
  Future<double?> getSlicerProgress() async {
    if (!_printing) return null;
    _syncProgress();
    return (_currentLayer / _totalLayers).clamp(0.0, 1.0);
  }

  @override
  Future<bool?> isCalibrationPlateProcessed() async {
    _syncProgress();
    return !_printing && _currentLayer >= _totalLayers;
  }

  @override
  Future<bool> resetZOffset() async {
    _zOffset = 0;
    return true;
  }

  @override
  Future<bool> setZOffset(double offset) async {
    _zOffset = offset;
    return true;
  }

  void dispose() {
    if (!_statusController.isClosed) {
      _statusController.close();
    }
  }
}

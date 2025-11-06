/*
* Orion - Backend Service
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

import 'dart:typed_data';
import 'package:orion/backend_service/backend_client.dart';
import 'package:orion/backend_service/odyssey/odyssey_http_client.dart';
import 'package:orion/backend_service/nanodlp/nanodlp_http_client.dart';
import 'package:orion/backend_service/nanodlp/helpers/nano_simulated_client.dart';
import 'package:orion/util/orion_config.dart';

/// BackendService is a small façade that selects a concrete
/// `BackendClient` implementation at runtime. This centralizes the
/// point where an alternative backend implementation (different API)
/// can be swapped in without changing providers or UI code.
class BackendService implements BackendClient {
  final BackendClient _delegate;

  /// Default constructor: picks the concrete implementation based on
  /// configuration (or defaults to the HTTP adapter).
  BackendService({BackendClient? delegate})
      : _delegate = delegate ?? _chooseFromConfig();

  static BackendClient _chooseFromConfig() {
    try {
      final cfg = OrionConfig();
      // Developer-mode simulated backend flag (developer.simulated = true)
      final simulated = cfg.getFlag('simulated', category: 'developer');
      if (simulated) {
        return NanoDlpSimulatedClient();
      }
      if (cfg.isNanoDlpMode()) {
        // Return the NanoDLP adapter when explicitly requested in config.
        return NanoDlpHttpClient();
      }
    } catch (_) {
      // ignore config errors and fall back
    }
    return OdysseyHttpClient();
  }

  // Forward all BackendClient methods to the selected delegate.
  @override
  Future<Map<String, dynamic>> listItems(
          String location, int pageSize, int pageIndex, String subdirectory) =>
      _delegate.listItems(location, pageSize, pageIndex, subdirectory);

  @override
  Future<bool> usbAvailable() => _delegate.usbAvailable();

  @override
  Future<Map<String, dynamic>> getFileMetadata(
          String location, String filePath) =>
      _delegate.getFileMetadata(location, filePath);

  @override
  Future<Map<String, dynamic>> getConfig() => _delegate.getConfig();

  @override
  Future<String> getBackendVersion() => _delegate.getBackendVersion();

  @override
  Future<Uint8List> getFileThumbnail(
          String location, String filePath, String size) =>
      _delegate.getFileThumbnail(location, filePath, size);

  @override
  Future<void> startPrint(String location, String filePath) =>
      _delegate.startPrint(location, filePath);

  @override
  Future<Map<String, dynamic>> deleteFile(String location, String filePath) =>
      _delegate.deleteFile(location, filePath);

  @override
  Future<Map<String, dynamic>> getStatus() => _delegate.getStatus();

  @override
  Stream<Map<String, dynamic>> getStatusStream() => _delegate.getStatusStream();

  @override
  Future<List<Map<String, dynamic>>> getNotifications() =>
      _delegate.getNotifications();

  @override
  Future<void> disableNotification(int timestamp) =>
      _delegate.disableNotification(timestamp);

  @override
  Future<void> cancelPrint() => _delegate.cancelPrint();

  @override
  Future<void> pausePrint() => _delegate.pausePrint();

  @override
  Future<void> resumePrint() => _delegate.resumePrint();

  @override
  Future<Map<String, dynamic>> move(double height) => _delegate.move(height);

  @override
  Future<Map<String, dynamic>> moveDelta(double deltaMm) =>
      _delegate.moveDelta(deltaMm);

  @override
  Future<bool> canMoveToTop() => _delegate.canMoveToTop();

  @override
  Future<Map<String, dynamic>> moveToTop() => _delegate.moveToTop();

  @override
  Future<bool> canMoveToFloor() => _delegate.canMoveToFloor();

  @override
  Future<Map<String, dynamic>> moveToFloor() => _delegate.moveToFloor();

  @override
  Future<Map<String, dynamic>> manualCure(bool cure) =>
      _delegate.manualCure(cure);

  @override
  Future<Map<String, dynamic>> manualHome() => _delegate.manualHome();

  @override
  Future<Map<String, dynamic>> manualCommand(String command) =>
      _delegate.manualCommand(command);

  @override
  Future<Map<String, dynamic>> emergencyStop() => _delegate.emergencyStop();

  @override
  Future<void> displayTest(String test) => _delegate.displayTest(test);

  @override
  Future<Uint8List> getPlateLayerImage(int plateId, int layer) =>
      _delegate.getPlateLayerImage(plateId, layer);

  @override
  Future<List<Map<String, dynamic>>> getAnalytics(int n) =>
      _delegate.getAnalytics(n);

  @override
  Future<dynamic> getAnalyticValue(int id) => _delegate.getAnalyticValue(id);

  @override
  Future<Map<String, dynamic>> getMachine() => _delegate.getMachine();

  @override
  Future<int?> getDefaultProfileId() => _delegate.getDefaultProfileId();

  @override
  Future<Map<String, dynamic>> editProfile(
      int id, Map<String, dynamic> fields) async {
    try {
      return await _delegate.editProfile(id, fields);
    } catch (e, _) {
      // Treat backend-specific errors as empty result so callers don't crash
      return {};
    }
  }

  @override
  Future<Map<String, dynamic>> getProfileJson(int id) async {
    try {
      return await _delegate.getProfileJson(id);
    } catch (e, _) {
      // Don't let backend-specific fetch failures throw into UI code —
      // treat as unsupported/empty result.
      // Note: individual delegates should log details; keep this quiet
      // at info level to avoid spamming.
      return {};
    }
  }

  @override
  Future<void> setDefaultProfileId(int id) => _delegate.setDefaultProfileId(id);

  @override
  Future<dynamic> tareForceSensor() => _delegate.tareForceSensor();

  @override
  Future setChamberTemperature(double temperature) =>
      _delegate.setChamberTemperature(temperature);

  @override
  Future setVatTemperature(double temperature) =>
      _delegate.setVatTemperature(temperature);

  @override
  Future getChamberTemperature() => _delegate.getChamberTemperature();

  @override
  Future getVatTemperature() => _delegate.getVatTemperature();

  @override
  Future<bool> isChamberTemperatureControlEnabled() {
    return _delegate.isChamberTemperatureControlEnabled();
  }

  @override
  Future<bool> isVatTemperatureControlEnabled() {
    return _delegate.isVatTemperatureControlEnabled();
  }

  @override
  Future<void> preheatAndMix(double temperature) =>
      _delegate.preheatAndMix(temperature);

  @override
  Future<String?> getCalibrationImageUrl(int modelId) =>
      _delegate.getCalibrationImageUrl(modelId);

  @override
  Future<List<Map<String, dynamic>>> getCalibrationModels() =>
      _delegate.getCalibrationModels();

  @override
  Future<bool> startCalibrationPrint({
    required int calibrationModelId,
    required List<double> exposureTimes,
    required int profileId,
  }) =>
      _delegate.startCalibrationPrint(
        calibrationModelId: calibrationModelId,
        exposureTimes: exposureTimes,
        profileId: profileId,
      );

  @override
  Future<double?> getSlicerProgress() => _delegate.getSlicerProgress();

  @override
  Future<bool?> isCalibrationPlateProcessed() =>
      _delegate.isCalibrationPlateProcessed();
}

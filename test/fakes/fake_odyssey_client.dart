/*
* Orion - Fake Odyssey Client
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
import 'dart:async';

import 'package:orion/backend_service/backend_client.dart';

/// Simple fake client used by unit tests to assert ManualProvider behavior.
class FakeBackendClient implements BackendClient {
  bool moveCalled = false;
  double? lastMoveHeight;
  bool manualHomeCalled = false;
  bool manualCureCalled = false;
  bool displayTestCalled = false;
  String? lastCommand;

  bool throwOnMove = false;

  @override
  Future<void> cancelPrint() => throw UnimplementedError();

  @override
  Future<Map<String, dynamic>> deleteFile(String location, String filePath) =>
      throw UnimplementedError();

  @override
  Future<Map<String, dynamic>> getConfig() => throw UnimplementedError();

  @override
  Future<Map<String, dynamic>> getFileMetadata(
          String location, String filePath) =>
      throw UnimplementedError();

  @override
  Future<Uint8List> getFileThumbnail(
          String location, String filePath, String size) =>
      throw UnimplementedError();

  @override
  Future<Map<String, dynamic>> getStatus() => throw UnimplementedError();

  @override
  Stream<Map<String, dynamic>> getStatusStream() => Stream.empty();

  @override
  Future<bool> pausePrint() => throw UnimplementedError();

  @override
  Future<void> resumePrint() => throw UnimplementedError();

  @override
  Future<bool> startPrint(String location, String filePath) =>
      throw UnimplementedError();

  @override
  Future<bool> usbAvailable() => Future.value(true);

  @override
  Future<Map<String, dynamic>> listItems(
          String location, int pageSize, int pageIndex, String subdirectory) =>
      throw UnimplementedError();

  @override
  Future<Map<String, dynamic>> manualHome() async {
    manualHomeCalled = true;
    return {};
  }

  @override
  Future<Map<String, dynamic>> manualCommand(String command) async {
    lastCommand = command;
    return {};
  }

  @override
  Future<Map<String, dynamic>> manualCure(bool cure) async {
    manualCureCalled = true;
    return {};
  }

  @override
  Future<Map<String, dynamic>> move(double height) async {
    if (throwOnMove) throw Exception('move failed');
    moveCalled = true;
    lastMoveHeight = height;
    return {};
  }

  @override
  Future<void> displayTest(String test) async {
    displayTestCalled = true;
  }

  @override
  Future<Map<String, dynamic>> moveDelta(double deltaMm) async {
    // Minimal fake implementation: record as a move and return empty map.
    moveCalled = true;
    lastMoveHeight = deltaMm;
    return {};
  }

  @override
  Future<bool> canMoveToTop() async {
    // Default fake: not supported
    return false;
  }

  @override
  Future<Map<String, dynamic>> moveToTop() async {
    // No-op fake implementation
    return {};
  }

  @override
  Future<bool> canMoveToFloor() async {
    // Default fake: not supported
    return false;
  }

  @override
  Future<Map<String, dynamic>> moveToFloor() async {
    // No-op fake implementation
    return {};
  }

  @override
  Future<Map<String, dynamic>> emergencyStop() async {
    lastCommand = 'M112';
    return {};
  }

  @override
  Future<String> getBackendVersion() {
    return Future.value('0.0.0');
  }

  @override
  Future<List<Map<String, dynamic>>> getNotifications() async {
    return <Map<String, dynamic>>[];
  }

  @override
  Future<void> disableNotification(int timestamp) async {
    // no-op fake for tests
    return;
  }

  @override
  Future<Uint8List> getPlateLayerImage(int plateId, int layer) async {
    // Tests that use this fake generally don't fetch real plate layers.
    // Return empty bytes which callers should handle as placeholder.
    return Uint8List(0);
  }

  @override
  Future<List<Map<String, dynamic>>> getAnalytics(int n) {
    throw UnimplementedError();
  }

  @override
  Future<dynamic> getAnalyticValue(int id) async {
    // Not used in most tests; return null to indicate unsupported.
    return null;
  }

  @override
  Future tareForceSensor() {
    throw UnimplementedError();
  }
}

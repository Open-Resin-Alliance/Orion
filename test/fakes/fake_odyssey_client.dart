import 'dart:typed_data';
import 'dart:async';

import 'package:orion/backend_service/odyssey/odyssey_client.dart';

/// Simple fake client used by unit tests to assert ManualProvider behavior.
class FakeOdysseyClient implements OdysseyClient {
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
}

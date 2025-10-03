import 'dart:async';
import 'dart:typed_data';

import 'package:orion/backend_service/odyssey/odyssey_client.dart';

class FakeOdysseyClientForThumbnailTest implements OdysseyClient {
  final Uint8List bytes;
  FakeOdysseyClientForThumbnailTest(this.bytes);

  @override
  Future<Uint8List> getFileThumbnail(
      String location, String filePath, String size) async {
    return bytes;
  }

  // Minimal implementations for the rest of the interface used to satisfy
  // the abstract class. They should not be called by the thumbnail test.
  @override
  Future<Map<String, dynamic>> listItems(
      String location, int pageSize, int pageIndex, String subdirectory) {
    throw UnimplementedError();
  }

  @override
  Future<bool> usbAvailable() {
    throw UnimplementedError();
  }

  @override
  Future<Map<String, dynamic>> getFileMetadata(
      String location, String filePath) {
    throw UnimplementedError();
  }

  @override
  Future<Map<String, dynamic>> getConfig() {
    throw UnimplementedError();
  }

  @override
  Future<void> startPrint(String location, String filePath) {
    throw UnimplementedError();
  }

  @override
  Future<Map<String, dynamic>> deleteFile(String location, String filePath) {
    throw UnimplementedError();
  }

  @override
  Future<Map<String, dynamic>> getStatus() {
    throw UnimplementedError();
  }

  @override
  Stream<Map<String, dynamic>> getStatusStream() => const Stream.empty();

  @override
  Future<void> cancelPrint() {
    throw UnimplementedError();
  }

  @override
  Future<void> pausePrint() {
    throw UnimplementedError();
  }

  @override
  Future<void> resumePrint() {
    throw UnimplementedError();
  }

  @override
  Future<Map<String, dynamic>> move(double height) {
    throw UnimplementedError();
  }

  @override
  Future<Map<String, dynamic>> manualCure(bool cure) {
    throw UnimplementedError();
  }

  @override
  Future<Map<String, dynamic>> manualHome() {
    throw UnimplementedError();
  }

  @override
  Future<Map<String, dynamic>> manualCommand(String command) {
    throw UnimplementedError();
  }

  @override
  Future<void> displayTest(String test) {
    throw UnimplementedError();
  }

  @override
  Future<Map<String, dynamic>> moveDelta(double deltaMm) {
    throw UnimplementedError();
  }

  @override
  Future<bool> canMoveToTop() {
    return Future.value(false);
  }

  @override
  Future<Map<String, dynamic>> moveToTop() {
    throw UnimplementedError();
  }

  void main() {}
}

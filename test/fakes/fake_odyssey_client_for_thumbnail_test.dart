/*
* Orion - Fake Odyssey Client for Thumbnail Test
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
import 'dart:typed_data';

import 'package:orion/backend_service/backend_client.dart';

class FakeBackendClientForThumbnailTest implements BackendClient {
  final Uint8List bytes;
  FakeBackendClientForThumbnailTest(this.bytes);

  @override
  Future<Uint8List> getFileThumbnail(
      String location, String filePath, String size) async {
    return bytes;
  }

  @override
  Future<Uint8List> getPlateLayerImage(int plateId, int layer) async {
    // For thumbnail tests, just return the supplied bytes as a stand-in
    // for a plate layer image.
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

  @override
  Future<bool> canMoveToFloor() {
    return Future.value(false);
  }

  @override
  Future<Map<String, dynamic>> moveToFloor() {
    throw UnimplementedError();
  }

  void main() {}

  @override
  Future<Map<String, dynamic>> emergencyStop() {
    throw UnimplementedError();
  }

  @override
  Future<String> getBackendVersion() {
    throw UnimplementedError();
  }

  @override
  Future<List<Map<String, dynamic>>> getNotifications() async {
    return <Map<String, dynamic>>[];
  }

  @override
  Future<void> disableNotification(int timestamp) async {
    // no-op for this fake
    return;
  }

  @override
  Future<List<Map<String, dynamic>>> getAnalytics(int n) {
    // TODO: implement getAnalytics
    throw UnimplementedError();
  }

  @override
  Future<dynamic> getAnalyticValue(int id) async {
    // Not used by thumbnail tests.
    return null;
  }
}

/*
* Orion - Backend Client
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

/// Minimal abstraction over the Backend API used by providers. This allows
/// swapping implementations (real HTTP client, mock, or unit-test doubles)
/// while keeping providers free from direct dependency on ApiService.
abstract class BackendClient {
  Future<Map<String, dynamic>> listItems(
      String location, int pageSize, int pageIndex, String subdirectory);

  Future<bool> usbAvailable();

  Future<Map<String, dynamic>> getFileMetadata(
      String location, String filePath);

  Future<Map<String, dynamic>> getConfig();

  Future<String> getBackendVersion();

  Future<Uint8List> getFileThumbnail(
      String location, String filePath, String size);

  Future<void> startPrint(String location, String filePath);

  Future<Map<String, dynamic>> deleteFile(String location, String filePath);

  // Status-related
  Future<Map<String, dynamic>> getStatus();

  /// Stream of status updates from the server. Implementations may expose
  /// an SSE / streaming endpoint. Each emitted Map corresponds to a JSON
  /// object parsed from the stream's data payloads.
  Stream<Map<String, dynamic>> getStatusStream();

  /// Fetch recent notifications from the backend. Returns a list of JSON
  /// objects representing notifications. Some backends (e.g. NanoDLP)
  /// expose a `/notification` endpoint that returns an array.
  Future<List<Map<String, dynamic>>> getNotifications();

  /// Disable / acknowledge a notification on the backend when supported.
  /// The timestamp argument is the numeric timestamp provided by the
  /// notification payload (e.g. NanoDLP uses an integer timestamp).
  Future<void> disableNotification(int timestamp);

  // Print control
  Future<void> cancelPrint();
  Future<void> pausePrint();
  Future<void> resumePrint();

  // Manual controls and hardware commands
  Future<Map<String, dynamic>> move(double height);

  /// Send a relative Z move in millimeters (positive = up, negative = down).
  /// This maps directly to the device's relative move endpoints when
  /// available (e.g. NanoDLP /z-axis/move/.../micron/...).
  Future<Map<String, dynamic>> moveDelta(double deltaMm);

  /// Whether the client supports a direct "move to top limit" command.
  Future<bool> canMoveToTop();
  Future<bool> canMoveToFloor();

  /// Move the Z axis directly to the device's top limit if supported.
  Future<Map<String, dynamic>> moveToTop();
  Future<Map<String, dynamic>> moveToFloor();
  Future<Map<String, dynamic>> manualCure(bool cure);
  Future<Map<String, dynamic>> manualHome();
  Future<Map<String, dynamic>> manualCommand(String command);
  Future<Map<String, dynamic>> emergencyStop();
  Future<void> displayTest(String test);

  /// Fetch a specific 2D layer PNG from a NanoDLP-style plates endpoint.
  /// plateId is the numeric plate identifier and layer is the layer index
  /// (as reported by the backend). Implementations that don't support this
  /// may return a placeholder image or empty bytes.
  Future<Uint8List> getPlateLayerImage(int plateId, int layer);

  /// Fetch recent analytics entries. `n` requests the last N entries.
  /// Returns a list of JSON objects with keys like 'ID', 'T', 'V'.
  Future<List<Map<String, dynamic>>> getAnalytics(int n);

  /// Fetch a single analytic value by metric id (e.g. /analytic/value/6).
  /// Returns the raw value (number or string) or null on failure.
  Future<dynamic> getAnalyticValue(int id);
}

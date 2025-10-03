import 'dart:typed_data';
import 'dart:async';

/// Minimal abstraction over the Odyssey API used by providers. This allows
/// swapping implementations (real HTTP client, mock, or unit-test doubles)
/// while keeping providers free from direct dependency on ApiService.
abstract class OdysseyClient {
  Future<Map<String, dynamic>> listItems(
      String location, int pageSize, int pageIndex, String subdirectory);

  Future<bool> usbAvailable();

  Future<Map<String, dynamic>> getFileMetadata(
      String location, String filePath);

  Future<Map<String, dynamic>> getConfig();

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

  /// Move the Z axis directly to the device's top limit if supported.
  Future<Map<String, dynamic>> moveToTop();
  Future<Map<String, dynamic>> manualCure(bool cure);
  Future<Map<String, dynamic>> manualHome();
  Future<Map<String, dynamic>> manualCommand(String command);
  Future<void> displayTest(String test);
}

import 'dart:typed_data';
import 'package:orion/backend_service/odyssey/odyssey_client.dart';
import 'package:orion/backend_service/odyssey/odyssey_http_client.dart';
//import 'package:orion/backend_service/nanodlp/nanodlp_http_client.dart';
import 'package:orion/util/orion_config.dart';

/// BackendService is a small façade that selects a concrete
/// `OdysseyClient` implementation at runtime. This centralizes the
/// point where an alternative backend implementation (different API)
/// can be swapped in without changing providers or UI code.
class BackendService implements OdysseyClient {
  final OdysseyClient _delegate;

  /// Default constructor: picks the concrete implementation based on
  /// configuration (or defaults to the HTTP adapter).
  BackendService({OdysseyClient? delegate})
      : _delegate = delegate ?? _chooseFromConfig();

  static OdysseyClient _chooseFromConfig() {
    try {
      final cfg = OrionConfig();
      final backend = cfg.getString('backend', category: 'advanced');
      if (backend == 'nanodlp') {
        // Return the NanoDLP adapter when explicitly requested in config.
        // Add a small log to aid debugging in cases where config isn't applied.
        // Note: avoid bringing logging package into this file if not used
        //return NanoDlpHttpClient();
        return OdysseyHttpClient(); // Until NanoDLP support is ready
      }
    } catch (_) {
      // ignore config errors and fall back
    }
    return OdysseyHttpClient();
  }

  // Forward all OdysseyClient methods to the selected delegate.
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
  Future<void> cancelPrint() => _delegate.cancelPrint();

  @override
  Future<void> pausePrint() => _delegate.pausePrint();

  @override
  Future<void> resumePrint() => _delegate.resumePrint();

  @override
  Future<Map<String, dynamic>> move(double height) => _delegate.move(height);

  @override
  Future<Map<String, dynamic>> manualCure(bool cure) =>
      _delegate.manualCure(cure);

  @override
  Future<Map<String, dynamic>> manualHome() => _delegate.manualHome();

  @override
  Future<Map<String, dynamic>> manualCommand(String command) =>
      _delegate.manualCommand(command);

  @override
  Future<void> displayTest(String test) => _delegate.displayTest(test);
}

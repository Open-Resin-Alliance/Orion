/*
* Orion - NanoDLP Simulated Client
* Provides a simple in-memory simulated NanoDLP backend for development
* without a physical printer. Behavior is intentionally simple: it
* simulates a print job advancing layers over time and responds to
* control commands (start/pause/resume/cancel). This implementation
* implements the BackendClient interface used by the app.
*/

import 'dart:async';
import 'dart:typed_data';
import 'dart:math' as math;

import 'package:orion/backend_service/backend_client.dart';
import 'package:orion/backend_service/nanodlp/helpers/nano_thumbnail_generator.dart';
import 'package:orion/backend_service/nanodlp/models/nano_status.dart';
import 'package:orion/backend_service/nanodlp/nanodlp_mappers.dart';

class NanoDlpSimulatedClient implements BackendClient {
  // Simulated job state
  bool _printing = false;
  bool _paused = false;
  bool _cancelLatched = false;
  int _currentLayer = 0;
  final int _totalLayers = 200;

  // Status stream
  final StreamController<Map<String, dynamic>> _statusController =
      StreamController.broadcast();
  Timer? _tickTimer;

  NanoDlpSimulatedClient() {
    // start periodic tick to update status stream
    _tickTimer = Timer.periodic(Duration(seconds: 1), (_) => _tick());
  }

  void _tick() {
    if (_printing && !_paused && !_cancelLatched) {
      _currentLayer = math.min(_totalLayers, _currentLayer + 1);
      if (_currentLayer >= _totalLayers) {
        // job finished
        _printing = false;
      }
    }

    final nanoJson = _makeStatusMap();
    try {
      final ns = NanoStatus.fromJson(Map<String, dynamic>.from(nanoJson));
      final odyssey = nanoStatusToOdysseyMap(ns);
      if (!_statusController.isClosed) _statusController.add(odyssey);
    } catch (_) {
      // Fallback: emit the raw nano map if mapping fails
      if (!_statusController.isClosed) _statusController.add(nanoJson);
    }
  }

  Map<String, dynamic> _makeStatusMap() {
    return {
      'Printing': _printing,
      'Paused': _paused,
      'State': _printing ? 5 : 0,
      'LayerID': _printing ? _currentLayer : null,
      'LayersCount': _totalLayers,
      'Status': _printing ? 'Printing' : 'Idle',
      // Minimal file metadata when a job is active
      if (_printing)
        'file': {
          'name': 'simulated_print.gcode',
          'path': '/sim/simulated_print.gcode',
          'layer_count': _totalLayers,
        }
    };
  }

  @override
  Future<void> cancelPrint() async {
    if (!_printing) return;
    _cancelLatched = true;
    // simulate immediate stop
    _printing = false;
    _paused = false;
    _currentLayer = 0;
    _statusController.add(_makeStatusMap());
  }

  @override
  Future<void> pausePrint() async {
    if (!_printing || _paused) return;
    _paused = true;
    _statusController.add(_makeStatusMap());
  }

  @override
  Future<void> resumePrint() async {
    if (!_printing || !_paused) return;
    _paused = false;
    _statusController.add(_makeStatusMap());
  }

  @override
  Future<Map<String, dynamic>> deleteFile(
      String location, String filePath) async {
    return {'deleted': true};
  }

  @override
  Future<Map<String, dynamic>> displayTest(String test) async {
    return {'ok': true};
  }

  @override
  Future<void> startPrint(String location, String filePath) async {
    _printing = true;
    _paused = false;
    _cancelLatched = false;
    _currentLayer = 0;
    _statusController.add(_makeStatusMap());
  }

  @override
  Future<Map<String, dynamic>> getConfig() async {
    return {
      'general': {'hostname': 'sim-nanodlp'},
      'advanced': {'backend': 'nanodlp'}
    };
  }

  @override
  Future<String> getBackendVersion() async => 'NanoDLP-sim-1.0';

  @override
  Future<Uint8List> getFileThumbnail(
      String location, String filePath, String size) async {
    final dims = _parseSize(size);
    return NanoDlpThumbnailGenerator.generatePlaceholder(dims[0], dims[1]);
  }

  List<int> _parseSize(String size) {
    // expected like 'thumb' or 'large' - default to large
    if (size == 'thumb') return [160, 96];
    return [
      NanoDlpThumbnailGenerator.largeWidth,
      NanoDlpThumbnailGenerator.largeHeight
    ];
  }

  @override
  Future<Map<String, dynamic>> getFileMetadata(
      String location, String filePath) async {
    return {
      'file_data': {
        'path': filePath,
        'name': filePath.split('/').last,
        'last_modified': DateTime.now().millisecondsSinceEpoch,
        'parent_path': '/sim'
      }
    };
  }

  @override
  Future<Map<String, dynamic>> listItems(
      String location, int pageSize, int pageIndex, String subdirectory) async {
    // Return a small simulated file list for Local location.
    final files = List.generate(5, (i) {
      return {
        'name': 'sim_model_${i + 1}.stl',
        'path': '/sim/sim_model_${i + 1}.stl',
        'last_modified': DateTime.now().millisecondsSinceEpoch - i * 1000,
      };
    });
    return {
      'files': files,
      'dirs': <Map<String, dynamic>>[],
      'page_index': pageIndex,
      'page_size': pageSize,
    };
  }

  @override
  Future<void> disableNotification(int timestamp) async {
    // no-op for simulated backend
    return;
  }

  @override
  Future<List<Map<String, dynamic>>> getNotifications() async => [];

  @override
  Future<Map<String, dynamic>> getStatus() async {
    final nanoJson = _makeStatusMap();
    final ns = NanoStatus.fromJson(Map<String, dynamic>.from(nanoJson));
    return nanoStatusToOdysseyMap(ns);
  }

  @override
  Stream<Map<String, dynamic>> getStatusStream() => _statusController.stream;

  @override
  Future<List<Map<String, dynamic>>> getAnalytics(int n) async {
    // Simulated client has no analytics; return empty list.
    return [];
  }

  @override
  Future<bool> usbAvailable() async => false;

  @override
  Future<Map<String, dynamic>> manualCommand(String command) async =>
      {'ok': true};

  @override
  Future<Map<String, dynamic>> manualCure(bool cure) async => {'ok': true};

  @override
  Future<Map<String, dynamic>> manualHome() async => {'ok': true};

  @override
  Future<Map<String, dynamic>> move(double height) async => {'ok': true};

  @override
  Future<Map<String, dynamic>> moveDelta(double deltaMm) async => {'ok': true};

  @override
  Future<bool> canMoveToFloor() async => false;

  @override
  Future<bool> canMoveToTop() async => false;

  @override
  Future<Map<String, dynamic>> moveToFloor() async => {'ok': true};

  @override
  Future<Map<String, dynamic>> moveToTop() async => {'ok': true};

  @override
  Future<Map<String, dynamic>> emergencyStop() async {
    _printing = false;
    _paused = false;
    _statusController.add(_makeStatusMap());
    return {'stopped': true};
  }

  @override
  Future<Uint8List> getPlateLayerImage(int plateId, int layer) async {
    // Generate a simple placeholder image for the requested layer.
    // We'll encode a tiny image with a band indicating the layer number.
    final bytes = NanoDlpThumbnailGenerator.resizeLayer2D(Uint8List.fromList([
      // empty source triggers placeholder
    ]));
    return bytes;
  }

  void dispose() {
    _tickTimer?.cancel();
    _statusController.close();
  }
}

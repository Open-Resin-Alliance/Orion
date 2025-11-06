/*
* Orion - NanoDLP Simulated Client
* Provides a simple in-memory simulated NanoDLP backend for development
* without a physical printer. Behavior is intentionally simple: it
* simulates a print job advancing layers over time and responds to
* control commands (start/pause/resume/cancel). This implementation
* implements the BackendClient interface used by the app.
*/

import 'dart:async';
import 'dart:math';
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
  Future<Map<String, dynamic>> getMachine() async {
    // Provide a small simulated machine.json-like payload for tests/dev.
    return {
      'Name': 'NanoDLP-Sim',
      'UUID': 'sim-uuid',
      'DefaultProfile': _defaultProfileId ?? 0,
      'CustomValues': {'VatHeaterPresent': '0', 'ChamberHeaterPresent': '0'},
    };
  }

  int? _defaultProfileId;

  @override
  Future<int?> getDefaultProfileId() async {
    return _defaultProfileId;
  }

  @override
  Future<void> setDefaultProfileId(int id) async {
    _defaultProfileId = id;
    return;
  }

  @override
  Future<String> getBackendVersion() async => 'NanoDLP-sim-1.0';

  @override
  Future<Map<String, dynamic>> getProfileJson(int id) async {
    // Return a simple simulated profile payload. Include a few keys that the
    // EditResinScreen expects (both top-level and CustomValues) so the UI
    // can read sane defaults during development.
    return {
      'ResinID': 0,
      'ProfileID': id,
      'Title': 'Simulated Resin Profile #$id',
      'Desc': 'Simulated profile for UI development',
      'CustomValues': {
        'burn_in_cure_time': '10',
        'normal_cure_time': '8',
        'lift_after_print': '5.0',
        'burn_in_count': '3',
        'wait_after_cure': '2',
        'wait_after_life': '2'
      },
      // Also include top-level keys to make parsing simpler in some codepaths
      'burn_in_cure_time': 10,
      'normal_cure_time': 8,
      'lift_after_print': 5.0,
      'burn_in_count': 3,
      'wait_after_cure': 2,
      'wait_after_life': 2,
    };
  }

  @override
  Future<Map<String, dynamic>> editProfile(
      int id, Map<String, dynamic> fields) async {
    // In the simulated client, simply echo back the submitted fields merged
    // into a simulated profile representation so UI code can observe the
    // change without a real backend.
    final base = await getProfileJson(id);
    final merged = Map<String, dynamic>.from(base);
    try {
      // Overlay CustomValues if present
      final cv = merged['CustomValues'] is Map<String, dynamic>
          ? Map<String, dynamic>.from(merged['CustomValues'])
          : <String, dynamic>{};
      fields.forEach((k, v) {
        // Put small fields into CustomValues to emulate NanoDLP behavior
        cv[k] = v;
        merged[k] = v;
      });
      merged['CustomValues'] = cv;
    } catch (_) {}
    return merged;
  }

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
    // Simulated analytics payloads for UI and testing.
    // Provide TemperatureInside (T id 7) and TemperatureInsideTarget (T id 12)
    // so the AnalyticsProvider / SystemStatusWidget can display stable
    // simulated values (22°C current and 22°C target).
    final now = DateTime.now().millisecondsSinceEpoch;
    final entries = <Map<String, dynamic>>[];

    // TemperatureInside (id 7)
    entries.add({'T': 7, 'V': 22, 'id': now});

    // TemperatureInsideTarget (id 12)
    entries.add({'T': 12, 'V': 0, 'id': now});

    // TemperatureChamberTarget (id 23)
    entries.add({'T': 23, 'V': 0, 'id': now});

    // TemperaturePTCTarget (id 24)
    entries.add({'T': 25, 'V': 0, 'id': now});

    // Keep the list small but deterministic for tests.
    return entries;
  }

  @override
  Future<dynamic> getAnalyticValue(int id) async {
    // Smoothly ramp to a large peak after restart instead of an instant jump.
    final now = DateTime.now().millisecondsSinceEpoch / 1000.0;
    const period = 60.0; // restart every 40 seconds
    final elapsed = now % period;

    const maxAmp = 6000.0; // target peak amplitude
    const decayTime = 30.0; // seconds to decay back down
    final decay = math.log(30.0) / decayTime;
    final envelope = math.exp(-decay * elapsed);

    // ramp up over the first few seconds after a restart to avoid an immediate jump
    const rampUpTime = 2.0; // seconds to reach full amplitude
    final ramp = (elapsed >= rampUpTime) ? 1.0 : (elapsed / rampUpTime);

    // use cosine for oscillation, scaled by ramp and decay envelope
    final raw =
        math.cos(2 * math.pi * (elapsed / 3.0)) * maxAmp * ramp * envelope;

    // small random noise in [-5,5]
    final noise = (Random().nextDouble() * 10.0) - 5.0;

    // once the oscillation has decayed below ±5, return only the small random noise
    if (raw.abs() < 5.0) return noise;

    // otherwise return the oscillation with a little jitter
    return raw + noise * 0.2;
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

  @override
  Future tareForceSensor() {
    throw UnimplementedError();
  }

  @override
  Future setChamberTemperature(double temperature) {
    // TODO: implement setChamberTemperature
    throw UnimplementedError();
  }

  @override
  Future setVatTemperature(double temperature) {
    // TODO: implement setVatTemperature
    throw UnimplementedError();
  }

  @override
  Future<bool> isChamberTemperatureControlEnabled() {
    // TODO: implement isChamberTemperatureControlEnabled
    throw UnimplementedError();
  }

  @override
  Future<bool> isVatTemperatureControlEnabled() {
    // TODO: implement isVatTemperatureControlEnabled
    throw UnimplementedError();
  }

  @override
  Future getChamberTemperature() {
    // TODO: implement getChamberTemperature
    throw UnimplementedError();
  }

  @override
  Future getVatTemperature() {
    // TODO: implement getVatTemperature
    throw UnimplementedError();
  }

  @override
  Future<void> preheatAndMix(double temperature) async {
    // Simulated client: no-op
    return;
  }

  @override
  Future<String?> getCalibrationImageUrl(int modelId) async {
    // Simulated client: return placeholder
    return 'http://localhost/static/shots/calibration-images/$modelId.png';
  }

  @override
  Future<List<Map<String, dynamic>>> getCalibrationModels() async {
    // Simulated client: return mock calibration models
    return [
      {
        "id": 1,
        "name": "J3D Calibration RERF",
        "models": 6,
        "info": {"resinRequired": 21, "height": 3700}
      },
      {
        "id": 2,
        "name": "J3D Calibration Boxes of Calibration",
        "models": 6,
        "info": {"resinRequired": 9, "height": 10100}
      }
    ];
  }

  @override
  Future<bool> startCalibrationPrint({
    required int calibrationModelId,
    required List<double> exposureTimes,
    required int profileId,
  }) async {
    // Simulated client: pretend to submit successfully
    await Future.delayed(const Duration(milliseconds: 200));
    return true;
  }

  @override
  Future<double?> getSlicerProgress() async {
    // Simulated client: return mock progress
    await Future.delayed(const Duration(milliseconds: 100));
    return 0.95; // 50% progress
  }

  @override
  Future<bool?> isCalibrationPlateProcessed() async {
    // Simulated client: return false (not yet processed)
    await Future.delayed(const Duration(milliseconds: 100));
    startPrint('', '');
    return false;
  }
}

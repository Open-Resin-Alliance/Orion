import 'nano_file.dart';

// Minimal NanoDLP status DTO
class NanoStatus {
  // Raw fields from NanoDLP /status
  final bool printing;
  final bool paused;
  final String? statusMessage;
  final int? currentHeight; // possibly microns or device units
  final int? layerId;
  final int? layersCount;
  final double? resinLevel; // mm or percent depending on device
  final double? temp;
  final double? mcuTemp;
  final String? rawJsonStatus;

  // Existing convenience fields
  final String state; // 'printing' | 'paused' | 'idle'
  final double? progress; // 0.0 - 1.0
  final NanoFile? file; // not always present in NanoDLP status
  final double? z; // z position (converted if needed)
  final bool curing;

  NanoStatus({
    required this.printing,
    required this.paused,
    this.statusMessage,
    this.currentHeight,
    this.layerId,
    this.layersCount,
    this.resinLevel,
    this.temp,
    this.mcuTemp,
    this.rawJsonStatus,
    required this.state,
    this.progress,
    this.file,
    this.z,
    this.curing = false,
  });

  factory NanoStatus.fromJson(Map<String, dynamic> json) {
    // The NanoDLP /status payloads vary between installs. File/plate metadata
    // may appear under different keys (lower/upper case or different names).
    // Search a set of likely candidate keys and pick the first Map-like value.
    NanoFile? nf;
    final candidateFileKeys = [
      'file',
      'File',
      'plate',
      'Plate',
      'file_data',
      'FileData',
      'fileData',
      'current_file',
      'CurrentFile',
      'job',
      'Job',
    ];
    for (final k in candidateFileKeys) {
      final val = json[k];
      if (val is Map<String, dynamic>) {
        nf = NanoFile.fromJson(Map<String, dynamic>.from(val));
        break;
      }
      if (val is Map) {
        try {
          nf = NanoFile.fromJson(Map<String, dynamic>.from(val));
          break;
        } catch (_) {
          // ignore and continue
        }
      }
    }

    // Helpers
    int? parseInt(dynamic v) {
      if (v == null) return null;
      if (v is int) return v;
      if (v is num) return v.toInt();
      if (v is String) return int.tryParse(v);
      return null;
    }

    double? parseDouble(dynamic v) {
      if (v == null) return null;
      if (v is double) return v;
      if (v is num) return v.toDouble();
      if (v is String) {
        // Some devices send '24.85Â°C' — strip non-numeric
        final cleaned = v.replaceAll(RegExp(r'[^0-9+\-\.]'), '');
        return double.tryParse(cleaned);
      }
      return null;
    }

    final printing = json['Printing'] == true ||
        json['printing'] == true ||
        json['Started'] == 1 ||
        json['started'] == 1;
    final paused = json['Paused'] == true || json['paused'] == true;
    final statusMessage =
        json['Status']?.toString() ?? json['status']?.toString();
    final currentHeight = parseInt(json['CurrentHeight'] ??
        json['current_height'] ??
        json['CurrentHeight']);
    final layerId =
        parseInt(json['LayerID'] ?? json['layer_id'] ?? json['LayerID']);
    final layersCount = parseInt(
        json['LayersCount'] ?? json['layers_count'] ?? json['LayersCount']);
    final resinLevel = parseDouble(
        json['resin'] ?? json['ResinLevelMm'] ?? json['resin_level_mm']);
    final temp = parseDouble(json['temp']);
    final mcuTemp = parseDouble(json['mcu']);
    final curing = json['Curing'] == true || json['curing'] == true;

    // Map to simple state
    String state;
    if (printing) {
      state = 'printing';
    } else if (paused) {
      state = 'paused';
    } else {
      state = 'idle';
    }

    double? progress;
    if (layerId != null && layersCount != null && layersCount > 0) {
      progress = (layerId / layersCount).clamp(0.0, 1.0).toDouble();
    }

    double? z;
    if (currentHeight != null) {
      // CurrentHeight units vary between NanoDLP installs. Common possibilities:
      // - already in mm (small integers, e.g. 150)
      // - in microns (e.g. 150000 -> 150 mm)
      // - in nanometers (e.g. 1504000 -> 1.504 mm)
      // Heuristic: pick the conversion that yields a plausible Z (<= 300 mm).
      final asMmIfMicrons = currentHeight / 1000.0; // microns -> mm
      final asMmIfNanometers = currentHeight / 1000000.0; // nm -> mm
      if (currentHeight <= 1000) {
        // Small values are likely already mm
        z = currentHeight.toDouble();
      } else if (asMmIfMicrons <= 300.0) {
        z = asMmIfMicrons;
      } else if (asMmIfNanometers <= 300.0) {
        z = asMmIfNanometers;
      } else {
        // Fallback: assume microns
        z = asMmIfMicrons;
      }
    }

    return NanoStatus(
      printing: printing,
      paused: paused,
      statusMessage: statusMessage,
      currentHeight: currentHeight,
      layerId: layerId,
      layersCount: layersCount,
      resinLevel: resinLevel,
      temp: temp,
      mcuTemp: mcuTemp,
      rawJsonStatus: json['Status']?.toString() ?? json.toString(),
      state: state,
      progress: progress,
      file: nf,
      z: z,
      curing: curing,
    );
  }

  Map<String, dynamic> toJson() => {
        'printing': printing,
        'paused': paused,
        'statusMessage': statusMessage,
        'currentHeight': currentHeight,
        'layerId': layerId,
        'layersCount': layersCount,
        'resinLevel': resinLevel,
        'temp': temp,
        'mcuTemp': mcuTemp,
        'state': state,
        'progress': progress,
        'file': file?.toJson(),
        'z': z,
        'curing': curing,
      };
}

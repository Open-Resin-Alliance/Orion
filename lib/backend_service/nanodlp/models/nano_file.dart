// DTO for a NanoDLP "plate" or file as returned by status or plates endpoints.
//
// Centralises parsing/normalisation so higher layers (like the HTTP client)
// stay small and simply convert to Odyssey-shaped maps.
class NanoFile {
  final String? path; // full path or filename
  final String? name;
  final int? layerCount;
  final double? printTime; // seconds

  // Extended metadata commonly returned by /plates/list/json or similar
  final int? lastModified;
  final String? parentPath;
  final int? fileSize;
  final String? materialName;
  final double? usedMaterial;
  final double? layerHeight; // millimetres
  final String? locationCategory;
  final int? plateId;
  final bool previewAvailable;

  // Keep a reference to the source map for advanced consumers/debug
  final Map<String, dynamic>? raw;

  const NanoFile({
    this.path,
    this.name,
    this.layerCount,
    this.printTime,
    this.lastModified,
    this.parentPath,
    this.fileSize,
    this.materialName,
    this.usedMaterial,
    this.layerHeight,
    this.locationCategory,
    this.plateId,
    this.previewAvailable = false,
    this.raw,
  });

  factory NanoFile.fromJson(Map<String, dynamic> json) {
    int? parseInt(dynamic v) {
      if (v == null) return null;
      if (v is int) return v;
      if (v is num) return v.toInt();
      if (v is String) return int.tryParse(v);
      return null;
    }

    // parseDouble removed — volume parsing is handled by parseVolume below.

    bool parseBool(dynamic v) {
      if (v == null) return false;
      if (v is bool) return v;
      if (v is num) return v != 0;
      if (v is String) {
        final lowered = v.toLowerCase().trim();
        if (lowered == 'true' || lowered == 't' || lowered == 'yes') {
          return true;
        }
        final numeric = int.tryParse(lowered);
        if (numeric != null) return numeric != 0;
      }
      return false;
    }

    double? parsePrintTime(dynamic v) {
      if (v == null) return null;
      if (v is num) return v.toDouble();
      if (v is String) {
        final trimmed = v.trim();
        final durationMatch =
            RegExp(r'~?(\d{1,2}):(\d{1,2}):(\d{1,2})').firstMatch(trimmed);
        if (durationMatch != null) {
          final h = int.parse(durationMatch.group(1)!);
          final m = int.parse(durationMatch.group(2)!);
          final s = int.parse(durationMatch.group(3)!);
          return (h * 3600 + m * 60 + s).toDouble();
        }
        return double.tryParse(trimmed.replaceAll(RegExp(r'[^0-9+\-.]'), ''));
      }
      return null;
    }

    double? parseLayerHeight(dynamic value, {bool assumeMicrons = false}) {
      if (value == null) return null;
      double? numeric;
      String source = '';
      if (value is num) {
        numeric = value.toDouble();
      } else {
        source = value.toString();
        numeric = double.tryParse(source.replaceAll(RegExp(r'[^0-9+\-.]'), ''));
      }
      if (numeric == null) return null;

      final src = source.toLowerCase();
      final hintMicrons =
          assumeMicrons || src.contains('µ') || src.contains('micron');
      if (hintMicrons) {
        return numeric / 1000.0;
      }
      if (src.contains('mm')) {
        return numeric;
      }
      if (source.isEmpty && assumeMicrons) {
        return numeric / 1000.0;
      }
      // If no units and numeric seems large (e.g. 50), treat as microns.
      if (!src.contains(RegExp(r'[a-z]')) && numeric >= 10) {
        return numeric / 1000.0;
      }
      return numeric;
    }

    String? path = json['path']?.toString() ??
        json['Path']?.toString() ??
        json['file_path']?.toString() ??
        json['File']?.toString();
    String? name = json['name']?.toString() ?? json['Name']?.toString();
    if (name == null && path != null) {
      final parts = path.split('/');
      if (parts.isNotEmpty) name = parts.last;
    }
    if (path == null && name != null) {
      path = name;
    }

    final layerCount = parseInt(
        json['layer_count'] ?? json['LayerCount'] ?? json['layerCount']);
    final printTime = parsePrintTime(
        json['print_time'] ?? json['printTime'] ?? json['PrintTime']);
    final lastModified = parseInt(json['last_modified'] ??
        json['LastModified'] ??
        json['Updated'] ??
        json['UpdatedOn'] ??
        json['CreatedDate']);
    String? parentPath =
        (json['parent_path'] ?? json['parentPath'])?.toString();
    final fileSize = parseInt(
        json['file_size'] ?? json['FileSize'] ?? json['size'] ?? json['Size']);
    double? parseVolume(dynamic v) {
      if (v == null) return null;
      // If it's numeric, assume it's already in mL
      if (v is num) return v.toDouble();
      final s = v.toString().trim();
      if (s.isEmpty) return null;

      final lower = s.toLowerCase();
      // Extract numeric portion
      final numStr = lower.replaceAll(RegExp(r'[^0-9+\-\.eE]'), '');
      final parsed = double.tryParse(numStr);
      if (parsed == null) return null;

      // Unit detection
      if (lower.contains('µ') ||
          lower.contains('ul') ||
          lower.contains('microl')) {
        // micro-liters -> mL
        return parsed / 1000.0;
      }
      if (lower.contains('l') &&
          !lower.contains('ml') &&
          !lower.contains('ul')) {
        // liters -> mL
        return parsed * 1000.0;
      }
      if (lower.contains('ml') ||
          lower.contains('cc') ||
          lower.contains('cm3')) {
        return parsed;
      }
      // Heuristic: if the number is very large (>1000) and no unit, it might be µL
      if (parsed >= 1000.0) return parsed / 1000.0;
      return parsed;
    }

    final materialName = json['ProfileName'] ?? 'N/A';
    final usedMaterial = parseVolume(json['used_material'] ??
        json['usedMaterial'] ??
        json['UsedMaterial'] ??
        json['UsedMaterialMl'] ??
        json['UsedResin'] ??
        json['ResinVolume'] ??
        json['UsedVolume'] ??
        json['Volume'] ??
        json['TotalSolidArea'] ??
        0);

    double? layerHeight = parseLayerHeight(
        json['layer_height'] ?? json['layerHeight'] ?? json['PlateHeight']);
    layerHeight ??=
        parseLayerHeight(json['LayerThickness'], assumeMicrons: true) ??
            parseLayerHeight(json['ZRes'], assumeMicrons: true);

    final locationCategory =
        json['location_category']?.toString() ?? json['location']?.toString();
    final plateId = parseInt(json['PlateID'] ?? json['plate_id']);
    final previewAvailable =
        parseBool(json['Preview'] ?? json['preview'] ?? json['HasPreview']);

    final resolvedPath = path ?? '';
    final resolvedName = name ?? resolvedPath;
    if ((parentPath == null || parentPath.isEmpty) &&
        resolvedPath.contains('/')) {
      parentPath = resolvedPath.substring(0, resolvedPath.lastIndexOf('/'));
    }

    return NanoFile(
      path: resolvedPath,
      name: resolvedName,
      layerCount: layerCount,
      printTime: printTime,
      lastModified: lastModified,
      parentPath: parentPath ?? '',
      fileSize: fileSize,
      materialName: materialName,
      usedMaterial: usedMaterial,
      layerHeight: layerHeight,
      locationCategory: locationCategory ?? 'Local',
      plateId: plateId,
      previewAvailable: previewAvailable,
      raw: json,
    );
  }

  Map<String, dynamic> toJson() => {
        'path': path,
        'name': name,
        'layer_count': layerCount,
        'print_time': printTime,
        'last_modified': lastModified,
        'parent_path': parentPath,
        'file_size': fileSize,
        'material_name': materialName,
        'used_material': usedMaterial,
        'layer_height': layerHeight,
        'location_category': locationCategory,
        'plate_id': plateId,
        'preview': previewAvailable,
      };

  String? _formatSecondsToHMS(double? seconds) {
    if (seconds == null) return null;
    final secs = seconds.toInt();
    final h = secs ~/ 3600;
    final m = (secs % 3600) ~/ 60;
    final s = secs % 60;
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(h)}:${two(m)}:${two(s)}';
  }

  String get resolvedPath => path ?? name ?? '';

  Map<String, dynamic> toOdysseyFileEntry() {
    final basePath = resolvedPath;
    final resolvedName = name ?? basePath;
    final resolvedParent = (parentPath != null && parentPath!.isNotEmpty)
        ? parentPath!
        : (basePath.contains('/')
            ? basePath.substring(0, basePath.lastIndexOf('/'))
            : '');

    final entry = <String, dynamic>{
      'file_data': {
        'path': basePath,
        'name': resolvedName,
        'last_modified': lastModified ?? 0,
        'parent_path': resolvedParent,
        'file_size': fileSize,
      },
      'location_category': locationCategory ?? 'Local',
      'material_name': materialName ?? 'N/A',
      'used_material': usedMaterial ?? 0.0,
      'print_time': printTime ?? 0.0,
      if (printTime != null)
        'print_time_formatted': _formatSecondsToHMS(printTime),
      'layer_count': layerCount ?? 0,
    };
    if (layerHeight != null) {
      entry['layer_height'] = layerHeight;
    }
    if (plateId != null) {
      entry['plate_id'] = plateId;
    }
    entry['preview_available'] = previewAvailable;
    return entry;
  }

  Map<String, dynamic> toOdysseyMetadata() {
    final meta = <String, dynamic>{
      'file_data': toOdysseyFileEntry()['file_data'],
      'layer_height': layerHeight,
      'material_name': materialName ?? 'N/A',
      'used_material': usedMaterial ?? 0.0,
      'print_time': printTime ?? 0.0,
      if (printTime != null)
        'print_time_formatted': _formatSecondsToHMS(printTime),
      'plate_id': plateId,
      'preview_available': previewAvailable,
    };
    return meta;
  }
}

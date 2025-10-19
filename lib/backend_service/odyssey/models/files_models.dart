/*
 * Orion - Generated Files Models (json_serializable)
 * Strong typing for /files and /file/metadata endpoints.
 */

import 'package:json_annotation/json_annotation.dart';

part 'files_models.g.dart';

// Custom (de)serializers for print_time so we always emit a HH:MM:SS
// formatted string while still accepting either numeric seconds or an
// HH:MM:SS string when decoding.
double? _printTimeFromJson(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  if (v is String) {
    final s = v.trim();
    // Try Duration-like HH:MM:SS(.micro) pattern first (e.g. "0:38:50.000000")
    final match =
        RegExp(r'^(\d+):([0-5]\d):([0-5]\d)(?:\.(\d+))?$').firstMatch(s);
    if (match != null) {
      final h = int.tryParse(match.group(1)!) ?? 0;
      final m = int.tryParse(match.group(2)!) ?? 0;
      final sec = int.tryParse(match.group(3)!) ?? 0;
      return (h * 3600 + m * 60 + sec).toDouble();
    }
    // Try plain HH:MM:SS without microseconds
    final simple = RegExp(r'^(\d{1,2}):(\d{1,2}):(\d{1,2})$').firstMatch(s);
    if (simple != null) {
      final h = int.tryParse(simple.group(1)!) ?? 0;
      final m = int.tryParse(simple.group(2)!) ?? 0;
      final sec = int.tryParse(simple.group(3)!) ?? 0;
      return (h * 3600 + m * 60 + sec).toDouble();
    }
    // Fallback: try to parse as a plain numeric value (seconds)
    final numVal = double.tryParse(s);
    return numVal;
  }
  return null;
}

String? _printTimeToJson(double? seconds) {
  if (seconds == null) return null;
  final secs = seconds.toInt();
  final h = secs ~/ 3600;
  final m = (secs % 3600) ~/ 60;
  final s = secs % 60;
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(h)}:${two(m)}:${two(s)}';
}

/// Root model returned by the Odyssey `/files` endpoint.
///
/// Contains lists of files and directories along with pagination metadata
/// when provided by the API.
@JsonSerializable(explicitToJson: true)
class FilesListModel {
  final List<FileEntry> files;
  final List<DirEntry> dirs;
  @JsonKey(name: 'page_index')
  final int? pageIndex;
  @JsonKey(name: 'page_size')
  final int? pageSize;

  FilesListModel(
      {required this.files, required this.dirs, this.pageIndex, this.pageSize});

  factory FilesListModel.fromJson(Map<String, dynamic> json) =>
      _$FilesListModelFromJson(json);
  Map<String, dynamic> toJson() => _$FilesListModelToJson(this);
}

@JsonSerializable()
class FileEntry {
  @JsonKey(name: 'file_data')
  final FileData fileData;
  @JsonKey(name: 'location_category')
  final String locationCategory;
  @JsonKey(name: 'used_material')
  final double? usedMaterial;
  @JsonKey(
      name: 'print_time',
      fromJson: _printTimeFromJson,
      toJson: _printTimeToJson)
  final double? printTime;
  @JsonKey(name: 'layer_height')
  final double? layerHeight;
  @JsonKey(name: 'layer_count')
  final int? layerCount;

  FileEntry(
      {required this.fileData,
      required this.locationCategory,
      this.usedMaterial,
      this.printTime,
      this.layerHeight,
      this.layerCount});

  factory FileEntry.fromJson(Map<String, dynamic> json) =>
      _$FileEntryFromJson(json);
  Map<String, dynamic> toJson() => _$FileEntryToJson(this);
}

@JsonSerializable()
class DirEntry {
  final String path;
  final String name;
  @JsonKey(name: 'last_modified')
  final int lastModified;
  @JsonKey(name: 'location_category')
  final String locationCategory;
  @JsonKey(name: 'parent_path')
  final String parentPath;

  DirEntry(
      {required this.path,
      required this.name,
      required this.lastModified,
      required this.locationCategory,
      required this.parentPath});

  factory DirEntry.fromJson(Map<String, dynamic> json) =>
      _$DirEntryFromJson(json);
  Map<String, dynamic> toJson() => _$DirEntryToJson(this);
}

@JsonSerializable()
class FileData {
  final String path;
  final String name;
  @JsonKey(name: 'last_modified')
  final int lastModified;
  @JsonKey(name: 'parent_path')
  final String parentPath;
  @JsonKey(name: 'file_size')
  final int? fileSize;

  FileData(
      {required this.path,
      required this.name,
      required this.lastModified,
      required this.parentPath,
      this.fileSize});

  factory FileData.fromJson(Map<String, dynamic> json) =>
      _$FileDataFromJson(json);
  Map<String, dynamic> toJson() => _$FileDataToJson(this);
}

/// Model returned by `/file/metadata` endpoint for detailed metadata about a file.
@JsonSerializable()
class FileMetadata {
  @JsonKey(name: 'file_data')
  final FileData fileData;
  @JsonKey(name: 'layer_height')
  final double? layerHeight;
  @JsonKey(name: 'material_name')
  final String? materialName;
  @JsonKey(name: 'used_material')
  final double? usedMaterial;
  @JsonKey(
      name: 'print_time',
      fromJson: _printTimeFromJson,
      toJson: _printTimeToJson)
  final double? printTime;

  FileMetadata(
      {required this.fileData,
      this.layerHeight,
      this.materialName,
      this.usedMaterial,
      this.printTime});

  /// Formatted print time as HH:MM:SS (zero-padded). printTime is in seconds.
  String get formattedPrintTime {
    final secs = (printTime ?? 0).toInt();
    final d = Duration(seconds: secs);
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.inHours)}:${two(d.inMinutes.remainder(60))}:${two(d.inSeconds.remainder(60))}';
  }

  factory FileMetadata.fromJson(Map<String, dynamic> json) =>
      _$FileMetadataFromJson(json);
  Map<String, dynamic> toJson() => _$FileMetadataToJson(this);
}

// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'files_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

FilesListModel _$FilesListModelFromJson(Map<String, dynamic> json) =>
    FilesListModel(
      files: (json['files'] as List<dynamic>)
          .map((e) => FileEntry.fromJson(e as Map<String, dynamic>))
          .toList(),
      dirs: (json['dirs'] as List<dynamic>)
          .map((e) => DirEntry.fromJson(e as Map<String, dynamic>))
          .toList(),
      pageIndex: (json['page_index'] as num?)?.toInt(),
      pageSize: (json['page_size'] as num?)?.toInt(),
    );

Map<String, dynamic> _$FilesListModelToJson(FilesListModel instance) =>
    <String, dynamic>{
      'files': instance.files.map((e) => e.toJson()).toList(),
      'dirs': instance.dirs.map((e) => e.toJson()).toList(),
      'page_index': instance.pageIndex,
      'page_size': instance.pageSize,
    };

FileEntry _$FileEntryFromJson(Map<String, dynamic> json) => FileEntry(
      fileData: FileData.fromJson(json['file_data'] as Map<String, dynamic>),
      locationCategory: json['location_category'] as String,
      usedMaterial: (json['used_material'] as num?)?.toDouble(),
      printTime: _printTimeFromJson(json['print_time']),
      layerHeight: (json['layer_height'] as num?)?.toDouble(),
      layerCount: (json['layer_count'] as num?)?.toInt(),
    );

Map<String, dynamic> _$FileEntryToJson(FileEntry instance) => <String, dynamic>{
      'file_data': instance.fileData,
      'location_category': instance.locationCategory,
      'used_material': instance.usedMaterial,
      'print_time': _printTimeToJson(instance.printTime),
      'layer_height': instance.layerHeight,
      'layer_count': instance.layerCount,
    };

DirEntry _$DirEntryFromJson(Map<String, dynamic> json) => DirEntry(
      path: json['path'] as String,
      name: json['name'] as String,
      lastModified: (json['last_modified'] as num).toInt(),
      locationCategory: json['location_category'] as String,
      parentPath: json['parent_path'] as String,
    );

Map<String, dynamic> _$DirEntryToJson(DirEntry instance) => <String, dynamic>{
      'path': instance.path,
      'name': instance.name,
      'last_modified': instance.lastModified,
      'location_category': instance.locationCategory,
      'parent_path': instance.parentPath,
    };

FileData _$FileDataFromJson(Map<String, dynamic> json) => FileData(
      path: json['path'] as String,
      name: json['name'] as String,
      lastModified: (json['last_modified'] as num).toInt(),
      parentPath: json['parent_path'] as String,
      fileSize: (json['file_size'] as num?)?.toInt(),
    );

Map<String, dynamic> _$FileDataToJson(FileData instance) => <String, dynamic>{
      'path': instance.path,
      'name': instance.name,
      'last_modified': instance.lastModified,
      'parent_path': instance.parentPath,
      'file_size': instance.fileSize,
    };

FileMetadata _$FileMetadataFromJson(Map<String, dynamic> json) => FileMetadata(
      fileData: FileData.fromJson(json['file_data'] as Map<String, dynamic>),
      layerHeight: (json['layer_height'] as num?)?.toDouble(),
      materialName: json['material_name'] as String?,
      usedMaterial: (json['used_material'] as num?)?.toDouble(),
      printTime: _printTimeFromJson(json['print_time']),
    );

Map<String, dynamic> _$FileMetadataToJson(FileMetadata instance) =>
    <String, dynamic>{
      'file_data': instance.fileData,
      'layer_height': instance.layerHeight,
      'material_name': instance.materialName,
      'used_material': instance.usedMaterial,
      'print_time': _printTimeToJson(instance.printTime),
    };

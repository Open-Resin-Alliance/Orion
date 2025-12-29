// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'status_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

StatusModel _$StatusModelFromJson(Map<String, dynamic> json) => StatusModel(
      status: json['status'] as String,
      paused: json['paused'] as bool?,
      layer: (json['layer'] as num?)?.toInt(),
      cancelLatched: json['cancel_latched'] as bool?,
      pauseLatched: json['pause_latched'] as bool?,
      finished: json['finished'] as bool?,
      printData: json['print_data'] == null
          ? null
          : PrintData.fromJson(json['print_data'] as Map<String, dynamic>),
      physicalState: PhysicalState.fromJson(
          json['physical_state'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$StatusModelToJson(StatusModel instance) =>
    <String, dynamic>{
      'status': instance.status,
      'paused': instance.paused,
      'layer': instance.layer,
      'cancel_latched': instance.cancelLatched,
      'pause_latched': instance.pauseLatched,
      'finished': instance.finished,
      'print_data': instance.printData?.toJson(),
      'physical_state': instance.physicalState.toJson(),
    };

PhysicalState _$PhysicalStateFromJson(Map<String, dynamic> json) =>
    PhysicalState(
      z: (json['z'] as num).toDouble(),
      curing: json['curing'] as bool?,
    );

Map<String, dynamic> _$PhysicalStateToJson(PhysicalState instance) =>
    <String, dynamic>{
      'z': instance.z,
      'curing': instance.curing,
    };

PrintData _$PrintDataFromJson(Map<String, dynamic> json) => PrintData(
      layerCount: (json['layer_count'] as num).toInt(),
      usedMaterial: (json['used_material'] as num).toDouble(),
      printTime: json['print_time'] as num,
      fileData: json['file_data'] == null
          ? null
          : FileData.fromJson(json['file_data'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$PrintDataToJson(PrintData instance) => <String, dynamic>{
      'layer_count': instance.layerCount,
      'used_material': instance.usedMaterial,
      'print_time': instance.printTime,
      'file_data': instance.fileData?.toJson(),
    };

FileData _$FileDataFromJson(Map<String, dynamic> json) => FileData(
      name: json['name'] as String,
      path: json['path'] as String,
      locationCategory: json['location_category'] as String?,
    );

Map<String, dynamic> _$FileDataToJson(FileData instance) => <String, dynamic>{
      'name': instance.name,
      'path': instance.path,
      'location_category': instance.locationCategory,
    };

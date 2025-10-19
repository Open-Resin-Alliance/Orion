// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'config_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ConfigModel _$ConfigModelFromJson(Map<String, dynamic> json) => ConfigModel(
      general: json['general'] as Map<String, dynamic>?,
      advanced: json['advanced'] as Map<String, dynamic>?,
      machine: json['machine'] as Map<String, dynamic>?,
      vendor: json['vendor'] as Map<String, dynamic>?,
    );

Map<String, dynamic> _$ConfigModelToJson(ConfigModel instance) =>
    <String, dynamic>{
      'general': instance.general,
      'advanced': instance.advanced,
      'machine': instance.machine,
      'vendor': instance.vendor,
    };

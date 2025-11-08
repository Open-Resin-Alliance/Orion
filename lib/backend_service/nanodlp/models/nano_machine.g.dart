// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'nano_machine.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

NanoMachine _$NanoMachineFromJson(Map<String, dynamic> json) => NanoMachine(
      name: json['Name'] as String?,
      lang: json['Lang'] as String?,
      email: json['Email'] as String?,
      printerId: json['PrinterID'] as int?,
      port: json['Port'] as int?,
      uuid: json['UUID'] as String?,
      printerType: json['PrinterType'] as int?,
      zAxisHeight: json['ZAxisHeight'] as int?,
      stopPositionMm: json['StopPositionMm'] as int?,
      resinDistanceMm: json['ResinDistanceMm'] as int?,
      vatWidth: json['VatWidth'] as int?,
      vatHeight: json['VatHeight'] as int?,
      projectorWidth: json['ProjectorWidth'] as int?,
      projectorHeight: json['ProjectorHeight'] as int?,
      defaultProfileId: json['DefaultProfile'] as int?,
      customValues: (json['CustomValues'] as Map<String, dynamic>?)
          ?.map((k, e) => MapEntry(k, e as String)),
    );

Map<String, dynamic> _$NanoMachineToJson(NanoMachine instance) =>
    <String, dynamic>{
      'Name': instance.name,
      'Lang': instance.lang,
      'Email': instance.email,
      'PrinterID': instance.printerId,
      'Port': instance.port,
      'UUID': instance.uuid,
      'PrinterType': instance.printerType,
      'ZAxisHeight': instance.zAxisHeight,
      'StopPositionMm': instance.stopPositionMm,
      'ResinDistanceMm': instance.resinDistanceMm,
      'VatWidth': instance.vatWidth,
      'VatHeight': instance.vatHeight,
      'ProjectorWidth': instance.projectorWidth,
      'ProjectorHeight': instance.projectorHeight,
      'DefaultProfile': instance.defaultProfileId,
      'CustomValues': instance.customValues,
    };

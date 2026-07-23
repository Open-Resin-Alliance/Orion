// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'nano_profiles.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

NanoProfile _$NanoProfileFromJson(Map<String, dynamic> json) => NanoProfile(
      profileId: json['ProfileID'] as int?,
      title: json['Title'] as String?,
    );

Map<String, dynamic> _$NanoProfileToJson(NanoProfile instance) =>
    <String, dynamic>{
      'ProfileID': instance.profileId,
      'Title': instance.title,
    };

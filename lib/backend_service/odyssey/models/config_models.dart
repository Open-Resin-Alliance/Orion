/**
 * Orion - Config Models
 * Lightweight typed wrapper for the /config endpoint. We keep nested
 * sections as Map<String,dynamic> to avoid coupling to a rigid schema.
 */

import 'package:json_annotation/json_annotation.dart';

part 'config_models.g.dart';

@JsonSerializable(explicitToJson: true)
class ConfigModel {
  final Map<String, dynamic>? general;
  final Map<String, dynamic>? advanced;
  final Map<String, dynamic>? machine;
  final Map<String, dynamic>? vendor;

  ConfigModel({this.general, this.advanced, this.machine, this.vendor});

  factory ConfigModel.fromJson(Map<String, dynamic> json) =>
      _$ConfigModelFromJson(json);
  Map<String, dynamic> toJson() => _$ConfigModelToJson(this);
}

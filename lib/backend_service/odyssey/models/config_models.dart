/*
* Orion - Odyssey Config Models
* Copyright (C) 2025 Open Resin Alliance
*
* Licensed under the Apache License, Version 2.0 (the "License");
* you may not use this file except in compliance with the License.
* You may obtain a copy of the License at
*
*     http://www.apache.org/licenses/LICENSE-2.0
*
* Unless required by applicable law or agreed to in writing, software
* distributed under the License is distributed on an "AS IS" BASIS,
* WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
* See the License for the specific language governing permissions and
* limitations under the License.
*/

/// Orion - Config Models
/// Lightweight typed wrapper for the /config endpoint. We keep nested
/// sections as Map`<String,dynamic`> to avoid coupling to a rigid schema.
library;

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

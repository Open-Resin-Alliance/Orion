/*
* Orion - Athena Feature Flags Model
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

class AthenaFeatureFlags {
  final bool? hasAirFilter;
  final bool? hasCamera;
  final bool? hasCameraFlash;
  final bool? hasForceSensor;
  final bool? hasHeatedChamber;
  final bool? hasHeatedVat;
  final bool? hasSmartpower;
  final String? machineType;

  const AthenaFeatureFlags(
      {this.hasAirFilter,
      this.hasCamera,
      this.hasCameraFlash,
      this.hasForceSensor,
      this.hasHeatedChamber,
      this.hasHeatedVat,
      this.hasSmartpower,
      this.machineType});

  factory AthenaFeatureFlags.fromJson(Map<String, dynamic> json) {
    bool? toBool(dynamic v) {
      if (v == null) return null;
      if (v is bool) return v;
      if (v is num) return v != 0;
      if (v is String) return v.toLowerCase() == 'true';
      return null;
    }

    return AthenaFeatureFlags(
      hasAirFilter: toBool(json['hasAirFilter'] ?? json['has_air_filter']),
      hasCamera: toBool(json['hasCamera'] ?? json['has_camera']),
      hasCameraFlash:
          toBool(json['hasCameraFlash'] ?? json['has_camera_flash']),
      hasForceSensor:
          toBool(json['hasForceSensor'] ?? json['has_force_sensor']),
      hasHeatedChamber:
          toBool(json['hasHeatedChamber'] ?? json['has_heated_chamber']),
      hasHeatedVat: toBool(json['hasHeatedVat'] ?? json['has_heated_vat']),
      hasSmartpower: toBool(json['hasSmartpower'] ?? json['has_smartpower']),
      machineType: (json['machineType'] ?? json['machine_type']) as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'hasAirFilter': hasAirFilter,
        'hasCamera': hasCamera,
        'hasCameraFlash': hasCameraFlash,
        'hasForceSensor': hasForceSensor,
        'hasHeatedChamber': hasHeatedChamber,
        'hasHeatedVat': hasHeatedVat,
        'hasSmartpower': hasSmartpower,
        'machineType': machineType,
      };

  @override
  String toString() =>
      'AthenaFeatureFlags(hasAirFilter: $hasAirFilter, hasCamera: $hasCamera, hasCameraFlash: $hasCameraFlash, hasForceSensor: $hasForceSensor, hasHeatedChamber: $hasHeatedChamber, hasHeatedVat: $hasHeatedVat, hasSmartpower: $hasSmartpower, machineType: $machineType)';
}

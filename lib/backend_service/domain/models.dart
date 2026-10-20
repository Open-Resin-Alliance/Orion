/*
* Orion - Backend Domain Models
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

/// Backend-agnostic file import request.
///
/// This replaces backend-specific request DTOs in UI/provider layers.
class FileImportRequest {
  const FileImportRequest({
    required this.usbFilePath,
    required this.jobName,
    required this.profileId,
  });

  final String usbFilePath;
  final String jobName;
  final int profileId;
}

/// Canonical resin exposure/settings model used by UI and service layers.
class ResinSettings {
  const ResinSettings({
    required this.normalCureTime,
    required this.burnInCureTime,
    required this.burnInCount,
    required this.liftAfterPrint,
    required this.waitAfterCure,
    required this.waitAfterLife,
    this.layerThicknessUm,
    this.resinTemperature,
    this.peelDetection,
    this.bottomLiftAfterPrint,
    this.liftSpeed,
    this.retractSpeed,
  });

  final double normalCureTime;
  final double burnInCureTime;
  final int burnInCount;
  final double liftAfterPrint;
  final double waitAfterCure;
  final double waitAfterLife;

  /// Printed layer thickness in microns (NanoDLP `Depth`).
  final double? layerThicknessUm;

  /// Resin preheat temperature in °C (`CustomValues.ResinPreheatTemperature`).
  final double? resinTemperature;

  /// Peel detection ("Smart Mode") flag (`CustomValues.FssEnablePeeldetection`).
  final bool? peelDetection;

  /// Lift distance after the burn-in layers, in mm (`SupportWaitHeight`).
  final double? bottomLiftAfterPrint;

  /// Lift and retract speeds in mm/min.
  final double? liftSpeed;
  final double? retractSpeed;

  factory ResinSettings.fromNormalizedMap(Map<String, dynamic> normalized) {
    return ResinSettings(
      normalCureTime:
          (normalized['normal_cure_time'] as num?)?.toDouble() ?? 0.0,
      burnInCureTime:
          (normalized['burn_in_cure_time'] as num?)?.toDouble() ?? 0.0,
      burnInCount: (normalized['burn_in_count'] as num?)?.toInt() ?? 0,
      liftAfterPrint:
          (normalized['lift_after_print'] as num?)?.toDouble() ?? 0.0,
      waitAfterCure: (normalized['wait_after_cure'] as num?)?.toDouble() ?? 0.0,
      waitAfterLife: (normalized['wait_after_life'] as num?)?.toDouble() ?? 0.0,
      layerThicknessUm: (normalized['layer_thickness_um'] as num?)?.toDouble(),
      resinTemperature: (normalized['resin_temperature'] as num?)?.toDouble(),
      peelDetection: normalized['peel_detection'] as bool?,
      bottomLiftAfterPrint:
          (normalized['bottom_lift_after_print'] as num?)?.toDouble(),
      liftSpeed: (normalized['lift_speed'] as num?)?.toDouble(),
      retractSpeed: (normalized['retract_speed'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toNormalizedMap() {
    return {
      'normal_cure_time': normalCureTime,
      'burn_in_cure_time': burnInCureTime,
      'burn_in_count': burnInCount,
      'lift_after_print': liftAfterPrint,
      'wait_after_cure': waitAfterCure,
      'wait_after_life': waitAfterLife,
      'layer_thickness_um': layerThicknessUm,
      'resin_temperature': resinTemperature,
      'peel_detection': peelDetection,
      'bottom_lift_after_print': bottomLiftAfterPrint,
      'lift_speed': liftSpeed,
      'retract_speed': retractSpeed,
    };
  }
}

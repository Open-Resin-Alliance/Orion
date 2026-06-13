/*
* Orion - NanoDLP Import Request Model
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

/// Model for NanoDLP file import request parameters.
///
/// Represents the data needed to import a file from USB/local storage
/// to NanoDLP's internal storage with associated settings.
class NanoImportRequest {
  /// Full path to the USB/local file to import
  final String usbFilePath;

  /// Job/plate name to save the file as in NanoDLP
  final String jobName;

  /// Material profile ID to associate with this print
  final String profileId;

  /// Optional path to a zip file (typically empty)
  final String? zipFile;

  /// Auto-center the model (0 = disabled, 1 = enabled)
  final int autoCenter;

  /// Multi-thickness settings (comma-separated values or empty)
  final String? multiThickness;

  /// Multi-cure settings (comma-separated values or empty)
  final String? multiCure;

  /// Z-offset in mm
  final double offset;

  /// Stop at specific layers (comma-separated layer numbers or empty)
  final String? stopLayers;

  /// Number of low quality layers
  final int lowQualityLayerNumber;

  /// Path to mask file (typically empty)
  final String? maskFile;

  /// Mask effect strength (0.00 - 1.00)
  final double maskEffect;

  /// Image rotation in degrees (0, 90, 180, 270)
  final int imageRotate;

  const NanoImportRequest({
    required this.usbFilePath,
    required this.jobName,
    required this.profileId,
    this.zipFile = '',
    this.autoCenter = 0,
    this.multiThickness = '',
    this.multiCure = '',
    this.offset = 0.0,
    this.stopLayers = '',
    this.lowQualityLayerNumber = 0,
    this.maskFile = '',
    this.maskEffect = 0.0,
    this.imageRotate = 0,
  });

  /// Convert to multipart form fields for NanoDLP's /importfile endpoint
  Map<String, String> toFormFields() {
    return {
      'USBFile': usbFilePath,
      'ZipFile': zipFile ?? '',
      'Path': jobName,
      'ProfileID': profileId,
      'AutoCenter': autoCenter.toString(),
      'MultiThickness': multiThickness ?? '',
      'MultiCure': multiCure ?? '',
      'Offset': offset.toStringAsFixed(2),
      'StopLayers': stopLayers ?? '',
      'LowQualityLayerNumber': lowQualityLayerNumber.toString(),
      'MaskFile': maskFile ?? '',
      'MaskEffect': maskEffect.toStringAsFixed(2),
      'ImageRotate': imageRotate.toString(),
    };
  }

  @override
  String toString() {
    return 'NanoImportRequest(usbFile: $usbFilePath, jobName: $jobName, profileId: $profileId)';
  }
}

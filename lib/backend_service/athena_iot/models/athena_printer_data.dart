/*
* Orion - Athena Printer Data Model
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

class AthenaPrinterData {
  final String? cpuSerial;
  final String? machineType;
  final String? printerName;
  final String? printerSerial;
  final String? softwareBuild;
  final String? softwareVersion;
  final String? updateChannel;

  const AthenaPrinterData({
    this.cpuSerial,
    this.machineType,
    this.printerName,
    this.printerSerial,
    this.softwareBuild,
    this.softwareVersion,
    this.updateChannel,
  });

  static String? _normalizeString(dynamic v) {
    if (v == null) return null;
    if (v is String) return v.trim();
    return v.toString();
  }

  factory AthenaPrinterData.fromJson(Map<String, dynamic> json) {
    return AthenaPrinterData(
      cpuSerial: _normalizeString(json['cpuSerial'] ?? json['cpu_serial']),
      machineType:
          _normalizeString(json['machineType'] ?? json['machine_type']),
      printerName:
          _normalizeString(json['printerName'] ?? json['printer_name']),
      printerSerial:
          _normalizeString(json['printerSerial'] ?? json['printer_serial']),
      softwareBuild:
          _normalizeString(json['softwareBuild'] ?? json['software_build']),
      softwareVersion:
          _normalizeString(json['softwareVersion'] ?? json['software_version']),
      updateChannel:
          _normalizeString(json['updateChannel'] ?? json['update_channel']),
    );
  }

  Map<String, dynamic> toJson() => {
        'cpuSerial': cpuSerial,
        'machineType': machineType,
        'printerName': printerName,
        'printerSerial': printerSerial,
        'softwareBuild': softwareBuild,
        'softwareVersion': softwareVersion,
        'updateChannel': updateChannel,
      };

  @override
  String toString() =>
      'AthenaPrinterData(cpuSerial: $cpuSerial, machineType: $machineType, printerName: $printerName, printerSerial: $printerSerial, softwareBuild: $softwareBuild, softwareVersion: $softwareVersion, updateChannel: $updateChannel)';
}

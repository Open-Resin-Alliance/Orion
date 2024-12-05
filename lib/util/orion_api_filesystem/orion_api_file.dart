/*
* Orion - Orion API File
* Copyright (C) 2024 Open Resin Alliance
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

import 'dart:io' as io;

import 'package:orion/util/orion_api_filesystem/orion_api_item.dart';

class OrionApiFile implements OrionApiItem {
  final io.File? file;
  @override
  final String path;
  final String name;
  final int? lastModified;
  final String? locationCategory;
  @override
  final String parentPath;
  final double? usedMaterial;
  final double? printTime;
  final double? layerHeight;
  final int? layerCount;

  OrionApiFile({
    this.file,
    required this.path,
    required this.name,
    required this.parentPath,
    this.lastModified,
    this.locationCategory,
    this.usedMaterial,
    this.printTime,
    this.layerHeight,
    this.layerCount,
  });

  factory OrionApiFile.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic> fileData = json['file_data'] ?? {};

    return OrionApiFile(
      file: fileData['path'] != null ? io.File(fileData['path']) : null,
      path: fileData['path'] ?? '',
      name: fileData['name'] ?? '',
      lastModified: fileData['last_modified'] ?? 0,
      parentPath: fileData['parent_path'] ?? '',
      locationCategory: json['location_category'],
      usedMaterial: json['used_material'] ?? 0.0,
      printTime: json['print_time'] ?? 0.0,
      layerHeight: json['layer_height'] ?? 0.0,
      layerCount: json['layer_count'] ?? 0,
    );
  }
}

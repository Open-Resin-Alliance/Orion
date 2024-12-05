/*
* Orion - Orion API Directory
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

// ignore_for_file: unused_element

import 'package:orion/util/orion_api_filesystem/orion_api_item.dart';

class OrionApiDirectory implements OrionApiItem {
  @override
  final String path;
  final String name;
  final int lastModified;
  final String locationCategory;
  @override
  final String parentPath;

  OrionApiDirectory({
    required this.path,
    required this.name,
    required this.lastModified,
    required this.locationCategory,
    required this.parentPath,
  });

  factory OrionApiDirectory.fromJson(Map<String, dynamic> json) {
    return OrionApiDirectory(
      path: json['path'],
      name: json['name'],
      lastModified: json['last_modified'],
      locationCategory: json['location_category'],
      parentPath: json['parent_path'],
    );
  }
}

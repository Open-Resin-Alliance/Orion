/*
* Orion - Odyssey API Service
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

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:http/http.dart' as http;
import 'package:orion/util/orion_config.dart';

class ApiService {
  static final _logger = Logger('ApiService');

  late String apiUrl;
  late String customUrl;
  late bool useCustomUrl;

  ApiService() {
    try {
      OrionConfig config = OrionConfig();
      customUrl = config.getString('customUrl', category: 'advanced');
      useCustomUrl = config.getFlag('useCustomUrl', category: 'advanced');
      apiUrl = useCustomUrl ? customUrl : 'http://localhost:12357';
    } catch (e) {
      throw Exception('Failed to load orion.cfg: $e');
    }
  }

  // Method for creating a Uri object based on http or https protocol
  static Uri dynUri(
      String apiUrl, String path, Map<String, dynamic> queryParams) {
    if (queryParams.containsKey('file_path')) {
      queryParams['file_path'] =
          queryParams['file_path'].toString().replaceAll('//', '');
    }

    if (apiUrl.startsWith('https://')) {
      return Uri.https(apiUrl.replaceFirst('https://', ''), path, queryParams);
    } else if (apiUrl.startsWith('http://')) {
      return Uri.http(apiUrl.replaceFirst('http://', ''), path, queryParams);
    } else {
      throw ArgumentError('apiUrl must start with either http:// or https://');
    }
  }

  ///
  /// GET METHODS TO ODYSSEY
  ///

  Future<http.Response> odysseyGet(
      String endpoint, Map<String, dynamic> queryParams) async {
    var uri = dynUri(apiUrl, endpoint, queryParams);
    _logger.fine('Odyssey GET $uri');

    final response = await http.get(uri);

    if (response.statusCode == 200) {
      return response;
    } else {
      throw Exception('Odyssey GET call failed: $response');
    }
  }

  Future<http.Response> odysseyPost(
      String endpoint, Map<String, dynamic> queryParams) async {
    var uri = dynUri(apiUrl, endpoint, queryParams);
    _logger.fine('Odyssey POST $uri');

    final response = await http.post(uri);

    if (response.statusCode == 200) {
      return response;
    } else {
      throw Exception('Odyssey POST call failed: $response');
    }
  }

  Future<http.Response> odysseyDelete(
      String endpoint, Map<String, dynamic> queryParams) async {
    var uri = dynUri(apiUrl, endpoint, queryParams);
    _logger.fine('Odyssey DELETE $uri');

    final response = await http.delete(uri);

    if (response.statusCode == 200) {
      return response;
    } else {
      throw Exception('Odyssey DELETE call failed: $response');
    }
  }

  // Get current status of the printer
  Future<Map<String, dynamic>> getStatus() async {
    _logger.info("getStatus");
    final response = await odysseyGet('/status', {});
    return json.decode(response.body);
  }

  // Get current status of the printer
  Future<Map<String, dynamic>> getConfig() async {
    _logger.info("getConfig");
    final response = await odysseyGet('/config', {});
    return json.decode(response.body);
  }

  // Get list of files and directories in a specific location with pagination
  // Takes 3 parameters : location [string], pageSize [int] and pageIndex [int]
  Future<Map<String, dynamic>> listItems(
      String location, int pageSize, int pageIndex, String subdirectory) async {
    _logger.info(
        "listItems location=$location pageSize=$pageSize pageIndex=$pageIndex subdirectory=$subdirectory");
    final queryParams = {
      "location": location,
      "subdirectory": subdirectory,
      "page_index": pageIndex.toString(),
      "page_size": pageSize.toString(),
    };

    final response = await odysseyGet('/files', queryParams);
    return json.decode(response.body);
  }

  // Method to check if USB is available
  Future<bool> usbAvailable() async {
    try {
      await listItems('Local', 1, 0, '');
    } catch (e) {
      _logger.severe('Failed to list items on Internal: $e');
      return false;
    }

    try {
      // Try to list items on Usb
      await listItems('Usb', 1, 0, '');
      return true; // If successful, return true
    } catch (e) {
      _logger.severe('Failed to list items on Usb: $e');
      return false; // If unsuccessful, return false
    }
  }

  // Get file metadata
  // Takes 2 parameters : location [string] and filePath [String]
  Future<Map<String, dynamic>> getFileMetadata(
      String location, String filePath) async {
    _logger.info("getFileMetadata location=$location filePath=$filePath");
    final queryParams = {"location": location, "file_path": filePath};

    final response = await odysseyGet('/file/metadata', queryParams);
    return json.decode(response.body);
  }

  // Get file thumbnail
  // Takes 2 parameters : location [string] and filePath [String]
  Future<Uint8List> getFileThumbnail(
      String location, String filePath, String size) async {
    _logger.info(
        "getFileThumbnail location=$location filePath=$filePath size=$size");
    final queryParams = {
      "location": location,
      "file_path": filePath,
      "size": size
    };

    final response = await odysseyGet('/file/thumbnail', queryParams);
    return response.bodyBytes;
  }

  ///
  /// POST METHODS TO ODYSSEY
  ///

  // Start printing a given file
  // Takes 2 parameters : location [string] and filePath [String]
  Future<void> startPrint(String location, String filePath) async {
    _logger.info("startPrint location=$location filePath=$filePath");

    final queryParams = {
      'location': location,
      'file_path': filePath,
    };

    await odysseyPost('/print/start', queryParams);
  }

  // Cancel the print
  Future<void> cancelPrint() async {
    _logger.info("cancelPrint");

    await odysseyPost('/print/cancel', {});
  }

  // Pause the print
  Future<void> pausePrint() async {
    _logger.info("pausePrint");

    await odysseyPost('/print/pause', {});
  }

  // Resume the print
  Future<void> resumePrint() async {
    _logger.info("resumePrint");

    await odysseyPost('/print/resume', {});
  }

  // Move the Z axis
  // Takes 1 param height [double] which is the desired position of the Z axis
  Future<Map<String, dynamic>> move(double height) async {
    _logger.info("move height=$height");

    final response = await odysseyPost('/manual', {'z': height.toString()});
    return json.decode(response.body == '' ? '{}' : response.body);
  }

  // Toggle cure
  // Takes 1 param cure [bool] which define if we start or stop the curing
  Future<Map<String, dynamic>> manualCure(bool cure) async {
    _logger.info("manualCure cure=$cure");

    final response = await odysseyPost('/manual', {'cure': cure.toString()});
    return json.decode(response.body == '' ? '{}' : response.body);
  }

  // Home Z axis
  Future<Map<String, dynamic>> manualHome() async {
    _logger.info("manualHome");

    final response = await odysseyPost('/manual/home', {});
    return json.decode(response.body == '' ? '{}' : response.body);
  }

  // Issue hardware-layer command
  // Takes 1 param command [String] which holds the command to run
  Future<Map<String, dynamic>> manualCommand(String command) async {
    _logger.info("manualCommand");

    final response =
        await odysseyPost('/manual/hardware_command', {'command': command});
    return json.decode(response.body == '' ? '{}' : response.body);
  }

  // Display a test pattern on the screen
  // Takes 1 param test [String] which holds the test to display
  Future<void> displayTest(String test) async {
    _logger.info("displayTest test=$test");

    final queryParams = {
      'test': test,
    };

    await odysseyPost('/manual/display_test', queryParams);
  }

  ///
  /// DELETE METHODS TO ODYSSEY
  ///

  // Delete a file
  // Takes 2 parameters : location [string] and filePath [String]
  Future<Map<String, dynamic>> deleteFile(
      String location, String filePath) async {
    _logger.info("deleteFile location=$location fileName=$filePath");
    final queryParams = {
      'location': location,
      'file_path': filePath,
    };

    try {
      final response = await odysseyDelete('/file', queryParams);
      return json.decode(response.body);
    } catch (e) {
      _logger.severe('Failed to delete file: $e');
      throw Exception('Failed to delete file: $e');
    }
  }
}

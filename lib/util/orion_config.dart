/*
* Orion - Config
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

// ignore_for_file: use_build_context_synchronously

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as path;
import 'dart:convert';

class OrionConfig {
  final _logger = Logger('OrionConfig');
  late final String _configPath;

  OrionConfig() {
    _configPath = Platform.environment['ORION_CFG'] ?? '.';
  }

  ThemeMode getThemeMode() {
    var config = _getConfig();
    var themeMode = config['general']?['themeMode'] ?? 'light';
    return themeMode == 'dark' ? ThemeMode.dark : ThemeMode.light;
  }

  void setThemeMode(ThemeMode themeMode) {
    var config = _getConfig();
    config['general'] ??= {};
    config['general']['themeMode'] =
        themeMode == ThemeMode.dark ? 'dark' : 'light';
    _writeConfig(config);
  }

  void setFlag(String flagName, bool value, {String category = 'general'}) {
    var config = _getConfig();
    config[category] ??= {};
    config[category][flagName] = value;
    _logger.config('setFlag: $flagName to $value');

    _writeConfig(config);
  }

  void setString(String key, String value, {String category = 'general'}) {
    var config = _getConfig();
    config[category] ??= {};
    config[category][key] = value;

    if (value == '') {
      _logger.config('setString: cleared $key');
    } else {
      _logger.config('setString: $key to ${value == '' ? 'NULL' : value}');
    }

    _writeConfig(config);
  }

  bool getFlag(String flagName, {String category = 'general'}) {
    var config = _getConfig();
    return config[category]?[flagName] ?? false;
  }

  String getString(String key, {String category = 'general'}) {
    var config = _getConfig();
    return config[category]?[key] ?? '';
  }

  void toggleFlag(String flagName, {String category = 'general'}) {
    bool currentValue = getFlag(flagName, category: category);
    setFlag(flagName, !currentValue, category: category);
  }

  Color getVendorThemeSeed() {
    var config = _getConfig();
    var seedHex = config['vendor']?['vendorThemeSeed'] ?? '#ff6750a4';
    // Remove the '#' and parse the hex color
    _logger.config('Vendor theme seed: $seedHex');
    return Color(int.parse('${seedHex.replaceAll('#', '')}', radix: 16));
  }

  Map<String, dynamic> _getVendorConfig() {
    var fullPath = path.join(_configPath, 'vendor.cfg');
    var vendorFile = File(fullPath);

    if (!vendorFile.existsSync() || vendorFile.readAsStringSync().isEmpty) {
      return {};
    }

    try {
      return Map<String, dynamic>.from(
          json.decode(vendorFile.readAsStringSync()));
    } catch (e) {
      _logger.warning('Failed to parse vendor.cfg: $e');
      return {};
    }
  }

  Map<String, dynamic> _getConfig() {
    var fullPath = path.join(_configPath, 'orion.cfg');
    var configFile = File(fullPath);
    var vendorConfig = _getVendorConfig();

    // Get vendor machine name if available
    var defaultMachineName =
        vendorConfig['vendor']?['vendorMachineName'] ?? '3D Printer';

    var defaultConfig = {
      'general': {
        'themeMode': 'dark',
      },
      'advanced': {},
      'machine': {
        'machineName': defaultMachineName,
        'firstRun': true,
      },
    };

    if (!configFile.existsSync() || configFile.readAsStringSync().isEmpty) {
      // Remove vendor section before writing
      var configToWrite = Map<String, dynamic>.from(defaultConfig);
      _writeConfig(configToWrite);
      // Return merged view for reading
      return _mergeConfigs(defaultConfig, vendorConfig);
    }

    var userConfig =
        Map<String, dynamic>.from(json.decode(configFile.readAsStringSync()));

    // Return merged view for reading
    return _mergeConfigs(
        _mergeConfigs(defaultConfig, vendorConfig), userConfig);
  }

  void _writeConfig(Map<String, dynamic> config) {
    // Remove any vendor section before writing to orion.cfg
    var configToWrite = Map<String, dynamic>.from(config);
    configToWrite.remove('vendor');

    var fullPath = path.join(_configPath, 'orion.cfg');
    var configFile = File(fullPath);
    var encoder = const JsonEncoder.withIndent('  ');
    configFile.writeAsStringSync(encoder.convert(configToWrite));
  }

  Map<String, dynamic> _mergeConfigs(
      Map<String, dynamic> base, Map<String, dynamic> overlay) {
    var result = Map<String, dynamic>.from(base);

    overlay.forEach((key, value) {
      if (value is Map) {
        result[key] = result.containsKey(key)
            ? _mergeConfigs(Map<String, dynamic>.from(result[key] ?? {}),
                Map<String, dynamic>.from(value))
            : Map<String, dynamic>.from(value);
      } else {
        result[key] = value;
      }
    });

    return result;
  }
}

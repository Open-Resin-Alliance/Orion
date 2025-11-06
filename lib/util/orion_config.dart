/*
* Orion - Config
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

// ignore_for_file: use_build_context_synchronously

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as path;

class OrionConfig {
  final _logger = Logger('OrionConfig');
  late final String _configPath;
  // Simple change listener registry so other services can react when
  // `orion.cfg` is updated via _writeConfig(). Listeners should be
  // lightweight and avoid throwing.
  static final List<VoidCallback> _changeListeners = [];

  /// Register a callback to be invoked after `orion.cfg` is written.
  static void addChangeListener(VoidCallback cb) {
    if (!_changeListeners.contains(cb)) _changeListeners.add(cb);
  }

  /// Remove a previously-registered change listener.
  static void removeChangeListener(VoidCallback cb) {
    _changeListeners.remove(cb);
  }

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

    // NOTE: we intentionally do not write other flags here. Use explicit
    // configuration management to keep side-effects visible.

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

  Color getThemeSeed(String type) {
    var config = _getConfig();

    var seedHex = '#00000000';

    if (type == 'vendor') {
      seedHex = config['vendor']?['vendorThemeSeed'] ?? '#00000000';
    } else if (type == 'primary') {
      seedHex = config['general']?['themeSeed'] ?? '#00000000';
    }
    // Remove the '#' and parse the hex color
    return Color(int.parse(seedHex.replaceAll('#', ''), radix: 16));
  }

  /// Get gradient colors for glass theme mode
  List<Color> getThemeGradient(String type) {
    var config = _getConfig();

    List<String>? gradientHex;

    if (type == 'vendor') {
      gradientHex = config['vendor']?['vendorThemeGradient']?.cast<String>();
    } else if (type == 'primary') {
      gradientHex = config['general']?['themeGradient']?.cast<String>();
    }

    // If no gradient is defined, return empty list (will auto-generate)
    if (gradientHex == null || gradientHex.isEmpty) {
      return [];
    }

    // Convert hex strings to Color objects
    return gradientHex.map((hex) {
      return Color(int.parse(hex.replaceAll('#', ''), radix: 16));
    }).toList();
  }

  /// Set gradient colors for glass theme mode
  void setThemeGradient(List<Color> gradient, {String category = 'general'}) {
    var config = _getConfig();
    config[category] ??= {};

    if (gradient.isEmpty) {
      // Remove the gradient key completely when clearing
      config[category].remove('themeGradient');
    } else {
      // Convert colors to hex strings using toArgb()
      final gradientHex = gradient.map((color) {
        final alpha = ((color.a * 255.0).round() & 0xff)
            .toRadixString(16)
            .padLeft(2, '0');
        final red = ((color.r * 255.0).round() & 0xff)
            .toRadixString(16)
            .padLeft(2, '0');
        final green = ((color.g * 255.0).round() & 0xff)
            .toRadixString(16)
            .padLeft(2, '0');
        final blue = ((color.b * 255.0).round() & 0xff)
            .toRadixString(16)
            .padLeft(2, '0');
        return '#$alpha$red$green$blue';
      }).toList();

      config[category]['themeGradient'] = gradientHex;
    }

    _writeConfig(config);
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

  /// Return the vendor-declared machine model name.
  String getMachineModelName() {
    var vendor = _getVendorConfig();
    return vendor['machineModelName'] ??
        vendor['vendor']?['machineModelName'] ??
        vendor['vendor']?['vendorMachineName'] ??
        '3D Printer';
  }

  /// Read the vendor `homePosition` setting. Expected values: 'up'|'down'.
  /// Defaults to 'down' when absent or unrecognized.
  String getHomePosition() {
    final vendor = _getVendorConfig();
    final hp = vendor['homePosition'] ?? vendor['vendor']?['homePosition'];
    if (hp is String) {
      final v = hp.toLowerCase();
      if (v == 'up' || v == 'down') return v;
    }
    return 'down';
  }

  /// Convenience boolean: true when configured 'up'
  bool isHomePositionUp() => getHomePosition() == 'up';

  /// Query a boolean feature flag from the vendor `featureFlags` section.
  /// Returns [defaultValue] when not present.
  bool getFeatureFlag(String key, {bool defaultValue = false}) {
    // Read merged config so `orion.cfg` can override vendor-provided flags.
    var merged = _getConfig();
    final flags = merged['featureFlags'];
    if (flags is Map && flags.containsKey(key)) {
      return flags[key] == true;
    }
    return defaultValue;
  }

  // --- Convenience accessors for known vendor feature flags ---
  bool enableBetaFeatures() => getFeatureFlag('enableBetaFeatures');
  bool enableDeveloperSettings() => getFeatureFlag('enableDeveloperSettings');
  bool enableAdvancedSettings() => getFeatureFlag('enableAdvancedSettings');
  bool enableExperimentalFeatures() =>
      getFeatureFlag('enableExperimentalFeatures');
  bool enableResinProfiles() => getFeatureFlag('enableResinProfiles');
  bool enableCustomName() => getFeatureFlag('enableCustomName');
  bool enablePowerControl() => getFeatureFlag('enablePowerControl');

  /// Return nested `hardwareFeatures` map (may be empty)
  Map<String, dynamic> getHardwareFeatures() {
    var merged = _getConfig();
    final flags = merged['featureFlags'];
    if (flags is Map && flags['hardwareFeatures'] is Map<String, dynamic>) {
      return Map<String, dynamic>.from(flags['hardwareFeatures']);
    }
    return {};
  }

  /// Generic helper to read a hardware feature boolean from
  /// `featureFlags.hardwareFeatures`.
  bool getHardwareFeature(String key, {bool defaultValue = false}) {
    final hw = getHardwareFeatures();
    if (hw.containsKey(key)) return hw[key] == true;
    return defaultValue;
  }

  // --- Convenience accessors for common hardware features ---
  bool hasHeatedChamber() => getHardwareFeature('hasHeatedChamber');
  bool hasHeatedVat() => getHardwareFeature('hasHeatedVat');
  bool hasCamera() => getHardwareFeature('hasCamera');
  bool hasAirFilter() => getHardwareFeature('hasAirFilter');
  bool hasForceSensor() => getHardwareFeature('hasForceSensor');

  /// Return the full featureFlags map (may be empty)
  Map<String, dynamic> getFeatureFlags() {
    var merged = _getConfig();
    final flags = merged['featureFlags'];
    if (flags is Map<String, dynamic>) return Map<String, dynamic>.from(flags);
    return {};
  }

  /// Read the internalConfig section (vendor-specified internal config)
  Map<String, dynamic> getInternalConfig() {
    var vendor = _getVendorConfig();
    final internal = vendor['internalConfig'];
    if (internal is Map<String, dynamic>) {
      return Map<String, dynamic>.from(internal);
    }
    return {};
  }

  /// Convenience for string-backed internalConfig values.
  String getInternalConfigString(String key, {String defaultValue = ''}) {
    final internal = getInternalConfig();
    return internal[key]?.toString() ?? defaultValue;
  }

  /// Convenience check for whether the app should operate in NanoDLP mode.
  /// Determined solely from the merged 'advanced.backend' setting.
  bool isNanoDlpMode() {
    try {
      final backend = getString('backend', category: 'advanced');
      return backend.toLowerCase() == 'nanodlp';
    } catch (_) {
      return false;
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
      // When creating the initial orion.cfg, write a merged view that
      // includes vendor-provided defaults so runtime immediately sees
      // backend, featureFlags and hardwareFeatures without waiting for
      // a later write from onboarding. Vendor preferences should override
      // the app defaults for initial setup.
      var mergedInit = _mergeConfigs(defaultConfig, vendorConfig);

      try {
        final vendorBlock = vendorConfig['vendor'];
        if (vendorBlock is Map<String, dynamic>) {
          final vThemeMode = vendorBlock['themeMode'];
          if (vThemeMode is String && vThemeMode.isNotEmpty) {
            mergedInit['general'] ??= {};
            mergedInit['general']['themeMode'] = vThemeMode;
          }

          final vSeed = vendorBlock['vendorThemeSeed'];
          if (vSeed is String && vSeed.isNotEmpty) {
            mergedInit['general'] ??= {};
            mergedInit['general']['colorSeed'] = 'vendor';
          }
        }
      } catch (e) {
        _logger.fine('Failed to apply vendor initial theme defaults: $e');
      }

      _writeConfig(mergedInit);
      // Return the merged view for reading
      return mergedInit;
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
    // If vendor provides internalConfig.backend or internalConfig.defaultLanguage,
    // copy them into the 'advanced' section so they persist in orion.cfg.
    final vendor = _getVendorConfig();
    final internal = vendor['internalConfig'];
    if (internal is Map<String, dynamic>) {
      configToWrite['advanced'] ??= {};
      if (internal.containsKey('backend') &&
          (configToWrite['advanced']['backend'] == null ||
              configToWrite['advanced']['backend'] == '')) {
        configToWrite['advanced']['backend'] = internal['backend'];
      }
      if (internal.containsKey('defaultLanguage') &&
          (configToWrite['advanced']['defaultLanguage'] == null ||
              configToWrite['advanced']['defaultLanguage'] == '')) {
        configToWrite['advanced']['defaultLanguage'] =
            internal['defaultLanguage'];
      }
    }
    // Allow vendor to preconfigure a theme mode or use the vendor color seed
    // as the default. If vendor provides 'vendor.themeMode' or
    // 'vendor.vendorThemeSeed' prefer those values when orion.cfg has no
    // explicit setting.
    try {
      final vendorBlock = vendor['vendor'];
      if (vendorBlock is Map<String, dynamic>) {
        // Vendor-provided theme mode (e.g. 'glass')
        final vThemeMode = vendorBlock['themeMode'];
        if (vThemeMode is String) {
          configToWrite['general'] ??= {};
          if (configToWrite['general']['themeMode'] == null ||
              (configToWrite['general']['themeMode'] as String).isEmpty) {
            configToWrite['general']['themeMode'] = vThemeMode;
          }
        }

        // If vendor has a theme seed, default to using the vendor seed
        // by setting colorSeed to the special value 'vendor' unless the
        // user has already chosen a seed.
        final vSeed = vendorBlock['vendorThemeSeed'];
        if (vSeed is String && vSeed.isNotEmpty) {
          configToWrite['general'] ??= {};
          if (configToWrite['general']['colorSeed'] == null ||
              (configToWrite['general']['colorSeed'] as String).isEmpty) {
            configToWrite['general']['colorSeed'] = 'vendor';
          }
        }
      }
    } catch (e) {
      _logger.fine('Failed to copy vendor theme defaults: $e');
    }

    configToWrite.remove('vendor');

    var fullPath = path.join(_configPath, 'orion.cfg');
    var configFile = File(fullPath);
    var encoder = const JsonEncoder.withIndent('  ');
    configFile.writeAsStringSync(encoder.convert(configToWrite));
    // Notify any registered listeners that the on-disk config has changed.
    for (final cb in _changeListeners) {
      try {
        cb();
      } catch (e) {
        _logger.warning('Config change listener threw: $e');
      }
    }
  }

  void blowUp(BuildContext context, String imagePath) {
    _logger.severe('Blowing up the app');
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return FutureBuilder(
          future: Future.delayed(const Duration(seconds: 4)),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return SafeArea(
                child: Dialog(
                  shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.zero),
                  insetPadding: EdgeInsets.zero,
                  backgroundColor: Theme.of(context).colorScheme.surface,
                  child: const Center(
                    child: SizedBox(
                      height: 75,
                      width: 75,
                      child: CircularProgressIndicator(
                        strokeWidth: 6,
                      ),
                    ),
                  ),
                ),
              );
            } else {
              Future.delayed(const Duration(seconds: 10), () {
                Navigator.of(context).pop(true);
              });
              return SafeArea(
                child: Dialog(
                  insetPadding: EdgeInsets.zero,
                  backgroundColor: Colors.transparent,
                  child: Image.asset(
                    imagePath,
                    fit: BoxFit.fill,
                    width: MediaQuery.of(context).size.width,
                    height: MediaQuery.of(context).size.height,
                  ),
                ),
              );
            }
          },
        );
      },
    );
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

/*
* Orion - Calibration Context Provider
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

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:orion/util/orion_config.dart';

/// Holds calibration context data for post-print evaluation
/// This allows us to pass calibration parameters from CalibrationScreen
/// to StatusScreen and finally to PostCalibrationOverlay
class CalibrationContextProvider extends ChangeNotifier {
  CalibrationContext? _context;

  CalibrationContextProvider() {
    _loadFromConfig();
  }

  CalibrationContext? get context {
    // Always try to load from config if in-memory context is null
    // This ensures we don't lose context after long waits or app lifecycle events
    if (_context == null) {
      _loadFromConfig();
    }
    return _context;
  }

  bool get hasContext {
    // Check both in-memory and persistent storage
    if (_context != null) return true;
    _loadFromConfig();
    return _context != null;
  }

  /// Store calibration context when starting a calibration print
  void setContext(CalibrationContext context) {
    _context = context;
    _saveToConfig();
    notifyListeners();
  }

  /// Clear context after post-calibration evaluation is complete
  void clearContext() {
    _context = null;
    _clearConfig();
    notifyListeners();
  }

  void _saveToConfig() {
    if (_context != null) {
      try {
        final jsonString = jsonEncode(_context!.toJson());
        OrionConfig()
            .setString('activeContext', jsonString, category: 'calibration');
        debugPrint('Saved calibration context to config');
      } catch (e) {
        debugPrint('Failed to save calibration context: $e');
      }
    }
  }

  void _clearConfig() {
    try {
      OrionConfig().setString('activeContext', '', category: 'calibration');
      debugPrint('Cleared calibration context from config');
    } catch (e) {
      debugPrint('Failed to clear calibration context from config: $e');
    }
  }

  void _loadFromConfig() {
    try {
      final jsonString =
          OrionConfig().getString('activeContext', category: 'calibration');
      if (jsonString.isNotEmpty) {
        final map = jsonDecode(jsonString);
        _context = CalibrationContext.fromJson(map);
        debugPrint(
            'Loaded calibration context from config: ${_context?.calibrationModelName}');
      } else {
        _context = null;
        debugPrint('No calibration context found in config');
      }
    } catch (e) {
      debugPrint('Failed to load calibration context: $e');
      _context = null;
    }
  }
}

/// Calibration context data
class CalibrationContext {
  final String calibrationModelName;
  final String? resinProfileName;
  final double startExposure;
  final double exposureIncrement;
  final int profileId;
  final int calibrationModelId;
  final String? evaluationGuideUrl;

  CalibrationContext({
    required this.calibrationModelName,
    required this.resinProfileName,
    required this.startExposure,
    required this.exposureIncrement,
    required this.profileId,
    required this.calibrationModelId,
    this.evaluationGuideUrl,
  });

  Map<String, dynamic> toJson() {
    return {
      'calibrationModelName': calibrationModelName,
      'resinProfileName': resinProfileName,
      'startExposure': startExposure,
      'exposureIncrement': exposureIncrement,
      'profileId': profileId,
      'calibrationModelId': calibrationModelId,
      'evaluationGuideUrl': evaluationGuideUrl,
    };
  }

  factory CalibrationContext.fromJson(Map<String, dynamic> json) {
    return CalibrationContext(
      calibrationModelName: json['calibrationModelName'] ?? '',
      resinProfileName: json['resinProfileName'],
      startExposure: (json['startExposure'] as num?)?.toDouble() ?? 0.0,
      exposureIncrement: (json['exposureIncrement'] as num?)?.toDouble() ?? 0.0,
      profileId: json['profileId'] ?? 0,
      calibrationModelId: json['calibrationModelId'] ?? 0,
      evaluationGuideUrl: json['evaluationGuideUrl'],
    );
  }
}

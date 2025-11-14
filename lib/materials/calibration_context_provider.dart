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

import 'package:flutter/foundation.dart';

/// Holds calibration context data for post-print evaluation
/// This allows us to pass calibration parameters from CalibrationScreen
/// to StatusScreen and finally to PostCalibrationOverlay
class CalibrationContextProvider extends ChangeNotifier {
  CalibrationContext? _context;

  CalibrationContext? get context => _context;

  bool get hasContext => _context != null;

  /// Store calibration context when starting a calibration print
  void setContext(CalibrationContext context) {
    _context = context;
    notifyListeners();
  }

  /// Clear context after post-calibration evaluation is complete
  void clearContext() {
    _context = null;
    notifyListeners();
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
}

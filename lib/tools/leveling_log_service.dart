/*
* Orion - Leveling Log Service
* Copyright (C) 2026 Open Resin Alliance
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
import 'dart:io';

import 'package:logging/logging.dart';
import 'package:orion/tools/leveling_log_entry.dart';
import 'package:orion/util/orion_config.dart';
import 'package:path/path.dart' as path;

/// Persists corner-check results to `orion_level.log` (JSON Lines) in the
/// same directory as `orion.cfg`.
class LevelingLogService {
  LevelingLogService._();

  static final _log = Logger('LevelingLogService');
  static String? _resolvedDir;

  /// Resolve the directory for the log file. Uses the same directory as
  /// `orion.cfg` when available; otherwise falls back to known locations.
  static String _resolveLogDir() {
    // 1) Use the same directory as orion.cfg
    final configDir = OrionConfig.configDirectory;
    if (configDir != null && configDir.isNotEmpty) {
      return configDir;
    }

    // 2) Fallback: executable directory
    try {
      final execDir = path.dirname(Platform.resolvedExecutable);
      if (execDir.isNotEmpty) return execDir;
    } catch (_) {}

    // 3) Fallback: current working directory
    try {
      return Directory.current.path;
    } catch (_) {}

    return '.';
  }

  /// Returns the full path to `orion_level.log`.
  static String get logFilePath {
    _resolvedDir ??= _resolveLogDir();
    return path.join(_resolvedDir!, 'orion_level.log');
  }

  /// Append a corner-check entry to the log file.
  static Future<void> logCornerCheck(LevelingLogEntry entry) async {
    try {
      final file = File(logFilePath);
      final line = '${json.encode(entry.toJson())}\n';
      await file.writeAsString(line, mode: FileMode.append);
      _log.info('Corner check logged: session=${entry.sessionId} '
          'recheck=${entry.recheckNumber} deviation=${entry.totalDeviationMm.toStringAsFixed(3)} '
          'passed=${entry.passed}');
    } catch (e, st) {
      _log.warning('Failed to write leveling log entry', e, st);
    }
  }
}

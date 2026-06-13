/*
* Orion - Install Locator
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

import 'dart:io';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as path;

final Logger _installLogger = Logger('InstallLocator');

/// Attempt to locate the directory containing the packaged application
/// shared-object or binary (for example `app.so`, `libapp.so`, `orion` or
/// `orion.so`). Returns the directory path or null when not found.
String? findEngineDir() {
  try {
    final exec = Platform.resolvedExecutable;
    if (exec.isNotEmpty) {
      final execDir = path.dirname(exec);

      final probeNames = [
        'app.so',
        'libapp.so',
        'orion',
        'orion.so',
        'libflutter_engine.so'
      ];

      for (final name in probeNames) {
        final p = path.join(execDir, name);
        if (File(p).existsSync()) return execDir;
      }

      // Try one level up
      final parent = path.dirname(execDir);
      for (final name in probeNames) {
        final p = path.join(parent, name);
        if (File(p).existsSync()) return parent;
      }
    }
  } catch (e) {
    _installLogger.fine('engine-dir probe from resolvedExecutable failed: $e');
  }

  // On Linux, inspect /proc/self/maps for an absolute path to a loaded
  // shared object that looks like our app/engine.
  try {
    if (Platform.isLinux) {
      final maps = File('/proc/self/maps');
      if (maps.existsSync()) {
        final lines = maps.readAsLinesSync();
        final re = RegExp(r'(/\S+\.(so|bin)(?:\.[0-9]+)?)');
        for (final l in lines) {
          final m = re.firstMatch(l);
          if (m != null) {
            final p = m.group(1) ?? '';
            if (p.contains('app') || p.contains('orion')) {
              return path.dirname(p);
            }
          }
        }
      }
    }
  } catch (e) {
    _installLogger.fine('engine-dir probe via /proc/self/maps failed: $e');
  }

  return null;
}

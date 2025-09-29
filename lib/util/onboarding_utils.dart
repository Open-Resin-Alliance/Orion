/*
* Orion - Onboarding Utils
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

class OnboardingUtils {
  static final Logger _logger = Logger('OnboardingUtils');

  static Future<bool> checkInitialConnectionStatus() async {
    if (!Platform.isLinux) return false;
    try {
      final result = await Process.run('ip', ['route', 'show', 'default']);
      if (result.exitCode != 0) {
        _logger.severe('Failed to get default gateway: ${result.stderr}');
        return false;
      }

      final gateway =
          RegExp(r'default via (\S+)').firstMatch(result.stdout)?.group(1);
      if (gateway == null) {
        _logger.severe('No default gateway found');
        return false;
      }

      final pingResult = await Process.run('ping', ['-c', '1', gateway]);
      return pingResult.exitCode == 0;
    } catch (e) {
      _logger.severe('Failed to check initial connection status: $e');
      return false;
    }
  }

  static Future<void> setSystemTimezone(String timezone) async {
    if (!Platform.isLinux) return;
    try {
      final checkResult = await Process.run('sudo', ['-n', 'true']);
      if (checkResult.exitCode == 0) {
        final result = await Process.run(
          'sudo',
          ['timedatectl', 'set-timezone', timezone],
        );
        if (result.exitCode != 0) {
          _logger.severe('Failed to set timezone: ${result.stderr}');
        }
      } else {
        _logger.warning('No sudo access to set system timezone');
      }
    } catch (e) {
      _logger.severe('Error setting system timezone: $e');
    }
  }

  static Future<String?> getSystemTimezone() async {
    if (!Platform.isLinux) return null;
    try {
      final result = await Process.run('timedatectl', ['show']);
      if (result.exitCode == 0) {
        return RegExp(r'Timezone=(\S+)')
            .firstMatch(result.stdout.toString())
            ?.group(1);
      }
    } catch (e) {
      _logger.warning('Failed to get system timezone: $e');
    }
    return null;
  }
}

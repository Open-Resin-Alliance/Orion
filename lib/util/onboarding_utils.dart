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
      // Map human-friendly timezone strings (e.g. "UTC-5 - Eastern Time")
      // into an IANA timezone name that timedatectl understands.
      final iana = _toIanaTimezone(timezone);
      if (iana == null) {
        _logger.severe('Failed to map timezone "$timezone" to IANA name');
        return;
      }
      _logger.config('Setting system timezone to $iana (from "$timezone")');
      final checkResult = await Process.run('sudo', ['-n', 'true']);
      if (checkResult.exitCode == 0) {
        final result = await Process.run(
          'sudo',
          ['timedatectl', 'set-timezone', iana],
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

  // Convert a human-readable timezone (as presented in UI countryData)
  // into an IANA timezone name suitable for timedatectl. Returns null when
  // no mapping can be made.
  static String? _toIanaTimezone(String tz) {
    if (tz.isEmpty) return null;
    // If it's already likely an IANA name, pass through
    if (tz.contains('/')) return tz;
    final parts = tz.split(' - ');
    final label = parts.length > 1 ? parts[1].trim().toLowerCase() : '';
    final offset = parts.first.trim().toUpperCase();

    // Common descriptive mappings
    final map = <String, String>{
      'coordinated universal time': 'UTC',
      'greenwich mean time': 'UTC',
      'eastern time': 'America/New_York',
      'eastern daylight time': 'America/New_York',
      'central time': 'America/Chicago',
      'central standard time': 'America/Chicago',
      'mountain time': 'America/Denver',
      'pacific time': 'America/Los_Angeles',
      'alaska time': 'America/Anchorage',
      'hawaii time': 'Pacific/Honolulu',
      'newfoundland time': 'America/St_Johns',
      'atlantic standard time': 'America/Halifax',
      'argentina time': 'America/Argentina/Buenos_Aires',
      'peru time': 'America/Lima',
      'colombia time': 'America/Bogota',
      'ecuador time': 'America/Guayaquil',
      'brazilia time': 'America/Sao_Paulo',
      'brazil time': 'America/Sao_Paulo',
      'china standard time': 'Asia/Shanghai',
      'japan standard time': 'Asia/Tokyo',
      'india standard time': 'Asia/Kolkata',
      'philippine time': 'Asia/Manila',
      'australian eastern standard time': 'Australia/Sydney',
      'chile standard time': 'America/Santiago',
      'kamchatka time': 'Asia/Kamchatka'
    };

    if (label.isNotEmpty && map.containsKey(label)) return map[label];

    // If label didn't map, try parsing offsets like UTC-5 or UTC+2:30
    final re = RegExp(r'^UTC([+-])(\d{1,2})(?::(\d{1,2}))?\$');
    final m = re.firstMatch(offset);
    if (m != null) {
      final sign = m.group(1); // + or -
      final hours = int.tryParse(m.group(2) ?? '0') ?? 0;
      // Use Etc/GMT naming (note inverse sign convention)
      // POSIX TZ 'Etc/GMT+X' corresponds to UTC-X, so we invert the sign
      final etcSign = (sign == '-') ? '+' : '-';
      return 'Etc/GMT${etcSign}${hours}';
    }

    // As a last resort, if offset equals 'UTC' or similar, return UTC
    if (offset == 'UTC' ||
        offset == 'UTC+0' ||
        offset == 'UTC+0 - COORDINATED UNIVERSAL TIME') return 'UTC';

    return null;
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

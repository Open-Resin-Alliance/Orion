/*
* Orion - Legacy WiFi Backend (iwlist + wpa_supplicant)
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

import 'dart:io';

import 'package:logging/logging.dart';

import 'wifi_backend.dart';

/// Legacy WiFi backend using iwlist for scanning and wpa_supplicant for connections.
/// This backend is designed for older systems without NetworkManager installed
/// and provides fallback support for systems where nmcli is unavailable.
///
/// Scanning: Uses `iwlist` to enumerate available WiFi networks
/// Connecting: Manages `/etc/wpa_supplicant/wpa_supplicant.conf` and controls
///             wpa_supplicant daemon
class LegacyWiFiBackend extends WiFiBackend {
  final Logger _log = Logger('LegacyWiFiBackend');
  final String _wifiInterface;
  final String _wpaConfigPath;

  // These will be provided by the WiFiProvider parent
  late Function(String?, int?, bool, String) updateState;
  late Function(String?) updateIp;
  late Function(String?) updateIfaceName;

  LegacyWiFiBackend({
    String wifiInterface = 'wlan0',
    String wpaConfigPath = '/etc/wpa_supplicant/wpa_supplicant.conf',
  })  : _wifiInterface = wifiInterface,
        _wpaConfigPath = wpaConfigPath;

  @override
  Future<void> fetchWiFiStatus() async {
    try {
      // Use iwconfig to check connection status
      final result = await Process.run('iwconfig', [_wifiInterface]);

      if (result.exitCode == 0) {
        final output = result.stdout.toString();
        final ssidMatch = RegExp(r'ESSID:"([^"]*)"').firstMatch(output);
        final signalMatch =
            RegExp(r'Signal level=(-?\d+)\s*dBm').firstMatch(output);

        if (ssidMatch != null && ssidMatch.group(1)!.isNotEmpty) {
          final ssid = ssidMatch.group(1);
          int? signal;
          if (signalMatch != null) {
            // Convert dBm to 0-100 scale: -30 dBm = 100%, -90 dBm = 0%
            final dbm = int.parse(signalMatch.group(1)!);
            signal = ((dbm + 90) * 100 ~/ 60).clamp(0, 100);
          }
          updateState(ssid, signal, true, 'wifi');
          await fetchIPAddress();
        } else {
          updateState(null, null, false, 'none');
        }
      } else {
        updateState(null, null, false, 'none');
      }
    } catch (e) {
      _log.fine('Error fetching WiFi status: $e');
      updateState(null, null, false, 'none');
    }

    // Check for Ethernet as fallback
    if (!await _isConnectedWiFi()) {
      await _checkEthernetConnection();
    }
  }

  Future<bool> _isConnectedWiFi() async {
    try {
      final result = await Process.run('iwconfig', [_wifiInterface]);
      if (result.exitCode == 0) {
        final output = result.stdout.toString();
        return !output.contains('ESSID:off') && !output.contains('ESSID:""');
      }
    } catch (_) {}
    return false;
  }

  Future<void> _checkEthernetConnection() async {
    try {
      final interfaces =
          await NetworkInterface.list(type: InternetAddressType.IPv4);

      for (final iface in interfaces) {
        // Skip loopback and the WiFi interface
        if (iface.name == 'lo' || iface.name == _wifiInterface) continue;

        // Check if interface is up and has an address
        if (iface.addresses.isNotEmpty) {
          updateState(null, null, true, 'ethernet');
          updateIfaceName(iface.name);
          updateIp(iface.addresses.first.address);
          await fetchNetworkDetails(iface.name);
          break;
        }
      }
    } catch (e) {
      _log.fine('Ethernet check failed: $e');
    }
  }

  Future<void> fetchIPAddress() async {
    try {
      final interfaces =
          await NetworkInterface.list(type: InternetAddressType.IPv4);

      for (final iface in interfaces) {
        if (iface.name == _wifiInterface && iface.addresses.isNotEmpty) {
          updateIfaceName(iface.name);
          updateIp(iface.addresses.first.address);
          await fetchNetworkDetails(iface.name);
          return;
        }
      }
    } catch (e) {
      _log.fine('Error fetching IP address: $e');
    }
  }

  @override
  Future<List<Map<String, String>>> scanNetworks() async {
    try {
      _log.info('Scanning WiFi networks with iwlist');
      final result = await Process.run('sudo', ['iwlist', _wifiInterface, 'scan']);

      if (result.exitCode == 0) {
        return _parseIwlistOutput(result.stdout.toString());
      } else {
        _log.severe('Failed to scan networks: ${result.stderr}');
        return [];
      }
    } catch (e, st) {
      _log.severe('Error scanning WiFi networks', e, st);
      return [];
    }
  }

  /// Parse iwlist scan output to extract SSID, signal strength, and security
  List<Map<String, String>> _parseIwlistOutput(String output) {
    final networks = <String, Map<String, String>>{};

    // Split by cell blocks
    final cells = output.split('Cell');
    for (int i = 1; i < cells.length; i++) {
      final cellContent = cells[i];
      final ssidMatch = RegExp(r'ESSID:"([^"]*)"').firstMatch(cellContent);
      final signalMatch = RegExp(r'Signal level[=:](-?\d+)').firstMatch(cellContent);
      final securityMatch = RegExp(r'(WPA|WEP|Open).*?(?:$|\n)')
          .firstMatch(cellContent);

      if (ssidMatch != null && ssidMatch.group(1)!.isNotEmpty) {
        final ssid = ssidMatch.group(1)!;
        int signal = 0;

        if (signalMatch != null) {
          final dbm = int.parse(signalMatch.group(1)!);
          // Convert dBm to 0-100 scale
          signal = ((dbm + 90) * 100 ~/ 60).clamp(0, 100);
        }

        final security = securityMatch?.group(0)?.trim() ?? '(Open)';

        // Keep highest signal strength for duplicate SSIDs
        if (!networks.containsKey(ssid) || 
            int.parse(networks[ssid]!['SIGNAL'] ?? '0') < signal) {
          networks[ssid] = {
            'SSID': ssid,
            'SIGNAL': signal.toString(),
            'SECURITY': security,
          };
        }
      }
    }

    return networks.values.toList();
  }

  @override
  Future<bool> connectToNetwork(String ssid, String password) async {
    try {
      _log.info('Connecting to WiFi network: $ssid (legacy mode)');

      // Generate wpa_supplicant network block using wpa_passphrase
      final passphraseResult = await Process.run(
        'wpa_passphrase',
        [ssid, password],
      );

      if (passphraseResult.exitCode != 0) {
        _log.warning('wpa_passphrase failed: ${passphraseResult.stderr}');
        return false;
      }

      final wpaConfig = passphraseResult.stdout.toString();

      // Append to wpa_supplicant config
      try {
        final configFile = File(_wpaConfigPath);
        if (!await configFile.exists()) {
          _log.warning('wpa_supplicant config not found at $_wpaConfigPath');
          return false;
        }

        // Read existing config and append new network block
        final existingConfig = await configFile.readAsString();
        final updatedConfig = existingConfig.trimRight() + '\n\n' + wpaConfig;
        
        // Write updated config using echo and tee with sudo
        final process = await Process.start('sudo', ['tee', _wpaConfigPath]);
        process.stdin.write(updatedConfig);
        await process.stdin.close();
        await process.exitCode;
      } catch (e) {
        _log.warning('Failed to update wpa_supplicant config: $e');
        return false;
      }

      // Restart wpa_supplicant to apply changes
      try {
        await Process.run('sudo', ['systemctl', 'restart', 'wpa_supplicant']);
        _log.info('Restarted wpa_supplicant service');
      } catch (e) {
        _log.warning('Failed to restart wpa_supplicant: $e');
        return false;
      }

      // Re-check status after a short delay
      await Future.delayed(Duration(seconds: 2));
      await fetchWiFiStatus();
      return true;
    } catch (e, st) {
      _log.warning('Failed to connect to WiFi network', e, st);
      return false;
    }
  }

  @override
  Future<bool> disconnect() async {
    try {
      _log.info('Disconnecting WiFi (legacy mode)');

      // Remove network configs from wpa_supplicant
      try {
        final configFile = File(_wpaConfigPath);
        if (await configFile.exists()) {
          // Keep only the header, remove network blocks
          final content = await configFile.readAsString();
          // Find where network blocks start
          final networkIndex = content.indexOf(RegExp(r'network=\{', multiLine: true));
          final header = networkIndex >= 0 ? content.substring(0, networkIndex) : '';

          final process = await Process.start('sudo', ['tee', _wpaConfigPath]);
          process.stdin.write(header);
          await process.stdin.close();
          await process.exitCode;
        }
      } catch (e) {
        _log.warning('Failed to clear wpa_supplicant config: $e');
      }

      // Restart wpa_supplicant
      await Process.run('sudo', ['systemctl', 'restart', 'wpa_supplicant']);

      updateState(null, null, false, 'none');
      return true;
    } catch (e, st) {
      _log.warning('Failed to disconnect WiFi', e, st);
      return false;
    }
  }

  @override
  Future<void> fetchNetworkDetails(String iface) async {
    // MAC address from sysfs
    try {
      final macFile = File('/sys/class/net/$iface/address');
      if (await macFile.exists()) {
        // This would update MAC in the WiFiProvider
      }
    } catch (e) {
      _log.fine('Failed reading MAC from sysfs: $e');
    }
  }
}

/*
* Orion - WiFi Provider
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

import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';

/// Provides comprehensive WiFi management including status, scanning, and connection.
class WiFiProvider with ChangeNotifier {
  final Logger _log = Logger('WiFiProvider');

  String? _currentSSID;
  int? _signalStrength; // 0-100 for Linux, negative dBm for macOS
  bool _isConnected = false;
  String _connectionType = 'none'; // 'wifi' | 'ethernet' | 'none'
  String _platform = 'unknown';
  String? _ipAddress;
  String? _ifaceName;
  String? _macAddress;
  String? _linkSpeed;
  List<Map<String, String>> _availableNetworks = [];
  bool _isConnecting = false;
  bool _isScanning = false;

  String? get currentSSID => _currentSSID;
  int? get signalStrength => _signalStrength;
  bool get isConnected => _isConnected;
  bool get isEthernet => _connectionType == 'ethernet';
  bool get isWiFi => _connectionType == 'wifi';
  String get connectionType => _connectionType;
  String get platform => _platform;
  String? get ipAddress => _ipAddress;
  String? get ifaceName => _ifaceName;
  String? get macAddress => _macAddress;
  String? get linkSpeed => _linkSpeed;
  List<Map<String, String>> get availableNetworks =>
      List.unmodifiable(_availableNetworks);
  bool get isConnecting => _isConnecting;
  bool get isScanning => _isScanning;

  Timer? _pollTimer;
  bool _disposed = false;
  static const Duration _pollInterval = Duration(seconds: 5);

  WiFiProvider({bool startPolling = true}) {
    _detectPlatform();
    if (startPolling) {
      _startPolling();
    }
  }

  void _detectPlatform() {
    if (Platform.isLinux) {
      _platform = 'linux';
    } else if (Platform.isMacOS) {
      _platform = 'macos';
    } else {
      _platform = 'other';
    }
  }

  void _startPolling() {
    if (_disposed) return;

    // Initial fetch
    _fetchWiFiStatus();

    // Set up periodic polling
    _pollTimer = Timer.periodic(_pollInterval, (_) {
      if (!_disposed) {
        _fetchWiFiStatus();
      }
    });
  }

  Future<void> _fetchWiFiStatus() async {
    if (_disposed) return;
    // Snapshot previous state so we only notify listeners when meaningful
    // values change. This reduces noisy notifications that cause UI flicker.
    final prevCurrentSSID = _currentSSID;
    final prevSignalStrength = _signalStrength;
    final prevIsConnected = _isConnected;
    final prevConnectionType = _connectionType;
    final prevIpAddress = _ipAddress;
    final prevIfaceName = _ifaceName;
    final prevMacAddress = _macAddress;
    final prevLinkSpeed = _linkSpeed;

    try {
      if (_platform == 'linux') {
        await _fetchLinuxWiFiStatus();
      } else if (_platform == 'macos') {
        await _fetchMacOSWiFiStatus();
      } else {
        // Not supported on other platforms
        _isConnected = false;
        _currentSSID = null;
        _signalStrength = null;
        _ipAddress = null;
        _connectionType = 'none';
      }

      // Determine if any of the observed fields changed
      final changed = (prevCurrentSSID != _currentSSID) ||
          (prevSignalStrength != _signalStrength) ||
          (prevIsConnected != _isConnected) ||
          (prevConnectionType != _connectionType) ||
          (prevIpAddress != _ipAddress) ||
          (prevIfaceName != _ifaceName) ||
          (prevMacAddress != _macAddress) ||
          (prevLinkSpeed != _linkSpeed);

      if (changed && !_disposed) notifyListeners();
    } catch (e, st) {
      _log.fine('Failed to fetch WiFi status', e, st);
      _isConnected = false;
      _currentSSID = null;
      _signalStrength = null;
      _ipAddress = null;
      _connectionType = 'none';

      final changed = (prevCurrentSSID != _currentSSID) ||
          (prevSignalStrength != _signalStrength) ||
          (prevIsConnected != _isConnected) ||
          (prevConnectionType != _connectionType) ||
          (prevIpAddress != _ipAddress) ||
          (prevIfaceName != _ifaceName) ||
          (prevMacAddress != _macAddress) ||
          (prevLinkSpeed != _linkSpeed);

      if (changed && !_disposed) notifyListeners();
    }
  }

  Future<void> _fetchLinuxWiFiStatus() async {
    try {
      // Get active connection
      final result = await Process.run(
        'nmcli',
        ['-t', '-f', 'active,ssid,signal', 'dev', 'wifi'],
      );

      if (result.exitCode == 0) {
        final lines = result.stdout.toString().split('\n');
        final activeLine = lines.firstWhere(
          (line) => line.startsWith('yes:'),
          orElse: () => '',
        );

        if (activeLine.isNotEmpty) {
          final parts = activeLine.split(':');
          if (parts.length >= 3) {
            _isConnected = true;
            _connectionType = 'wifi';
            _currentSSID = parts[1];
            _signalStrength = int.tryParse(parts[2]) ?? 0;
            await _fetchIPAddress();
          } else {
            _isConnected = false;
            _currentSSID = null;
            _signalStrength = null;
            _ipAddress = null;
          }
        } else {
          _isConnected = false;
          _currentSSID = null;
          _signalStrength = null;
          _ipAddress = null;
        }
      } else {
        _isConnected = false;
        _currentSSID = null;
        _signalStrength = null;
        _ipAddress = null;
      }
    } catch (e) {
      _log.fine('Error fetching Linux WiFi status: $e');
      _isConnected = false;
      _currentSSID = null;
      _signalStrength = null;
      _ipAddress = null;
    }

    // If not connected via WiFi, check for Ethernet connectivity (nmcli)
    if (!_isConnected) {
      try {
        // Ask nmcli for TYPE,STATE and DEVICE so we know which iface is connected
        final result = await Process.run(
          'nmcli',
          ['-t', '-f', 'TYPE,STATE,DEVICE', 'device'],
        );
        if (result.exitCode == 0) {
          final lines = result.stdout.toString().split('\n');
          for (final line in lines) {
            if (line.startsWith('ethernet:')) {
              final parts = line.split(':');
              // Expect TYPE:STATE:DEVICE
              if (parts.length >= 3 && parts[1] == 'connected') {
                final dev = parts[2];
                _isConnected = true;
                _connectionType = 'ethernet';
                _currentSSID = null;
                _signalStrength = null;

                // Record interface name and try to resolve its IP
                _ifaceName = dev;
                try {
                  final interfaces = await NetworkInterface.list(
                      type: InternetAddressType.IPv4);
                  NetworkInterface? matching;
                  for (final i in interfaces) {
                    if (i.name == dev) {
                      matching = i;
                      break;
                    }
                  }
                  // fallback to first interface if exact name not found
                  matching ??= interfaces.isNotEmpty ? interfaces.first : null;
                  if (matching != null && matching.addresses.isNotEmpty) {
                    _ipAddress = matching.addresses.first.address;
                  }
                } catch (e) {
                  _log.fine('Failed to resolve IP for $dev: $e');
                }

                // Populate MAC and link speed for this interface
                await _fetchNetworkDetails(dev);
                break;
              }
            }
          }
        }
      } catch (e) {
        // nmcli may not be available; leave as not connected
      }
    }
  }

  Future<void> _fetchMacOSWiFiStatus() async {
    // For macOS assume Ethernet is the active connection on developer machines
    _isConnected = true;
    _connectionType = 'ethernet';
    _currentSSID = null;
    _signalStrength = null;
    await _fetchIPAddress();
  }

  Future<void> _fetchIPAddress() async {
    try {
      final interfaces =
          await NetworkInterface.list(type: InternetAddressType.IPv4);
      if (interfaces.isNotEmpty) {
        final iface = interfaces.first;
        _ifaceName = iface.name;
        _ipAddress = iface.addresses.first.address;
        // Try to populate MAC and link speed from system tools
        await _fetchNetworkDetails(iface.name);
      } else {
        _ipAddress = null;
      }
    } catch (e) {
      _log.fine('Error fetching IP address: $e');
      _ipAddress = null;
    }
  }

  Future<void> _fetchNetworkDetails(String iface) async {
    _macAddress = null;
    _linkSpeed = null;

    try {
      if (_platform == 'linux') {
        // Try sysfs for MAC
        try {
          final macFile = File('/sys/class/net/$iface/address');
          if (await macFile.exists()) {
            _macAddress = (await macFile.readAsString()).trim();
          }
        } catch (e) {
          _log.fine('Failed reading MAC from sysfs: $e');
        }

        // Try sysfs for speed (works for many ethernet interfaces)
        try {
          final speedFile = File('/sys/class/net/$iface/speed');
          if (await speedFile.exists()) {
            final val = (await speedFile.readAsString()).trim();
            if (val.isNotEmpty) {
              _linkSpeed = '$val/$val';
            }
          }
        } catch (e) {
          _log.fine('Failed reading speed from sysfs: $e');
        }

        // Fallback: try nmcli device show
        if (_macAddress == null || _linkSpeed == null) {
          try {
            final res =
                await Process.run('nmcli', ['-t', 'device', 'show', iface]);
            if (res.exitCode == 0) {
              final out = res.stdout.toString().split('\n');
              for (final line in out) {
                if (line.trim().isEmpty) continue;
                final idx = line.indexOf(':');
                if (idx <= 0) continue;
                final key = line.substring(0, idx).trim();
                final val = line.substring(idx + 1).trim();

                if (_macAddress == null && key == 'GENERAL.HWADDR') {
                  _macAddress = val;
                } else if (_linkSpeed == null &&
                    (key == 'SPEED' || key == 'GENERAL.SPEED')) {
                  // nmcli may use SPEED or GENERAL.SPEED depending on version
                  final sp = val.replaceAll(RegExp(r'\s+'), '');
                  if (sp.isNotEmpty) _linkSpeed = '$sp/$sp';
                } else if (_ipAddress == null &&
                    key.startsWith('IP4.ADDRESS')) {
                  // val may include CIDR, keep the address with CIDR
                  _ipAddress = val;
                }
              }
            }
          } catch (e) {
            _log.fine('nmcli device show failed: $e');
          }
        }

        // If link speed still unknown, try ethtool as a final fallback (common on Linux)
        if (_linkSpeed == null && _platform == 'linux') {
          try {
            final eth = await Process.run('ethtool', [iface]);
            if (eth.exitCode == 0) {
              final lines = eth.stdout.toString().split('\n');
              for (final l in lines) {
                final m = RegExp(r'Speed:\s*(\d+)([A-Za-z/]+)?').firstMatch(l);
                if (m != null) {
                  final sp = m.group(1);
                  if (sp != null && sp.isNotEmpty) {
                    _linkSpeed = '$sp/$sp';
                    break;
                  }
                }
              }
            }
          } catch (e) {
            // ethtool may not be installed or allowed; ignore
          }
        }
      } else if (_platform == 'macos') {
        // macOS: use ifconfig to get ether and media lines
        try {
          final res = await Process.run('ifconfig', [iface]);
          if (res.exitCode == 0) {
            final out = res.stdout.toString().split('\n');
            for (final line in out) {
              final trimmed = line.trim();
              if (trimmed.startsWith('ether ') && _macAddress == null) {
                _macAddress = trimmed.split(' ').sublist(1).join(' ').trim();
              } else if (trimmed.startsWith('media:') && _linkSpeed == null) {
                // media: autoselect (1000baseT <full-duplex>)
                final m = RegExp(r"(\d+)base").firstMatch(trimmed);
                if (m != null) {
                  final sp = m.group(1);
                  if (sp != null) _linkSpeed = '$sp/$sp';
                }
              }
            }
          }
        } catch (e) {
          _log.fine('ifconfig failed: $e');
        }
      }
    } catch (e) {
      _log.fine('Failed to fetch network details for $iface: $e');
    }
  }

  /// Scan for available WiFi networks
  Future<List<Map<String, String>>> scanNetworks() async {
    if (_platform == 'other') {
      _log.warning('WiFi scanning not supported on this platform');
      return [];
    }

    _isScanning = true;
    notifyListeners();

    try {
      if (_platform == 'macos') {
        // Return mock networks for macOS (for development)
        final networks = List.generate(10, (i) {
          int rand = Random().nextInt(100);
          return {
            'SSID': 'Network $rand',
            'SIGNAL': '${-30 - i * 5}',
            'SECURITY': '(WPA2)'
          };
        });
        _availableNetworks = networks;
      } else if (_platform == 'linux') {
        await Process.run('sudo', ['nmcli', 'device', 'wifi', 'rescan']);
        _log.info('Rescanning Wi-Fi networks');
        final result = await Process.run('nmcli', ['device', 'wifi', 'list']);

        if (result.exitCode == 0) {
          final networks = <Map<String, String>>[];
          final lines = result.stdout.toString().split('\n');
          final pattern = RegExp(
            r"(?:(\*)\s+)?([0-9A-Fa-f:]{17})\s+(.*?)\s+(Infra)\s+(\d+)\s+([\d\sMbit/s]+)\s+(\d+)\s+([\w▂▄▆█_]+)\s+(.*)",
            multiLine: true,
          );

          for (int i = 2; i < lines.length; i++) {
            final match = pattern.firstMatch(lines[i]);
            if (match != null) {
              networks.add({
                'SSID': match.group(3) ?? '',
                'SIGNAL': match.group(7) ?? '',
                'SECURITY': match.group(9) ?? '',
              });
            }
          }

          // Sort: current network first, then by signal strength
          networks.sort((a, b) {
            if (a['SSID'] == _currentSSID) return -1;
            if (b['SSID'] == _currentSSID) return 1;
            return int.parse(b['SIGNAL'] ?? '0')
                .compareTo(int.parse(a['SIGNAL'] ?? '0'));
          });

          _availableNetworks = _mergeNetworks(networks);
        } else {
          _log.severe('Failed to get Wi-Fi networks: ${result.stderr}');
          _availableNetworks = [];
        }
      }
    } catch (e, st) {
      _log.severe('Error scanning WiFi networks', e, st);
      _availableNetworks = [];
    } finally {
      _isScanning = false;
      notifyListeners();
    }

    return _availableNetworks;
  }

  List<Map<String, String>> _mergeNetworks(List<Map<String, String>> networks) {
    final merged = <String, Map<String, String>>{};

    for (var network in networks) {
      final ssid = network['SSID'];
      if (ssid == null || ssid.isEmpty) continue;

      if (merged.containsKey(ssid)) {
        final existingSignal = int.parse(merged[ssid]!['SIGNAL']!);
        final newSignal = int.parse(network['SIGNAL']!);
        if (newSignal > existingSignal) {
          merged[ssid] = network;
        }
      } else {
        merged[ssid] = network;
      }
    }

    return merged.values.toList();
  }

  /// Connect to a WiFi network
  Future<bool> connectToNetwork(String ssid, String password) async {
    _isConnecting = true;
    notifyListeners();

    try {
      if (_platform == 'macos') {
        // Fake connection for macOS development
        await Future.delayed(const Duration(seconds: 2));
        _log.info('Fake connected to $ssid (macOS dev mode)');
        _currentSSID = ssid;
        _isConnected = true;
        _signalStrength = -45; // Good signal
        await _fetchIPAddress();
        await scanNetworks();
        return true;
      } else if (_platform == 'linux') {
        final result = await Process.run(
          'sudo',
          ['nmcli', 'dev', 'wifi', 'connect', ssid, 'password', password],
        );

        if (result.exitCode == 0) {
          _log.info('Connected to $ssid');
          _currentSSID = ssid;
          await _fetchWiFiStatus();
          await scanNetworks();
          return true;
        } else {
          _log.warning('Failed to connect to $ssid: ${result.stderr}');
          return false;
        }
      } else {
        _log.warning('WiFi connection not supported on this platform');
        return false;
      }
    } catch (e, st) {
      _log.warning('Failed to connect to WiFi network', e, st);
      return false;
    } finally {
      _isConnecting = false;
      notifyListeners();
    }
  }

  /// Disconnect from current WiFi network
  Future<bool> disconnect() async {
    try {
      _log.info('Disconnecting Wi-Fi');

      if (_platform == 'macos') {
        // Fake disconnection for macOS development
        await Future.delayed(const Duration(seconds: 1));
        _currentSSID = null;
        _signalStrength = null;
        _isConnected = false;
        _ipAddress = null;
        _ifaceName = null;
        _macAddress = null;
        _linkSpeed = null;
        await scanNetworks();
        notifyListeners();
        _log.info('Fake disconnected (macOS dev mode)');
        return true;
      } else if (_platform == 'linux') {
        // If ethernet, disconnect the actual interface; otherwise disconnect WiFi
        final iface = _ifaceName ?? 'wlan0';
        final result = await Process.run(
          'sudo',
          ['nmcli', 'device', 'disconnect', iface],
        );

        if (result.exitCode == 0) {
          _currentSSID = null;
          _signalStrength = null;
          _isConnected = false;
          _ipAddress = null;
          _ifaceName = null;
          _macAddress = null;
          _linkSpeed = null;
          await scanNetworks();
          notifyListeners();
          return true;
        } else {
          _log.warning('Failed to disconnect: ${result.stderr}');
          return false;
        }
      } else {
        _log.warning('WiFi disconnection not supported on this platform');
        return false;
      }
    } catch (e, st) {
      _log.warning('Failed to disconnect Wi-Fi', e, st);
      return false;
    }
  }

  /// Get signal strength quality label
  String getSignalQuality(int? signal) {
    if (signal == null) return 'Unknown';

    if (_platform == 'linux') {
      // Linux uses 0-100 percentage
      if (signal >= 80) return 'Excellent';
      if (signal >= 60) return 'Good';
      if (signal >= 40) return 'Fair';
      return 'Poor';
    } else {
      // macOS uses negative dBm
      if (signal >= -50) return 'Excellent';
      if (signal >= -60) return 'Good';
      if (signal >= -70) return 'Fair';
      return 'Poor';
    }
  }

  /// Manually refresh WiFi status
  Future<void> refresh() async {
    await _fetchWiFiStatus();
  }

  @override
  void dispose() {
    _disposed = true;
    _pollTimer?.cancel();
    super.dispose();
  }
}

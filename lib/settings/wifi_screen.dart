/*
* Orion - WiFi Screen
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

// ignore_for_file: avoid_print, use_build_context_synchronously, library_private_types_in_public_api, unused_field

import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:logging/logging.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'package:orion/util/orion_kb/orion_keyboard_expander.dart';
import 'package:orion/util/orion_kb/orion_textfield_spawn.dart';

class WifiScreen extends StatefulWidget {
  const WifiScreen({super.key, required this.isConnected});

  final ValueNotifier<bool> isConnected;

  @override
  WifiScreenState createState() => WifiScreenState();
}

class WifiScreenState extends State<WifiScreen> {
  List<String> wifiNetworks = [];
  String? currentWifiSSID;
  Future<List<Map<String, String>>>? _networksFuture;

  final Color _standardColor = Colors.white.withValues(alpha: 0.0);
  final Logger _logger = Logger('WifiScreen');
  final ValueNotifier<bool> _isConnecting = ValueNotifier(false);

  late String platform;
  bool _connectionFailed = false;

  final GlobalKey<SpawnOrionTextFieldState> wifiPasswordKey =
      GlobalKey<SpawnOrionTextFieldState>();

  @override
  void initState() {
    super.initState();
    if (!Platform.isLinux) {
      if (kDebugMode) currentWifiSSID = 'Local Network (Debug)';
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _networksFuture = _getWifiNetworks();
  }

  Future<String> getIPAddress() async {
    try {
      final List<NetworkInterface> networkInterfaces =
          await NetworkInterface.list(type: InternetAddressType.IPv4);
      if (networkInterfaces.isNotEmpty) {
        final ipAddress = networkInterfaces.first.addresses.first.address;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          widget.isConnected.value = true; // Set isConnected to true
        });
        _logger.info('SSID: $currentWifiSSID');
        _logger.info('IP Address: $ipAddress');
        return ipAddress;
      } else {
        throw Exception('No network interfaces found.');
      }
    } on PlatformException catch (e) {
      _logger.warning('Failed to get IP Address: $e');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.isConnected.value = false; // Set isConnected to false
      });
      return 'Failed to get IP Address';
    }
  }

  Future<void> disconnect() async {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        widget.isConnected.value = false;
      }
    });
    try {
      _logger.info('Disconnecting Wi-Fi');
      await Process.run(
          'sudo', ['nmcli', 'dev', 'disconnect', 'iface', 'wlan0']);
      setState(() {
        currentWifiSSID = null;
        _networksFuture = _getWifiNetworks(alreadyConnected: true);
      });
    } catch (e) {
      _logger.warning('Failed to disconnect Wi-Fi: $e');
    }
  }

  Icon getSignalStrengthIcon(dynamic signalStrengthReceived, String platform) {
    int signalStrength;

    try {
      signalStrength = int.parse(signalStrengthReceived);
    } catch (e) {
      _logger.warning(e);
      return const Icon(Icons.warning_rounded);
    }

    final Map<int, Icon> icons = platform == 'linux'
        ? {
            100: Icon(Icons.network_wifi_rounded,
                color: Colors.green[300], size: 30),
            80: Icon(Icons.network_wifi_rounded,
                color: Colors.green[300], size: 30),
            60: Icon(Icons.network_wifi_3_bar_rounded,
                color: Colors.green[300], size: 30),
            40: Icon(Icons.network_wifi_2_bar_rounded,
                color: Colors.orange[300], size: 30),
            20: Icon(Icons.network_wifi_1_bar_rounded,
                color: Colors.orange[300], size: 30),
            0: Icon(Icons.warning_rounded, color: Colors.red[300], size: 30),
          }
        : {
            10: Icon(Icons.network_wifi_rounded,
                color: Colors.green[300], size: 30),
            0: Icon(Icons.network_wifi_rounded,
                color: Colors.green[300], size: 30),
            -50: Icon(Icons.network_wifi_3_bar_rounded,
                color: Colors.green[300], size: 30),
            -70: Icon(Icons.network_wifi_2_bar_rounded,
                color: Colors.orange[300], size: 30),
            -90: Icon(Icons.warning_rounded, color: Colors.red[300], size: 30),
          };

    for (var threshold in icons.keys.toList().reversed) {
      if (signalStrength <= threshold) {
        return icons[threshold]!;
      }
    }

    return const Icon(Icons.warning_rounded);
  }

  Future<List<Map<String, String>>> _getWifiNetworks(
      {bool alreadyConnected = false}) async {
    wifiNetworks.clear();
    try {
      ProcessResult? result;
      platform = Theme.of(context).platform == TargetPlatform.macOS
          ? 'macos'
          : 'linux';

      if (platform == 'macos') {
        final List<Map<String, String>> networks = List.generate(10, (i) {
          int rand = Random().nextInt(100);
          return {
            'SSID': 'Network $rand',
            'SIGNAL': '${-30 - i * 5}',
            'BSSID': '00:0a:95:9d:68:1$i',
            'RSSI': '${-30 - i * 5}',
            'CHANNEL': '${1 + i}',
            'HT': 'Y',
            'CC': 'US',
            'SECURITY': '(WPA2)'
          };
        });
        return networks;
      } else if (platform == 'linux') {
        await Process.run('sudo', ['nmcli', 'device', 'wifi', 'rescan']);
        _logger.info('Rescanning Wi-Fi networks');
        result = await Process.run('nmcli', ['device', 'wifi', 'list']);
        try {
          var result = await Process.run(
              'nmcli', ['-t', '-f', 'active,ssid', 'dev', 'wifi']);
          var activeNetworkLine = result.stdout
              .toString()
              .split('\n')
              .firstWhere((line) => line.startsWith('yes:'), orElse: () => '');
          var activeNetworkSSID = activeNetworkLine.split(':')[1];
          if (!alreadyConnected) currentWifiSSID = activeNetworkSSID;
          _logger.info(activeNetworkSSID);
        } catch (e) {
          _logger.severe('Failed to get current Wi-Fi network: $e');
          setState(() {});
        }
        _logger.info('Getting Wi-Fi networks');
      }

      if (result?.exitCode == 0) {
        final List<Map<String, String>> networks = [];
        final List<String> lines = result!.stdout.toString().split('\n');
        RegExp pattern = platform == 'macos'
            ? RegExp(
                r'^\s*(.+?)\s{2,}(.+?)\s{2,}([^]+?)\s{2,}([^]+?)\s{2,}([^]+)$')
            : RegExp(
                r"(?:(\*)\s+)?([0-9A-Fa-f:]{17})\s+(.*?)\s+(Infra)\s+(\d+)\s+([\d\sMbit/s]+)\s+(\d+)\s+([\w▂▄▆█_]+)\s+(.*)",
                multiLine: true);

        for (int i = 2; i < lines.length; i++) {
          final RegExpMatch? match = pattern.firstMatch(lines[i]);
          if (match != null) {
            networks.add({
              'SSID': platform == 'macos'
                  ? match.group(1) ?? ''
                  : match.group(3) ?? '',
              'SIGNAL': platform == 'macos'
                  ? match.group(2) ?? ''
                  : match.group(7) ?? '',
              'SECURITY': platform == 'macos'
                  ? match.group(8) ?? ''
                  : match.group(9) ?? '',
            });
          }
        }

        networks.sort((a, b) {
          if (a['SSID'] == currentWifiSSID) return -1;
          if (b['SSID'] == currentWifiSSID) return 1;
          return int.parse(b['SIGNAL'] ?? '0')
              .compareTo(int.parse(a['SIGNAL'] ?? '0'));
        });
        return mergeNetworks(networks);
      } else {
        _logger.severe('Failed to get Wi-Fi networks: ${result?.stderr}');
        return [];
      }
    } catch (e) {
      _logger.severe('Error: $e');
      return [];
    }
  }

  void connectToNetwork(String ssid, String password) async {
    _isConnecting.value = true; // Start of connection attempt
    try {
      final result = await Process.run(
        'sudo',
        ['nmcli', 'dev', 'wifi', 'connect', ssid, 'password', password],
      );
      if (result.exitCode == 0) {
        setState(() {
          currentWifiSSID = ssid;
          _networksFuture = _getWifiNetworks(alreadyConnected: true);
        });
        _logger.info('Connected to $ssid');
        Navigator.of(context).pop();
      } else {
        _logger.warning('Failed to connect to $ssid');
        _connectionFailed = true;
      }
    } catch (e) {
      _logger.warning('Failed to connect to Wi-Fi network: $e');
      _connectionFailed = true;
    } finally {
      _isConnecting.value = false; // End of connection attempt
    }
  }

  List<Map<String, String>> mergeNetworks(List<Map<String, String>> networks) {
    var mergedNetworks = <String, Map<String, String>>{};

    for (var network in networks) {
      var ssid = network['SSID'];
      if (ssid == null) continue;

      if (mergedNetworks.containsKey(ssid)) {
        var existingNetwork = mergedNetworks[ssid]!;
        var existingSignalStrength = int.parse(existingNetwork['SIGNAL']!);
        var newSignalStrength = int.parse(network['SIGNAL']!);
        if (newSignalStrength > existingSignalStrength) {
          mergedNetworks[ssid] = network;
        }
      } else {
        mergedNetworks[ssid] = network;
      }
    }

    return mergedNetworks.values.toList();
  }

  String signalStrengthToQuality(int signalStrength) {
    if (signalStrength >= -50) {
      return 'Perfect';
    } else if (signalStrength >= -60) {
      return 'Good';
    } else if (signalStrength >= -70) {
      return 'Fair';
    } else {
      return 'Weak';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<List<Map<String, String>>>(
        future: _networksFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (!Platform.isLinux && !kDebugMode) {
            return const Center(
              child: Text(
                'Sorry, this feature is only available on Linux',
                style: TextStyle(
                  fontSize: 24,
                ),
              ),
            );
          } else {
            final List<Map<String, String>> networks = snapshot.data ?? [];
            final String currentSSID = currentWifiSSID ?? '';
            if (currentSSID.isNotEmpty) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  widget.isConnected.value = true;
                }
              });
              return FutureBuilder<String>(
                future: getIPAddress(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  } else if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  } else {
                    final String ipAddress = snapshot.data ?? '';
                    bool isLandscape = MediaQuery.of(context).orientation ==
                        Orientation.landscape;
                    return Center(
                      child: SingleChildScrollView(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: isLandscape
                              ? buildLandscapeLayout(
                                  context, currentSSID, ipAddress, networks)
                              : buildPortraitLayout(
                                  context, currentSSID, ipAddress, networks),
                        ),
                      ),
                    );
                  }
                },
              );
            } else {
              widget.isConnected.value = false;
              return RefreshIndicator(
                onRefresh: () async {
                  setState(() {
                    _networksFuture = _getWifiNetworks();
                  });
                },
                child: ListView.builder(
                  itemCount: networks.length,
                  itemBuilder: (context, index) {
                    final network = networks[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Card.outlined(
                        elevation: 1,
                        child: ListTile(
                          key: ValueKey(network['SSID']),
                          title: Text(network['SSID'] ?? '',
                              style: const TextStyle(fontSize: 22)),
                          subtitle: Text(
                              'Signal Strength: ${network['SIGNAL']} dBm',
                              style: const TextStyle(fontSize: 18)),
                          trailing: getSignalStrengthIcon(
                              network['SIGNAL'], Platform.operatingSystem),
                          onTap: () {
                            showDialog(
                              barrierDismissible: false,
                              context: context,
                              builder: (BuildContext context) {
                                return AlertDialog(
                                  title: Center(
                                      child: Text(
                                          'Connect to ${network['SSID']}')),
                                  content: SizedBox(
                                    width:
                                        MediaQuery.of(context).size.width * 0.5,
                                    child: ValueListenableBuilder<bool>(
                                      valueListenable: _isConnecting,
                                      builder: (context, isConnecting, child) {
                                        return Stack(
                                          alignment: Alignment.center,
                                          children: [
                                            Opacity(
                                              opacity: isConnecting ? 0.0 : 1.0,
                                              child: SingleChildScrollView(
                                                child: Column(
                                                  children: [
                                                    SpawnOrionTextField(
                                                      key: wifiPasswordKey,
                                                      keyboardHint:
                                                          'Enter Password',
                                                      locale: Localizations
                                                              .localeOf(context)
                                                          .toString(),
                                                    ),
                                                    if (_connectionFailed)
                                                      const SizedBox(
                                                          height: 20),
                                                    if (_connectionFailed)
                                                      const Text(
                                                        'Connection failed. Please try again.',
                                                        style: TextStyle(
                                                            color: Colors.red,
                                                            fontSize: 20),
                                                      ),
                                                    OrionKbExpander(
                                                        textFieldKey:
                                                            wifiPasswordKey),
                                                  ],
                                                ),
                                              ),
                                            ),
                                            IgnorePointer(
                                              child: Opacity(
                                                opacity:
                                                    isConnecting ? 1.0 : 0.0,
                                                child: const SizedBox(
                                                  height: 60,
                                                  width: 60,
                                                  child:
                                                      CircularProgressIndicator(),
                                                ),
                                              ),
                                            ),
                                          ],
                                        );
                                      },
                                    ),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () {
                                        Navigator.of(context).pop();
                                        setState(() {
                                          _isConnecting.value = false;
                                          _connectionFailed = false;
                                        });
                                      },
                                      child: const Text('Close',
                                          style: TextStyle(fontSize: 20)),
                                    ),
                                    TextButton(
                                      onPressed: () {
                                        if (!_isConnecting.value) {
                                          _isConnecting.value = true;
                                          if (Theme.of(context).platform ==
                                              TargetPlatform.linux) {
                                            connectToNetwork(
                                                network['SSID']!,
                                                wifiPasswordKey.currentState!
                                                    .getCurrentText());
                                          } else {
                                            Future.delayed(
                                                const Duration(seconds: 3), () {
                                              Navigator.of(context).pop();
                                              _isConnecting.value = false;
                                            });
                                          }
                                        }
                                      },
                                      child: const Text('Confirm',
                                          style: TextStyle(fontSize: 20)),
                                    ),
                                  ],
                                );
                              },
                            );
                          },
                        ),
                      ),
                    );
                  },
                ),
              );
            }
          }
        },
      ),
    );
  }

  Widget buildPortraitLayout(BuildContext context, String currentSSID,
      String ipAddress, List<Map<String, String>> networks) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        buildNameCard('Connected to WiFi'),
        buildInfoCard('Network Name', currentSSID),
        buildInfoCard('IP Address', ipAddress),
        buildInfoCard(
          'Signal Strength',
          '${signalStrengthToQuality(int.parse(networks.first['SIGNAL']!))} [${networks.first['SIGNAL']}]',
        ),
        const SizedBox(height: 16),
        buildQrView(context, ipAddress),
      ],
    );
  }

  Widget buildLandscapeLayout(BuildContext context, String currentSSID,
      String ipAddress, List<Map<String, String>> networks) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              buildNameCard('Connected to WiFi'),
              buildInfoCard('Network Name', currentSSID),
              buildInfoCard('IP Address', ipAddress),
              buildInfoCard(
                'Signal Strength',
                '${signalStrengthToQuality(int.parse(networks.first['SIGNAL']!))} [${networks.first['SIGNAL']}]',
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        buildQrView(context, ipAddress),
      ],
    );
  }

  Widget buildNameCard(String title) {
    return Card.outlined(
      elevation: 1.0,
      child: ListTile(
        title: Text(
          title,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      ),
    );
  }

  Widget buildInfoCard(String title, String subtitle) {
    return Card.outlined(
      elevation: 1.0,
      child: ListTile(
        title: Text(title),
        subtitle: Text(subtitle),
      ),
    );
  }

  Widget buildQrView(BuildContext context, String ipAddress) {
    return Center(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Card.outlined(
          elevation: 1.0,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: QrImageView(
              data: 'http://$ipAddress',
              version: QrVersions.auto,
              size: 250,
              eyeStyle: QrEyeStyle(
                color: Theme.of(context).colorScheme.onSurface,
              ),
              dataModuleStyle: QrDataModuleStyle(
                color: Theme.of(context).colorScheme.onSurface,
                dataModuleShape: QrDataModuleShape.circle,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/*
* Orion - WiFi Backend Interface
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

/// Abstract interface for WiFi backend implementations (modern nmcli-based, legacy iwlist-based, etc.)
abstract class WiFiBackend {
  /// Check current WiFi connection status and update provider state
  Future<void> fetchWiFiStatus();

  /// Scan for available WiFi networks
  Future<List<Map<String, String>>> scanNetworks();

  /// Connect to a WiFi network
  Future<bool> connectToNetwork(String ssid, String password);

  /// Disconnect from current WiFi network
  Future<bool> disconnect();

  /// Get network details (MAC, speed, etc) for the given interface
  Future<void> fetchNetworkDetails(String iface);
}

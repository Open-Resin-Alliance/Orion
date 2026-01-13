/*
* Orion - Athena Update Provider
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

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';
import 'package:orion/backend_service/athena_iot/athena_iot_client.dart';
import 'package:orion/util/orion_config.dart';

class AthenaUpdateProvider extends ChangeNotifier {
  final Logger _log = Logger('AthenaUpdateProvider');

  bool isChecking = false;
  bool updateAvailable = false;
  String latestVersion = '';
  String currentVersion = '';
  String channel = 'stable';
  String printerType = '';

  AthenaUpdateProvider() {
    _loadPersistedState();
  }

  void _loadPersistedState() {
    final cfg = OrionConfig();
    if (cfg.getFlag('available', category: 'updates')) {
      final current = cfg.getString('athena.current', category: 'updates');
      final latest = cfg.getString('athena.latest', category: 'updates');
      final ch = cfg.getString('athena.channel', category: 'updates');

      if (current.isNotEmpty && latest.isNotEmpty) {
        currentVersion = current;
        latestVersion = latest;
        channel = ch.isNotEmpty ? ch : 'stable';
        updateAvailable = true;
        notifyListeners();
      }
    }
  }

  /// Check for updates using the Athena printer_data payload.
  ///
  /// This will call the configured olymp endpoint and set [updateAvailable]
  /// and [latestVersion] appropriately.
  Future<void> checkForUpdates(
      {String olympBase = 'https://olymp.concepts3d.eu'}) async {
    isChecking = true;
    notifyListeners();

    try {
      final cfg = OrionConfig();
      // Determine Athena IoT base URL. Prefer explicit nanodlp.base_url, but
      // fall back to the customUrl if useCustomUrl is set (mirrors
      // NanoDlpHttpClient/AthenaFeatureManager resolution logic).
      final base = cfg.getString('nanodlp.base_url', category: 'advanced');
      final useCustom = cfg.getFlag('useCustomUrl', category: 'advanced');
      final custom = cfg.getString('customUrl', category: 'advanced');
      final athenaBase = base.isNotEmpty
          ? base
          : (useCustom && custom.isNotEmpty ? custom : 'http://localhost');
      final athena = AthenaIotClient(athenaBase);

      final pd = await athena.getPrinterDataModel();
      if (pd == null) {
        _log.info('No Athena printer_data available');
        // Do not clear state on temporary failure to talk to local service
        isChecking = false;
        notifyListeners();
        return;
      }

      channel = pd.updateChannel?.trim().isNotEmpty == true
          ? pd.updateChannel!.trim()
          : 'stable';
      currentVersion = pd.softwareVersion ?? '';
      printerType = pd.machineType ?? '';

      // Build olymp URL
      final params = {
        'channel': channel,
        'printer_type': printerType,
        'current_version': currentVersion
      };
      final uri = Uri.parse('$olympBase/api/latestversion')
          .replace(queryParameters: params);
      _log.fine('Querying AthenaOS latest version: $uri');

      final resp = await http.get(uri);
      if (resp.statusCode != 200) {
        _log.warning('Olymp lookup failed: ${resp.statusCode} ${resp.body}');
        // Do not clear state on temporary network/server failure
        isChecking = false;
        notifyListeners();
        return;
      }

      final decoded = json.decode(resp.body);
      if (decoded is Map && decoded.containsKey('version')) {
        latestVersion = decoded['version']?.toString() ?? '';
      } else {
        latestVersion = '';
      }

      if (latestVersion.isEmpty || currentVersion.isEmpty) {
        updateAvailable = false;
      } else {
        updateAvailable = _isNewerVersion(latestVersion, currentVersion);
        if (channel != 'stable' && !updateAvailable) {
          _log.info(
              'No update available on $channel channel (Local: $currentVersion, Remote: $latestVersion)');
        }
      }
    } catch (e, st) {
      _log.warning('checkForUpdates failed', e, st);
      // Do not clear state on error; preserve persisted state
    } finally {
      isChecking = false;
      notifyListeners();
    }
  }

  bool _isNewerVersion(String latest, String current) {
    try {
      final lv = latest.split('+')[0];
      final cv = current.split('+')[0];
      final lp = lv.split('.').map((s) => int.tryParse(s) ?? 0).toList();
      final cp = cv.split('.').map((s) => int.tryParse(s) ?? 0).toList();
      final n = lp.length > cp.length ? lp.length : cp.length;
      for (var i = 0; i < n; i++) {
        final a = i < lp.length ? lp[i] : 0;
        final b = i < cp.length ? cp[i] : 0;
        if (a > b) return true;
        if (a < b) return false;
      }
      // Versions equal
      return false;
    } catch (_) {
      return false;
    }
  }
}

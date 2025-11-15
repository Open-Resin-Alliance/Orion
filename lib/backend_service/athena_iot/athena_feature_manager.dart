/*
* Orion - Athena IoT Feature Manager
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

import 'package:logging/logging.dart';
import 'package:orion/util/orion_config.dart';
import 'package:orion/backend_service/athena_iot/athena_iot_client.dart';

class AthenaFeatureManager {
  AthenaFeatureManager({OrionConfig? config})
      : _config = config ?? OrionConfig();

  final OrionConfig _config;
  final _log = Logger('AthenaFeatureManager');
  Timer? _periodic;

  String _resolveBaseUrl() {
    try {
      final base = _config.getString('nanodlp.base_url', category: 'advanced');
      final useCustom = _config.getFlag('useCustomUrl', category: 'advanced');
      final custom = _config.getString('customUrl', category: 'advanced');
      if (base.isNotEmpty) return base;
      if (useCustom && custom.isNotEmpty) return custom;
    } catch (_) {}
    return 'http://localhost';
  }

  Future<void> fetchAndApplyFeatureFlags() async {
    try {
      if (!_config.isNanoDlpMode()) return;
      final base = _resolveBaseUrl();
      final athena = AthenaIotClient(base);
      final flags = await athena.getFeatureFlagsModel();
      if (flags == null) {
        _log.fine('No Athena feature_flags present');
        return;
      }
      // Map Athena feature flags into the vendor.cfg shape so Orion's
      // `OrionConfig` helpers (getHardwareFeatures, getFeatureFlag, etc.)
      // see the expected keys. Athena fields are mapped into
      // featureFlags.hardwareFeatures. We also set vendor.vendorMachineName
      // when machineType is provided.
      final Map<String, dynamic> hw = {};
      if (flags.hasHeatedChamber != null) {
        hw['hasHeatedChamber'] = flags.hasHeatedChamber;
      }
      if (flags.hasHeatedVat != null) {
        hw['hasHeatedVat'] = flags.hasHeatedVat;
      }
      if (flags.hasCamera != null) {
        hw['hasCamera'] = flags.hasCamera;
      }
      if (flags.hasAirFilter != null) {
        hw['hasAirFilter'] = flags.hasAirFilter;
      }
      if (flags.hasForceSensor != null) {
        hw['hasForceSensor'] = flags.hasForceSensor;
      }
      // Additional hardware attributes exposed by Athena - include them
      // alongside the canonical hardwareFeatures map so callers can opt-in.
      if (flags.hasCameraFlash != null)
        hw['hasCameraFlash'] = flags.hasCameraFlash;
      if (flags.hasSmartpower != null)
        hw['hasSmartpower'] = flags.hasSmartpower;

      final Map<String, dynamic> featureFlags = {};
      if (hw.isNotEmpty) featureFlags['hardwareFeatures'] = hw;

      final Map<String, dynamic> overrides = {'featureFlags': featureFlags};

      // Persist the featureFlags into the main `orion.cfg` featureFlags
      // section. For the friendly machine name, set the canonical
      // `machine.machineName` value (trim newlines) so the UI shows a
      // normalized name without using vendor.*.
      // Persist feature flags into orion.cfg and vendor.machineModelName into
      // vendor_overrides.cfg so getMachineModelName() will pick it up.
      if (flags.machineType != null && flags.machineType!.isNotEmpty) {
        final trimmed = flags.machineType!.trim();
        overrides['vendor'] = {'machineModelName': trimmed};
        // Also persist into the canonical `machine` section so it's visible
        // in orion.cfg (user-visible) as machine.machineModelName.
        _config.setString('machineModelName', trimmed, category: 'machine');
      }
      _config.setVendorOverrides(overrides);
      _log.info('Applied Athena feature flags overrides from $base');
    } catch (e, st) {
      _log.fine('Failed to fetch/apply Athena feature flags', e, st);
    }
  }

  /// Run the initial check during onboarding.
  Future<void> runInitialCheck() async {
    await fetchAndApplyFeatureFlags();
  }

  /// Start periodic polling every [interval] (default 10 minutes)
  void startPeriodicPolling({Duration interval = const Duration(minutes: 10)}) {
    stopPeriodicPolling();
    _periodic = Timer.periodic(interval, (_) async {
      await fetchAndApplyFeatureFlags();
    });
  }

  void stopPeriodicPolling() {
    _periodic?.cancel();
    _periodic = null;
  }
}

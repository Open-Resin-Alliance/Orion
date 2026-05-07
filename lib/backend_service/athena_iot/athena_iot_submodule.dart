/*
* Orion - Athena IoT Submodule
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

import 'package:logging/logging.dart';
import 'package:orion/backend_service/athena_iot/athena_feature_manager.dart';
import 'package:orion/backend_service/backend_registry.dart';

/// Registry submodule for Athena IoT feature sync and periodic polling.
///
/// This submodule is attached to backends that support Athena integration,
/// and centralizes Athena lifecycle management under the backend registry
/// instead of ad-hoc initialization in app startup code.
class AthenaIotSubmodule implements BackendSubmodule {
  AthenaIotSubmodule({AthenaFeatureManager? manager})
      : _manager = manager ?? AthenaFeatureManager();

  final AthenaFeatureManager _manager;
  final _log = Logger('AthenaIotSubmodule');

  @override
  String get id => BackendSubmodules.athenaIot;

  @override
  String get displayName => 'Athena IoT';

  @override
  Future<void> initialize() async {
    try {
      await _manager.fetchAndApplyFeatureFlags();
      _manager.startPeriodicPolling();
      _log.info('Athena IoT submodule initialized');
    } catch (e, st) {
      _log.warning('Failed to initialize Athena IoT submodule', e, st);
    }
  }

  @override
  Future<void> dispose() async {
    try {
      _manager.stopPeriodicPolling();
      _log.info('Athena IoT submodule disposed');
    } catch (e, st) {
      _log.warning('Failed to dispose Athena IoT submodule', e, st);
    }
  }
}

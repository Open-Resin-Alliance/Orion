/*
* Orion - NanoDLP Finished Flow Test
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

import 'package:flutter_test/flutter_test.dart';
import 'package:orion/backend_service/nanodlp/models/nano_status.dart';
import 'package:orion/backend_service/nanodlp/helpers/nano_state_handler.dart';
import 'package:orion/backend_service/nanodlp/nanodlp_mappers.dart';
import 'package:orion/backend_service/odyssey/models/status_models.dart';

void main() {
  test('1->0 finish produces finished=true and mapped layer for green state',
      () {
    final h = NanoDlpStateHandler();
    h.reset();

    // Simulate transient printing state (1)
    var ns = NanoStatus(
      printing: true,
      paused: false,
      state: 'printing',
      stateCode: 1,
      layerId: 99,
      layersCount: 100,
    );
    var canonical = h.canonicalize(ns);
    expect(canonical['status'], equals('Printing'));

    // Now simulate finish transition 1 -> 0 with layersCount present
    ns = NanoStatus(
      printing: false,
      paused: false,
      state: 'idle',
      stateCode: 0,
      layerId: null,
      layersCount: 100,
    );
    canonical = h.canonicalize(ns);
    expect(canonical['status'], equals('Idle'));
    expect(canonical['finished'], true);

    final mapped = nanoStatusToOdysseyMap(ns);
    // Mapper should set finished and map a sensible layer
    expect(mapped['finished'], true);
    expect(mapped['layer'], isNotNull);

    final statusModel = StatusModel.fromJson(Map<String, dynamic>.from(mapped));
    // Model should show Idle with a layer -> not canceled
    expect(statusModel.isIdle, true);
    expect(statusModel.layer, isNotNull);
    expect(statusModel.isCanceled, false);
  });
}

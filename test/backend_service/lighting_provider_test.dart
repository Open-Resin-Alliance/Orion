/*
* Orion - Lighting Provider Test
* Copyright (C) 2026 Open Resin Alliance
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

import 'package:orion/backend_service/providers/lighting_provider.dart';
import 'package:orion/util/orion_config.dart';

import '../fakes/fake_odyssey_client.dart';

void main() {
  test('never touches the RGB LEDs while a print is active', () async {
    final config = OrionConfig();
    final before =
        config.getFlag('standbyLedDimmingEnabled', category: 'ui');
    config.setFlag('standbyLedDimmingEnabled', true, category: 'ui');
    addTearDown(
        () => config.setFlag('standbyLedDimmingEnabled', before, category: 'ui'));

    final backend = FakeBackendClient();
    final lighting = LightingProvider(client: backend, config: config);
    addTearDown(lighting.dispose);

    // The firmware owns the lighting during a job: no commands at all.
    lighting.setPrintActive(true);
    await lighting.applyStandbyProgress(0.5);
    await lighting.setFullBrightness();
    expect(backend.commands, isEmpty);

    // Once the job is over we may drive it again.
    lighting.setPrintActive(false);
    await lighting.setFullBrightness();
    expect(backend.commands, isNotEmpty);
  });
}

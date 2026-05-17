/*
* Orion - Nano Profile Denormalize Test
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

import 'package:test/test.dart';

import 'package:orion/backend_service/nanodlp/models/nano_profiles.dart';

void main() {
  test('denormalizeForBackend updates only supplied fields', () {
    final backend = NanoProfile.denormalizeForBackend(
      {'normal_cure_time': 2.75},
    );

    expect(backend, equals({'CureTime': 2.75}));
  });

  test('denormalizeForBackend maps all known normalized fields', () {
    final backend = NanoProfile.denormalizeForBackend({
      'burn_in_cure_time': 12.5,
      'normal_cure_time': 2.8,
      'lift_after_print': 6.0,
      'burn_in_count': 5,
      'wait_after_cure': 1.4,
      'wait_after_life': 1.8,
    });

    expect(
      backend,
      equals({
        'SupportCureTime': 12.5,
        'CureTime': 2.8,
        'TopDistance': 6.0,
        'WaitHeight': 6.0,
        'SupportLayerNumber': 5,
        'TopWait': 1.4,
        'WaitAfterPrint': 1.8,
      }),
    );
  });

  test('normalizeForEdit reads lift_after_print from TopDistance', () {
    final normalized = NanoProfile.normalizeForEdit({
      'TopDistance': 7.25,
    });

    expect(normalized['lift_after_print'], 7.25);
  });
}

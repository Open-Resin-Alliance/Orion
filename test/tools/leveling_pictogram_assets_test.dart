/*
* Orion - Leveling Pictogram Assets Test
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

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// The loosen/tighten pictograms are line art loaded by asset path. A missing
/// `pubspec.yaml` entry fails silently — `SvgPicture` just draws nothing — so
/// pin the paths here: the `assets/` directory entry does not reach into
/// `assets/images/concepts_3d/levelingsystem/standardarm/`.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('every leveling pictogram asset ships with the app', () async {
    const assets = [
      // Pro arm: top-view crop of the three leveling screws.
      'assets/images/concepts_3d/levelingsystem/'
          'a2_pro_arm_solo_leveling_screws_top.svg',
      // Standard arm: isometric plate art the callouts are drawn onto.
      'assets/images/concepts_3d/levelingsystem/standardarm/a2_standard.svg',
      // Standard arm: the hand holding the plate down while tightening.
      'assets/images/concepts_3d/levelingsystem/standardarm/'
          'a2_standard_hand_on_plate.svg',
    ];

    for (final asset in assets) {
      final data = await rootBundle.load(asset);
      expect(data.lengthInBytes, greaterThan(0), reason: '$asset is empty');
    }
  });
}

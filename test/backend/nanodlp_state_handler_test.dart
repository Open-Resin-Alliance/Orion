/*
* Orion - NanoDLP State Handler Test
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
import 'package:orion/backend_service/nanodlp/helpers/nano_state_handler.dart';
import 'package:orion/backend_service/nanodlp/models/nano_status.dart';

void main() {
  group('NanoDlpStateHandler', () {
    test('latches cancel and clears only on idle', () {
      final h = NanoDlpStateHandler();
      h.reset();

      // Observing state==4 should latch cancel
      var ns = NanoStatus(
          printing: false, paused: false, state: 'idle', stateCode: 4);
      var out = h.canonicalize(ns);
      expect(out['cancel_latched'], true);
      expect(out['status'], 'Canceling');

      // Transition to state 1 (starting) should keep latch
      ns = NanoStatus(
          printing: true, paused: false, state: 'printing', stateCode: 1);
      out = h.canonicalize(ns);
      expect(out['cancel_latched'], true);
      expect(out['status'], 'Canceling');

      // Now idle -> should report idle with cancel_latched true (remain latched)
      ns = NanoStatus(
          printing: false, paused: false, state: 'idle', stateCode: 0);
      out = h.canonicalize(ns);
      expect(out['status'], 'Idle');
      expect(out['cancel_latched'], true);

      // Subsequent idle should still show latch until a new print starts
      out = h.canonicalize(ns);
      expect(out['status'], 'Idle');
      expect(out['cancel_latched'], true);

      // New print (0 -> 1) should clear the latch
      ns = NanoStatus(
          printing: true, paused: false, state: 'printing', stateCode: 1);
      out = h.canonicalize(ns);
      expect(out['cancel_latched'], false);
    });

    test('new print clears previous cancel latch when coming from idle', () {
      final h = NanoDlpStateHandler();
      h.reset();

      // Simulate a previous cancel that completed (we'll set latch manually)
      // To simulate we first latch and then go to idle which clears it.
      var ns = NanoStatus(
          printing: false, paused: false, state: 'idle', stateCode: 4);
      var out = h.canonicalize(ns);
      expect(out['cancel_latched'], true);

      ns = NanoStatus(
          printing: false, paused: false, state: 'idle', stateCode: 0);
      out = h.canonicalize(ns);
      expect(out['cancel_latched'], true);

      // New print start (0 -> 1) should clear latch
      ns = NanoStatus(
          printing: true, paused: false, state: 'printing', stateCode: 1);
      out = h.canonicalize(ns);
      expect(out['cancel_latched'], false);
      expect(out['status'], 'Printing');
    });
  });
}

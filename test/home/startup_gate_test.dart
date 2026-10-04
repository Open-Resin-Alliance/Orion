/*
* Orion - Startup Gate Test
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

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:orion/home/startup_gate.dart';

void main() {
  test('a stalled update check cannot hold startup', () async {
    // The app used to sit on the splash screen until this future completed, and
    // an update request that never answers never completes.
    final started = DateTime.now();
    await awaitBounded(
      const Duration(milliseconds: 50),
      () => Completer<void>().future,
    );
    expect(DateTime.now().difference(started),
        lessThan(const Duration(seconds: 2)));
  });
}

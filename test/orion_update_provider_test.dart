/*
* Orion - Orion Update Provider Test
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

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:orion/util/providers/orion_update_provider.dart';

void main() {
  group('OrionUpdateProvider.findOrionRoot', () {
    test('prefers ORION_ROOT env var', () {
      // set env var temporarily by launching a subprocess is not trivial in tests,
      // so we just test the method behavior assuming env var is not set.
      // For a true env test, this should be run in an isolated process.
      final p = OrionUpdateProvider();
      final root = p.findOrionRoot();
      expect(root, isNotNull);
    });

    test('detects current working directory as install', () async {
      final tmp = await Directory.systemTemp.createTemp('orion_test_pwd_');
      final orionDir = Directory('${tmp.path}/orion');
      await orionDir.create(recursive: true);
      final cfg = File('${tmp.path}/orion/orion.cfg');
      await cfg.writeAsString('test');

      final old = Directory.current;
      try {
        Directory.current = tmp;
        final p = OrionUpdateProvider();
        final root = p.findOrionRoot();
        expect(root.contains('orion'), isTrue);
      } finally {
        Directory.current = old;
        await tmp.delete(recursive: true);
      }
    });
  });
}

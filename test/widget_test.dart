/*
* Orion - Widget Test
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

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orion/home/startup_gate.dart';

import 'package:orion/main.dart';
import 'package:provider/provider.dart';
import 'package:orion/util/providers/locale_provider.dart';
import 'package:orion/util/providers/theme_provider.dart';
import 'package:orion/backend_service/providers/status_provider.dart';
import 'fakes/fake_odyssey_client.dart';

// A lightweight test StatusProvider that reports the app as already
// connected so StartupGate will show the HomeScreen for widget tests.
class TestStatusProvider extends StatusProvider {
  TestStatusProvider() : super(client: FakeBackendClient());

  @override
  bool get hasEverConnected => true;
}

void main() {
  testWidgets('Counter increments smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => LocaleProvider()),
          ChangeNotifierProvider(create: (_) => ThemeProvider()),
          ChangeNotifierProvider<StatusProvider>(
              create: (_) => TestStatusProvider()),
        ],
        child: const OrionMainApp(),
      ),
    );

    // Verify the app boots and mounts the startup gate (smoke test).
    await tester.pumpAndSettle();
    expect(find.byType(StartupGate), findsOneWidget);
  });
}

/*
* Orion - Zoom Value Editor Dialog Test
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

import 'package:flutter/material.dart';
import 'package:flutter_i18n/flutter_i18n.dart';
import 'package:flutter_i18n/loaders/decoders/json_decode_strategy.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:orion/util/providers/theme_provider.dart';
import 'package:orion/widgets/zoom_value_editor_dialog.dart';

Future<void> _pumpFor(WidgetTester tester, [int ms = 1500]) async {
  for (var t = 0; t < ms; t += 250) {
    await tester.pump(const Duration(milliseconds: 250));
  }
}

void main() {
  Future<void> pumpEditor(WidgetTester tester, {required bool keep}) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final delegate = FlutterI18nDelegate(
      translationLoader: FileTranslationLoader(
        useCountryCode: false,
        fallbackFile: 'en',
        basePath: 'assets/i18n',
        decodeStrategies: [JsonDecodeStrategy()],
      ),
    );
    await delegate.load(const Locale('en'));

    final theme = ThemeProvider();
    await tester.pumpWidget(
      ChangeNotifierProvider<ThemeProvider>.value(
        value: theme,
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: [delegate],
          supportedLocales: const [Locale('en')],
          theme: theme.darkTheme,
          home: Scaffold(
            body: ZoomValueEditorDialog(
              title: 'Z Offset',
              currentValue: 0.25,
              min: -0.5,
              max: 1.0,
              suffix: 'mm',
              decimals: 3,
              step: 0.01,
              keepValueOnOpen: keep,
            ),
          ),
        ),
      ),
    );
    await _pumpFor(tester);
  }

  /// The dialog's big value readout: the RichText carrying the unit suffix.
  String readout(WidgetTester tester) {
    final texts = tester
        .widgetList<RichText>(find.byType(RichText))
        .map((w) => w.text.toPlainText())
        .where((t) => t.endsWith('mm'));
    return texts.first;
  }

  testWidgets('keeping the value shows it while editing', (tester) async {
    await pumpEditor(tester, keep: true);
    expect(readout(tester), '0.250mm');

    await tester.tap(find.byWidgetPredicate(
        (w) => w is RichText && w.text.toPlainText().endsWith('mm')));
    await _pumpFor(tester, 2000);

    // The numeric keyboard is open, but the readout still shows the value
    // rather than placeholder dashes.
    expect(readout(tester), '0.250mm');
  });

  testWidgets('by default the value clears to dashes', (tester) async {
    await pumpEditor(tester, keep: false);
    expect(readout(tester), '0.250mm');

    await tester.tap(find.byWidgetPredicate(
        (w) => w is RichText && w.text.toPlainText().endsWith('mm')));
    await _pumpFor(tester, 2000);

    final shown = readout(tester);
    expect(shown.contains('0'), isFalse);
    expect(shown.contains('−'), isTrue);
  });
}

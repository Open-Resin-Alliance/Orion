/*
* Orion - Post Calibration Overlay Test
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

import 'package:orion/glasser/glasser.dart';
import 'package:orion/materials/post_calibration_overlay.dart';
import 'package:orion/util/providers/theme_provider.dart';

Future<void> _pumpOverlay(WidgetTester tester) async {
  final delegate = FlutterI18nDelegate(
    translationLoader: FileTranslationLoader(
      useCountryCode: false,
      fallbackFile: 'en',
      basePath: 'assets/i18n',
      decodeStrategies: [JsonDecodeStrategy()],
    ),
  );
  await delegate.load(const Locale('en'));

  await tester.pumpWidget(
    MultiProvider(
      providers: [ChangeNotifierProvider(create: (_) => ThemeProvider())],
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: [delegate],
        supportedLocales: const [Locale('en')],
        home: PostCalibrationOverlay(
          calibrationModelName: 'RERF',
          startExposure: 1.0,
          exposureIncrement: 0.2,
          profileId: 5,
          calibrationModelId: 1,
          evaluationGuideUrl: 'https://example.org/guide',
          onComplete: () {},
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('evaluation guide card matches the QR card height',
      (tester) async {
    await _pumpOverlay(tester);

    // Guide on the left, QR on the right. The guide used to shrink to its
    // text, leaving it visibly shorter than the card beside it.
    final cards = find.byType(GlassCard);
    expect(cards, findsNWidgets(2));
    final guide = tester.getRect(cards.at(0));
    final qr = tester.getRect(cards.at(1));

    expect(guide.height, qr.height);
    expect(guide.top, qr.top);
    expect(guide.bottom, qr.bottom);

    // The header stays at the top of the card (whose box starts 4px above
    // the painted surface - GlassCard's own margin - plus the 20px padding).
    final header = tester.getRect(find.text('EVALUATION GUIDE'));
    expect(header.top, closeTo(guide.top + 4 + 20, 1.0));

    // ...and the body centres on the card as a whole, not on the space the
    // header leaves behind.
    final first = tester.getRect(find.textContaining('Use the evaluation'));
    final last = tester.getRect(find.textContaining('Read it before'));
    expect((first.top + last.bottom) / 2, closeTo(guide.center.dy, 4.0));
  });
}

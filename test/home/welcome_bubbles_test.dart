/*
* Orion - Welcome Bubbles Test
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
import 'package:flutter_test/flutter_test.dart';

import 'package:orion/home/onboarding/welcome_bubbles.dart';

WelcomeBubble bubble({
  required double x,
  required double y,
  double vx = 0,
  double vy = 0,
  String message = 'Resin printing',
}) =>
    WelcomeBubble(
      message: message,
      x: x,
      y: y,
      size: 24,
      velocityX: vx,
      velocityY: vy,
      baseSpeed: 20,
      textColor: Colors.black,
    );

void main() {
  const screen = Size(800, 600);

  test('a drifting bubble keeps its speed and stays on screen', () {
    final b = bubble(x: 400, y: 300, vx: 3, vy: 4);
    final others = [b];

    for (var frame = 0; frame < 600; frame++) {
      b.step(1 / 60, screen.width, screen.height, others);
    }

    expect(b.x, inInclusiveRange(0, screen.width - b.width));
    expect(b.y, inInclusiveRange(0, screen.height - b.height));
    // The minimum-speed nudge keeps it from settling.
    expect((b.velocityX).abs() + (b.velocityY).abs(), greaterThan(1));
  });

  test('a wall bounce reverses the axis and damps it', () {
    final b = bubble(x: 0, y: 300, vx: -60, vy: 0);
    final others = [b];

    b.step(1 / 60, screen.width, screen.height, others);

    expect(b.x, 0);
    expect(b.velocityX, greaterThan(0));
    expect(b.velocityX, lessThan(60));
  });

  test('two bubbles that overlap push each other apart', () {
    final a = bubble(x: 100, y: 100, vx: 0, vy: 0);
    final b = bubble(x: 105, y: 100, vx: 0, vy: 0);
    final others = [a, b];

    // Head-on: closing velocity makes them separate.
    a.velocityX = 10;
    b.velocityX = -10;
    a.step(1 / 60, screen.width, screen.height, others);

    expect(a.velocityX, lessThan(10));
    expect(b.velocityX, greaterThan(-10));
  });

  testWidgets('the exit fades every bubble out and completes',
      (WidgetTester tester) async {
    final bubbles = [
      bubble(x: 100, y: 100, vx: 3, vy: 3),
      bubble(x: 400, y: 300, vx: -3, vy: 2),
      bubble(x: 600, y: 500, vx: 2, vy: -3),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WelcomeBubblesView(bubbles: bubbles, lowGraphics: true),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 32));

    var completed = false;
    final state = tester.state<WelcomeBubblesViewState>(
      find.byType(WelcomeBubblesView),
    );
    unawaitedExit(state).then((_) => completed = true);

    for (var frame = 0; frame < 180 && !completed; frame++) {
      await tester.pump(const Duration(milliseconds: 16));
    }

    expect(completed, isTrue);
    expect(bubbles.every((b) => b.opacity == 0), isTrue);
  });
}

Future<void> unawaitedExit(WelcomeBubblesViewState state) => state.exit();

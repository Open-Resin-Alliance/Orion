/*
* Orion - Onboarding Screen - Welcome Bubbles
* Copyright (C) 2024 Open Resin Alliance
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
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' show PointMode;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// The font the bubbles use, and the family their widths are measured with.
/// Kept here so the model and the painter cannot disagree about either.
const String _bubbleFontFamily = 'AtkinsonHyperlegible';

/// A message bubble that drifts around the welcome screen and bounces off the
/// walls and its neighbours.
///
/// Everything about it is a plain number and [step] allocates nothing: this
/// runs once per frame on a printer's CPU, next to whatever else the shell is
/// doing, so the field is a handful of multiplications rather than a physics
/// engine. The text is laid out once, in [text], and reused for every frame.
class WelcomeBubble {
  WelcomeBubble({
    required this.message,
    required this.x,
    required this.y,
    required this.size,
    required this.velocityX,
    required this.velocityY,
    this.mass = 1.0,
    this.bounciness = 0.7,
    this.padding = 16,
    this.baseSpeed = 20.0,
    required Color textColor,
  }) : text = TextPainter(
          text: TextSpan(
            text: message,
            style: TextStyle(
              fontFamily: _bubbleFontFamily,
              fontFamilyFallback: const ['NotoSansCJK'],
              fontSize: size * 0.82,
              color: textColor,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout() {
    width = text.width + padding * 2;
    height = text.height + padding * 2;
  }

  final String message;

  /// Top-left corner, in logical pixels.
  double x;
  double y;

  double velocityX;
  double velocityY;

  /// Font size, which is also the pill's corner radius.
  final double size;

  final double mass;
  final double bounciness;
  final double padding;

  /// The speed the bubble is nudged back up to when it slows below it.
  final double baseSpeed;

  /// Fades to 0 during the exit sequence.
  double opacity = 1.0;

  /// Measured once; the painter reuses it instead of laying text out per frame.
  final TextPainter text;

  /// The pill's size, measured from the text.
  late final double width;
  late final double height;

  /// Trail points left behind during the exit, as global positions.
  final List<TrailPoint> trails = [];

  static const double _damping = 0.995;
  static const double _repulsion = 0.8;
  static const double _maxTrails = 8;

  void step(
    double dt,
    double screenWidth,
    double screenHeight,
    List<WelcomeBubble> others,
  ) {
    velocityX *= _damping;
    velocityY *= _damping;

    final speed = sqrt(velocityX * velocityX + velocityY * velocityY);
    if (speed > 0 && speed < baseSpeed) {
      final boost = (baseSpeed * 0.1) / speed;
      velocityX += velocityX * boost;
      velocityY += velocityY * boost;
    }

    x += velocityX * dt;
    y += velocityY * dt;

    // Neighbours only: a squared-distance test, no intermediate objects.
    for (var i = 0; i < others.length; i++) {
      final other = others[i];
      if (identical(other, this)) continue;
      final dx = (x + width / 2) - (other.x + other.width / 2);
      final dy = (y + height / 2) - (other.y + other.height / 2);
      final reach = (max(width, height) + max(other.width, other.height)) / 2;
      if (dx * dx + dy * dy >= reach * reach) continue;

      final distance = sqrt(dx * dx + dy * dy);
      if (distance == 0) continue;
      final nx = dx / distance;
      final ny = dy / distance;
      final along = (velocityX - other.velocityX) * nx +
          (velocityY - other.velocityY) * ny;
      if (along >= 0) continue;

      final impulse = -along * _repulsion;
      velocityX += nx * impulse / mass;
      velocityY += ny * impulse / mass;
      other.velocityX -= nx * impulse / other.mass;
      other.velocityY -= ny * impulse / other.mass;
    }

    if (x <= 0) {
      x = 0;
      velocityX = -velocityX * bounciness;
    } else if (x + width >= screenWidth) {
      x = screenWidth - width;
      velocityX = -velocityX * bounciness;
    }
    if (y <= 0) {
      y = 0;
      velocityY = -velocityY * bounciness;
    } else if (y + height >= screenHeight) {
      y = screenHeight - height;
      velocityY = -velocityY * bounciness;
    }

    for (var i = trails.length - 1; i >= 0; i--) {
      trails[i].life -= dt * 2.4;
      if (trails[i].life <= 0) trails.removeAt(i);
    }
  }

  void addTrail(double globalX, double globalY) {
    trails.insert(0, TrailPoint(globalX, globalY));
    if (trails.length > _maxTrails) trails.removeLast();
  }

  void pushFrom(double fromX, double fromY, double strength) {
    final dx = (x + width / 2) - fromX;
    final dy = (y + height / 2) - fromY;
    final distance = sqrt(dx * dx + dy * dy);
    if (distance == 0) return;
    velocityX += dx / distance * strength / mass;
    velocityY += dy / distance * strength / mass;
  }
}

class TrailPoint {
  TrailPoint(this.x, this.y);

  final double x;
  final double y;
  double life = 1.0;
}

/// The clock the painter reads while repainting, so a frame never has to
/// rebuild a widget to know what time it is.
class BubbleClock {
  double seconds = 0;
}

/// Draws the whole field in one pass: trails, then the bubbles.
///
/// One `CustomPaint` for every bubble means one layer, no widget rebuilds per
/// frame, and no per-bubble shadows or gradient widgets — which is what made
/// the old version heavy on a slow box.
class WelcomeBubblesPainter extends CustomPainter {
  WelcomeBubblesPainter({
    required this.bubbles,
    required this.clock,
    required this.primary,
    required this.secondary,
    required this.textColor,
    required this.lowGraphics,
    required Listenable repaint,
  }) : super(repaint: repaint);

  final List<WelcomeBubble> bubbles;
  final BubbleClock clock;
  final Color primary;
  final Color secondary;
  final Color textColor;

  /// Skips the trails and the drifting offset, leaving the plain drift.
  final bool lowGraphics;

  /// Outer first, so the nearer, darker copy lands on top.
  static const List<({double offsetY, double alpha})> _shadowPasses = [
    (offsetY: 9, alpha: 0.10),
    (offsetY: 4, alpha: 0.16),
  ];

  final Paint _fill = Paint();
  final Paint _trail = Paint();
  final Paint _halo = Paint();

  @override
  void paint(Canvas canvas, Size size) {
    final time = clock.seconds;

    for (var i = 0; i < bubbles.length; i++) {
      final bubble = bubbles[i];
      if (bubble.opacity <= 0) continue;

      _paintTrails(canvas, bubble);
      _paintBubble(canvas, bubble, time);
    }
  }

  void _paintTrails(Canvas canvas, WelcomeBubble bubble) {
    if (lowGraphics) return;
    for (var i = 0; i < bubble.trails.length; i++) {
      final trail = bubble.trails[i];
      final life = trail.life.clamp(0.0, 1.0);
      final radius = bubble.size * (0.14 + i * 0.03);
      // Three fading rings read as a soft dot without a gradient shader.
      for (var ring = 0; ring < 3; ring++) {
        _trail.color = primary.withValues(
          alpha: life * bubble.opacity * 0.22 * (1 - ring / 3),
        );
        canvas.drawCircle(
          Offset(trail.x, trail.y),
          radius * (1 + ring * 0.7),
          _trail,
        );
      }
    }
  }

  void _paintBubble(Canvas canvas, WelcomeBubble bubble, double time) {
    // The same gentle pulse, rotation and drift as before, derived from the
    // clock rather than from the system time.
    final phase = bubble.x * 0.01 + bubble.y * 0.007;
    final t = time + (bubble.x + bubble.y) * 0.001;
    final pulse = 1.0 + 0.035 * sin(2 * pi * t);
    final rotation = 0.03 * sin(2 * pi * (t * 0.6));

    var driftX = 0.0;
    var driftY = 0.0;
    if (!lowGraphics) {
      driftX = bubble.size * 0.014 * sin(2 * pi * (t * 0.18 + phase)) +
          bubble.size * 0.007 * sin(2 * pi * (t * 0.66 + phase * 1.3));
      driftY = bubble.size * 0.012 * cos(2 * pi * (t * 0.22 + phase * 0.9)) +
          bubble.size * 0.006 * cos(2 * pi * (t * 0.71 + phase * 1.1));
    }

    final width = bubble.width;
    final height = bubble.height;
    final radius = Radius.circular(bubble.size);
    final rect = Rect.fromLTWH(0, 0, width, height);

    canvas.save();
    canvas.translate(bubble.x + driftX + width / 2, bubble.y + driftY + height / 2);
    canvas.rotate(rotation);
    canvas.scale(pulse);
    canvas.translate(-width / 2, -height / 2);

    // A drop shadow under the pill rather than a glow around it: two dark,
    // offset copies read as a soft shadow without the blur (or the light halo
    // an inflated primary-tinted one produced on a dark background).
    for (final pass in _shadowPasses) {
      _halo.color = Colors.black.withValues(alpha: pass.alpha * bubble.opacity);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          rect.shift(Offset(0, pass.offsetY)),
          Radius.circular(bubble.size),
        ),
        _halo,
      );
    }

    _fill.shader = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        primary.withValues(alpha: 0.95 * bubble.opacity),
        secondary.withValues(alpha: 0.85 * bubble.opacity),
      ],
    ).createShader(rect);
    _fill.color = Colors.white;
    canvas.drawRRect(RRect.fromRectAndRadius(rect, radius), _fill);

    _fill.shader = null;
    _fill.color = Colors.white.withValues(alpha: 0.06 * bubble.opacity);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect.deflate(0.5), Radius.circular(bubble.size)),
      _fill..style = PaintingStyle.stroke..strokeWidth = 1.0,
    );
    _fill.style = PaintingStyle.fill;

    bubble.text.paint(
      canvas,
      Offset(bubble.padding, bubble.padding),
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(WelcomeBubblesPainter oldDelegate) =>
      oldDelegate.bubbles != bubbles ||
      oldDelegate.primary != primary ||
      oldDelegate.secondary != secondary;
}

/// The welcome screen's bubble field: one ticker stepping the physics and
/// repainting a single layer, with nothing rebuilt per frame.
class WelcomeBubblesView extends StatefulWidget {
  const WelcomeBubblesView({
    super.key,
    required this.bubbles,
    this.lowGraphics = false,
  });

  final List<WelcomeBubble> bubbles;
  final bool lowGraphics;

  @override
  State<WelcomeBubblesView> createState() => WelcomeBubblesViewState();
}

class WelcomeBubblesViewState extends State<WelcomeBubblesView>
    with SingleTickerProviderStateMixin {
  final BubbleClock _clock = BubbleClock();
  /// Ticks the painter's repaint without rebuilding anything.
  final ValueNotifier<int> _frame = ValueNotifier<int>(0);
  late final Ticker _ticker;
  Duration _lastTick = Duration.zero;

  /// The view's size, kept from build: the ticker must not reach back into the
  /// context every frame to ask how big it is.
  Size _size = Size.zero;

  /// Set while the exit sequence runs, so the ticker can drive it.
  Completer<void>? _exit;
  double _exitElapsed = 0;
  int _exitedCount = 0;
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick)..start();
  }

  void _onTick(Duration elapsed) {
    // Clamped so a stalled frame cannot teleport a bubble through a wall, but
    // generous enough that a slow device (10 fps) still moves at the right
    // speed: the physics is per second, not per frame.
    final dt = ((elapsed - _lastTick).inMicroseconds / 1e6).clamp(0.0, 0.1);
    _lastTick = elapsed;
    _clock.seconds = elapsed.inMicroseconds / 1e6;
    _frame.value++;

    if (_size.isEmpty) return;

    for (final bubble in widget.bubbles) {
      bubble.step(dt, _size.width, _size.height, widget.bubbles);
    }

    _stepExit(dt);
  }

  /// Pushes the bubbles outward, staggered, fading each one out. Completes when
  /// the last has gone — the screen waits on this before revealing the page.
  Future<void> exit() {
    _exit ??= Completer<void>();
    return _exit!.future;
  }

  void _stepExit(double dt) {
    if (_exit == null) return;
    _exitElapsed += dt;

    final centreX = _size.width / 2;
    final centreY = _size.height / 2;

    for (var i = 0; i < widget.bubbles.length; i++) {
      final bubble = widget.bubbles[i];
      if (_exitElapsed < i * 0.06) continue;

      // Pushed outward once, the moment its turn comes, then faded.
      if (bubble.opacity == 1.0) {
        bubble.pushFrom(centreX, centreY, 220.0 * (0.7 + _random.nextDouble() * 0.6));
        bubble.addTrail(centreX, centreY);
      }
      if (bubble.opacity > 0) {
        bubble.opacity = max(0, bubble.opacity - dt * 1.2);
        if (bubble.opacity == 0) _exitedCount++;
      }
    }

    if (_exitedCount >= widget.bubbles.length && !(_exit!.isCompleted)) {
      _exit!.complete();
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _frame.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    _size = MediaQuery.sizeOf(context);
    return CustomPaint(
      size: Size.infinite,
      painter: WelcomeBubblesPainter(
        bubbles: widget.bubbles,
        clock: _clock,
        primary: colors.primaryContainer,
        secondary: colors.secondaryContainer,
        textColor: colors.onPrimaryContainer,
        lowGraphics: widget.lowGraphics,
        repaint: _frame,
      ),
    );
  }
}

/// The welcome overlay: the dimmed gradient the reveal opens up, plus the faint
/// dot grid behind the bubbles.
///
/// One painter and one layer. The old version masked a full-screen child with a
/// ShaderMask — a saveLayer over the whole screen, rebuilt every frame — and
/// wrapped the dots in an Opacity, a second layer, re-rasterising a thousand
/// little circles while the hole opened. That is what made the reveal chug.
/// The same read is drawn straight here: a radial gradient that is transparent
/// where the hole is, one draw call, no layers, and the dots as a single
/// drawPoints over a cached point list.
class WelcomeRevealPainter extends CustomPainter {
  WelcomeRevealPainter({
    required this.progress,
    required this.tints,
    required this.dotColor,
    required Listenable repaint,
  }) : super(repaint: repaint);

  /// 0 = covered, 1 = fully revealed.
  final Animation<double> progress;

  /// The overlay colours, dark end first: glass themes dim their gradient, the
  /// others dim their own surface. One colour means a flat dim.
  final List<Color> tints;

  final Color dotColor;

  final Paint _paint = Paint();
  final Paint _dots = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeWidth = 4;

  Float32List? _points;
  Size _pointsFor = Size.zero;

  @override
  void paint(Canvas canvas, Size size) {
    final revealed = progress.value.clamp(0.0, 1.0);
    final rect = Offset.zero & size;

    // The overlay, transparent in the middle and the tint at the rim: the same
    // read as the old dstOut mask, drawn straight instead of through a layer.
    final maxRadius = sqrt(size.width * size.width + size.height * size.height);
    final radius = maxRadius * revealed;
    // Transparent up to half the radius, then the tints ramp out to the rim.
    final colors = <Color>[
      tints.first.withValues(alpha: 0),
      tints.first.withValues(alpha: 0),
    ];
    final stops = <double>[0.0, 0.5];
    for (var i = 0; i < tints.length; i++) {
      colors.add(tints[i]);
      stops.add(0.5 + 0.5 * (i + 1) / tints.length);
    }
    _paint.shader = RadialGradient(
      center: Alignment.center,
      radius: (radius / size.shortestSide * 2).clamp(0.0001, 10.0),
      colors: colors,
      stops: stops,
      tileMode: TileMode.clamp,
    ).createShader(rect);
    canvas.drawRect(rect, _paint);
    _paint.shader = null;

    // The dot grid, fading out with the overlay.
    final dotAlpha = (1.0 - revealed) * 0.1;
    if (dotAlpha > 0.004) {
      _dots.color = dotColor.withValues(alpha: dotAlpha);
      canvas.drawRawPoints(PointMode.points, _gridFor(size), _dots);
    }
  }

  /// Built once per size: a 30px grid of dots, as one point list.
  Float32List _gridFor(Size size) {
    if (_points != null && _pointsFor == size) return _points!;
    final count = (size.width / 30).ceil() * (size.height / 30).ceil();
    final points = Float32List(count * 2);
    var i = 0;
    for (var x = 0.0; x < size.width; x += 30) {
      for (var y = 0.0; y < size.height; y += 30) {
        points[i++] = x;
        points[i++] = y;
      }
    }
    _points = Float32List.sublistView(points, 0, i);
    _pointsFor = size;
    return _points!;
  }

  @override
  bool shouldRepaint(WelcomeRevealPainter oldDelegate) =>
      oldDelegate.tints != tints || oldDelegate.dotColor != dotColor;
}

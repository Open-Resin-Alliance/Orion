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

import 'package:flutter/material.dart';
import 'dart:math';

class WelcomeBubble {
  final String message;
  Offset position;
  final double size;
  Offset velocity;
  final double mass;
  final double bounciness;
  double padding;
  final double baseSpeed; // Minimum speed the bubble maintains
  final double repulsionForce = 0.8; // How strongly bubbles push apart
  // Trail points created by proximity interactions (global coordinates)
  final List<TrailPoint> proximityTrails = [];
  double get width => _calculateWidth();
  double get height => size * 2; // Account for padding and text size
  double opacity;

  WelcomeBubble({
    required this.message,
    required this.position,
    required this.size,
    this.velocity = const Offset(0, 0),
    this.mass = 1.0,
    this.bounciness = 0.7,
    this.padding = 16,
    this.baseSpeed = 20.0, // pixels per second
    this.opacity = 1.0, // Initialize opacity
  });

  double _calculateWidth() {
    // Improved text width calculation that accounts for CJK characters
    double baseWidth = 0;
    for (final int codeUnit in message.runes) {
      if (_isCJKCharacter(codeUnit)) {
        // CJK characters typically need ~1.5x the width of Latin characters
        baseWidth += size * 1.2;
      } else {
        baseWidth += size * 0.4;
      }
    }
    return baseWidth + (padding * 2);
  }

  bool _isCJKCharacter(int codeUnit) {
    // Unicode ranges for CJK characters
    return (codeUnit >= 0x4E00 &&
            codeUnit <= 0x9FFF) || // CJK Unified Ideographs
        (codeUnit >= 0x3040 && codeUnit <= 0x309F) || // Hiragana
        (codeUnit >= 0x30A0 && codeUnit <= 0x30FF) || // Katakana
        (codeUnit >= 0xAC00 && codeUnit <= 0xD7AF); // Korean Hangul
  }

  Rect get bounds => Rect.fromLTWH(
        position.dx,
        position.dy,
        width,
        height,
      );

  Circle get circularBounds => Circle(
        center: Offset(
          position.dx + width / 2,
          position.dy + height / 2,
        ),
        radius: max(width, height) / 2,
      );

  void update(Size screenSize, double deltaTime, List<WelcomeBubble> others) {
    // Apply damping with smoother transitions
    const damping = 0.995; // Slightly higher damping for smoother movement
    velocity = velocity.scale(damping, damping);

    // Maintain minimum velocity with smoother acceleration
    final speed = velocity.distance;
    if (speed < baseSpeed) {
      if (speed > 0) {
        final normalized = velocity.scale(1 / speed, 1 / speed);
        // Gradual acceleration instead of immediate speed change
        velocity += normalized.scale(baseSpeed * 0.1, baseSpeed * 0.1);
      }
    }

    // Optimize collision detection with spatial partitioning
    final nearbyBubbles = others.where((other) {
      if (other == this) return false;
      final distance = (other.position - position).distance;
      return distance <
          (circularBounds.radius + other.circularBounds.radius) * 2;
    }).toList();

    // Update position first
    final nextPosition = position + velocity.scale(deltaTime, deltaTime);
    position = nextPosition;

    // Then handle collisions with nearby bubbles only
    for (final other in nearbyBubbles) {
      if (_willCollide(other, position)) {
        _handleCollision(other);
      }
    }

    // Handle screen boundaries last
    _handleScreenCollision(screenSize);

    // Decay proximity trails
    if (proximityTrails.isNotEmpty) {
      final decay = 0.04; // per frame decay (approx 60fps)
      for (var t in proximityTrails) {
        t.life -= decay;
      }
      proximityTrails.removeWhere((t) => t.life <= 0);
    }
  }

  /// Add a global-position trail point for proximity visual effects.
  void addProximityTrail(Offset globalPosition) {
    proximityTrails.insert(0, TrailPoint(globalPosition, 1.0));
    if (proximityTrails.length > 14) proximityTrails.removeLast();
  }

  void _handleCollision(WelcomeBubble other) {
    final collisionNormal =
        (circularBounds.center - other.circularBounds.center).normalize();
    final relativeVelocity = velocity - other.velocity;
    final velocityAlongNormal = relativeVelocity.dot(collisionNormal);

    if (velocityAlongNormal < 0) {
      final impulse = collisionNormal.scale(
          -velocityAlongNormal * repulsionForce,
          -velocityAlongNormal * repulsionForce);
      velocity += impulse.scale(1 / mass, 1 / mass);
      other.velocity -= impulse.scale(1 / other.mass, 1 / other.mass);
    }
  }

  // Optimize collision detection
  bool _willCollide(WelcomeBubble other, Offset checkPosition) {
    final distance = (checkPosition - other.position).distance;
    return distance < (circularBounds.radius + other.circularBounds.radius);
  }

  void _handleScreenCollision(Size screenSize) {
    if (position.dx <= 0) {
      position = Offset(0, position.dy);
      velocity = Offset(-velocity.dx * bounciness, velocity.dy);
    } else if (position.dx + width >= screenSize.width) {
      position = Offset(screenSize.width - width, position.dy);
      velocity = Offset(-velocity.dx * bounciness, velocity.dy);
    }

    if (position.dy <= 0) {
      position = Offset(position.dx, 0);
      velocity = Offset(velocity.dx, -velocity.dy * bounciness);
    } else if (position.dy + height >= screenSize.height) {
      position = Offset(position.dx, screenSize.height - height);
      velocity = Offset(velocity.dx, -velocity.dy * bounciness);
    }
  }
}

class Circle {
  final Offset center;
  final double radius;

  const Circle({
    required this.center,
    required this.radius,
  });
}

class TrailPoint {
  Offset pos;
  double life;

  TrailPoint(this.pos, this.life);
}

extension OffsetX on Offset {
  double dot(Offset other) => dx * other.dx + dy * other.dy;

  Offset normalize() {
    final d = distance;
    if (d == 0) return Offset.zero;
    return scale(1 / d, 1 / d);
  }
}

class WelcomePatternPainter extends CustomPainter {
  final BuildContext context;

  WelcomePatternPainter(this.context);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Theme.of(context)
          .colorScheme
          .onPrimaryContainer
          .withValues(alpha: 0.1)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    for (var i = 0; i < size.width; i += 30) {
      for (var j = 0; j < size.height; j += 30) {
        canvas.drawCircle(Offset(i.toDouble(), j.toDouble()), 2, paint);
      }
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

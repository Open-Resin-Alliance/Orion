/*
* Orion - Force Sensor Pong Easter Egg
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

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:orion/backend_service/providers/analytics_provider.dart';
import 'package:provider/provider.dart';

class ForcePongGame extends StatefulWidget {
  const ForcePongGame({super.key});

  @override
  State<ForcePongGame> createState() => _ForcePongGameState();
}

class _ForcePongGameState extends State<ForcePongGame>
    with TickerProviderStateMixin {
  late final AnalyticsProvider _prov;
  VoidCallback? _listener;
  int _previousPollRateHz = 15;

  // Ball properties
  double _ballX = 0.5;
  double _ballY = 0.5;
  double _ballVelocityX = 0.0065;
  double _ballVelocityY = 0.0045;
  static const double _ballSize = 0.03;
  static const double _ballHitSpeedMultiplier = 1.03;

  // Paddle properties
  static const double _paddleWidth = 0.02;
  static const double _paddleHeight = 0.2;
  double _leftPaddleY = 0.4; // Controlled by force sensor
  double _leftPaddleTargetY = 0.4; // Smoothed target from force input
  double _leftPaddleVelocity = 0.0;
  double _rightPaddleY = 0.4; // AI controlled
  double _rightPaddleTargetY = 0.4;
  double _rightPaddleVelocity = 0.0;

  // Scores
  int _leftScore = 0;
  int _rightScore = 0;

  // Game state
  Timer? _gameTimer;
  bool _gameStarted = false;
  bool _canDismissByTap = false;
  Timer? _dismissGuardTimer;

  // Force sensor control
  double _baselineForce = 0.0;
  double _smoothedForceDelta = 0.0;
  double _smoothedForceRaw = 0.0;
  bool _isCalibrating = true;
  final List<double> _calibrationSamples = <double>[];
  Timer? _calibrationTimer;
  int _directionState = 0; // -1 pulling, 0 neutral, +1 pushing
  double _hysteresisEnter = 35.0; // grams to enter movement direction
  double _hysteresisExit = 18.0; // grams to leave/flip movement direction

  static const Duration _calibrationDuration = Duration(milliseconds: 550);
  static const double _rawForceSmoothingAlpha =
      0.22; // Slight smoothing directly on sensor values
  static const double _forceSmoothingAlpha = 0.28; // Faster reaction at 20Hz
  static const double _baselineDriftAlpha =
      0.004; // Slow drift compensation near neutral
  static const double _paddleInterpolation = 0.08; // Mild settle term
  static const double _playerAccelFactor = 0.12; // Slight acceleration assist
  static const double _targetSpringFactor = 0.06; // Pull toward target
  static const double _playerVelocityDamping =
      0.90; // Friction for fluid motion
  static const double _maxPlayerVelocity = 0.024;
  static const double _aiTrackStrength =
      0.10; // How quickly AI target follows the ball
  static const double _aiAccelFactor = 0.10; // Enemy acceleration toward target
  static const double _aiVelocityDamping =
      0.90; // Smooth glide for enemy paddle
  static const double _maxAiVelocity = 0.016;
  static const double _assistPredictionStrength =
      0.14; // Light auto-assist toward predicted intercept
  static const double _assistMaxStepPerFrame =
      0.004; // Keep assist subtle so user remains in control
  static const double _assistActivationDistance =
      0.70; // Start assisting when ball is on left side / approaching
  static const double _maxTargetStepPerSample = 0.024;
  static const double _minTargetStepPerSample = 0.0020;
  static const double _speedForceRange =
      140.0; // grams span from threshold to max speed

  @override
  void initState() {
    super.initState();
    _prov = Provider.of<AnalyticsProvider>(context, listen: false);

    // Temporarily raise force polling while pong is active.
    _previousPollRateHz = _prov.pressurePollIntervalHertz;
    _prov.pressurePollIntervalHertz = 20;

    // Auto-calibrate baseline at game start.
    _calibrationTimer = Timer(_calibrationDuration, _finishCalibration);

    // Listen to force sensor updates
    _listener = () {
      if (mounted) {
        _updatePaddleFromForce();
      }
    };
    _prov.addListener(_listener!);

    // Start the game after a delay
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        _startGame();
      }
    });

    // Block tap-to-dismiss briefly so rapid trigger taps don't close the game.
    _dismissGuardTimer = Timer(const Duration(seconds: 2), () {
      if (!mounted) return;
      setState(() {
        _canDismissByTap = true;
      });
    });
  }

  @override
  void dispose() {
    _gameTimer?.cancel();
    _dismissGuardTimer?.cancel();
    _calibrationTimer?.cancel();
    if (_listener != null) _prov.removeListener(_listener!);
    _prov.pressurePollIntervalHertz = _previousPollRateHz;
    super.dispose();
  }

  void _finishCalibration() {
    if (!mounted || !_isCalibrating) return;
    if (_calibrationSamples.isEmpty) {
      _isCalibrating = false;
      return;
    }

    final mean = _calibrationSamples.reduce((a, b) => a + b) /
        _calibrationSamples.length;
    double varianceSum = 0.0;
    for (final s in _calibrationSamples) {
      final d = s - mean;
      varianceSum += d * d;
    }
    final stdDev = math.sqrt(varianceSum / _calibrationSamples.length);

    _baselineForce = mean;
    // Small hysteresis so ~50 g can change direction, but still avoid chatter.
    _hysteresisEnter = (stdDev * 2.2).clamp(12.0, 35.0);
    _hysteresisExit = (_hysteresisEnter * 0.50).clamp(6.0, 18.0);
    _directionState = 0;
    _smoothedForceDelta = 0.0;

    setState(() {
      _isCalibrating = false;
    });
  }

  void _updatePaddleFromForce() {
    final series = _prov.pressureSeries.isNotEmpty
        ? _prov.pressureSeries
        : _prov.getSeriesForKey('Pressure');

    if (series.isEmpty) return;

    final lastReading = series.last;
    final vRaw = lastReading['v'];
    final force = vRaw is num
        ? vRaw.toDouble()
        : (double.tryParse(vRaw?.toString() ?? '') ?? 0.0);

    if (_isCalibrating) {
      if (_calibrationSamples.isEmpty) {
        _smoothedForceRaw = force;
      } else {
        _smoothedForceRaw =
            (_smoothedForceRaw * (1.0 - _rawForceSmoothingAlpha)) +
                (force * _rawForceSmoothingAlpha);
      }
      if (_calibrationSamples.length < 200) {
        _calibrationSamples.add(_smoothedForceRaw);
      }
      return;
    }

    _smoothedForceRaw = (_smoothedForceRaw * (1.0 - _rawForceSmoothingAlpha)) +
        (force * _rawForceSmoothingAlpha);

    final rawDelta = _smoothedForceRaw - _baselineForce;

    // Update baseline only when near neutral so active pushes don't move baseline.
    if (rawDelta.abs() < _hysteresisExit) {
      _baselineForce = (_baselineForce * (1.0 - _baselineDriftAlpha)) +
          (_smoothedForceRaw * _baselineDriftAlpha);
    }

    // Smooth force spikes into a stable signal.
    _smoothedForceDelta = (_smoothedForceDelta * (1.0 - _forceSmoothingAlpha)) +
        (rawDelta * _forceSmoothingAlpha);

    final d = _smoothedForceDelta;

    // Hysteresis state machine (small, direction-aware).
    if (_directionState == 0) {
      if (d >= _hysteresisEnter) {
        _directionState = 1;
      } else if (d <= -_hysteresisEnter) {
        _directionState = -1;
      }
    } else if (_directionState > 0) {
      if (d <= -_hysteresisEnter) {
        _directionState = -1;
      } else if (d <= _hysteresisExit) {
        _directionState = 0;
      }
    } else {
      if (d >= _hysteresisEnter) {
        _directionState = 1;
      } else if (d >= -_hysteresisExit) {
        _directionState = 0;
      }
    }

    if (_directionState == 0) return;

    // More force => more speed (non-linear curve, capped).
    final effectiveMag = (d.abs() - _hysteresisExit).clamp(0.0, 2000.0);
    final normalized = (effectiveMag / _speedForceRange).clamp(0.0, 1.0);
    final speedCurve = math.pow(normalized, 1.15).toDouble();
    final step = _minTargetStepPerSample +
        ((_maxTargetStepPerSample - _minTargetStepPerSample) * speedCurve);

    // Keep inverted control mapping from latest user preference.
    final targetStep = _directionState * step;

    _leftPaddleTargetY =
        (_leftPaddleTargetY + targetStep).clamp(0.0, 1.0 - _paddleHeight);
  }

  void _startGame() {
    setState(() {
      _gameStarted = true;
    });

    // Game loop at ~60 FPS
    _gameTimer = Timer.periodic(const Duration(milliseconds: 16), (_) {
      if (mounted) {
        _updateGame();
      }
    });
  }

  void _updateGame() {
    setState(() {
      // Light prediction assist for the player paddle.
      final predictedY = _predictBallYAtLeftPaddle();
      if (predictedY != null) {
        final predictedPaddleTop =
            (predictedY - (_paddleHeight / 2)).clamp(0.0, 1.0 - _paddleHeight);
        final assistError = predictedPaddleTop - _leftPaddleTargetY;
        final assistStep = (assistError * _assistPredictionStrength).clamp(
          -_assistMaxStepPerFrame,
          _assistMaxStepPerFrame,
        );
        _leftPaddleTargetY =
            (_leftPaddleTargetY + assistStep).clamp(0.0, 1.0 - _paddleHeight);
      }

      // Player paddle dynamics: slight acceleration + spring-to-target.
      final targetError = _leftPaddleTargetY - _leftPaddleY;
      final accelFromForce =
          (targetError * _playerAccelFactor).clamp(-0.01, 0.01);
      final spring = (targetError * _targetSpringFactor).clamp(-0.008, 0.008);

      _leftPaddleVelocity = (_leftPaddleVelocity + accelFromForce + spring)
          .clamp(-_maxPlayerVelocity, _maxPlayerVelocity);
      _leftPaddleVelocity *= _playerVelocityDamping;
      _leftPaddleY += _leftPaddleVelocity;

      // Keep a small interpolation term for final settle without harsh snapping.
      _leftPaddleY +=
          (_leftPaddleTargetY - _leftPaddleY) * _paddleInterpolation;
      _leftPaddleY = _leftPaddleY.clamp(0.0, 1.0 - _paddleHeight);

      // Update ball position
      _ballX += _ballVelocityX;
      _ballY += _ballVelocityY;

      // Ball collision with top and bottom walls
      if (_ballY <= 0 || _ballY >= 1.0 - _ballSize) {
        _ballVelocityY = -_ballVelocityY;
        _ballY = _ballY.clamp(0.0, 1.0 - _ballSize);
      }

      // Ball collision with left paddle (force sensor controlled)
      if (_ballX <= _paddleWidth &&
          _ballY >= _leftPaddleY &&
          _ballY <= _leftPaddleY + _paddleHeight) {
        _ballVelocityX =
            -_ballVelocityX * _ballHitSpeedMultiplier; // Speed up slightly
        _ballX = _paddleWidth;

        // Add spin based on where ball hits paddle
        final hitPos = (_ballY - _leftPaddleY) / _paddleHeight;
        _ballVelocityY += (hitPos - 0.5) * 0.01;
      }

      // Ball collision with right paddle (AI controlled)
      if (_ballX >= 1.0 - _paddleWidth - _ballSize &&
          _ballY >= _rightPaddleY &&
          _ballY <= _rightPaddleY + _paddleHeight) {
        _ballVelocityX =
            -_ballVelocityX * _ballHitSpeedMultiplier; // Speed up slightly
        _ballX = 1.0 - _paddleWidth - _ballSize;

        // Add spin based on where ball hits paddle
        final hitPos = (_ballY - _rightPaddleY) / _paddleHeight;
        _ballVelocityY += (hitPos - 0.5) * 0.01;
      }

      // Ball goes past left paddle (AI scores)
      if (_ballX < 0) {
        _rightScore++;
        _resetBall();
      }

      // Ball goes past right paddle (Player scores)
      if (_ballX > 1.0) {
        _leftScore++;
        _resetBall();
      }

      // Smooth AI paddle tracking.
      final aiInstantTarget =
          (_ballY - _paddleHeight / 2).clamp(0.0, 1.0 - _paddleHeight);
      _rightPaddleTargetY +=
          (aiInstantTarget - _rightPaddleTargetY) * _aiTrackStrength;
      final aiError = _rightPaddleTargetY - _rightPaddleY;
      final aiAccel = (aiError * _aiAccelFactor).clamp(-0.008, 0.008);
      _rightPaddleVelocity = (_rightPaddleVelocity + aiAccel)
          .clamp(-_maxAiVelocity, _maxAiVelocity);
      _rightPaddleVelocity *= _aiVelocityDamping;
      _rightPaddleY += _rightPaddleVelocity;
      _rightPaddleY = _rightPaddleY.clamp(0.0, 1.0 - _paddleHeight);

      // Cap ball velocity
      _ballVelocityX = _ballVelocityX.clamp(-0.016, 0.016);
      _ballVelocityY = _ballVelocityY.clamp(-0.012, 0.012);
    });
  }

  /// Predicts the normalized Y position where the ball will reach the
  /// left paddle x-plane, including top/bottom wall bounces.
  /// Returns null when prediction should not assist (e.g. ball moving away).
  double? _predictBallYAtLeftPaddle() {
    // Only assist when the ball is moving toward the player.
    if (_ballVelocityX >= 0) return null;

    final leftPlaneX = _paddleWidth + _ballSize;
    final dx = leftPlaneX - _ballX;
    if (dx >= 0) return null;

    // Optional activation gate: avoid over-assisting when ball is far right.
    if (_ballX > _assistActivationDistance) return null;

    final framesToIntercept = dx / _ballVelocityX; // both negative => positive
    if (!framesToIntercept.isFinite || framesToIntercept <= 0) return null;

    // Unbounded projected Y in normalized coords.
    final yMax = 1.0 - _ballSize;
    final projectedY = _ballY + (_ballVelocityY * framesToIntercept);

    // Reflect Y across [0, yMax] to account for wall bounces.
    final span = yMax;
    if (span <= 0) return _ballY;
    var t = projectedY % (2 * span);
    if (t < 0) t += 2 * span;
    final reflected = t <= span ? t : (2 * span - t);
    return reflected.clamp(0.0, yMax);
  }

  void _resetBall() {
    _ballX = 0.5;
    _ballY = 0.5;
    // Random initial direction
    final rand = math.Random();
    _ballVelocityX = (rand.nextBool() ? 1 : -1) * 0.0065;
    _ballVelocityY = (rand.nextDouble() - 0.5) * 0.009;
  }

  void _handleDismissTap() {
    if (!_canDismissByTap) return;
    Navigator.maybePop(context);
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Center line
          Positioned(
            left: screenSize.width / 2 - 1,
            top: 0,
            bottom: 0,
            child: Container(
              width: 2,
              color: primaryColor.withValues(alpha: 0.3),
            ),
          ),

          // Left paddle (force sensor controlled)
          Positioned(
            left: 0,
            top: _leftPaddleY * screenSize.height,
            child: Container(
              width: _paddleWidth * screenSize.width,
              height: _paddleHeight * screenSize.height,
              decoration: BoxDecoration(
                color: primaryColor,
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(4),
                  bottomRight: Radius.circular(4),
                ),
                boxShadow: [
                  BoxShadow(
                    color: primaryColor.withValues(alpha: 0.5),
                    blurRadius: 8,
                    spreadRadius: 2,
                  ),
                ],
              ),
            ),
          ),

          // Right paddle (AI controlled)
          Positioned(
            right: 0,
            top: _rightPaddleY * screenSize.height,
            child: Container(
              width: _paddleWidth * screenSize.width,
              height: _paddleHeight * screenSize.height,
              decoration: BoxDecoration(
                color: Colors.redAccent,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(4),
                  bottomLeft: Radius.circular(4),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.redAccent.withValues(alpha: 0.5),
                    blurRadius: 8,
                    spreadRadius: 2,
                  ),
                ],
              ),
            ),
          ),

          // Ball
          Positioned(
            left: _ballX * screenSize.width,
            top: _ballY * screenSize.height,
            child: Container(
              width: _ballSize * screenSize.width,
              height: _ballSize * screenSize.width,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.white.withValues(alpha: 0.5),
                    blurRadius: 8,
                    spreadRadius: 2,
                  ),
                ],
              ),
            ),
          ),

          // Scores
          Positioned(
            top: 40,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Player score
                Text(
                  '$_leftScore',
                  style: TextStyle(
                    fontSize: 72,
                    fontWeight: FontWeight.bold,
                    color: primaryColor.withValues(alpha: 0.5),
                    fontFamily: 'AtkinsonHyperlegible',
                  ),
                ),
                // AI score
                Text(
                  '$_rightScore',
                  style: TextStyle(
                    fontSize: 72,
                    fontWeight: FontWeight.bold,
                    color: Colors.redAccent.withValues(alpha: 0.5),
                    fontFamily: 'AtkinsonHyperlegible',
                  ),
                ),
              ],
            ),
          ),

          // Instructions overlay (fades after a few seconds)
          if (!_gameStarted || _leftScore == 0 && _rightScore == 0)
            Center(
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Force Sensor Pong',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: primaryColor,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Lightly push up and down on the force sensor\nto control your paddle!\n\n(Please wear gloves!)',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 20,
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Tap anywhere to close',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white38,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Tap to exit
          Positioned.fill(
            child: GestureDetector(
              onTap: _handleDismissTap,
              behavior: HitTestBehavior.translucent,
            ),
          ),

          // Explicit close affordance once the guard expires.
          if (_canDismissByTap)
            Positioned(
              top: 24,
              right: 24,
              child: Material(
                color: Colors.transparent,
                child: IconButton(
                  tooltip: 'Close',
                  onPressed: _handleDismissTap,
                  icon:
                      const Icon(Icons.close, color: Colors.white70, size: 30),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

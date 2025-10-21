/*
* Orion - Startup Screen
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
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:orion/backend_service/providers/status_provider.dart';
import 'package:orion/glasser/src/gradient_utils.dart';
import 'package:orion/util/providers/theme_provider.dart';
import 'package:orion/util/orion_config.dart';
import 'package:provider/provider.dart';

/// Blocking startup overlay shown while the app awaits the initial backend
/// connection. Displayed by [StartupGate] until
/// [StatusProvider.hasEverConnected] becomes true.
class StartupScreen extends StatefulWidget {
  const StartupScreen({super.key});

  @override
  State<StartupScreen> createState() => _StartupScreenState();
}

class _StartupScreenState extends State<StartupScreen>
    with TickerProviderStateMixin {
  late final AnimationController _logoController;
  late final AnimationController _loaderController;
  late final AnimationController _logoMoveController;
  late final AnimationController _backgroundController;
  late final Animation<double> _logoOpacity;
  late final Animation<double> _logoMove;
  late final Animation<double> _loaderOpacity;
  late final Animation<double> _backgroundOpacity;
  late final String _printerName;
  List<Color> _gradientColors = const [];
  Color _backgroundColor = Colors.black;

  @override
  void initState() {
    super.initState();

    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _logoMoveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    final config = OrionConfig();
    final rawPrinterName =
        config.getString('machineName', category: 'machine').trim();
    _printerName = rawPrinterName.isEmpty ? '3D Printer' : rawPrinterName;
    _loaderController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _backgroundController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    _logoOpacity =
        CurvedAnimation(parent: _logoController, curve: Curves.easeInOut);
    _logoMove = CurvedAnimation(
        parent: _logoMoveController, curve: Curves.easeInOutSine);
    _loaderOpacity =
        CurvedAnimation(parent: _loaderController, curve: Curves.easeInOut);
    _backgroundOpacity =
        CurvedAnimation(parent: _backgroundController, curve: Curves.easeInOut);

    // Stage animations: logo after 1s, background after 4s with a slower fade.
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) _logoController.forward();
    });
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) _logoMoveController.forward();
    });
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) _loaderController.forward();
    });
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted) _backgroundController.forward();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final baseBackground = Theme.of(context).scaffoldBackgroundColor;
    _backgroundColor =
        Color.lerp(baseBackground, Colors.black, 0.6) ?? Colors.black;
    try {
      final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
      if (themeProvider.isGlassTheme) {
        // Use the same gradient resolution as the rest of the app so
        // brightness and color stops match GlassApp.
        final gradient = GlassGradientUtils.resolveGradient(
          themeProvider: themeProvider,
        );
        _gradientColors = gradient.isNotEmpty ? gradient : const [];
      } else {
        // For non-glass themes, prefer the theme's scaffold background color
        // as a solid background. We already computed a blended _backgroundColor
        // above; slightly darken it so the startup overlay reads well over
        // light/dark backgrounds.
        _gradientColors = const [];
        _backgroundColor = Color.lerp(Theme.of(context).scaffoldBackgroundColor,
                Colors.black, 0.35) ??
            _backgroundColor;
      }
    } catch (_) {
      _gradientColors = const [];
    }
  }

  @override
  void dispose() {
    _logoController.dispose();
    _loaderController.dispose();
    _logoMoveController.dispose();
    _backgroundController.dispose();
    super.dispose();
  }

  // Interpolates between a greyscale color matrix (t=0) and the identity
  // color matrix (t=1). We drive this with the loader animation so the
  // logo is greyscale initially and transitions back to color as the
  // loader/text are revealed.
  List<double> _colorMatrixFor(double t) {
    const List<double> grey = [
      0.2126, 0.7152, 0.0722, 0, 0, // R
      0.2126, 0.7152, 0.0722, 0, 0, // G
      0.2126, 0.7152, 0.0722, 0, 0, // B
      0, 0, 0, 1, 0, // A
    ];
    const List<double> identity = [
      1, 0, 0, 0, 0, // R
      0, 1, 0, 0, 0, // G
      0, 0, 1, 0, 0, // B
      0, 0, 0, 1, 0, // A
    ];
    // t==0 => grey, t==1 => identity
    return List<double>.generate(
      20,
      (i) => grey[i] + (identity[i] - grey[i]) * t,
      growable: false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Container(color: Colors.black),
          FadeTransition(
            opacity: _backgroundOpacity,
            child: _gradientColors.length >= 2
                ? Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: _gradientColors,
                      ),
                    ),
                    // Match GlassApp: overlay a semi-transparent black layer on
                    // top of the gradient to achieve the same perceived
                    // brightness.
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.5),
                      ),
                    ),
                  )
                : DecoratedBox(
                    decoration: BoxDecoration(
                      color: _backgroundColor.withValues(alpha: 1.0),
                    ),
                  ),
          ),
          Center(
            child: FadeTransition(
              opacity: _logoOpacity,
              child: AnimatedBuilder(
                animation: _logoMove,
                builder: (context, _) {
                  final dy = -30.0 * _logoMove.value;
                  final matrix = _colorMatrixFor(_logoMove.value);
                  return Transform.translate(
                    offset: Offset(0, dy - 10),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Slightly upscaled blurred black copy (halo)
                        Transform.scale(
                          scale: 1.07,
                          child: ImageFiltered(
                            imageFilter:
                                ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                            child: ColorFiltered(
                              colorFilter: ColorFilter.mode(
                                  Colors.black.withValues(alpha: 0.5),
                                  BlendMode.srcIn),
                              child: Padding(
                                padding: const EdgeInsets.all(8),
                                child: Image.asset(
                                  'assets/images/open_resin_alliance_logo_darkmode.png',
                                  width: 220,
                                  height: 220,
                                ),
                              ),
                            ),
                          ),
                        ),
                        // Foreground logo which receives the greyscale->color
                        // matrix animation.
                        Padding(
                          padding: const EdgeInsets.all(8),
                          child: ColorFiltered(
                            colorFilter: ColorFilter.matrix(matrix),
                            child: Image.asset(
                              'assets/images/open_resin_alliance_logo_darkmode.png',
                              width: 220,
                              height: 220,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
          // Full-width indeterminate progress bar at the bottom edge. Kept
          // separate from the centered content so it doesn't affect layout.
          Positioned(
            left: 20,
            right: 20,
            bottom: 30,
            child: FadeTransition(
              opacity: _loaderOpacity,
              child: Text(
                'Starting up $_printerName',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'AtkinsonHyperlegible',
                  fontSize: 24,
                  color: Colors.white70,
                ),
              ),
            ),
          ),
          Positioned(
            left: 40,
            right: 40,
            bottom: 90,
            child: FadeTransition(
              opacity: _loaderOpacity,
              child: SizedBox(
                height: 14,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(7),
                  child: LinearProgressIndicator(
                    // Use theme primary color for the indicator to match app theming.
                    valueColor: AlwaysStoppedAnimation<Color>(
                        Theme.of(context).colorScheme.primary),
                    backgroundColor: Colors.black.withValues(alpha: 0.3),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

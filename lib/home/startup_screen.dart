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
import 'package:flutter_svg/flutter_svg.dart';
import 'package:orion/backend_service/providers/status_provider.dart';
import 'package:orion/glasser/src/gradient_utils.dart';
import 'package:orion/util/providers/theme_provider.dart';
import 'package:orion/util/orion_config.dart';
import 'package:provider/provider.dart';

/// Blocking startup overlay shown while the app awaits the initial backend
/// connection. Displayed by [StartupGate] until
/// [StatusProvider.hasEverConnected] becomes true.
class StartupScreen extends StatefulWidget {
  final VoidCallback? onAnimationsComplete;
  final bool shouldAnimateOut;
  final VoidCallback? onExitComplete;

  const StartupScreen({
    super.key,
    this.onAnimationsComplete,
    this.shouldAnimateOut = false,
    this.onExitComplete,
  });

  @override
  State<StartupScreen> createState() => _StartupScreenState();
}

class _StartupScreenState extends State<StartupScreen>
    with TickerProviderStateMixin {
  late final AnimationController _logoController;
  late final AnimationController _loaderController;
  late final AnimationController _logoMoveController;
  late final AnimationController _backgroundController;
  late final AnimationController _logoCrossfadeController;
  late final AnimationController _exitController; // New controller for exit
  late final Animation<double> _logoOpacity;
  late final Animation<double> _logoMove;
  late final Animation<double> _loaderOpacity;
  late final Animation<double> _backgroundOpacity;
  late final Animation<double> _logoCrossfade;
  late final Animation<double> _exitOpacity; // New animation for exit

  late final String _printerName;
  late final String _logoAssetPath;
  late final String? _secondaryLogoAssetPath;
  late final double _logoScale;
  late final double _secondaryLogoScale;
  late final Color? _logoColor;
  late final Color? _secondaryLogoColor;
  late final double _logoOffset;
  late final double _secondaryLogoOffset;
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

    // Load vendor-specific logo or default to ORA logo
    final vendorLogo =
        config.getString('vendorLogo', category: 'vendor').toLowerCase().trim();
    _logoAssetPath = _resolveLogoAsset(vendorLogo);

    // Load optional secondary logo for dual-stage animation
    final secondaryLogo = config
        .getString('vendorLogoSecondary', category: 'vendor')
        .toLowerCase()
        .trim();
    _secondaryLogoAssetPath =
        secondaryLogo.isNotEmpty && secondaryLogo != vendorLogo
            ? _resolveLogoAsset(secondaryLogo)
            : null;

    // Load optional logo scale (default 1.0)
    final logoScaleStr =
        config.getString('vendorLogoScale', category: 'vendor').trim();
    _logoScale = double.tryParse(logoScaleStr) ?? 1.0;

    // Load optional logo color override
    final logoColorHex =
        config.getString('vendorLogoColor', category: 'vendor').trim();
    _logoColor = logoColorHex.isNotEmpty && logoColorHex != 'null'
        ? _parseColor(logoColorHex)
        : null;

    // Load optional secondary logo scale (default 1.0)
    final secondaryLogoScaleStr =
        config.getString('vendorLogoSecondaryScale', category: 'vendor').trim();
    _secondaryLogoScale = double.tryParse(secondaryLogoScaleStr) ?? 1.0;

    // Load optional secondary logo color override
    final secondaryLogoColorHex =
        config.getString('vendorLogoSecondaryColor', category: 'vendor').trim();
    _secondaryLogoColor =
        secondaryLogoColorHex.isNotEmpty && secondaryLogoColorHex != 'null'
            ? _parseColor(secondaryLogoColorHex)
            : null;

    // Load optional vertical offset (default 0.0)
    final logoOffsetStr =
        config.getString('vendorLogoOffset', category: 'vendor').trim();
    _logoOffset = double.tryParse(logoOffsetStr) ?? 0.0;

    // Load optional secondary vertical offset (default 0.0)
    final secondaryLogoOffsetStr = config
        .getString('vendorLogoSecondaryOffset', category: 'vendor')
        .trim();
    _secondaryLogoOffset = double.tryParse(secondaryLogoOffsetStr) ?? 0.0;

    _loaderController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _backgroundController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    _logoCrossfadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _exitController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _logoOpacity =
        CurvedAnimation(parent: _logoController, curve: Curves.easeInOut);
    _logoMove = CurvedAnimation(
        parent: _logoMoveController, curve: Curves.easeInOutSine);
    _loaderOpacity =
        CurvedAnimation(parent: _loaderController, curve: Curves.easeInOut);
    _backgroundOpacity =
        CurvedAnimation(parent: _backgroundController, curve: Curves.easeInOut);
    // Split crossfade into two phases: fade out (0-0.5), fade in (0.5-1.0)
    _logoCrossfade = CurvedAnimation(
        parent: _logoCrossfadeController, curve: Curves.easeInOut);

    // Exit animation: fade out content (1.0 -> 0.0)
    _exitOpacity = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _exitController, curve: Curves.easeOut),
    );

    // Stage animations: logo after 1s, background after 4s with a slower fade.
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) _logoController.forward();
    });

    // If we have a secondary logo, sequence differently:
    // - Show vendor logo for ~2.5s
    // - Crossfade to secondary logo
    // - Then move up and continue sequence
    if (_secondaryLogoAssetPath != null) {
      // Start crossfade at 3.5s, completes at ~4.7s
      Future.delayed(const Duration(milliseconds: 3500), () {
        if (mounted) _logoCrossfadeController.forward();
      });
      // Wait for crossfade to complete, then move up
      Future.delayed(const Duration(milliseconds: 5800), () {
        if (mounted) _logoMoveController.forward();
      });
      // Continue sequence after move
      Future.delayed(const Duration(milliseconds: 6500), () {
        if (mounted) _loaderController.forward();
      });
      Future.delayed(const Duration(milliseconds: 7600), () {
        if (mounted) _backgroundController.forward();
      });
      // Signal completion after background fade finishes
      Future.delayed(const Duration(milliseconds: 9400), () {
        if (mounted) widget.onAnimationsComplete?.call();
      });
    } else {
      // No secondary logo: use original timing
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) _logoMoveController.forward();
      });
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) _loaderController.forward();
      });
      Future.delayed(const Duration(seconds: 4), () {
        if (mounted) _backgroundController.forward();
      });
      // Signal completion after background fade finishes
      Future.delayed(const Duration(milliseconds: 5800), () {
        if (mounted) widget.onAnimationsComplete?.call();
      });
    }
  }

  @override
  void didUpdateWidget(StartupScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.shouldAnimateOut && !oldWidget.shouldAnimateOut) {
      _exitController.forward().then((_) {
        widget.onExitComplete?.call();
      });
    }
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
    _logoCrossfadeController.dispose();
    _exitController.dispose();
    super.dispose();
  }

  /// Resolves the logo asset path based on vendor configuration.
  /// Supported vendor logos: 'c3d', 'athena', 'ora' (default)
  String _resolveLogoAsset(String vendorLogo) {
    switch (vendorLogo) {
      case 'c3d':
        return 'assets/images/concepts_3d/c3d.svg';
      case 'athena':
        return 'assets/images/concepts_3d/athena_logo.svg';
      case 'ora':
      default:
        return 'assets/images/ora/open_resin_alliance_logo_darkmode.png';
    }
  }

  /// Parses a hex color string (e.g., "#FFFFFFFF" or "#FF0000")
  Color? _parseColor(String hex) {
    try {
      if (hex.startsWith('#')) {
        hex = hex.substring(1);
      }
      if (hex.length == 6) {
        hex = 'FF$hex'; // Add full opacity if not specified
      }
      return Color(int.parse(hex, radix: 16));
    } catch (_) {
      return null;
    }
  }

  /// Builds a logo widget for the given asset path
  Widget _buildLogo(String assetPath, List<double> matrix,
      {double? scale, Color? color, double offset = 0.0}) {
    final effectiveScale = scale ?? _logoScale;
    final effectiveColor = color ?? _logoColor;

    return Transform.translate(
      offset: Offset(0, offset),
      child: Transform.scale(
        scale: effectiveScale,
        child: ColorFiltered(
          colorFilter: ColorFilter.matrix(matrix),
          child: assetPath.endsWith('.svg')
              ? SvgPicture.asset(
                  assetPath,
                  width: 220,
                  height: 220,
                  colorFilter: effectiveColor != null
                      ? ColorFilter.mode(
                          effectiveColor,
                          BlendMode.srcIn,
                        )
                      : null,
                )
              : Image.asset(
                  assetPath,
                  width: 220,
                  height: 220,
                  color: effectiveColor,
                ),
        ),
      ),
    );
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
              opacity: _exitOpacity, // Apply exit fade to logo content
              child: FadeTransition(
                opacity: _logoOpacity,
                child: AnimatedBuilder(
                  animation: _logoMove,
                  builder: (context, _) {
                    final dy = -30.0 * _logoMove.value;
                    final matrix = _colorMatrixFor(_logoMove.value);
                    return Transform.translate(
                      offset: Offset(0, dy - 10),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Stack(
                            alignment: Alignment.center,
                            children: [
                              // Slightly upscaled blurred black copy (halo)
                              // Animate halo to match the visible logo during crossfade
                              _secondaryLogoAssetPath != null
                                  ? AnimatedBuilder(
                                      animation: _logoCrossfade,
                                      builder: (context, _) {
                                        final fadeProgress =
                                            _logoCrossfade.value;
                                        final primaryOpacity =
                                            fadeProgress < 0.5
                                                ? 1.0 - (fadeProgress * 2.0)
                                                : 0.0;
                                        final secondaryOpacity =
                                            fadeProgress > 0.5
                                                ? (fadeProgress - 0.5) * 2.0
                                                : 0.0;

                                        return Stack(
                                          alignment: Alignment.center,
                                          children: [
                                            if (primaryOpacity > 0)
                                              Opacity(
                                                opacity: primaryOpacity,
                                                child: Transform.translate(
                                                  offset:
                                                      Offset(0, _logoOffset),
                                                  child: Transform.scale(
                                                    scale: 1.07 * _logoScale,
                                                    child: ImageFiltered(
                                                      imageFilter:
                                                          ui.ImageFilter.blur(
                                                              sigmaX: 12,
                                                              sigmaY: 12),
                                                      child: ColorFiltered(
                                                        colorFilter:
                                                            ColorFilter.mode(
                                                                Colors.black
                                                                    .withValues(
                                                                        alpha:
                                                                            0.5),
                                                                BlendMode
                                                                    .srcIn),
                                                        child: Padding(
                                                          padding:
                                                              const EdgeInsets
                                                                  .all(8),
                                                          child: _logoAssetPath
                                                                  .endsWith(
                                                                      '.svg')
                                                              ? SvgPicture
                                                                  .asset(
                                                                  _logoAssetPath,
                                                                  width: 220,
                                                                  height: 220,
                                                                  colorFilter: _logoColor !=
                                                                          null
                                                                      ? ColorFilter
                                                                          .mode(
                                                                          _logoColor,
                                                                          BlendMode
                                                                              .srcIn,
                                                                        )
                                                                      : null,
                                                                )
                                                              : Image.asset(
                                                                  _logoAssetPath,
                                                                  width: 220,
                                                                  height: 220,
                                                                  color:
                                                                      _logoColor,
                                                                ),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            if (secondaryOpacity > 0)
                                              Opacity(
                                                opacity: secondaryOpacity,
                                                child: Transform.translate(
                                                  offset: Offset(
                                                      0, _secondaryLogoOffset),
                                                  child: Transform.scale(
                                                    scale: 1.07 *
                                                        _secondaryLogoScale,
                                                    child: ImageFiltered(
                                                      imageFilter:
                                                          ui.ImageFilter.blur(
                                                              sigmaX: 12,
                                                              sigmaY: 12),
                                                      child: ColorFiltered(
                                                        colorFilter:
                                                            ColorFilter.mode(
                                                                Colors.black
                                                                    .withValues(
                                                                        alpha:
                                                                            0.5),
                                                                BlendMode
                                                                    .srcIn),
                                                        child: Padding(
                                                          padding:
                                                              const EdgeInsets
                                                                  .all(8),
                                                          child:
                                                              _secondaryLogoAssetPath
                                                                      .endsWith(
                                                                          '.svg')
                                                                  ? SvgPicture
                                                                      .asset(
                                                                      _secondaryLogoAssetPath,
                                                                      width:
                                                                          220,
                                                                      height:
                                                                          220,
                                                                      colorFilter: _secondaryLogoColor !=
                                                                              null
                                                                          ? ColorFilter
                                                                              .mode(
                                                                              _secondaryLogoColor,
                                                                              BlendMode.srcIn,
                                                                            )
                                                                          : null,
                                                                    )
                                                                  : Image.asset(
                                                                      _secondaryLogoAssetPath,
                                                                      width:
                                                                          220,
                                                                      height:
                                                                          220,
                                                                      color:
                                                                          _secondaryLogoColor,
                                                                    ),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                          ],
                                        );
                                      },
                                    )
                                  : Transform.translate(
                                      offset: Offset(0, _logoOffset),
                                      child: Transform.scale(
                                        scale: 1.07 * _logoScale,
                                        child: ImageFiltered(
                                          imageFilter: ui.ImageFilter.blur(
                                              sigmaX: 12, sigmaY: 12),
                                          child: ColorFiltered(
                                            colorFilter: ColorFilter.mode(
                                                Colors.black
                                                    .withValues(alpha: 0.5),
                                                BlendMode.srcIn),
                                            child: Padding(
                                              padding: const EdgeInsets.all(8),
                                              child: _logoAssetPath
                                                      .endsWith('.svg')
                                                  ? SvgPicture.asset(
                                                      _logoAssetPath,
                                                      width: 220,
                                                      height: 220,
                                                      colorFilter: _logoColor !=
                                                              null
                                                          ? ColorFilter.mode(
                                                              _logoColor,
                                                              BlendMode.srcIn,
                                                            )
                                                          : null,
                                                    )
                                                  : Image.asset(
                                                      _logoAssetPath,
                                                      width: 220,
                                                      height: 220,
                                                      color: _logoColor,
                                                    ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                              // Foreground logo which receives the greyscale->color
                              // matrix animation. Support fade-out-then-fade-in if secondary logo exists.
                              Padding(
                                padding: const EdgeInsets.all(8),
                                child: _secondaryLogoAssetPath != null
                                    ? AnimatedBuilder(
                                        animation: _logoCrossfade,
                                        builder: (context, _) {
                                          // First half (0-0.5): fade out primary
                                          // Second half (0.5-1.0): fade in secondary
                                          final fadeProgress =
                                              _logoCrossfade.value;
                                          final primaryOpacity =
                                              fadeProgress < 0.5
                                                  ? 1.0 - (fadeProgress * 2.0)
                                                  : 0.0;
                                          final secondaryOpacity =
                                              fadeProgress > 0.5
                                                  ? (fadeProgress - 0.5) * 2.0
                                                  : 0.0;

                                          return Stack(
                                            alignment: Alignment.center,
                                            children: [
                                              if (primaryOpacity > 0)
                                                Opacity(
                                                  opacity: primaryOpacity,
                                                  child: _buildLogo(
                                                    _logoAssetPath,
                                                    matrix,
                                                    offset: _logoOffset,
                                                  ),
                                                ),
                                              if (secondaryOpacity > 0)
                                                Opacity(
                                                  opacity: secondaryOpacity,
                                                  child: _buildLogo(
                                                    _secondaryLogoAssetPath,
                                                    matrix,
                                                    scale: _secondaryLogoScale,
                                                    color: _secondaryLogoColor,
                                                    offset:
                                                        _secondaryLogoOffset,
                                                  ),
                                                ),
                                            ],
                                          );
                                        },
                                      )
                                    : _buildLogo(_logoAssetPath, matrix,
                                        offset: _logoOffset),
                              ),
                            ],
                          ),
                          if (_secondaryLogoAssetPath != null) ...[
                            FadeTransition(
                              opacity: _backgroundOpacity,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'Powered by ',
                                    style: TextStyle(
                                      fontFamily: 'AtkinsonHyperlegible',
                                      fontSize: 22,
                                      color: Colors.grey,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  ShaderMask(
                                    shaderCallback: (bounds) =>
                                        const LinearGradient(
                                      colors: [
                                        Color(0xFFFF9D7A), // Pastel orange
                                        Color(0xFFFF7A85), // Pastel red
                                        Color(0xFFC49FE8), // Pastel purple
                                      ],
                                      begin: Alignment.centerLeft,
                                      end: Alignment.centerRight,
                                    ).createShader(bounds),
                                    child: const Text(
                                      'Open Resin Alliance',
                                      style: TextStyle(
                                        fontFamily: 'AtkinsonHyperlegible',
                                        fontSize: 22,
                                        color: Colors.white,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
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
              opacity: _exitOpacity, // Apply exit fade to loader text
              child: FadeTransition(
                opacity: _loaderOpacity,
                child: Text(
                  'Starting up $_printerName',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'AtkinsonHyperlegible',
                    fontSize: 24,
                    color: Theme.of(context).colorScheme.secondary,
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 40,
            right: 40,
            bottom: 90,
            child: FadeTransition(
              opacity: _exitOpacity, // Apply exit fade to progress bar
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
          ),
        ],
      ),
    );
  }
}

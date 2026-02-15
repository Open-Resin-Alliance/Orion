/*
* Orion - Onboarding Screen - Pages
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
import 'dart:math';
import 'package:flutter/scheduler.dart';
import 'package:flutter/gestures.dart';
import 'package:provider/provider.dart';
import 'package:country_flags/country_flags.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'package:orion/glasser/glasser.dart';
import 'package:orion/l10n/generated/app_localizations.dart';
import 'package:orion/settings/about_screen.dart';
import 'package:orion/settings/wifi_screen.dart';
import 'package:orion/util/locales/all_countries.dart';
import 'package:orion/util/locales/country_regions.dart';
import 'package:orion/util/locales/available_languages.dart';
import 'package:orion/util/orion_config.dart';
import 'package:orion/util/orion_kb/orion_keyboard_expander.dart';
import 'package:orion/util/orion_kb/orion_textfield_spawn.dart';
import 'package:orion/util/providers/locale_provider.dart';
import 'package:orion/util/providers/theme_provider.dart';
import 'package:orion/util/theme_color_selector.dart';

import 'welcome_bubbles.dart';

class OnboardingPages {
  static Widget buildWelcomePage(
    BuildContext context,
    AnimationController bubbleController,
    List<WelcomeBubble> welcomeBubbles,
    Animation<double> holeAnimation,
  ) {
    return Center(
      child: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerHover: (e) {
          // apply a soft proximity-based gravity (attraction) when the cursor is near
          final local = e.localPosition;
          const threshold = 140.0;
          for (var bubble in welcomeBubbles) {
            final center = Offset(
              bubble.position.dx + bubble.width / 2,
              bubble.position.dy + bubble.height / 2,
            );
            final dist = (center - local).distance;
            if (dist < threshold) {
              final dir = (local - center).normalize();
              final proximity = (1.0 - (dist / threshold)).clamp(0.0, 1.0);
              final strength = 18.0 * proximity; // tuneable
              final impulse =
                  dir.scale(strength / bubble.mass, strength / bubble.mass);
              // pull toward pointer (gravity)
              bubble.velocity += impulse;
              bubble.addProximityTrail(local);
            }
          }
        },
        onPointerDown: (e) {
          final local = e.localPosition;
          const threshold = 160.0;
          for (var bubble in welcomeBubbles) {
            final center = Offset(
              bubble.position.dx + bubble.width / 2,
              bubble.position.dy + bubble.height / 2,
            );
            final dist = (center - local).distance;
            if (dist < threshold) {
              final dir = (local - center).normalize();
              final proximity = (1.0 - (dist / threshold)).clamp(0.0, 1.0);
              final strength = 56.0 * proximity;
              final impulse =
                  dir.scale(strength / bubble.mass, strength / bubble.mass);
              bubble.velocity += impulse;
              bubble.addProximityTrail(local);
            }
          }
        },
        child: Stack(
          children: [
            // Opaque background layer that reveals the underlying page
            Positioned.fill(
              child: AnimatedBuilder(
                animation: holeAnimation,
                builder: (context, child) {
                  final themeProvider = Provider.of<ThemeProvider>(context);
                  final gradient = GlassGradientUtils.resolveGradient(
                    themeProvider: themeProvider,
                  );

                  return ShaderMask(
                    shaderCallback: (rect) {
                      // Calculate radius based on screen size to ensure full coverage
                      final maxRadius = sqrt(
                          rect.width * rect.width + rect.height * rect.height);
                      final currentRadius = maxRadius * holeAnimation.value;

                      return RadialGradient(
                        center: Alignment.center,
                        radius: currentRadius / rect.shortestSide * 2,
                        colors: const [Colors.white, Colors.transparent],
                        stops: const [0.5, 1.0], // Soft edge
                        tileMode: TileMode.clamp,
                      ).createShader(rect);
                    },
                    blendMode: BlendMode.dstOut,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: gradient,
                        ),
                      ),
                      child: Container(
                        color: Colors.black.withValues(alpha: 0.5),
                      ),
                    ),
                  );
                },
              ),
            ),
            AnimatedBuilder(
              animation: holeAnimation,
              builder: (context, child) {
                final opacity = (1.0 - holeAnimation.value).clamp(0.0, 1.0);
                return Opacity(
                  opacity: opacity,
                  child: child,
                );
              },
              child: CustomPaint(
                size: Size.infinite,
                painter: WelcomePatternPainter(context),
              ),
            ),
            AnimatedBuilder(
              animation: bubbleController,
              builder: (context, child) {
                final size = MediaQuery.of(context).size;

                // Add back the scheduler callback
                SchedulerBinding.instance.scheduleFrameCallback((_) {
                  for (var bubble in welcomeBubbles) {
                    bubble.update(size, 1 / 60, welcomeBubbles);
                  }
                });

                return Stack(
                  children: welcomeBubbles.map((bubble) {
                    return Positioned(
                      left: bubble.position.dx,
                      top: bubble.position.dy,
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 200),
                        opacity: bubble.opacity,
                        child: _GlassBubble(
                          bubble: bubble,
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Start an exit animation where bubbles are pushed outward from screen
  /// center and fade out in a staggered sequence. Calls [onComplete]
  /// after all bubbles have fully faded.
  static Future<void> startExitSequence(
    BuildContext context,
    List<WelcomeBubble> welcomeBubbles, {
    Duration stagger = const Duration(milliseconds: 60),
    VoidCallback? onComplete,
  }) async {
    final size = MediaQuery.of(context).size;
    final center = Offset(size.width / 2, size.height / 2);
    final rand = Random();

    Future<void> fadeBubble(WelcomeBubble b) async {
      // small delay before fade to give explosion motion
      await Future.delayed(const Duration(milliseconds: 80));
      while (b.opacity > 0) {
        b.opacity = max(0, b.opacity - 0.06);
        await Future.delayed(const Duration(milliseconds: 50));
      }
    }

    for (var i = 0; i < welcomeBubbles.length; i++) {
      final b = welcomeBubbles[i];
      await Future.delayed(stagger);

      final bubbleCenter =
          Offset(b.position.dx + b.width / 2, b.position.dy + b.height / 2);
      var dir = bubbleCenter - center;
      if (dir.distance == 0) {
        dir = Offset(rand.nextDouble() - 0.5, rand.nextDouble() - 0.5);
      }
      dir = dir.scale(1 / dir.distance, 1 / dir.distance);

      final strength = 220.0 * (0.7 + rand.nextDouble() * 0.6);
      final impulse = dir.scale(strength / b.mass, strength / b.mass);
      b.velocity += impulse;
      b.addProximityTrail(center);

      // start fade concurrently for this bubble
      Future.microtask(() => fadeBubble(b));
    }

    // wait until all bubbles have faded
    while (welcomeBubbles.any((b) => b.opacity > 0)) {
      await Future.delayed(const Duration(milliseconds: 60));
    }

    if (onComplete != null) onComplete();
  }

  static Widget buildLanguagePage(
    BuildContext context,
    Function(String) onLanguageSelected,
  ) {
    return GlassApp(
      child: Consumer<LocaleProvider>(
        builder: (context, localeProvider, _) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10.0),
            child: GridView.builder(
              physics: const BouncingScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                childAspectRatio: 1.03,
                mainAxisSpacing: 5,
                crossAxisSpacing: 5,
                crossAxisCount:
                    MediaQuery.of(context).orientation == Orientation.landscape
                        ? 4
                        : 2,
              ),
              itemCount: availableLanguages.length,
              itemBuilder: (context, index) {
                final language = availableLanguages[index];

                return GlassCard(
                  elevation: 2,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => onLanguageSelected(language['code']!),
                    child: GridTile(
                      footer: Container(
                        decoration: const BoxDecoration(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.only(
                            bottomLeft: Radius.circular(10),
                            bottomRight: Radius.circular(10),
                          ),
                        ),
                        child: GridTileBar(
                          backgroundColor: Colors.transparent,
                          title: Text(
                            language['nativeName'] ?? language['name']!,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface,
                              fontSize: 24,
                              fontFamily: 'AtkinsonHyperlegible',
                            ),
                          ),
                        ),
                      ),
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 30),
                          child: CountryFlag.fromCountryCode(
                            language['flag']!,
                            height: 95,
                            width: 130,
                            shape: RoundedRectangle(8),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  static Widget buildRegionCountryPage(
    BuildContext context,
    String? selectedLanguage,
    Function(String) onCountrySelected,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final suggestedCountries =
        languageCountrySuggestions[selectedLanguage] ?? [];

    final suggestedCountryCodes =
        suggestedCountries.map((c) => c['code']).toSet();

    final otherCountries = countryData.entries
        .map((e) =>
            <String, String>{'name': e.key, 'code': e.value['code'] as String})
        .where((country) => !suggestedCountryCodes.contains(country['code']))
        .toList();

    // Group countries by region
    final groupedCountries = groupCountriesByRegion(otherCountries);

    return GlassApp(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: ListView(
          children: [
            if (suggestedCountries.isNotEmpty) ...[
              Text(
                l10n.regionSuggestedCountries,
                style:
                    const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ...suggestedCountries.map(
                (country) =>
                    _buildCountryCard(context, country, onCountrySelected),
              ),
              const SizedBox(height: 16),
            ],
            Text(
              l10n.regionAllCountries,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            // Display countries grouped by region
            ...regionOrder.map((region) {
              final countriesInRegion = groupedCountries[region] ?? [];
              if (countriesInRegion.isEmpty) return const SizedBox.shrink();

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        vertical: 12.0, horizontal: 8.0),
                    child: Text(
                      region,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                  ...countriesInRegion.map(
                    (country) => _buildCountryCard(
                      context,
                      country
                          .map((key, value) => MapEntry(key, value.toString())),
                      onCountrySelected,
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  static Widget _buildCountryCard(
    BuildContext context,
    Map<String, String> country,
    Function(String) onCountrySelected,
  ) {
    final nativeName = country['nativeName'];
    final name = country['name']!;

    return GlassCard(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 5.0),
        child: ListTile(
          leading: CountryFlag.fromCountryCode(
            country['code']!,
            height: 45,
            width: 60,
            shape: RoundedRectangle(4),
          ),
          title: Padding(
            padding: const EdgeInsets.only(left: 5.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nativeName ?? name,
                  style: const TextStyle(fontSize: 24),
                ),
                if (nativeName != null && nativeName != name)
                  Text(
                    '($name)',
                    style: const TextStyle(fontSize: 16, color: Colors.grey),
                  ),
              ],
            ),
          ),
          onTap: () => onCountrySelected(name),
        ),
      ),
    );
  }

  static Widget buildTimezonePage(
    BuildContext context,
    String? selectedCountry,
    Function(String) onTimezoneSelected,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final countryTimezones = countryData[selectedCountry]?['timezones'];

    if (countryTimezones == null) {
      return GlassApp(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              l10n.timezoneNoneAvailable,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 20),
            ),
          ),
        ),
      );
    }

    final suggestedTimezones = countryTimezones['suggested'] as List<String>;
    final otherTimezones = countryTimezones['other'] as List<String>;

    return GlassApp(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: ListView(
          children: [
            Text(
              l10n.timezoneSuggested,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ...suggestedTimezones.map((timezone) => _buildTimezoneCard(
                  context,
                  timezone,
                  onTimezoneSelected,
                )),
            const SizedBox(height: 16),
            Text(
              l10n.timezoneOther,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ...otherTimezones.map((timezone) => _buildTimezoneCard(
                  context,
                  timezone,
                  onTimezoneSelected,
                )),
          ],
        ),
      ),
    );
  }

  static Widget buildInitialSettingsPage(
    BuildContext context,
    GlobalKey<SpawnOrionTextFieldState> nameTextFieldKey,
    ScrollController scrollController,
    Function(String) onNameChanged,
  ) {
    final l10n = AppLocalizations.of(context)!;

    return GlassApp(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Builder(builder: (context) {
                return Padding(
                  padding: const EdgeInsets.all(5.0),
                  child: SpawnOrionTextField(
                    presetText:
                        config.getString('machineName', category: 'machine'),
                    key: nameTextFieldKey,
                    keyboardHint: l10n.printerName,
                    locale: Localizations.localeOf(context).toString(),
                    scrollController: scrollController,
                    onChanged: onNameChanged,
                  ),
                );
              }),
              OrionKbExpander(textFieldKey: nameTextFieldKey),
              const SizedBox(height: kToolbarHeight),
            ],
          ),
        ),
      ),
    );
  }

  static Widget buildThemePage(
    BuildContext context,
    Function(OrionThemeMode) onThemeChanged,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final themeProvider = context.watch<ThemeProvider>();
    final config = OrionConfig();

    return GlassApp(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.only(left: 16.0, right: 16.0, bottom: 16.0),
          child: LayoutBuilder(
            builder: (context, constraints) {
              // If a vendor theme is present, onboarding can have 6 theme
              // tiles which may overflow smaller displays. When that is the
              // case make the inner content scrollable and constrained so
              // the page doesn't overflow the screen.
              final vendorTheme = config.getThemeSeed('vendor');
              final bool hasVendorTheme = vendorTheme.r != 0 ||
                  vendorTheme.g != 0 ||
                  vendorTheme.b != 0;

              Widget contentColumn = Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  GlassCard(
                    child: Padding(
                      padding: const EdgeInsets.all(10.0),
                      child: Column(
                        children: [
                          GlassThemeSelector(
                            selectedTheme: themeProvider.orionThemeMode,
                            onThemeChanged: onThemeChanged,
                            padding: EdgeInsets.zero,
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (config.getFlag('mandateTheme', category: 'vendor'))
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: GlassCard(
                        elevation: 2,
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                color: Theme.of(context).colorScheme.primary,
                                size: 20,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  l10n.themeVendorLocked,
                                  style: TextStyle(
                                    color: themeProvider.isGlassTheme
                                        ? Colors.white.withValues(alpha: 0.9)
                                        : Theme.of(context)
                                            .colorScheme
                                            .onSurface,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  GlassCard(
                    elevation: 1,
                    child: Padding(
                      padding: const EdgeInsets.all(10.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ThemeColorSelector(
                            config: config,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: kToolbarHeight),
                ],
              );

              if (hasVendorTheme) {
                // Constrain the scrollable area to avoid pushing controls off
                // the screen (approximate safe height).
                final double maxScrollableHeight = constraints.maxHeight;
                return ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: maxScrollableHeight),
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: contentColumn,
                  ),
                );
              }

              return contentColumn;
            },
          ),
        ),
      ),
    );
  }

  static Widget buildWifiPage(
    BuildContext context,
    GlobalKey<WifiScreenState> wifiScreenKey,
    ValueNotifier<bool> isConnected,
    bool initialized,
  ) {
    if (!initialized) {
      return GlassApp(
        child: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return GlassApp(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Flexible(
            child: WifiScreen(
              key: wifiScreenKey,
              isConnected: isConnected,
            ),
          ),
          const SizedBox(height: kToolbarHeight * 1.5),
        ],
      ),
    );
  }

  static Widget buildCompletePage(
    BuildContext context,
    Animation<Offset> completeAnimation,
    String printerName,
  ) {
    final l10n = AppLocalizations.of(context)!;

    return GlassApp(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SlideTransition(
              position: completeAnimation,
              child: Text(
                '$printerName ${l10n.setupCompletionMessage}',
                style: const TextStyle(
                    fontSize: 30, fontWeight: FontWeight.normal),
              ),
            ),
            const SizedBox(height: kToolbarHeight),
          ],
        ),
      ),
    );
  }

  static Widget _buildTimezoneCard(
    BuildContext context,
    String timezone,
    Function(String) onTimezoneSelected,
  ) {
    return GlassCard(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 5.0),
        child: ListTile(
          leading: PhosphorIcon(PhosphorIcons.clock(), size: 45),
          title: Padding(
            padding: const EdgeInsets.only(left: 5.0),
            child: Text(
              timezone,
              style: const TextStyle(fontSize: 24),
            ),
          ),
          onTap: () => onTimezoneSelected(timezone),
        ),
      ),
    );
  }
}

/// A glassmorphic-aware welcome bubble for the onboarding screen
class _GlassBubble extends StatefulWidget {
  final WelcomeBubble bubble;

  const _GlassBubble({
    Key? key,
    required this.bubble,
  }) : super(key: key);

  @override
  _GlassBubbleState createState() => _GlassBubbleState();
}

class _TrailPoint {
  Offset pos;
  double life;

  _TrailPoint(this.pos, this.life);
}

class _GlassBubbleState extends State<_GlassBubble>
    with SingleTickerProviderStateMixin {
  final List<_TrailPoint> _trail = [];
  late final Ticker _ticker;
  Offset? _lastHoverPos;
  int _lastHoverTick = 0;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((_) {
      // Clean up trail points and request repaint while trails exist.
      if (_trail.isNotEmpty) {
        final decay = 0.04; // per frame decay (approx 60fps)
        for (var p in _trail) {
          p.life -= decay;
        }
        _trail.removeWhere((p) => p.life <= 0);
        setState(() {});
      }
    });
    _ticker.start();
  }

  @override
  void dispose() {
    _ticker.stop();
    _ticker.dispose();
    super.dispose();
  }

  void _addTrail(Offset localPos) {
    _trail.insert(0, _TrailPoint(localPos, 1.0));
    if (_trail.length > 10) _trail.removeLast();
  }

  void _applyBumpFromLocal(Offset localPos) {
    // Compute direction from pointer to bubble center in local coordinates
    final center = Offset(widget.bubble.width / 2, widget.bubble.height / 2);
    final delta = localPos - center; // from center -> pointer
    final dist = delta.distance;
    final dir = dist == 0 ? Offset(1, 0) : delta.scale(1 / dist, 1 / dist);

    // Strength falls off with distance; small base impulse plus a distance
    // dependent term so nearer touches feel stronger.
    final maxRadius = max(widget.bubble.width, widget.bubble.height) * 1.6;
    final proximity = (1.0 - (dist / maxRadius).clamp(0.0, 1.0));
    final strength = 60.0 * (0.45 + 0.8 * proximity);

    // push away from pointer (dir points center->pointer)
    final impulse =
        dir.scale(strength / widget.bubble.mass, strength / widget.bubble.mass);
    widget.bubble.velocity += impulse;
  }

  void _onTapDown(TapDownDetails details) {
    _addTrail(details.localPosition);
    _applyBumpFromLocal(details.localPosition);
    setState(() {});
  }

  void _onPanUpdate(DragUpdateDetails details) {
    _addTrail(details.localPosition);
    // Apply a smaller impulse for drags so the movement feels natural
    final center = Offset(widget.bubble.width / 2, widget.bubble.height / 2);
    final delta = details.localPosition - center;
    final dist = delta.distance;
    if (dist > 0) {
      final dir = delta.scale(1 / dist, 1 / dist);
      final strength = 28.0;
      final impulse = dir.scale(
          strength / widget.bubble.mass, strength / widget.bubble.mass);
      widget.bubble.velocity += impulse;
    }
    setState(() {});
  }

  void _onHover(PointerHoverEvent event) {
    // Small nudge on hover movement; avoid applying too often.
    final tick = DateTime.now().millisecondsSinceEpoch;
    if (_lastHoverPos != null) {
      final delta = event.localPosition - _lastHoverPos!;
      final speed = delta.distance;
      if (speed > 3 && (tick - _lastHoverTick) > 80) {
        _addTrail(event.localPosition);
        // subtle impulse proportional to hover speed
        final center =
            Offset(widget.bubble.width / 2, widget.bubble.height / 2);
        final dirDelta = center - event.localPosition;
        final d = dirDelta.distance;
        if (d > 0) {
          final dir = dirDelta.scale(1 / d, 1 / d);
          final strength = (speed * 2).clamp(6.0, 40.0);
          final impulse = dir.scale(
              strength / widget.bubble.mass, strength / widget.bubble.mass);
          widget.bubble.velocity += impulse;
        }
        _lastHoverTick = tick;
      }
    }
    _lastHoverPos = event.localPosition;
  }

  @override
  Widget build(BuildContext context) {
    // Gentle time-based animation derived from system clock. The parent
    // AnimatedBuilder rebuilds frequently so using DateTime here produces
    // a smooth, low-cost per-frame micro-animation (pulse + rotation).
    final t = DateTime.now().millisecondsSinceEpoch / 1000.0 +
        (widget.bubble.position.dx + widget.bubble.position.dy) * 0.001;
    final pulse = 1.0 + 0.035 * sin(2 * pi * t);
    final rot = 0.03 * sin(2 * pi * (t * 0.6));

    final primary = Theme.of(context).colorScheme.primaryContainer;
    final secondary = Theme.of(context).colorScheme.secondaryContainer;

    // Add a gentle multi-frequency drifting translation to give each
    // bubble a more organic, natural motion independent of the physics
    // engine's position updates.
    final phase =
        (widget.bubble.position.dx * 0.01 + widget.bubble.position.dy * 0.007);

    // Amplitudes scale with bubble.size so larger bubbles drift slightly
    // more than smaller ones. Frequencies chosen to avoid obvious
    // repeating patterns.
    final driftAX = widget.bubble.size * 0.014;
    final driftBX = widget.bubble.size * 0.007;
    final driftAY = widget.bubble.size * 0.012;
    final driftBY = widget.bubble.size * 0.006;

    final driftX = driftAX * sin(2 * pi * (t * 0.18 + phase)) +
        driftBX * sin(2 * pi * (t * 0.66 + phase * 1.3));
    final driftY = driftAY * cos(2 * pi * (t * 0.22 + phase * 0.9)) +
        driftBY * cos(2 * pi * (t * 0.71 + phase * 1.1));

    // Build trail visuals (drawn beneath the bubble content)
    final trailWidgets = <Widget>[];

    // Render proximity trails provided by the bubble model (global coords -> local)
    for (var i = 0; i < widget.bubble.proximityTrails.length; i++) {
      final pt = widget.bubble.proximityTrails[i];
      final local = pt.pos - widget.bubble.position;
      final size = widget.bubble.size * (0.28 + (i * 0.04));
      final opacity = (pt.life.clamp(0.0, 1.0) * 0.55);
      trailWidgets.add(Positioned(
        left: local.dx - size / 2,
        top: local.dy - size / 2,
        child: IgnorePointer(
          child: Opacity(
            opacity: opacity,
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    primary.withValues(alpha: opacity * 0.9),
                    primary.withValues(alpha: opacity * 0.06),
                  ],
                ),
              ),
            ),
          ),
        ),
      ));
    }
    for (var i = 0; i < _trail.length; i++) {
      final p = _trail[i];
      final size = widget.bubble.size * (0.22 + (i * 0.06));
      final opacity = (p.life.clamp(0.0, 1.0) * 0.7);
      trailWidgets.add(Positioned(
        left: p.pos.dx - size / 2,
        top: p.pos.dy - size / 2,
        child: IgnorePointer(
          child: Opacity(
            opacity: opacity,
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    primary.withValues(alpha: opacity),
                    primary.withValues(alpha: opacity * 0.04),
                  ],
                ),
              ),
            ),
          ),
        ),
      ));
    }

    return Transform.translate(
      offset: Offset(driftX, driftY),
      child: Transform.rotate(
        angle: rot,
        child: Transform.scale(
          scale: pulse,
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            onHover: _onHover,
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTapDown: _onTapDown,
              onPanUpdate: _onPanUpdate,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // Trails
                  ...trailWidgets,
                  // Bubble
                  Container(
                    padding: EdgeInsets.all(widget.bubble.padding),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          primary.withValues(alpha: 0.95),
                          secondary.withValues(alpha: 0.85),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(widget.bubble.size),
                      boxShadow: [
                        BoxShadow(
                          color: Theme.of(context)
                              .colorScheme
                              .primary
                              .withValues(alpha: 0.12),
                          blurRadius: 18,
                          offset: Offset(0, 6),
                        ),
                        BoxShadow(
                          color: Colors.black.withOpacity(0.06),
                          blurRadius: 6,
                          offset: Offset(0, 2),
                        ),
                      ],
                      border: Border.all(
                        color: Theme.of(context)
                            .colorScheme
                            .onPrimaryContainer
                            .withValues(alpha: 0.06),
                        width: 1.0,
                      ),
                    ),
                    child: Text(
                      widget.bubble.message,
                      style: TextStyle(
                        fontFamily: 'AtkinsonHyperlegible',
                        fontFamilyFallback: ['NotoSansCJK'],
                        fontSize: widget.bubble.size * 0.82,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                        shadows: [
                          Shadow(
                            color: Colors.black.withOpacity(0.15),
                            blurRadius: 4,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

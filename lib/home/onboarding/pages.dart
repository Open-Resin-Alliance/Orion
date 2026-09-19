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
import 'package:provider/provider.dart';
import 'package:country_flags/country_flags.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'package:orion/glasser/glasser.dart';
import 'package:flutter_i18n/flutter_i18n.dart';
import 'package:orion/settings/about_screen.dart';
import 'package:orion/settings/wifi_screen.dart';
import 'package:orion/util/locales/all_countries.dart';
import 'package:orion/util/locales/country_regions.dart';
import 'package:orion/util/locales/available_languages.dart';
import 'package:orion/util/orion_config.dart';
import 'package:orion/util/orion_kb/orion_keyboard_expander.dart';
import 'package:orion/util/orion_kb/orion_textfield_spawn.dart';
import 'package:orion/util/orion_spacing.dart';
import 'package:orion/util/providers/theme_provider.dart';
import 'package:orion/util/theme_color_selector.dart';

import 'welcome_bubbles.dart';

class OnboardingPages {
  static Widget buildWelcomePage(
    BuildContext context,
    GlobalKey<WelcomeBubblesViewState> bubblesKey,
    List<WelcomeBubble> welcomeBubbles,
    Animation<double> holeAnimation,
  ) {
    final lowGraphicsMode =
        OrionConfig().getFlag('lowGraphicsMode', category: 'vendor');

    return Center(
      child: Stack(
        children: [
          // The dim and the dot grid, opening from the centre as the reveal
          // runs: one painter, one layer, repainted straight from the animation
          // instead of rebuilt through a ShaderMask and an Opacity.
          Positioned.fill(
            child: CustomPaint(
              size: Size.infinite,
              painter: WelcomeRevealPainter(
                progress: holeAnimation,
                tints: _revealTints(context),
                dotColor: Theme.of(context).colorScheme.onPrimaryContainer,
                repaint: holeAnimation,
              ),
            ),
          ),
          // The whole field is one layer: one ticker, one painter, and a
          // repaint boundary so a frame of drifting bubbles never dirties the
          // rest of the welcome screen.
          Positioned.fill(
            child: RepaintBoundary(
              child: WelcomeBubblesView(
                key: bubblesKey,
                bubbles: welcomeBubbles,
                lowGraphics: lowGraphicsMode,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// The dim the welcome overlay uses.
  ///
  /// Glass themes sit on the gradient GlassApp paints behind every page, so the
  /// welcome dims that gradient. Every other theme dims its own surface: a
  /// hard-coded gradient made the welcome look like the glass theme on a dark
  /// printer, whichever theme was actually chosen.
  static List<Color> _revealTints(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final wash = Colors.black.withValues(alpha: 0.5);

    if (!themeProvider.isGlassTheme) {
      return [Color.alphaBlend(wash, Theme.of(context).colorScheme.surface)];
    }

    return GlassGradientUtils.resolveGradient(themeProvider: themeProvider)
        .map((color) => Color.alphaBlend(wash, color))
        .toList(growable: false);
  }

  static Widget buildLanguagePage(
    BuildContext context,
    Function(String) onLanguageSelected,
  ) {
    // No locale consumer here on purpose: the grid shows each language's own
    // name and its flag, so a locale change has nothing to rebuild. Wrapping it
    // in one meant every tap re-rendered eight flag drawings and their cards.
    return GlassApp(
      child: Padding(
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
      ),
    );
  }

  static Widget buildRegionCountryPage(
    BuildContext context,
    String? selectedLanguage,
    Function(String) onCountrySelected,
  ) {
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
                FlutterI18n.translate(context, 'region.suggestedCountries'),
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
              FlutterI18n.translate(context, 'region.allCountries'),
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
            }),
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
    final countryTimezones = countryData[selectedCountry]?['timezones'];

    if (countryTimezones == null) {
      return GlassApp(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              FlutterI18n.translate(context, 'timezone.noneAvailable'),
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
              FlutterI18n.translate(context, 'timezone.suggested'),
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
              FlutterI18n.translate(context, 'timezone.other'),
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
                    keyboardHint:
                        FlutterI18n.translate(context, 'printer.name'),
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
                                  FlutterI18n.translate(
                                      context, 'theme.vendorLocked'),
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

  /// A step that offers to run a wizard: what it is for, what it does, and the
  /// way in — plus a decline for skipping it.
  ///
  /// Used by the leveling check and the resin calibration, so both steps read
  /// as the same kind of offer.
  ///
  /// [onAction] is null when the wizard cannot be offered at all — no leveling
  /// data to check, say. The button is then left out rather than shown dead, and
  /// the step becomes the notice the heading and detail describe, with
  /// [secondaryKey] carrying the way on.
  static Widget buildWizardOfferPage(
    BuildContext context, {
    required String headingKey,
    required String detailKey,
    required String actionKey,
    required IconData actionIcon,
    required VoidCallback? onAction,
    required VoidCallback onDecline,
    String secondaryKey = 'common.decline',
  }) {
    final theme = Theme.of(context);
    return GlassApp(
      child: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 20),
                Text(
                  FlutterI18n.translate(context, headingKey),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  FlutterI18n.translate(context, detailKey),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 20,
                    height: 1.4,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.72),
                  ),
                ),
                const SizedBox(height: OrionSpacing.controlGap + 24),
                if (onAction != null) ...[
                  SizedBox(
                    width: 320,
                    child: GlassButton(
                      tint: GlassButtonTint.positive,
                      onPressed: onAction,
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 65),
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(actionIcon, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              FlutterI18n.translate(context, actionKey),
                              style: const TextStyle(
                                  fontSize: 21, fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: OrionSpacing.controlGap),
                ],
                SizedBox(
                  width: 320,
                  child: GlassButton(
                    // With nothing to offer this is the only way on, so it
                    // carries the action tint and the way-on label.
                    tint: onAction == null
                        ? GlassButtonTint.positive
                        : GlassButtonTint.neutral,
                    onPressed: onDecline,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 55),
                    ),
                    child: Text(
                      FlutterI18n.translate(context, secondaryKey),
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                const SizedBox(height: kToolbarHeight),
              ],
            ),
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
    return GlassApp(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SlideTransition(
              position: completeAnimation,
              child: Text(
                '$printerName ${FlutterI18n.translate(context, 'complete.completionMessage')}',
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

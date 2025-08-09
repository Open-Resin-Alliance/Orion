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

import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:provider/provider.dart';
import 'package:country_flags/country_flags.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'package:orion/glasser/glasser.dart';
import 'package:orion/l10n/generated/app_localizations.dart';
import 'package:orion/settings/about_screen.dart';
import 'package:orion/settings/wifi_screen.dart';
import 'package:orion/util/locales/all_countries.dart';
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
  ) {
    return GlassApp(
      child: Center(
        child: Stack(
          children: [
            CustomPaint(
              size: Size.infinite,
              painter: WelcomePatternPainter(context),
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

    final allCountries = countryData.entries
        .map((e) => {'name': e.key, 'code': e.value['code']})
        .where((country) => !suggestedCountryCodes.contains(country['code']))
        .toList()
      ..sort((a, b) => a['name']!.compareTo(b['name']!));

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
              Text(
                l10n.regionAllCountries,
                style:
                    const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
            ],
            ...allCountries.map(
              (country) => _buildCountryCard(
                context,
                country.map((key, value) => MapEntry(key, value.toString())),
                onCountrySelected,
              ),
            ),
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
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Center(
          child: Padding(
            padding:
                const EdgeInsets.only(left: 16.0, right: 16.0, bottom: 16.0),
            child: Column(
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
                                      : Theme.of(context).colorScheme.onSurface,
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
                        const SizedBox(height: 10.0),
                        ThemeColorSelector(
                          config: config,
                        ),
                        const SizedBox(height: 10.0),
                      ],
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
class _GlassBubble extends StatelessWidget {
  final WelcomeBubble bubble;

  const _GlassBubble({
    required this.bubble,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(bubble.padding),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .primaryContainer
            .withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(bubble.size),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).shadowColor.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        bubble.message,
        style: TextStyle(
          fontSize: bubble.size * 0.8,
          color: Theme.of(context).colorScheme.onPrimaryContainer,
        ),
      ),
    );
  }
}

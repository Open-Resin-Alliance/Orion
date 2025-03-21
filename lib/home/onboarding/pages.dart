/*
* Orion - Onboarding Screen - Pages
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
import 'package:flutter/scheduler.dart';
import 'package:orion/settings/about_screen.dart';
import 'package:provider/provider.dart';
import 'package:country_flags/country_flags.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import 'package:orion/util/orion_kb/orion_keyboard_expander.dart';
import 'package:orion/util/orion_kb/orion_textfield_spawn.dart';
import 'package:orion/settings/wifi_screen.dart';
import 'package:orion/util/orion_list_tile.dart';
import 'package:orion/util/theme_color_selector.dart';
import 'package:orion/util/providers/theme_provider.dart';
import 'package:orion/util/orion_config.dart';
import 'package:orion/util/locales/all_countries.dart';
import 'package:orion/util/locales/available_languages.dart';
import 'package:orion/util/providers/locale_provider.dart';
import 'welcome_bubbles.dart';

class OnboardingPages {
  static Widget buildWelcomePage(
    BuildContext context,
    AnimationController bubbleController,
    List<WelcomeBubble> welcomeBubbles,
  ) {
    return Center(
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
                      child: Container(
                        padding: EdgeInsets.all(bubble.padding),
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .primaryContainer
                              .withValues(alpha: 0.8),
                          borderRadius: BorderRadius.circular(bubble.size),
                          boxShadow: [
                            BoxShadow(
                              color: Theme.of(context)
                                  .shadowColor
                                  .withValues(alpha: 0.1),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Text(
                          bubble.message,
                          style: TextStyle(
                            fontSize: bubble.size * 0.8,
                            color: Theme.of(context)
                                .colorScheme
                                .onPrimaryContainer,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  static Widget buildLanguagePage(
    BuildContext context,
    Function(String) onLanguageSelected,
  ) {
    return Consumer<LocaleProvider>(
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

              return Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => onLanguageSelected(language['code']!),
                  child: GridTile(
                    footer: Card(
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.only(
                          bottomLeft: Radius.circular(10),
                          bottomRight: Radius.circular(10),
                        ),
                      ),
                      color: Colors.transparent,
                      elevation: 0,
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

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: ListView(
        children: [
          if (suggestedCountries.isNotEmpty) ...[
            Text(
              l10n.regionSuggestedCountries,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ...suggestedCountries.map(
              (country) =>
                  _buildCountryCard(context, country, onCountrySelected),
            ),
            const SizedBox(height: 16),
            Text(
              l10n.regionAllCountries,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
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
    );
  }

  static Widget _buildCountryCard(
    BuildContext context,
    Map<String, String> country,
    Function(String) onCountrySelected,
  ) {
    final nativeName = country['nativeName'];
    final name = country['name']!;

    return Card(
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
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            l10n.timezoneNoneAvailable,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 20),
          ),
        ),
      );
    }

    final suggestedTimezones = countryTimezones['suggested'] as List<String>;
    final otherTimezones = countryTimezones['other'] as List<String>;

    return Padding(
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
    );
  }

  static Widget buildInitialSettingsPage(
    BuildContext context,
    GlobalKey<SpawnOrionTextFieldState> nameTextFieldKey,
    ScrollController scrollController,
    Function(String) onNameChanged,
  ) {
    final l10n = AppLocalizations.of(context)!;

    return Center(
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
    );
  }

  static Widget buildThemePage(
    BuildContext context,
    Function(ThemeMode) onThemeChanged,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = themeProvider.themeMode == ThemeMode.dark;
    final config = OrionConfig();

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Card.outlined(
              child: Padding(
                padding: const EdgeInsets.all(10.0),
                child: OrionListTile(
                  title: l10n.themeDarkMode,
                  icon: PhosphorIcons.moonStars,
                  value: isDark,
                  onChanged: (bool value) {
                    onThemeChanged(value ? ThemeMode.dark : ThemeMode.light);
                  },
                ),
              ),
            ),
            Card.outlined(
              elevation: 1,
              child: Padding(
                padding: const EdgeInsets.all(10.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 10.0),
                    ThemeColorSelector(
                      config: config,
                      changeThemeMode: onThemeChanged,
                    ),
                    const SizedBox(height: 10.0),
                  ],
                ),
              ),
            ),
            if (config.getFlag('mandateTheme', category: 'vendor'))
              Card.outlined(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: BorderSide(color: Theme.of(context).colorScheme.error),
                ),
                child: Padding(
                  padding: const EdgeInsets.only(
                    top: 2.5,
                    bottom: 2.5,
                    left: 10.0,
                    right: 10.0,
                  ),
                  child: Text(
                    l10n.themeVendorLocked,
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ),
              ),
            const SizedBox(height: kToolbarHeight),
          ],
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
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    return Column(
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
    );
  }

  static Widget buildCompletePage(
    BuildContext context,
    Animation<Offset> completeAnimation,
    String printerName,
  ) {
    final l10n = AppLocalizations.of(context)!;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SlideTransition(
            position: completeAnimation,
            child: Text(
              '$printerName ${l10n.setupCompletionMessage}',
              style:
                  const TextStyle(fontSize: 30, fontWeight: FontWeight.normal),
            ),
          ),
          const SizedBox(height: kToolbarHeight),
        ],
      ),
    );
  }

  static Widget _buildTimezoneCard(
    BuildContext context,
    String timezone,
    Function(String) onTimezoneSelected,
  ) {
    return Card(
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

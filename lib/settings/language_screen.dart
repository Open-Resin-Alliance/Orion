/*
* Orion - Language Selection Screen
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

import 'package:country_flags/country_flags.dart';
import 'package:flutter/material.dart';
import 'package:flutter_i18n/flutter_i18n.dart';
import 'package:orion/util/widgets/system_status_widget.dart';
import 'package:provider/provider.dart';

import 'package:orion/glasser/glasser.dart';
import 'package:orion/util/locales/available_languages.dart';
import 'package:orion/util/orion_spacing.dart';
import 'package:orion/util/providers/locale_provider.dart';
import 'package:orion/widgets/orion_app_bar.dart';

class LanguageScreen extends StatelessWidget {
  const LanguageScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GlassApp(
      child: Scaffold(
        appBar: OrionAppBar(
          title: Text(FlutterI18n.translate(context, 'setup.languageTitle')),
          toolbarHeight: Theme.of(context).appBarTheme.toolbarHeight,
          actions: <Widget>[
            SystemStatusWidget(),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.only(
            left: OrionSpacing.settingsScreenHorizontal,
            right: OrionSpacing.settingsScreenHorizontal,
            top: OrionSpacing.screenTop,
            bottom: OrionSpacing.screenBottomNavClearance,
          ),
          child: Consumer<LocaleProvider>(
            builder: (context, localeProvider, _) {
              final currentLocale = localeProvider.locale;
              final currentCode =
                  '${currentLocale.languageCode}_${currentLocale.countryCode}';

              return Column(
                children: [
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final gridWidth = constraints.maxWidth;
                        final gridHeight = constraints.maxHeight;
                        final cardWidth = (gridWidth - 6) / 2;
                        final cardHeight = (gridHeight - 3 * 6) / 4;
                        final aspectRatio = cardWidth / cardHeight;

                        return GridView.builder(
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                            childAspectRatio: aspectRatio,
                            mainAxisSpacing: 6,
                            crossAxisSpacing: 6,
                            crossAxisCount: 2,
                          ),
                          itemCount: availableLanguages.length,
                          itemBuilder: (context, index) {
                            final language = availableLanguages[index];
                            final isSelected = language['code'] == currentCode;
                            final primary =
                                Theme.of(context).colorScheme.primary;
                            final isDark =
                                Theme.of(context).brightness == Brightness.dark;

                            return GlassCard(
                              elevation: isSelected ? 4 : 1,
                              outlined: isSelected,
                              accentColor: isSelected ? primary : null,
                              accentOpacity:
                                  isSelected ? (isDark ? 0.22 : 0.06) : 0.06,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(10),
                                onTap: () {
                                  final parts = language['code']!.split('_');
                                  if (parts.length == 2) {
                                    localeProvider
                                        .setLocale(Locale(parts[0], parts[1]));
                                  }
                                },
                                child: Center(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12),
                                    child: Row(
                                      children: [
                                        CountryFlag.fromCountryCode(
                                          language['flag']!,
                                          height: 40,
                                          width: 60,
                                          shape: RoundedRectangle(6),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            language['nativeName']!,
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              fontSize: 22,
                                              fontWeight: isSelected
                                                  ? FontWeight.bold
                                                  : FontWeight.normal,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        if (isSelected)
                                          Icon(
                                            Icons.check_circle,
                                            color: primary,
                                            size: 28,
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_de.dart';
import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_fr.dart';
import 'app_localizations_hr.dart';
import 'app_localizations_ja.dart';
import 'app_localizations_ko.dart';
import 'app_localizations_pl.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('de'),
    Locale('en'),
    Locale('es'),
    Locale('fr'),
    Locale('hr'),
    Locale('ja'),
    Locale('ko'),
    Locale('pl'),
    Locale('zh'),
    Locale('zh', 'CN'),
    Locale('zh', 'TW')
  ];

  /// No description provided for @sectionCommon.
  ///
  /// In en, this message translates to:
  /// **'Common'**
  String get sectionCommon;

  /// No description provided for @commonNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get commonNext;

  /// No description provided for @commonBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get commonBack;

  /// No description provided for @commonSkip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get commonSkip;

  /// No description provided for @commonCompleteSetup.
  ///
  /// In en, this message translates to:
  /// **'Complete Setup'**
  String get commonCompleteSetup;

  /// No description provided for @sectionSetup.
  ///
  /// In en, this message translates to:
  /// **'Setup'**
  String get sectionSetup;

  /// No description provided for @setupGetStarted.
  ///
  /// In en, this message translates to:
  /// **'Get Started'**
  String get setupGetStarted;

  /// No description provided for @setupLanguageTitle.
  ///
  /// In en, this message translates to:
  /// **'Select Language'**
  String get setupLanguageTitle;

  /// No description provided for @setupRegionTitle.
  ///
  /// In en, this message translates to:
  /// **'Select Region'**
  String get setupRegionTitle;

  /// No description provided for @setupTimezoneTitle.
  ///
  /// In en, this message translates to:
  /// **'Select Timezone'**
  String get setupTimezoneTitle;

  /// No description provided for @setupNameTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose a Name'**
  String get setupNameTitle;

  /// No description provided for @setupThemeTitle.
  ///
  /// In en, this message translates to:
  /// **'Select Theme'**
  String get setupThemeTitle;

  /// No description provided for @setupWifiTitle.
  ///
  /// In en, this message translates to:
  /// **'Connect to WiFi'**
  String get setupWifiTitle;

  /// No description provided for @setupCompleteTitle.
  ///
  /// In en, this message translates to:
  /// **''**
  String get setupCompleteTitle;

  /// No description provided for @sectionRegion.
  ///
  /// In en, this message translates to:
  /// **'Region'**
  String get sectionRegion;

  /// No description provided for @regionSuggestedCountries.
  ///
  /// In en, this message translates to:
  /// **'Suggested Countries'**
  String get regionSuggestedCountries;

  /// No description provided for @regionAllCountries.
  ///
  /// In en, this message translates to:
  /// **'All Countries'**
  String get regionAllCountries;

  /// No description provided for @sectionTimezone.
  ///
  /// In en, this message translates to:
  /// **'Timezone'**
  String get sectionTimezone;

  /// No description provided for @timezoneSuggested.
  ///
  /// In en, this message translates to:
  /// **'Suggested Timezones'**
  String get timezoneSuggested;

  /// No description provided for @timezoneOther.
  ///
  /// In en, this message translates to:
  /// **'Other Timezones'**
  String get timezoneOther;

  /// No description provided for @timezoneNoneAvailable.
  ///
  /// In en, this message translates to:
  /// **'No timezones available for selected region.\nDefaulting to UTC.'**
  String get timezoneNoneAvailable;

  /// No description provided for @sectionPrinter.
  ///
  /// In en, this message translates to:
  /// **'Printer'**
  String get sectionPrinter;

  /// No description provided for @printerName.
  ///
  /// In en, this message translates to:
  /// **'Printer Name'**
  String get printerName;

  /// No description provided for @sectionTheme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get sectionTheme;

  /// No description provided for @themeDarkMode.
  ///
  /// In en, this message translates to:
  /// **'Dark Mode'**
  String get themeDarkMode;

  /// No description provided for @themeVendorLocked.
  ///
  /// In en, this message translates to:
  /// **'Theme has been set by Vendor'**
  String get themeVendorLocked;

  /// No description provided for @themePurple.
  ///
  /// In en, this message translates to:
  /// **'Purple'**
  String get themePurple;

  /// No description provided for @themeBlue.
  ///
  /// In en, this message translates to:
  /// **'Blue'**
  String get themeBlue;

  /// No description provided for @themeGreen.
  ///
  /// In en, this message translates to:
  /// **'Green'**
  String get themeGreen;

  /// No description provided for @themeRed.
  ///
  /// In en, this message translates to:
  /// **'Red'**
  String get themeRed;

  /// No description provided for @themeOrange.
  ///
  /// In en, this message translates to:
  /// **'Orange'**
  String get themeOrange;

  /// No description provided for @themeColor.
  ///
  /// In en, this message translates to:
  /// **'Theme Color'**
  String get themeColor;

  /// No description provided for @sectionWifi.
  ///
  /// In en, this message translates to:
  /// **'WiFi'**
  String get sectionWifi;

  /// No description provided for @wifiSkipTitle.
  ///
  /// In en, this message translates to:
  /// **'Skip WiFi Setup?'**
  String get wifiSkipTitle;

  /// No description provided for @wifiSkipMessage.
  ///
  /// In en, this message translates to:
  /// **'You can always connect to WiFi later in settings'**
  String get wifiSkipMessage;

  /// No description provided for @wifiConnectNow.
  ///
  /// In en, this message translates to:
  /// **'Connect Now'**
  String get wifiConnectNow;

  /// No description provided for @wifiSkipAnyway.
  ///
  /// In en, this message translates to:
  /// **'Skip Anyway'**
  String get wifiSkipAnyway;

  /// No description provided for @wifiDisconnectTitle.
  ///
  /// In en, this message translates to:
  /// **'Disconnect from WiFi?'**
  String get wifiDisconnectTitle;

  /// No description provided for @wifiDisconnectMessage.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to disconnect from the current network?'**
  String get wifiDisconnectMessage;

  /// No description provided for @wifiStayConnected.
  ///
  /// In en, this message translates to:
  /// **'Stay Connected'**
  String get wifiStayConnected;

  /// No description provided for @wifiDisconnect.
  ///
  /// In en, this message translates to:
  /// **'Disconnect'**
  String get wifiDisconnect;

  /// No description provided for @sectionComplete.
  ///
  /// In en, this message translates to:
  /// **'Complete'**
  String get sectionComplete;

  /// No description provided for @setupCompletionMessage.
  ///
  /// In en, this message translates to:
  /// **'is ready to go!'**
  String get setupCompletionMessage;

  /// No description provided for @homePowerOptions.
  ///
  /// In en, this message translates to:
  /// **'Power Options'**
  String get homePowerOptions;

  /// No description provided for @homePowerRemote.
  ///
  /// In en, this message translates to:
  /// **'(Remote)'**
  String get homePowerRemote;

  /// No description provided for @homePowerLocal.
  ///
  /// In en, this message translates to:
  /// **'(Local)'**
  String get homePowerLocal;

  /// No description provided for @homeFirmwareRestart.
  ///
  /// In en, this message translates to:
  /// **'Firmware Restart'**
  String get homeFirmwareRestart;

  /// No description provided for @homeRebootSystem.
  ///
  /// In en, this message translates to:
  /// **'Reboot System'**
  String get homeRebootSystem;

  /// No description provided for @homeShutdownSystem.
  ///
  /// In en, this message translates to:
  /// **'Shutdown System'**
  String get homeShutdownSystem;

  /// No description provided for @homeBtnPrint.
  ///
  /// In en, this message translates to:
  /// **'Print'**
  String get homeBtnPrint;

  /// No description provided for @homeBtnTools.
  ///
  /// In en, this message translates to:
  /// **'Tools'**
  String get homeBtnTools;

  /// No description provided for @homeBtnSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get homeBtnSettings;

  /// No description provided for @printUSBAvailable.
  ///
  /// In en, this message translates to:
  /// **'USB Available'**
  String get printUSBAvailable;

  /// No description provided for @printUSBNotAvailable.
  ///
  /// In en, this message translates to:
  /// **'USB Not Available'**
  String get printUSBNotAvailable;

  /// No description provided for @printTitleInternal.
  ///
  /// In en, this message translates to:
  /// **'Print Files (Internal)'**
  String get printTitleInternal;

  /// No description provided for @printTitleUSB.
  ///
  /// In en, this message translates to:
  /// **'Print Files (USB)'**
  String get printTitleUSB;

  /// No description provided for @printTitleApiError.
  ///
  /// In en, this message translates to:
  /// **'Odyssey API Error'**
  String get printTitleApiError;

  /// No description provided for @printTitleUSBError.
  ///
  /// In en, this message translates to:
  /// **'(USB)'**
  String get printTitleUSBError;

  /// No description provided for @printTitleInternalError.
  ///
  /// In en, this message translates to:
  /// **'(Internal)'**
  String get printTitleInternalError;

  /// No description provided for @printFetchFail.
  ///
  /// In en, this message translates to:
  /// **'Failed to fetch files'**
  String get printFetchFail;

  /// No description provided for @printNotPermitted.
  ///
  /// In en, this message translates to:
  /// **'Operation not permitted'**
  String get printNotPermitted;

  /// No description provided for @printSwitchUSB.
  ///
  /// In en, this message translates to:
  /// **'Switch to USB'**
  String get printSwitchUSB;

  /// No description provided for @printUSBUnavailable.
  ///
  /// In en, this message translates to:
  /// **'USB unavailable'**
  String get printUSBUnavailable;

  /// No description provided for @printInternalSwitch.
  ///
  /// In en, this message translates to:
  /// **'Switch to Internal'**
  String get printInternalSwitch;

  /// No description provided for @printParentDir.
  ///
  /// In en, this message translates to:
  /// **'Parent Directory'**
  String get printParentDir;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>[
        'de',
        'en',
        'es',
        'fr',
        'hr',
        'ja',
        'ko',
        'pl',
        'zh'
      ].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when language+country codes are specified.
  switch (locale.languageCode) {
    case 'zh':
      {
        switch (locale.countryCode) {
          case 'CN':
            return AppLocalizationsZhCn();
          case 'TW':
            return AppLocalizationsZhTw();
        }
        break;
      }
  }

  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'de':
      return AppLocalizationsDe();
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
    case 'fr':
      return AppLocalizationsFr();
    case 'hr':
      return AppLocalizationsHr();
    case 'ja':
      return AppLocalizationsJa();
    case 'ko':
      return AppLocalizationsKo();
    case 'pl':
      return AppLocalizationsPl();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}

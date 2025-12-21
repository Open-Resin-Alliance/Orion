/*
* Orion - Onboarding Screen
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

// ignore_for_file: unused_field

import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:animations/animations.dart';
import 'package:logging/logging.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';

import 'package:orion/glasser/glasser.dart';
import 'package:orion/home/home_screen.dart';
import 'package:orion/home/onboarding/animations.dart';
import 'package:orion/home/onboarding/pages.dart';
import 'package:orion/home/onboarding/welcome_bubbles.dart';
import 'package:orion/l10n/generated/app_localizations.dart';
import 'package:orion/settings/wifi_screen.dart';
import 'package:orion/util/locales/all_countries.dart';
import 'package:orion/util/locales/available_languages.dart';
import 'package:orion/util/onboarding_utils.dart';
import 'package:orion/util/orion_config.dart';
import 'package:orion/util/orion_kb/orion_textfield_spawn.dart';
import 'package:orion/util/providers/locale_provider.dart';
import 'package:orion/util/providers/theme_provider.dart';
import 'package:orion/backend_service/athena_iot/athena_feature_manager.dart';
import 'package:orion/util/providers/wifi_provider.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  OnboardingScreenState createState() => OnboardingScreenState();
}

class OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  // Controllers
  final ScrollController _scrollController = ScrollController();

  // Keys
  GlobalKey<SpawnOrionTextFieldState> _nameTextFieldKey =
      GlobalKey<SpawnOrionTextFieldState>();
  final GlobalKey<WifiScreenState> _wifiScreenKey =
      GlobalKey<WifiScreenState>();

  // Animation related
  late AnimationController _welcomeAnimationController;
  late AnimationController _completeAnimationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<Offset> _completeAnimation;
  final String _currentWelcome = 'Welcome';
  final String _nextWelcome = 'Welcome';

  // Configuration and system state
  final OrionConfig config = OrionConfig();
  final Logger _logger = Logger('Onboarding');
  late Future<void> _wifiScreenFuture;
  String _printerName = '';
  bool _isLinuxPlatform = false;
  final ValueNotifier<bool> isConnected = ValueNotifier(false);

  // Navigation state
  int _currentPage = 0;

  // Locale and region settings
  String? _selectedCountry;
  String? _selectedLanguage;

  // Vendor information
  late String vendorName;
  late String vendorMachineName;
  late String vendorUrl;

  // Static UI text
  List<String> _getTitles(AppLocalizations l10n) => [
        '',
        l10n.setupLanguageTitle,
        l10n.setupRegionTitle,
        l10n.setupTimezoneTitle,
        l10n.setupNameTitle,
        l10n.setupThemeTitle,
        l10n.setupWifiTitle,
        l10n.setupCompleteTitle
      ];

  List<String> _getBtnTitles(AppLocalizations l10n) => [
        l10n.setupGetStarted,
        l10n.commonNext,
        l10n.commonNext,
        l10n.commonNext,
        l10n.commonNext,
        l10n.commonNext,
        l10n.commonNext,
        l10n.commonCompleteSetup
      ];

  // Add this to the existing class variables
  late String _currentLocale;

  // Cache for prebuilt pages to avoid expensive rebuilds during transition
  final Map<int, Widget> _prebuiltPages = {};

  // Add these to class variables
  final Random _random = Random();
  final List<WelcomeBubble> _welcomeBubbles = [];
  late AnimationController _bubbleController;

  // Add title animation controller
  late AnimationController _titleAnimationController;
  late Animation<Offset> _titleSlideAnimation;
  late Animation<double> _titleFadeAnimation;

  // Add page transition animation controller
  late Animation<double> _pageTransitionAnimation;

  // Add this flag to track initialization
  bool _wifiInitialized = false;

  // Add new animation controller for page transitions
  late AnimationController _transitionController;

  // Add new animation controller for title transition
  late AnimationController _titleSlideController;
  late Animation<Offset> _titleSlideInAnimation;
  late Animation<double> _titleOpacityAnimation;

  // Add animation controller for the hole reveal effect
  late AnimationController _holeAnimationController;
  late Animation<double> _holeAnimation;

  // Add field to track previous page
  late int _previousPage = 0;

  // Add this field to track appBar transparency
  late bool _isAppBarTransparent = true;

  // Add fields for welcome overlay transition
  bool _showWelcomeOverlay = true;
  bool _fabVisible = true;

  @override
  void initState() {
    super.initState();
    _currentLocale = config.getString('orionLocale', category: 'machine');
    _initializeSettings();
    _initializeSystemState();
    _initializeAnimations();
  }

  void _initializeSystemState() async {
    _isLinuxPlatform = Platform.isLinux;
    if (_isLinuxPlatform) {
      isConnected.value = await OnboardingUtils.checkInitialConnectionStatus();
    }
    final timezone = await OnboardingUtils.getSystemTimezone();
    if (timezone != null) {
      config.setString('timezone', timezone, category: 'machine');
    }

    // Fetch printer name and serial from Athena as soon as onboarding loads
    if (config.isNanoDlpMode()) {
      try {
        final mgr = AthenaFeatureManager();
        await mgr.fetchAndApplyFeatureFlags();
        // Reload printer name from config in case it was updated
        final name = config.getString('machineName', category: 'machine');
        if (name.isNotEmpty && mounted) {
          setState(() {
            _printerName = name;
          });
        }
      } catch (e) {
        _logger.fine('Failed to fetch initial printer data: $e');
      }
    }
  }

  void _initializeAnimations() {
    _bubbleController = AnimationController(
      duration: const Duration(seconds: 30),
      vsync: this,
    )..repeat();

    _completeAnimationController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    );

    _titleAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _titleSlideController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _transitionController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _holeAnimationController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    _holeAnimation = CurvedAnimation(
      parent: _holeAnimationController,
      curve: Curves.easeInOut,
    );

    // Initialize the page transition animation here
    _pageTransitionAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _transitionController,
      curve: Curves.easeInOut,
    ));

    // Use OnboardingAnimations to create animations
    _completeAnimation = OnboardingAnimations.createCompleteAnimation(
        _completeAnimationController);
    _titleSlideAnimation =
        OnboardingAnimations.createTitleAnimation(_titleAnimationController);
    _titleFadeAnimation =
        OnboardingAnimations.createFadeAnimation(_titleAnimationController);
    _titleSlideInAnimation =
        OnboardingAnimations.createSlideAnimation(_titleSlideController);
    _titleOpacityAnimation =
        OnboardingAnimations.createFadeAnimation(_titleSlideController);
  }

  void _initializeWelcomeBubbles() {
    _welcomeBubbles.clear();

    final size = MediaQuery.of(context).size;
    const int bubbleCount = 9;
    final random = Random();

    final cellWidth = size.width / 3;
    final cellHeight = size.height / 3;

    int index = 0;
    welcomeMessages.entries.take(bubbleCount).forEach((entry) {
      final row = (index / 3).floor();
      final col = index % 3;

      // Add some randomness to initial position within cell
      final x = (col * cellWidth) + random.nextDouble() * (cellWidth * 0.5);
      final y = (row * cellHeight) + random.nextDouble() * (cellHeight * 0.5);

      // Set initial speed and direction
      final angle = random.nextDouble() * 2 * pi;
      final baseSpeed =
          3.0 + random.nextDouble() * 3.0; // Much slower: 3-6 pixels/second

      // Calculate initial velocity components
      final vx = cos(angle) * baseSpeed;
      final vy = sin(angle) * baseSpeed;

      _welcomeBubbles.add(
        WelcomeBubble(
          message: entry.value,
          position: Offset(x, y),
          size: 24 + random.nextDouble() * 16,
          velocity: Offset(vx, vy), // Initial velocity that will be maintained
          mass: 4.0 + random.nextDouble() * 4.0, // Higher mass: 4-8
          bounciness:
              0.2 + random.nextDouble() * 0.2, // Lower bounciness: 0.2-0.4
          baseSpeed: baseSpeed,
        ),
      );
      index++;
    });
  }

  void _initializeSettings() {
    _checkVendorInfo();
  }

  void _checkVendorInfo() {
    const vendorCategory = 'vendor';
    vendorName = config.getString('vendorName', category: vendorCategory);
    vendorMachineName =
        config.getString('vendorMachineName', category: vendorCategory);
    vendorUrl = config.getString('vendorUrl', category: vendorCategory);

    // Log vendor information for debugging
    _logger.fine(
        'Vendor Info - Name: $vendorName, Machine: $vendorMachineName, URL: $vendorUrl');
  }

  Future<void> _initializeWifiScreen() async {
    if (!mounted) return;

    try {
      final bool connected =
          await OnboardingUtils.checkInitialConnectionStatus();
      if (mounted) {
        setState(() {
          isConnected.value = connected;
          _wifiInitialized = true;
        });
      }
    } catch (e) {
      _logger.severe('Failed to initialize WiFi screen: $e');
      if (mounted) {
        setState(() {
          isConnected.value = false;
          _wifiInitialized = true;
        });
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updatePlatformStatus();
    _initializeWelcomeBubbles(); // Initialize bubble positions when size is available
  }

  void _updatePlatformStatus() {
    _isLinuxPlatform = Theme.of(context).platform == TargetPlatform.linux;
    if (_isLinuxPlatform) {
      OnboardingUtils.checkInitialConnectionStatus();
    }
  }

  @override
  void dispose() {
    _bubbleController.dispose();
    _completeAnimationController.dispose();
    _titleAnimationController.dispose();
    _transitionController.dispose();
    _titleSlideController.dispose();
    _holeAnimationController.dispose();
    super.dispose();
  }

  void _handlePageChange(int index) {
    int targetPage = index;
    // Skip Machine Name page (4) if custom name is disabled
    if (targetPage == 4 && !config.enableCustomName()) {
      if (targetPage > _currentPage) {
        targetPage = 5;
      } else {
        targetPage = 3;
      }
    }

    if (targetPage >= 0 && targetPage <= 7) {
      // Store previous page before updating current
      _previousPage = _currentPage;

      // Reset the text field key when moving to or from the name page
      if (_currentPage == 4 || targetPage == 4) {
        _nameTextFieldKey = GlobalKey<SpawnOrionTextFieldState>();
      }

      // Other transitions will be handled by callers; keep this method
      // focused on updating page state.

      // Initialize WiFi when needed
      if (targetPage == 6 && !_wifiInitialized) {
        _initializeWifiScreen();
      }

      setState(() {
        _currentPage = targetPage;
      });

      // Fade FAB back in on the Region selection page (page 2)
      if (targetPage == 2 && !_fabVisible) {
        // slight delay so the page content settles before the FAB appears
        Future.delayed(const Duration(milliseconds: 120), () {
          if (mounted) {
            setState(() {
              _fabVisible = true;
            });
          }
        });
      }
    }
  }

  // Bubble transition helpers removed; exit sequence is handled via
  // OnboardingPages.startExitSequence to avoid duplicate logic.

  Widget _buildPageView(AppLocalizations l10n) {
    return PageTransitionSwitcher(
      reverse: _currentPage > 0 &&
          _currentPage < _previousPage, // true when going back
      duration: const Duration(milliseconds: 800),
      transitionBuilder: (child, animation, secondaryAnimation) {
        // No animation when transitioning from Welcome (0) to Language (1)
        // as they are visually identical underneath the overlay
        if (_currentPage == 1 && _previousPage == 0) {
          return child;
        }

        // Special zoom transition only for welcome->language
        if (_currentPage <= 1) {
          return FadeScaleTransition(
            animation: animation,
            child: SharedAxisTransition(
              animation: animation,
              secondaryAnimation: secondaryAnimation,
              transitionType: SharedAxisTransitionType.scaled,
              child: child,
            ),
          );
        }
        // Standard slide transition for all other pages
        return SharedAxisTransition(
          animation: animation,
          secondaryAnimation: secondaryAnimation,
          transitionType: SharedAxisTransitionType.horizontal,
          child: child,
        );
      },
      child: KeyedSubtree(
        key: ValueKey<int>(_currentPage),
        child: _buildPage(l10n, _currentPage),
      ),
    );
  }

  // Replace existing page building methods with calls to OnboardingPages
  Widget _buildPage(AppLocalizations l10n, int page) {
    if (_prebuiltPages.containsKey(page)) return _prebuiltPages[page]!;

    switch (page) {
      case 0:
        // Page 0 is now visually the Language Page, but covered by the Welcome Overlay
        return OnboardingPages.buildLanguagePage(
            context, _handleLanguageSelection);
      case 1:
        return OnboardingPages.buildLanguagePage(
            context, _handleLanguageSelection);
      case 2:
        return OnboardingPages.buildRegionCountryPage(
            context, _selectedLanguage, _handleCountrySelection);
      case 3:
        return OnboardingPages.buildTimezonePage(
            context, _selectedCountry, _handleTimezoneSelection);
      case 4:
        return OnboardingPages.buildInitialSettingsPage(
            context, _nameTextFieldKey, _scrollController, _handleNameChange);
      case 5:
        return OnboardingPages.buildThemePage(context, _handleThemeChange);
      case 6:
        return OnboardingPages.buildWifiPage(
            context, _wifiScreenKey, isConnected, _wifiInitialized);
      case 7:
        return OnboardingPages.buildCompletePage(
            context, _completeAnimation, _printerName);
      default:
        return const SizedBox.shrink();
    }
  }

  // Add handler methods that were previously inline in the page builds
  void _handleLanguageSelection(String code) {
    final parts = code.split('_');
    final locale =
        parts.length > 1 ? Locale(parts[0], parts[1]) : Locale(parts[0]);

    setState(() {
      _selectedLanguage = code;
      _currentLocale = code;
    });

    context.read<LocaleProvider>().setLocale(locale);
    // Use _handlePageChange so transitions and FAB logic run consistently
    _handlePageChange(_currentPage + 1);
  }

  void _handleCountrySelection(String name) {
    setState(() {
      _selectedCountry = name;
    });
    _handlePageChange(_currentPage + 1);
  }

  void _handleTimezoneSelection(String timezone) async {
    // Store timezone before advancing
    config.setString('timezone', timezone, category: 'machine');
    await OnboardingUtils.setSystemTimezone(timezone);
    _handlePageChange(_currentPage + 1);
  }

  void _handleNameChange(String name) {
    _printerName = name;
    config.setString('machineName', name, category: 'machine');
  }

  void _handleThemeChange(OrionThemeMode mode) {
    final themeProvider = context.read<ThemeProvider>();
    themeProvider.setThemeMode(mode);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    _printerName = config.getString('machineName', category: 'machine');

    return GlassApp(
      child: Scaffold(
        // Only extend body behind the app bar when the app bar is transparent
        // This lets us switch off the overlap after the reveal transition by
        // setting `_isAppBarTransparent = false`.
        extendBodyBehindAppBar:
            _currentPage <= 1 && _isAppBarTransparent, // welcome/lang only
        appBar: _buildAppBar(l10n),
        body: Stack(
          children: [
            IgnorePointer(
              ignoring: _showWelcomeOverlay,
              child: _buildPageView(l10n),
            ),
            if (_showWelcomeOverlay)
              Positioned.fill(
                child: OnboardingPages.buildWelcomePage(
                  context,
                  _bubbleController,
                  _welcomeBubbles,
                  _holeAnimation,
                ),
              ),
          ],
        ),
        floatingActionButton: _buildFloatingActionButton(l10n),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(AppLocalizations l10n) {
    return AppBar(
      centerTitle: true,
      backgroundColor: _isAppBarTransparent ? Colors.transparent : null,
      title: SlideTransition(
        position: _titleSlideInAnimation,
        child: FadeTransition(
          opacity: _titleOpacityAnimation,
          child: Text(_getTitles(l10n)[_currentPage]),
        ),
      ),
      actions: [_buildAppBarActions(l10n)],
    );
  }

  Widget _buildAppBarActions(AppLocalizations l10n) {
    return const SizedBox.shrink();
  }

  Widget _buildFloatingActionButton(AppLocalizations l10n) {
    final bool hideBackButton = _currentPage == 1;
    final bool isTimezonePageWithNoData = _currentPage == 3 &&
        countryData[_selectedCountry]?['timezones'] == null;
    // Hide Next button on language, region, and timezone pages (unless no timezones available)
    final bool hideNextButton = _currentPage == 1 ||
        _currentPage == 2 ||
        (_currentPage == 3 && !isTimezonePageWithNoData);

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 300),
      opacity: _fabVisible ? 1.0 : 0.0,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const SizedBox(width: 32),
          if (_currentPage > 0)
            _buildButton(
              hide: hideBackButton,
              label: l10n.commonBack,
              icon: Icons.arrow_back,
              onPressed: () {
                _handlePageChange(_currentPage - 1);
              },
              iconAfter: false,
            ),
          const Spacer(),
          // Next button
          ValueListenableBuilder<bool>(
            valueListenable: isConnected,
            builder: (context, connected, _) {
              return _buildButton(
                hide: hideNextButton,
                label: _currentPage == 6 && !connected
                    ? l10n.commonSkip
                    : _getBtnTitles(l10n)[_currentPage],
                icon: _currentPage < 6 ? Icons.arrow_forward : Icons.check,
                onPressed: () {
                  if (isTimezonePageWithNoData) {
                    _handleTimezoneSelection('UTC');
                  } else {
                    _handleNextButtonPressed();
                  }
                },
                disable: _currentPage == 6 && !_wifiInitialized,
                iconAfter: true,
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildButton({
    required bool hide,
    required String label,
    required IconData icon,
    required VoidCallback onPressed,
    bool disable = false,
    bool iconAfter = false,
  }) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      opacity: hide ? 0.0 : 1.0,
      child: IgnorePointer(
        ignoring: hide || disable,
        child: GlassFloatingActionButton.extended(
          heroTag: label,
          onPressed: onPressed,
          label: label,
          icon: Icon(icon),
          scale: 1.3,
          iconAfterLabel: iconAfter,
          doForceBlur: true,
          tint: iconAfter ? GlassButtonTint.positive : GlassButtonTint.neutral,
        ),
      ),
    );
  }

  void _handleNextButtonPressed() {
    if (_currentPage < 7) {
      if (_currentPage == 6 && !isConnected.value) {
        _showSkipWifiDialog();
      } else if (_currentPage == 0) {
        // Fade out FAB
        setState(() {
          _fabVisible = false;
        });

        // Run exit sequence and then advance
        Future.delayed(const Duration(milliseconds: 400), () {
          if (mounted) {
            _holeAnimationController.forward();
            // Start title animation slightly after hole starts opening
            Future.delayed(const Duration(milliseconds: 200), () {
              if (mounted) {
                setState(() {
                  _previousPage = _currentPage;
                  _currentPage = 1;
                });
                _titleSlideController.forward();
              }
            });
          }
        });
        OnboardingPages.startExitSequence(context, _welcomeBubbles,
            stagger: const Duration(milliseconds: 60), onComplete: () {
          if (mounted) {
            // play page transition animations
            _transitionController.forward();
            setState(() {
              _isAppBarTransparent = false;
              _showWelcomeOverlay = false;
              // FAB remains hidden on language page
            });
          }
        });
      } else {
        _handlePageChange(_currentPage + 1);
      }
    } else {
      _completeSetup();
    }
  }

  void _showSkipWifiDialog() {
    final l10n = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (context) {
        return GlassAlertDialog(
          title: Text(l10n!.wifiSkipTitle),
          content: Text(l10n.wifiSkipMessage),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text(l10n.wifiConnectNow),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                setState(() {
                  _currentPage++;
                });
              },
              child: Text(l10n.wifiSkipAnyway),
            ),
          ],
        );
      },
    );
  }

  void _completeSetup() {
    final printerName = _printerName;
    config.setString('machineName', printerName, category: 'machine');
    // Fire-and-forget: run initial check but don't block the UI long.
    try {
      final mgr = AthenaFeatureManager();
      mgr.runInitialCheck();
      mgr.startPeriodicPolling();
    } catch (_) {}

    config.setFlag('firstRun', false, category: 'machine');

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const HomeScreen(),
      ),
    );
  }
}

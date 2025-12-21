/*
* Orion - Startup Gate
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
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:orion/backend_service/providers/status_provider.dart';
import 'package:orion/backend_service/athena_iot/athena_iot_client.dart';
import 'package:orion/home/onboarding_screen.dart';
import 'package:orion/home/home_screen.dart';
import 'package:orion/home/startup_screen.dart';
import 'package:orion/home/update_available_screen.dart';
import 'package:orion/util/orion_config.dart';
import 'package:orion/util/update_manager.dart';

/// Blocks initial app content until the backend reports a successful
/// initial connection. While waiting, shows the branded [StartupScreen].
class StartupGate extends StatefulWidget {
  const StartupGate({super.key});

  @override
  State<StartupGate> createState() => _StartupGateState();
}

class _StartupGateState extends State<StartupGate> {
  late StatusProvider _statusProv;
  bool _isAthena = false;
  bool _athenaReady = false;
  bool _checkingAthena = false;

  // Startup sequence state
  bool _animationsComplete = false;
  bool _checkForUpdatesComplete = false;
  bool _dismissUpdateScreen = false;
  bool _startupExitComplete = false;

  @override
  void initState() {
    super.initState();
    // Trigger update check immediately and suppress notifications during startup
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final updateManager = Provider.of<UpdateManager>(context, listen: false);
      updateManager.suppressNotifications = true;
      _checkForUpdates();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _statusProv = Provider.of<StatusProvider>(context, listen: false);
    // Listen for changes so we can rebuild when status becomes available.
    _statusProv.addListener(_onStatusChange);
    // Detect Athena machines: NanoDLP backend and model name contains 'athena'
    try {
      final cfg = OrionConfig();
      _isAthena = cfg.isNanoDlpMode() &&
          cfg.getMachineModelName().toLowerCase().contains('athena');
    } catch (_) {
      _isAthena = false;
    }
  }

  Future<void> _checkForUpdates() async {
    final updateManager = Provider.of<UpdateManager>(context, listen: false);
    // Retry logic: try up to 5 times with increasing backoff
    // (1s, 2s, 4s, 8s, 16s) = ~31s total wait time max
    const maxAttempts = 5;
    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      try {
        await updateManager.checkForUpdates();
        // If we successfully checked (even if no update found), break
        break;
      } catch (_) {
        // If it failed (e.g. no network), wait and retry
        if (attempt < maxAttempts - 1) {
          await Future.delayed(Duration(seconds: 1 << attempt));
        }
      }
    }

    if (mounted) {
      setState(() {
        _checkForUpdatesComplete = true;
      });
    }
  }

  void _onStatusChange() {
    // Rebuild whenever provider updates
    if (mounted) setState(() {});
    // When we see the backend become available, kick off Athena IoT checks
    try {
      final prov = Provider.of<StatusProvider>(context, listen: false);
      if (_isAthena && !_athenaReady && prov.hasEverConnected) {
        _ensureAthenaReady();
      }
    } catch (_) {}
  }

  String _resolveNanodlpBaseUrl() {
    try {
      final cfg = OrionConfig();
      final base = cfg.getString('nanodlp.base_url', category: 'advanced');
      final useCustom = cfg.getFlag('useCustomUrl', category: 'advanced');
      final custom = cfg.getString('customUrl', category: 'advanced');
      if (base.isNotEmpty) return base;
      if (useCustom && custom.isNotEmpty) return custom;
    } catch (_) {}
    return 'http://localhost';
  }

  Future<void> _ensureAthenaReady() async {
    if (_checkingAthena) return;
    _checkingAthena = true;
    try {
      final base = _resolveNanodlpBaseUrl();
      final client =
          AthenaIotClient(base, requestTimeout: const Duration(seconds: 3));
      // Retry a few times with backoff
      const maxAttempts = 6;
      for (var attempt = 0; attempt < maxAttempts; attempt++) {
        try {
          final model = await client.getPrinterDataModel();
          if (model != null) {
            _athenaReady = true;
            if (mounted) setState(() {});
            break;
          }
        } catch (_) {}
        // Backoff before next attempt
        await Future.delayed(Duration(milliseconds: 500 * (1 << attempt)));
      }
    } finally {
      _checkingAthena = false;
    }
  }

  @override
  void dispose() {
    try {
      _statusProv.removeListener(_onStatusChange);
      // Ensure notifications are unsuppressed when leaving startup
      Provider.of<UpdateManager>(context, listen: false).suppressNotifications =
          false;
    } catch (_) {}
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final prov = Provider.of<StatusProvider>(context, listen: false);
    final updateManager = Provider.of<UpdateManager>(context, listen: false);

    final backendReady = prov.hasEverConnected && (!_isAthena || _athenaReady);
    final isReadyToProceed =
        _animationsComplete && backendReady && _checkForUpdatesComplete;

    // Choose the child widget depending on state
    final Widget child;
    final showUpdate =
        updateManager.hasPendingUpdateNotification && !_dismissUpdateScreen;

    if (!isReadyToProceed) {
      child = StartupScreen(
        key: const ValueKey('startup'),
        onAnimationsComplete: () {
          if (mounted) {
            setState(() {
              _animationsComplete = true;
            });
          }
        },
      );
    } else if (showUpdate && !_startupExitComplete) {
      // Ready to show update, but need to animate out startup screen first
      child = StartupScreen(
        key: const ValueKey('startup'),
        shouldAnimateOut: true,
        onExitComplete: () {
          if (mounted) {
            setState(() {
              _startupExitComplete = true;
            });
          }
        },
      );
    } else if (showUpdate && _startupExitComplete) {
      child = UpdateAvailableScreen(
        key: const ValueKey('update_available'),
        onRemindLater: () {
          updateManager.remindLater();
          setState(() {
            _dismissUpdateScreen = true;
          });
        },
        onUpdateNow: () {
          setState(() {
            _dismissUpdateScreen = true;
          });
          // Navigate after frame to ensure HomeScreen is mounted
          WidgetsBinding.instance.addPostFrameCallback((_) {
            context.go('/settings/updates');
          });
        },
      );
    } else {
      // We are proceeding to the main app, so unsuppress notifications
      if (updateManager.suppressNotifications) {
        Future.microtask(() => updateManager.suppressNotifications = false);
      }

      final cfg = OrionConfig();
      final showOnboarding = cfg.getFlag('firstRun', category: 'machine');
      child = showOnboarding
          ? const OnboardingScreen(key: ValueKey('onboarding'))
          : const HomeScreen(key: ValueKey('home'));
    }

    return Container(
      color: Colors.black,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 600),
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        transitionBuilder: (widget, animation) {
          // The StartupScreen handles its own internal exit animation (fading out content).
          // We keep the widget itself (the background) fully opaque during the switch
          // to prevent a brightness dip when the next screen (Update/Home) fades in on top.
          if (widget.key == const ValueKey('startup')) {
            return widget;
          }
          return FadeTransition(
            opacity: animation,
            child: widget,
          );
        },
        layoutBuilder: (currentChild, previousChildren) {
          // Ensure the new child is stacked on top of the previous ones
          return Stack(
            alignment: Alignment.center,
            children: <Widget>[
              ...previousChildren,
              if (currentChild != null) currentChild,
            ],
          );
        },
        child: child,
      ),
    );
  }
}

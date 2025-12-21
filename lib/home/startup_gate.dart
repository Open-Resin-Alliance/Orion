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
import 'package:provider/provider.dart';
import 'package:orion/backend_service/providers/status_provider.dart';
import 'package:orion/backend_service/athena_iot/athena_iot_client.dart';
import 'package:orion/home/onboarding_screen.dart';
import 'package:orion/home/home_screen.dart';
import 'package:orion/home/startup_screen.dart';
import 'package:orion/util/orion_config.dart';

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
    } catch (_) {}
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final prov = Provider.of<StatusProvider>(context, listen: false);
    // Choose the child widget depending on whether we've ever connected.
    // We use keys so AnimatedSwitcher can correctly cross-fade between
    // the startup overlay and the main app content.
    final Widget child;
    if (!prov.hasEverConnected || (_isAthena && !_athenaReady)) {
      // If this is an Athena machine, wait for Athena IoT readiness in
      // addition to the backend connection before dismissing the startup
      // overlay.
      child = const StartupScreen(key: ValueKey('startup'));
    } else {
      final cfg = OrionConfig();
      final showOnboarding = cfg.getFlag('firstRun', category: 'machine');
      child = showOnboarding
          ? const OnboardingScreen(key: ValueKey('onboarding'))
          : const HomeScreen(key: ValueKey('home'));
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 600),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (widget, animation) => FadeTransition(
        opacity: animation,
        child: widget,
      ),
      child: child,
    );
  }
}

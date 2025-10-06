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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _statusProv = Provider.of<StatusProvider>(context, listen: false);
    // Listen for changes so we can rebuild when status becomes available.
    _statusProv.addListener(_onStatusChange);
  }

  void _onStatusChange() {
    // Rebuild whenever provider updates
    if (mounted) setState(() {});
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
    if (!prov.hasEverConnected) {
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

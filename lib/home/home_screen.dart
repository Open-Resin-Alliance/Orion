/*
* Orion - Home Screen
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

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:orion/backend_service/providers/manual_provider.dart';
import 'package:orion/backend_service/providers/status_provider.dart';
import 'package:orion/util/widgets/system_status_widget.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';
import 'package:orion/glasser/glasser.dart';
import 'package:orion/l10n/generated/app_localizations.dart';
import 'package:orion/util/hold_button.dart';
import 'package:orion/util/orion_config.dart';
import 'package:orion/main.dart' show appRouteObserver;
import 'package:orion/util/update_manager.dart';
import 'package:orion/tools/exposure_util.dart' as exposure_util;

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  HomeScreenState createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> with RouteAware {
  final OrionConfig _config = OrionConfig();
  bool isRemote = false;
  bool _showingFullMenu = false;

  @override
  void initState() {
    super.initState();
    OrionConfig.addChangeListener(_onConfigChanged);
    // Safety check: Ensure the status screen flag is cleared when we land on Home.
    // This prevents the update dialog from being permanently suppressed if the
    // status screen didn't clean up properly.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Provider.of<StatusProvider>(context, listen: false)
            .setStatusScreenOpen(false);
      }
    });
  }

  @override
  void dispose() {
    OrionConfig.removeChangeListener(_onConfigChanged);
    final route = ModalRoute.of(context);
    if (route is PageRoute) {
      appRouteObserver.unsubscribe(this);
    }
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute) {
      appRouteObserver.subscribe(this, route);
    }
    // Ensure we refresh config-driven UI (like Quick Access) after navigating back.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void didPopNext() {
    // Reset to quick access when returning from another screen
    if (mounted) {
      setState(() {
        _showingFullMenu = false;
      });
    }
  }

  @override
  void didPush() {
    if (mounted) setState(() {});
  }

  void _onConfigChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    Size homeBtnSize = const Size(double.infinity, double.infinity);
    final l10n = AppLocalizations.of(context)!;

    final quickAccessMode =
        _config.getFlag('quickAccessMode', category: 'ui');

    final theme = Theme.of(context).copyWith(
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ButtonStyle(
          shape: WidgetStateProperty.resolveWith<OutlinedBorder?>(
            (Set<WidgetState> states) {
              return RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              );
            },
          ),
          minimumSize: WidgetStateProperty.resolveWith<Size?>(
            (Set<WidgetState> states) {
              return homeBtnSize;
            },
          ),
        ),
      ),
    );

    // Power dialog moved to helper method

    return GlassApp(
      child: Scaffold(
        appBar: _buildAppBar(context, l10n),
        body: Center(
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              // Show full menu if: quick access disabled OR user tapped "More"
              final showFull = !quickAccessMode || _showingFullMenu;
              return showFull
                  ? _buildFullHomeLayout(context, theme, l10n, _showPowerOptionsDialog)
                  : _buildQuickAccessLayout(context, theme, l10n);
            },
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context, AppLocalizations l10n) {
    return AppBar(
      title: Consumer<UpdateManager>(
        builder: (context, updateManager, child) {
          final machineName =
              _config.getString('machineName', category: 'machine');

          // Match DetailScreen styling logic
          final baseFontSize =
              (Theme.of(context).appBarTheme.titleTextStyle?.fontSize ?? 14) -
                  10;

          if (updateManager.isUpdateAvailable) {
            return GestureDetector(
              onTap: () => context.go('/updates'),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    machineName,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context)
                        .appBarTheme
                        .titleTextStyle
                        ?.copyWith(
                          fontSize: baseFontSize,
                          fontWeight: FontWeight.normal,
                          color: Theme.of(context)
                              .appBarTheme
                              .titleTextStyle
                              ?.color
                              ?.withValues(alpha: 0.95),
                        ),
                  ),
                  const SizedBox(height: 4),
                  GlassCard(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                    accentColor: Colors.orangeAccent,
                    accentOpacity: 0.15,
                    margin: EdgeInsets.zero,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8.0, vertical: 2.0),
                      child: Text(
                        updateManager.updateMessage,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context)
                                .appBarTheme
                                .titleTextStyle
                                ?.copyWith(
                                  fontSize: baseFontSize - 2,
                                  fontWeight: FontWeight.normal,
                                  color: Colors.orangeAccent,
                                ) ??
                            TextStyle(
                              fontSize: baseFontSize - 2,
                              fontWeight: FontWeight.normal,
                              color: Colors.orangeAccent,
                            ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }
          return Text(
            machineName,
            textAlign: TextAlign.center,
          );
        },
      ),
      centerTitle: true,
      leadingWidth: 120,
      leading: const Center(
        child: Padding(
          padding: EdgeInsets.only(left: 15),
          child: LiveClock(),
        ),
      ),
      actions: [SystemStatusWidget()],
    );
  }

  void _showPowerOptionsDialog() {
    final l10n = AppLocalizations.of(context)!;
    isRemote = _config.getFlag('useCustomUrl', category: 'advanced');
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return GlassDialog(
          padding: const EdgeInsets.all(8),
          child: SizedBox(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    '${l10n.homePowerOptions} ${isRemote ? l10n.homePowerRemote : l10n.homePowerLocal}',
                    style:
                        const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.only(left: 20, right: 20),
                  child: SizedBox(
                    height: 65,
                    width: 450,
                    child: HoldButton(
                      onPressed: () {
                        Navigator.pop(context);
                        try {
                          final manual =
                              Provider.of<ManualProvider>(context, listen: false);
                          manual.manualCommand('FIRMWARE_RESTART');
                        } catch (_) {}
                      },
                      child: Text(
                        l10n.homeFirmwareRestart,
                        style: const TextStyle(fontSize: 24),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                if (!isRemote)
                  Padding(
                    padding: const EdgeInsets.only(left: 20, right: 20),
                    child: SizedBox(
                      height: 65,
                      width: 450,
                      child: HoldButton(
                        onPressed: () {
                          Process.run('sudo', ['reboot', 'now']);
                        },
                        child: Text(
                          l10n.homeRebootSystem,
                          style: const TextStyle(fontSize: 24),
                        ),
                      ),
                    ),
                  ),
                if (!isRemote) const SizedBox(height: 20),
                if (!isRemote)
                  Padding(
                    padding: const EdgeInsets.only(left: 20, right: 20),
                    child: SizedBox(
                      height: 65,
                      width: 450,
                      child: HoldButton(
                        onPressed: () {
                          Process.run('sudo', ['shutdown', 'now']);
                        },
                        child: Text(
                          l10n.homeShutdownSystem,
                          style: const TextStyle(fontSize: 24),
                        ),
                      ),
                    ),
                  ),
                if (!isRemote) const SizedBox(height: 20),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFullHomeLayout(BuildContext context, ThemeData theme,
      AppLocalizations l10n, VoidCallback showPowerOptionsDialog) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        const SizedBox(height: 5),
        Expanded(
          child: Row(
            children: [
              const SizedBox(width: 20),
              Expanded(
                child: GlassButton(
                  style: theme.elevatedButtonTheme.style,
                  onPressed: () => context.go('/gridfiles'),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      PhosphorIcon(PhosphorIcons.printer(), size: 52),
                      Text(
                        l10n.homeBtnPrint,
                        style: const TextStyle(fontSize: 28),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 20),
              if (_config.enableResinProfiles()) ...[
                Expanded(
                  child: GlassButton(
                    style: theme.elevatedButtonTheme.style,
                    onPressed: () => context.go('/materials'),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        PhosphorIcon(PhosphorIcons.flask(), size: 52),
                        Text(
                          'Materials',
                          style: const TextStyle(fontSize: 28),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 20),
              ],
            ],
          ),
        ),
        const SizedBox(height: 20),
        Expanded(
          child: Row(
            children: [
              const SizedBox(width: 20),
              Expanded(
                child: GlassButton(
                  style: theme.elevatedButtonTheme.style,
                  onPressed: () => context.go('/tools'),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      PhosphorIcon(PhosphorIcons.toolbox(), size: 52),
                      Text(
                        l10n.homeBtnTools,
                        style: const TextStyle(fontSize: 28),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: GlassButton(
                  style: theme.elevatedButtonTheme.style,
                  onPressed: () => context.go('/settings'),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      PhosphorIcon(PhosphorIcons.gear(), size: 52),
                      Text(
                        l10n.homeBtnSettings,
                        style: const TextStyle(fontSize: 28),
                      ),
                    ],
                  ),
                ),
              ),
              if (_config.enablePowerControl()) ...[
                const SizedBox(width: 20),
                Expanded(
                  child: GlassButton(
                    style: theme.elevatedButtonTheme.style,
                    onPressed: () => showPowerOptionsDialog(),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        PhosphorIcon(PhosphorIcons.power(), size: 52),
                        Text(
                          'Power',
                          style: const TextStyle(fontSize: 28),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(width: 20),
            ],
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildQuickAccessLayout(
      BuildContext context, ThemeData theme, AppLocalizations l10n) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox(height: 5),
        Expanded(
          child: Row(
            children: [
              const SizedBox(width: 20),
              Expanded(
                child: GlassButton(
                  style: theme.elevatedButtonTheme.style,
                  onPressed: () => context.go('/gridfiles'),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      PhosphorIcon(PhosphorIcons.printer(), size: 52),
                      Text(
                        l10n.homeBtnPrint,
                        style: const TextStyle(fontSize: 26),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: GlassButton(
                  style: theme.elevatedButtonTheme.style,
                  onPressed: () => _handleHomeZ(context),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      PhosphorIcon(PhosphorIcons.house(), size: 52),
                      Text(
                        'Home',
                        style: const TextStyle(fontSize: 26),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 20),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Expanded(
          child: Row(
            children: [
              const SizedBox(width: 20),
              Expanded(
                child: SizedBox.expand(
                  child: HoldButton(
                    duration: Duration(milliseconds: 1500),
                    style: theme.elevatedButtonTheme.style,
                    onPressed: () => _handleTankClean(context),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        PhosphorIcon(PhosphorIcons.broom(), size: 52),
                        Text(
                          'Tank Clean',
                          style: const TextStyle(fontSize: 26),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: GlassButton(
                  style: theme.elevatedButtonTheme.style,
                  onPressed: () {
                    setState(() {
                      _showingFullMenu = true;
                    });
                  },
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      PhosphorIcon(PhosphorIconsFill.dotsThreeOutline,
                          size: 52),
                      Text(
                        'More',
                        style: const TextStyle(fontSize: 26),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 20),
            ],
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Future<void> _handleHomeZ(BuildContext context) async {
    try {
      final manual = Provider.of<ManualProvider>(context, listen: false);
      final ok = await manual.manualHome();
      if (!ok && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to home the printer.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to home the printer.')),
        );
      }
    }
  }

  Future<void> _handleTankClean(BuildContext context) async {
    final manual = Provider.of<ManualProvider>(context, listen: false);
    await exposure_util.exposeScreen(context, manual, 'White', 8);
  }
}

/// A live clock widget
class LiveClock extends StatefulWidget {
  const LiveClock({super.key});

  @override
  LiveClockState createState() => LiveClockState();
}

class LiveClockState extends State<LiveClock> {
  late Timer _timer;
  late DateTime _dateTime;

  @override
  void initState() {
    super.initState();
    _dateTime = DateTime.now();
    _timer = Timer.periodic(const Duration(seconds: 1), (Timer timer) {
      setState(() {
        _dateTime = DateTime.now();
      });
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      '${_dateTime.hour.toString().padLeft(2, '0')}:${_dateTime.minute.toString().padLeft(2, '0')}',
      style: const TextStyle(fontSize: 28),
    );
  }
}

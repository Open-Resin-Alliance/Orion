import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:orion/util/update_manager.dart';
import 'package:orion/backend_service/providers/status_provider.dart';
import 'package:orion/glasser/glasser.dart';
import 'package:go_router/go_router.dart';
import 'package:orion/widgets/version_comparison.dart';

class UpdateNotificationWatcher {
  final BuildContext context;
  bool _isDialogShown = false;
  Timer? _cooldownTimer;

  UpdateNotificationWatcher(this.context) {
    final updateManager = Provider.of<UpdateManager>(context, listen: false);
    final statusProvider = Provider.of<StatusProvider>(context, listen: false);

    updateManager.addListener(_check);
    statusProvider.addListener(_check);
  }

  void dispose() {
    final updateManager = Provider.of<UpdateManager>(context, listen: false);
    final statusProvider = Provider.of<StatusProvider>(context, listen: false);
    updateManager.removeListener(_check);
    statusProvider.removeListener(_check);
    _cooldownTimer?.cancel();
  }

  bool _isOnStatusScreen() {
    // Check the authoritative flag from StatusProvider first
    // Note: We avoid checking GoRouter location string directly because during
    // navigation transitions (e.g. popping the Status screen) the router check
    // might still return '/status' while the screen is actually disposing,
    // causing a race condition where the notification remains blocked.
    // Relying on the provider flag (managed by StatusScreen state) is safer.
    final statusProvider = Provider.of<StatusProvider>(context, listen: false);
    return statusProvider.isStatusScreenOpen;
  }

  void _check() {
    if (_isDialogShown) return;

    final updateManager = Provider.of<UpdateManager>(context, listen: false);
    final statusProvider = Provider.of<StatusProvider>(context, listen: false);

    if (updateManager.shouldShowNotification) {
      final isPrinting = statusProvider.status?.isPrinting ?? false;
      final isPaused = statusProvider.status?.isPaused ?? false;
      final isStatusScreen = _isOnStatusScreen();

      if (!isPrinting && !isPaused && !isStatusScreen) {
        // If a timer is already running, let it finish (don't reset it)
        if (_cooldownTimer?.isActive ?? false) return;

        // Start a cooldown before showing the dialog
        _cooldownTimer = Timer(const Duration(seconds: 3), () {
          if (_isDialogShown) return;
          // Re-check conditions as they might have changed during delay
          if (!context.mounted) return;

          final curUpdateManager =
              Provider.of<UpdateManager>(context, listen: false);
          final curStatusProvider =
              Provider.of<StatusProvider>(context, listen: false);

          if (curUpdateManager.shouldShowNotification) {
            final curIsPrinting =
                curStatusProvider.status?.isPrinting ?? false;
            final curIsPaused = curStatusProvider.status?.isPaused ?? false;
            final curIsStatusScreen = _isOnStatusScreen();

            if (!curIsPrinting && !curIsPaused && !curIsStatusScreen) {
              _showDialog();
            }
          }
        });
      } else {
        // If we started printing/paused, cancel any pending notification
        _cooldownTimer?.cancel();
        _cooldownTimer = null;
      }
    } else {
      _cooldownTimer?.cancel();
      _cooldownTimer = null;
    }
  }

  void _showDialog() {
    _isDialogShown = true;
    final updateManager = Provider.of<UpdateManager>(context, listen: false);
    final orion = updateManager.orionProvider;
    final athena = updateManager.athenaProvider;

    showDialog(
      context: context,
      builder: (ctx) => GlassAlertDialog(
        title: const Text(
          'Update Available',
          style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (orion.isUpdateAvailable)
                VersionComparison(
                  title: 'Orion',
                  branch: orion.release,
                  currentVersion: orion.currentVersion,
                  newVersion: orion.latestVersion,
                ),
              if (orion.isUpdateAvailable && athena.updateAvailable)
                const SizedBox(height: 12),
              if (athena.updateAvailable)
                VersionComparison(
                  title: 'AthenaOS',
                  branch: athena.channel,
                  currentVersion: athena.currentVersion,
                  newVersion: athena.latestVersion,
                ),
              const SizedBox(height: 16),
              Text(
                'Would you like to update now?',
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.grey.shade400,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        actions: [
          GlassButton(
            tint: GlassButtonTint.neutral,
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(140, 60),
            ),
            onPressed: () {
              updateManager.remindLater();
              Navigator.of(ctx).pop();
            },
            child: const Text(
              'Remind Later',
              style: TextStyle(fontSize: 22),
            ),
          ),
          GlassButton(
            tint: GlassButtonTint.positive,
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(140, 60),
            ),
            onPressed: () {
              Navigator.of(ctx).pop();
              context.go('/updates');
            },
            child: const Text(
              'Update Now',
              style: TextStyle(fontSize: 22),
            ),
          ),
        ],
      ),
    ).then((_) => _isDialogShown = false);
  }

  static UpdateNotificationWatcher? install(BuildContext context) {
    return UpdateNotificationWatcher(context);
  }
}

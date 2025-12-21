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
  }

  void _check() {
    if (_isDialogShown) return;

    final updateManager = Provider.of<UpdateManager>(context, listen: false);
    final statusProvider = Provider.of<StatusProvider>(context, listen: false);

    if (updateManager.shouldShowNotification) {
      final isPrinting = statusProvider.status?.isPrinting ?? false;
      final isPaused = statusProvider.status?.isPaused ?? false;

      if (!isPrinting && !isPaused) {
        _showDialog();
      }
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
              minimumSize: const Size(140, 55),
            ),
            onPressed: () {
              updateManager.remindLater();
              Navigator.of(ctx).pop();
            },
            child: const Text(
              'Remind Later',
              style: TextStyle(fontSize: 20),
            ),
          ),
          GlassButton(
            tint: GlassButtonTint.positive,
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(140, 55),
            ),
            onPressed: () {
              Navigator.of(ctx).pop();
              context.go('/settings/updates');
            },
            child: const Text(
              'Update Now',
              style: TextStyle(fontSize: 20),
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

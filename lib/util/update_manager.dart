import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:orion/util/providers/athena_update_provider.dart';
import 'package:orion/util/providers/orion_update_provider.dart';
import 'package:orion/util/orion_config.dart';

class UpdateManager extends ChangeNotifier {
  final OrionUpdateProvider orionProvider;
  final AthenaUpdateProvider athenaProvider;
  final OrionConfig _config = OrionConfig();
  Timer? _timer;
  Timer? _debounceTimer;
  bool _suppressNotifications = false;
  bool _promptAcknowledgedThisSession = false;

  UpdateManager(this.orionProvider, this.athenaProvider) {
    _startTimer();
    OrionConfig.addChangeListener(_onConfigChanged);
  }

  set suppressNotifications(bool value) {
    if (_suppressNotifications != value) {
      _suppressNotifications = value;
      notifyListeners();
    }
  }

  bool get suppressNotifications => _suppressNotifications;

  /// Mark that a user has acknowledged an update prompt for this app session.
  /// Prevents further update dialogs until Orion is restarted.
  void acknowledgeUpdatePrompt() {
    if (_promptAcknowledgedThisSession) return;
    _promptAcknowledgedThisSession = true;
    notifyListeners();
  }

  void _startTimer() {
    // Initial check after a short delay to allow app to settle
    Future.delayed(const Duration(seconds: 5), () => checkForUpdates());

    // Periodic check every 20 minutes
    _timer =
        Timer.periodic(const Duration(minutes: 20), (_) => checkForUpdates());
  }

  void _onConfigChanged() {
    // Debounce config changes to avoid rapid re-checks or loops
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(seconds: 2), () {
      checkForUpdates();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _debounceTimer?.cancel();
    OrionConfig.removeChangeListener(_onConfigChanged);
    super.dispose();
  }

  Future<void> checkForUpdates() async {
    await Future.wait([
      orionProvider.checkForUpdates(),
      athenaProvider.checkForUpdates(),
    ]);

    final available =
        orionProvider.isUpdateAvailable || athenaProvider.updateAvailable;
    _config.setFlag('available', available, category: 'updates');

    if (available) {
      // Persist version details so we can show the dialog immediately on restart
      if (orionProvider.isUpdateAvailable) {
        _config.setString('orion.current', orionProvider.currentVersion,
            category: 'updates');
        _config.setString('orion.latest', orionProvider.latestVersion,
            category: 'updates');
        _config.setString('orion.release', orionProvider.release,
            category: 'updates');
      }
      if (athenaProvider.updateAvailable) {
        _config.setString('athena.current', athenaProvider.currentVersion,
            category: 'updates');
        _config.setString('athena.latest', athenaProvider.latestVersion,
            category: 'updates');
        _config.setString('athena.channel', athenaProvider.channel,
            category: 'updates');
      }
    }

    notifyListeners();
  }

  void remindLater() {
    final remindTime = DateTime.now().add(const Duration(hours: 24));
    _config.setString('remindLater', remindTime.toIso8601String(),
        category: 'updates');
    notifyListeners();
  }

  void setIgnoreUpdates(bool value) {
    _config.setFlag('ignoreUpdates', value, category: 'updates');
    notifyListeners();
  }

  bool get isUpdateIgnored {
    return _config.getFlag('ignoreUpdates', category: 'updates');
  }

  /// Returns true if an update is available, regardless of whether the user
  /// has snoozed notifications.
  bool get isUpdateAvailable {
    // Check live providers first
    if (orionProvider.isUpdateAvailable || athenaProvider.updateAvailable) {
      return true;
    }
    // Fallback to config (useful for startup before check completes)
    return _config.getFlag('available', category: 'updates');
  }

  /// Returns true if an update is available AND the user has not snoozed
  /// notifications (or the snooze period has expired).
  /// This respects the [suppressNotifications] flag.
  bool get shouldShowNotification {
    if (_suppressNotifications) return false;
    if (_promptAcknowledgedThisSession) return false;
    return hasPendingUpdateNotification;
  }

  /// Returns true if an update is available AND the user has not snoozed
  /// notifications, ignoring the [suppressNotifications] flag.
  bool get hasPendingUpdateNotification {
    if (!isUpdateAvailable) return false;

    if (_config.getFlag('ignoreUpdates', category: 'updates')) {
      return false;
    }

    final remindStr = _config.getString('remindLater', category: 'updates');
    if (remindStr.isNotEmpty) {
      final remindTime = DateTime.tryParse(remindStr);
      if (remindTime != null && DateTime.now().isBefore(remindTime)) {
        return false;
      }
    }
    return true;
  }

  String get updateMessage {
    if (orionProvider.isUpdateAvailable && athenaProvider.updateAvailable) {
      return 'Updates Available';
    } else if (orionProvider.isUpdateAvailable) {
      return 'Orion Update Available';
    } else if (athenaProvider.updateAvailable) {
      return 'AthenaOS Update Available';
    }
    // If we only have the config flag but not the specific provider details yet,
    // return a generic message.
    if (isUpdateAvailable) {
      return 'Update Available';
    }
    return '';
  }
}

import 'package:flutter/material.dart';
import 'package:logging/logging.dart';

import 'package:orion/backend_service/odyssey/odyssey_client.dart';
import 'package:orion/backend_service/backend_service.dart';
import 'package:orion/backend_service/odyssey/models/config_models.dart';

class ConfigProvider extends ChangeNotifier {
  final OdysseyClient _client;
  final _log = Logger('ConfigProvider');

  ConfigModel? _config;
  ConfigModel? get config => _config;

  bool _loading = true;
  bool get isLoading => _loading;

  Object? _error;
  Object? get error => _error;

  ConfigProvider({OdysseyClient? client})
      : _client = client ?? BackendService() {
    refresh();
  }

  Future<void> refresh() async {
    _log.info('refreshing config');
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final raw = await _client.getConfig();
      _config = ConfigModel.fromJson(raw);
      _error = null;
      _loading = false;
      _log.fine('config fetched');
    } catch (e, st) {
      _log.severe('Failed to fetch config', e, st);
      _error = e;
      _loading = false;
    } finally {
      notifyListeners();
    }
  }

  // Convenience getters
  String get themeMode =>
      (_config?.general?['themeMode'] as String?) ?? 'light';

  bool get useUsbByDefault =>
      (_config?.general?['useUsbByDefault'] as bool?) ?? false;
}

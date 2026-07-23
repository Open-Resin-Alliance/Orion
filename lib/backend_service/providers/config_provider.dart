import 'package:flutter/material.dart';
import 'package:logging/logging.dart';

import 'package:orion/backend_service/backend_client.dart';
import 'package:orion/backend_service/backend_service.dart';
import 'package:orion/backend_service/odyssey/models/config_models.dart';

class ConfigProvider extends ChangeNotifier {
  final BackendClient _client;
  final _log = Logger('ConfigProvider');

  ConfigModel? _config;
  ConfigModel? get config => _config;

  bool _loading = true;
  bool get isLoading => _loading;

  Object? _error;
  Object? get error => _error;

  ConfigProvider({BackendClient? client})
      : _client = client ?? BackendService() {
    // Don't call refresh synchronously during construction — when the
    // provider is created inside widget build (e.g. `create: (_) =>
    // ConfigProvider()`), calling `notifyListeners()` can trigger the
    // 'setState() or markNeedsBuild() called during build' assertion. Use
    // a post-frame callback so the initial fetch runs after the first frame
    // has been rendered and the framework is no longer building widgets.
    WidgetsBinding.instance.addPostFrameCallback((_) => refresh());
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
      // Rethrow so callers can decide how to surface the error. Avoids
      // coupling the provider to UI dialog presentation during build.
      rethrow;
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

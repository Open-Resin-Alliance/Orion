import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:orion/backend_service/backend_service.dart';

class ResinProfile {
  final String name;
  final String? path;
  final Map<String, dynamic> meta;
  final bool locked;

  ResinProfile(this.name,
      {this.path, this.meta = const {}, this.locked = false});
}

class CalibrationModel {
  final int id;
  final String name;
  final int models;
  final int? resinRequired;
  final int? height;
  final String? evaluationGuideUrl;

  CalibrationModel({
    required this.id,
    required this.name,
    required this.models,
    this.resinRequired,
    this.height,
    this.evaluationGuideUrl,
  });

  factory CalibrationModel.fromJson(Map<String, dynamic> json) {
    final info = json['info'] as Map<String, dynamic>?;
    return CalibrationModel(
      id: json['id'] as int,
      name: json['name'] as String,
      models: json['models'] as int,
      resinRequired: info?['resinRequired'] as int?,
      height: info?['height'] as int?,
      evaluationGuideUrl: info?['evaluationGuideUrl'] as String?,
    );
  }
}

class ResinsProvider extends ChangeNotifier {
  final _log = Logger('ResinsProvider');
  final BackendService _service;

  bool _loading = true;
  bool get isLoading => _loading;

  Object? _error;
  Object? get error => _error;

  List<ResinProfile> _resins = [];
  List<ResinProfile> get resins => List.unmodifiable(_resins);

  // Calibration models available for this backend
  List<CalibrationModel> _calibrationModels = [];
  List<CalibrationModel> get calibrationModels =>
      List.unmodifiable(_calibrationModels);

  int? _activeProfileId;
  int? get activeProfileId => _activeProfileId;

  String? _activeResinKey;
  String? get activeResinKey => _activeResinKey;

  ResinsProvider({BackendService? service})
      : _service = service ?? BackendService() {
    WidgetsBinding.instance.addPostFrameCallback((_) => refresh());
  }

  Future<void> refresh() async {
    _log.info('Refreshing resin profiles');
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      // Fetch calibration models from backend
      final calibrationData = await _service.getCalibrationModels();
      _calibrationModels = calibrationData
          .map((json) => CalibrationModel.fromJson(json))
          .toList();
      _log.info('Loaded ${_calibrationModels.length} calibration models');

      // Try common locations the backend might expose.
      final resp = await _service.listItems('Resins', 100, 0, '');

      List<Map<String, dynamic>> items = [];
      if (resp.containsKey('resins') && resp['resins'] is List) {
        items =
            (resp['resins'] as List).whereType<Map<String, dynamic>>().toList();
      } else if (resp.containsKey('files') && resp['files'] is List) {
        items =
            (resp['files'] as List).whereType<Map<String, dynamic>>().toList();
      }

      String friendlyName(Map<String, dynamic> m) {
        // Prefer explicit display fields provided by the backend.
        final candidates = [
          m['display_name'],
          m['label'],
          m['title'],
          m['name'],
        ];

        for (final c in candidates) {
          if (c is String && c.trim().isNotEmpty) return c.trim();
        }

        // Fallback to path basename if available
        final path = m['path'] as String?;
        if (path != null && path.isNotEmpty) {
          final parts = path.split('/');
          var base = parts.isNotEmpty ? parts.last : path;
          // strip extension
          final dot = base.lastIndexOf('.');
          if (dot > 0) base = base.substring(0, dot);
          base = base.replaceAll(RegExp(r'[_\-]+'), ' ').trim();
          if (base.isNotEmpty) return base;
        }

        return 'Unknown';
      }

      bool detectLocked(String name, Map<String, dynamic> meta) {
        // Prefer explicit backend signals if provided
        try {
          final lockedMeta = meta['locked'];
          if (lockedMeta is bool) return lockedMeta;
        } catch (_) {}

        // Heuristic: NanoDLP-style locked profiles often use short
        // uppercase bracket prefixes like "[AFP] Name". We treat
        // names with a short uppercase token in brackets (2-5 chars)
        // as locked. This avoids matching longer labels like
        // "[Template]" which are not intended to indicate a lock.
        final re = RegExp(r'^\[([A-Z]{2,5})\]\s*');
        return re.hasMatch(name);
      }

      _resins = items.map((m) {
        final name = friendlyName(m);
        final locked = detectLocked(name, m);
        return ResinProfile(name,
            path: m['path'] as String?, meta: m, locked: locked);
      }).toList(growable: false);

      // Ask the backend for its notion of the current default profile id.
      try {
        _activeProfileId = await _service.getDefaultProfileId();
      } catch (_) {
        _activeProfileId = null;
      }

      // If we have a default profile id, try to map it to a resin key from
      // the fetched resins list. We check common metadata keys used by
      // various backends (ProfileID, profileId, id, etc.). This keeps the
      // mapping logic centralized in the provider rather than in UI code.
      _activeResinKey = null;
      try {
        final did = _activeProfileId;
        if (did != null) {
          for (final r in _resins) {
            final meta = r.meta;
            final candidates = [
              meta['ProfileID'],
              meta['ProfileId'],
              meta['profileId'],
              meta['id'],
              meta['ID']
            ];
            for (final c in candidates) {
              if (c == null) continue;
              final parsed = int.tryParse('$c');
              if (parsed != null && parsed == did) {
                _activeResinKey = r.path ?? r.name;
                break;
              }
            }
            if (_activeResinKey != null) break;
          }
        }
      } catch (_) {
        _activeResinKey = null;
      }

      _loading = false;
      _error = null;
    } catch (e, st) {
      _log.severe('Failed to fetch resins', e, st);
      _error = e;
      _resins = [];
      _loading = false;
    } finally {
      notifyListeners();
    }
  }

  /// Selects the given resin as the backend's default profile when possible.
  /// This will attempt to extract a numeric profile id from the resin's
  /// metadata (common keys: ProfileID, profileId, id, ID) and call the
  /// backend to persist the default profile. On success the provider's
  /// activeProfileId / activeResinKey are updated and listeners notified.
  Future<void> selectResin(ResinProfile resin) async {
    int? did;
    try {
      final meta = resin.meta;
      final candidates = [
        meta['ProfileID'],
        meta['ProfileId'],
        meta['profileId'],
        meta['id'],
        meta['ID']
      ];
      for (final c in candidates) {
        if (c == null) continue;
        final parsed = int.tryParse('$c');
        if (parsed != null) {
          did = parsed;
          break;
        }
      }
    } catch (_) {
      did = null;
    }

    if (did == null) {
      throw Exception('Resin does not contain a numeric ProfileID');
    }

    _log.info('Setting default profile id to $did');
    await _service.setDefaultProfileId(did);
    _activeProfileId = did;
    _activeResinKey = resin.path ?? resin.name;
    notifyListeners();
  }
}

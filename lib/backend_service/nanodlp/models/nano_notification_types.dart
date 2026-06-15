/*
* Orion - NanoDLP Notification Types
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

class NanoDlpNotificationType {
  final String type;
  final List<String> actions;
  final int priority;

  const NanoDlpNotificationType(
      {required this.type, required this.actions, required this.priority});
}

class NanoDlpNotificationTypes {
  static const List<NanoDlpNotificationType> _table = [
    NanoDlpNotificationType(
        type: 'error', actions: ['continue', 'stop'], priority: 1),
    NanoDlpNotificationType(
        type: 'warn', actions: ['continue', 'stop'], priority: 2),
    NanoDlpNotificationType(
        type: 'klipper-error', actions: ['confirm'], priority: 3),
    NanoDlpNotificationType(
        type: 'aegis-error', actions: ['confirm'], priority: 4),
    NanoDlpNotificationType(
        type: 'aegis-info', actions: ['confirm'], priority: 5),
    NanoDlpNotificationType(type: 'default', actions: ['confirm'], priority: 6),
  ];

  static NanoDlpNotificationType lookup(String? type) {
    if (type == null) return _table.last;
    try {
      return _table.firstWhere((e) => e.type == type,
          orElse: () => _table.last);
    } catch (_) {
      return _table.last;
    }
  }

  static int priorityOf(String? type) => lookup(type).priority;
}

// Backwards-compatible functional helpers
const List<Map<String, dynamic>> _defaultNanoNotificationTypes = [
  {
    'type': 'error',
    'actions': ['continue', 'stop'],
    'priority': 1
  },
  {
    'type': 'warn',
    'actions': ['continue', 'stop'],
    'priority': 2
  },
  {
    'type': 'klipper-error',
    'actions': ['close'],
    'priority': 3
  },
  {
    'type': 'aegis-error',
    'actions': ['close'],
    'priority': 4
  },
  {
    'type': 'aegis-info',
    'actions': ['close'],
    'priority': 5
  },
  {
    'type': 'default',
    'actions': ['close'],
    'priority': 6
  },
];

const List<Map<String, dynamic>> _notificationTypeTitles = [
  {'type': 'error', 'title': 'notification.error'},
  {'type': 'warn', 'title': 'notification.warning'},
  {'type': 'klipper-error', 'title': 'notification.klipperError'},
  {'type': 'aegis-error', 'title': 'notification.aegisError'},
  {'type': 'aegis-info', 'title': 'notification.aegisInfo'},
  {'type': 'default', 'title': 'notification.default'},
];

Map<String, Map<String, dynamic>> _indexByType(
    List<Map<String, dynamic>> list) {
  final map = <String, Map<String, dynamic>>{};
  for (final e in list) {
    final t = (e['type'] ?? 'default').toString();
    map[t] = e;
  }
  return map;
}

/// Returns the default lookup table as a type -> config map.
Map<String, Map<String, dynamic>> getDefaultNanoNotificationLookup() {
  return _indexByType(_defaultNanoNotificationTypes);
}

/// Convenience: get priority for a type. Lower = higher priority.
int getNanoTypePriority(String? type) {
  if (type == null) return 999;
  final lookup = getDefaultNanoNotificationLookup();
  final entry = lookup[type] ?? lookup['default'];
  return (entry?['priority'] as int?) ?? 999;
}

/// Convenience: get config for a type (actions + priority). Returns default if missing.
Map<String, dynamic> getNanoTypeConfig(String? type) {
  final lookup = getDefaultNanoNotificationLookup();
  return lookup[type] ?? lookup['default']!;
}

/// Convenience: get a human-friendly title for the notification type.
String getNanoTypeTitle(String? type) {
  final lookup = _indexByType(_notificationTypeTitles);
  final entry = lookup[type] ?? lookup['default'];
  return (entry?['title'] as String?) ?? 'notification.default';
}

String _normalizeNotificationText(String? text) {
  return (text ?? '').trim().toLowerCase();
}

/// Human-friendly dialog title, with optional text-aware intercepts.
String getNanoNotificationDisplayTitle(String? type, String? text) {
  final normalized = _normalizeNotificationText(text);

  if (type == 'klipper-error') {
    if (normalized.contains('m112') ||
        normalized.contains('emergency stop') ||
        normalized.contains('shutdown due to m112')) {
      return 'notification.emergencyStop';
    }
    if (normalized.contains('must home axis first')) {
      return 'notification.homingRequired';
    }
    return 'notification.warning';
  }

  return getNanoTypeTitle(type);
}

/// Human-friendly dialog message, with optional text-aware intercepts.
String getNanoNotificationDisplayMessage(String? type, String? text) {
  final raw = (text ?? '').trim();
  final normalized = raw.toLowerCase();

  if (type == 'klipper-error') {
    if (normalized.contains('m112') ||
        normalized.contains('emergency stop') ||
        normalized.contains('shutdown due to m112')) {
      return 'notification.emergencyStopMsg';
    }
    if (normalized.contains('must home axis first')) {
      return 'notification.homingRequiredMsg';
    }
  }

  return raw.isNotEmpty ? raw : 'notification.noDetails';
}

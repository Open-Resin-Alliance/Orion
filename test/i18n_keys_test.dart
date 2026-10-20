/*
* Orion - Translation key audit
* Copyright (C) 2026 Open Resin Alliance
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

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// A key literal the code asks the translator for, and where it asks.
class _Reference {
  _Reference(this.file, this.line, this.key);

  final String file;
  final int line;
  final String key;

  @override
  String toString() => '$file:$line asks for "$key"';
}

/// Every string literal key the code passes to the translator.
///
/// Keys assembled at runtime (interpolation) are skipped: they cannot be
/// checked without running the screen.
final _lookup = RegExp(
  r"""(?:FlutterI18n\.translate\([^;]{0,200}?|"""
  r"""I18nText\(|"""
  r"""translationKey:\s*)"""
  r"""'([a-zA-Z][\w]*\.[\w]+)'""",
  dotAll: true,
);

Iterable<_Reference> _referencesIn(String root) sync* {
  for (final entity in Directory(root).listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.dart')) continue;
    final source = entity.readAsStringSync();
    for (final match in _lookup.allMatches(source)) {
      final line = '\n'.allMatches(source.substring(0, match.start)).length + 1;
      yield _Reference(entity.path, line, match.group(1)!);
    }
  }
}

Map<String, dynamic> _flatten(Map<String, dynamic> node, [String prefix = '']) {
  final flat = <String, dynamic>{};
  for (final entry in node.entries) {
    final value = entry.value;
    if (value is Map<String, dynamic>) {
      flat.addAll(_flatten(value, '$prefix${entry.key}.'));
    } else {
      flat['$prefix${entry.key}'] = value;
    }
  }
  return flat;
}

Map<String, dynamic> _load(String locale) =>
    _flatten(jsonDecode(File('assets/i18n/$locale.json').readAsStringSync())
        as Map<String, dynamic>);

void main() {
  test('every key the code asks for is defined in en.json', () {
    final en = _load('en');
    final missing = <_Reference>[
      for (final reference in _referencesIn('lib'))
        if (!en.containsKey(reference.key)) reference,
    ];

    // A key that no locale defines renders as the raw key on screen.
    expect(missing, isEmpty, reason: 'undefined keys:\n${missing.join('\n')}');
  });

  test('every locale carries the same keys as en.json', () {
    final en = _load('en');
    for (final locale in ['de', 'es', 'fr', 'it', 'ja', 'nl', 'zh']) {
      final translation = _load(locale);
      expect(
        translation.keys.toSet().difference(en.keys.toSet()),
        isEmpty,
        reason: '$locale defines keys en.json does not',
      );
      expect(
        en.keys.toSet().difference(translation.keys.toSet()),
        isEmpty,
        reason: '$locale is missing keys en.json defines',
      );
    }
  });
}

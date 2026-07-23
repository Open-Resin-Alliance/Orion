/*
* Orion - Thumbnail Cache Clear Test
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

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:orion/util/thumbnail_cache.dart';
import 'package:path/path.dart' as p;

Directory _expectedDiskCacheDir() {
  if (Platform.isLinux) {
    final xdg = Platform.environment['XDG_CACHE_HOME'] ??
        (Platform.environment['HOME'] != null
            ? p.join(Platform.environment['HOME']!, '.cache')
            : null);
    if (xdg != null && xdg.isNotEmpty) {
      return Directory(p.join(xdg, 'orion_thumbnail_cache'));
    } else {
      return Directory(
          p.join(Directory.systemTemp.path, 'orion_thumbnail_cache'));
    }
  } else if (Platform.isMacOS) {
    final home = Platform.environment['HOME'] ?? '.';
    return Directory(
        p.join(home, 'Library', 'Caches', 'orion_thumbnail_cache'));
  } else if (Platform.isWindows) {
    final local = Platform.environment['LOCALAPPDATA'] ??
        Platform.environment['USERPROFILE'] ??
        '.';
    return Directory(p.join(local, 'orion_thumbnail_cache'));
  } else {
    return Directory(
        p.join(Directory.systemTemp.path, 'orion_thumbnail_cache'));
  }
}

void main() {
  test('clearDisk removes files in disk cache directory', () async {
    final dir = _expectedDiskCacheDir();
    if (!await dir.exists()) await dir.create(recursive: true);

    final testFile = File(p.join(dir.path, 'thumbnail_cache_clear_test.tmp'));
    await testFile.writeAsString('dummy');
    expect(await testFile.exists(), isTrue,
        reason: 'test file should exist before clearDisk');

    // Now call clearDisk and expect the file to be removed (best-effort).
    await ThumbnailCache.instance.clearDisk();

    // Allow for potential async deletion scheduling; check that file no longer exists
    // or that the directory may have been cleaned.
    final existsAfter = await testFile.exists();
    expect(existsAfter, isFalse,
        reason:
            'clearDisk should remove cache files created under the thumbnail disk cache dir');
  });

  test('clear() runs without error (memory clear)', () async {
    // This test simply ensures the in-memory clear does not throw.
    ThumbnailCache.instance.clear();
  });
}

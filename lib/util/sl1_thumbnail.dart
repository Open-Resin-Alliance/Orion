/*
* Orion - Thumbnail Util
* Copyright (C) 2024 Open Resin Alliance
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
import 'package:logging/logging.dart';
import 'package:orion/api_services/api_services.dart';
import 'package:path_provider/path_provider.dart';

class ThumbnailUtil {
  static final _logger = Logger('ThumbnailUtil');
  static final ApiService _api = ApiService();

  static Future<String> extractThumbnail(
      String location, String subdirectory, String filename,
      {String size = "Small"}) async {
    try {
      String finalLocation = _isDefaultDir(subdirectory)
          ? filename
          : [subdirectory, filename].join('/');
      final bytes = await _api.getFileThumbnail(location, finalLocation, size);

      final tempDir = await getTemporaryDirectory();
      final orionTmpDir = Directory('${tempDir.path}/oriontmp/$finalLocation');
      if (!await orionTmpDir.exists()) {
        await orionTmpDir.create(recursive: true);
      }

      final filePath = size == "Small"
          ? '${orionTmpDir.path}/thumbnail400x400.png'
          : '${orionTmpDir.path}/thumbnail840x400.png';
      final outputFile = File(filePath);
      outputFile.writeAsBytesSync(bytes);

      // Check the total size of the oriontmp directory
      int totalSize = 0;
      final files = orionTmpDir.listSync(recursive: true);
      for (var file in files) {
        if (file is File) {
          totalSize += await file.length();
        }
      }

      // If the total size exceeds 100MB, delete the oldest files
      if (totalSize > 100 * 1024 * 1024) {
        files.sort(
            (a, b) => a.statSync().modified.compareTo(b.statSync().modified));
        while (totalSize > 100 * 1024 * 1024 && files.isNotEmpty) {
          int fileSize = await (files.first as File).length();
          await files.first.delete();
          totalSize -= fileSize;
          files.removeAt(0);
        }
      }

      return filePath;
    } catch (e) {
      _logger.severe('Failed to fetch thumbnail', e);
    }

    return 'assets/images/placeholder.png';
  }

  static bool _isDefaultDir(String subdirectory) {
    return subdirectory == '';
  }
}

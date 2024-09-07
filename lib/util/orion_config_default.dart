// orion_config_default.dart

/*
* Orion - Config
* Copyright (C) 2024 TheContrappostoShop
*
* This program is free software: you can redistribute it and/or modify
* it under the terms of the GNU General Public License as published by
* the Free Software Foundation, either version 3 of the License, or
* (at your option) any later version.
*
* This program is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
* GNU General Public License for more details.
*
* You should have received a copy of the GNU General Public License
* along with this program.  If not, see <http://www.gnu.org/licenses/>.
*/

import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as path;

String _configPath = Platform.environment['ORION_CFG'] ?? '.';

Map<String, dynamic> getConfig() {
  var fullPath = path.join(_configPath, 'orion.cfg');
  var configFile = File(fullPath);

  if (!configFile.existsSync() || configFile.readAsStringSync().isEmpty) {
    var defaultConfig = {
      'general': {
        'themeMode': 'dark',
      },
      'advanced': {},
    };
    writeConfig(defaultConfig);
    return defaultConfig;
  }

  return json.decode(configFile.readAsStringSync());
}

void writeConfig(Map<String, dynamic> config) {
  var fullPath = path.join(_configPath, 'orion.cfg');
  var configFile = File(fullPath);
  var encoder = const JsonEncoder.withIndent('  ');
  configFile.writeAsStringSync(encoder.convert(config));
}

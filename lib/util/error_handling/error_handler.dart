/*
* Orion - Error Handler
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

import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';

class ErrorHandler {
  static final _logger = Logger('ErrorHandler');

  static void onError(Object error, StackTrace stackTrace) {
    _logger.severe("Error encountered:", error, stackTrace);
    return;
  }

  static void onErrorDetails(FlutterErrorDetails details) {
    _logger.severe(
        "Flutter error encountered:", details.exception, details.stack);
    return;
  }
}

/*
* Orion - NanoDLP Status Mapping Test
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

import 'package:test/test.dart';

import 'package:orion/backend_service/nanodlp/models/nano_status.dart';
import 'package:orion/backend_service/nanodlp/nanodlp_mappers.dart';
import 'package:orion/backend_service/odyssey/models/status_models.dart';

void main() {
  test('nano status mapping includes print_data when printing without file',
      () {
    final raw = {
      'Printing': true,
      'LayerID': 5,
      'LayersCount': 100,
      // No 'file' key present to simulate backend delay
      'CurrentHeight': 150000
    };

    final ns = NanoStatus.fromJson(raw);
    final mapped = nanoStatusToOdysseyMap(ns);
    final statusModel = StatusModel.fromJson(mapped);

    expect(statusModel.isPrinting, isTrue);
    // We expect printData to be non-null because mapper supplies minimal
    // print_data when backend reports printing but lacks file metadata.
    expect(statusModel.printData, isNotNull);
  });
}

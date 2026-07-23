/*
* Orion - Odyssey HTTP Client Test
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

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:orion/backend_service/odyssey/odyssey_http_client.dart';

void main() {
  test('OdysseyHttpClient getStatus fails fast when backend is unresponsive',
      () async {
    final client = OdysseyHttpClient(
      clientFactory: () => _NeverCompletesClient(),
      requestTimeout: const Duration(milliseconds: 25),
    );

    final sw = Stopwatch()..start();
    final future = client.getStatus();
    await expectLater(future, throwsA(isA<TimeoutException>()));
    sw.stop();

    expect(sw.elapsed, lessThan(const Duration(milliseconds: 300)));
  });
}

class _NeverCompletesClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    return Completer<http.StreamedResponse>().future;
  }

  @override
  void close() {}
}

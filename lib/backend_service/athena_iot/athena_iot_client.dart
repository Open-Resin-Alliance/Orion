/*
* Orion - Athena IoT Client
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
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';
import 'models/athena_printer_data.dart';
import 'models/athena_feature_flags.dart';

class AthenaIotClient {
  AthenaIotClient(this.baseUrl,
      {http.Client Function()? clientFactory, Duration? requestTimeout})
      : _clientFactory = clientFactory ?? http.Client.new,
        _requestTimeout = requestTimeout ?? const Duration(seconds: 5) {
    _log = Logger('AthenaIotClient');
  }

  final String baseUrl;
  late final Logger _log;
  final http.Client Function() _clientFactory;
  final Duration _requestTimeout;

  http.Client _createClient() {
    final inner = _clientFactory();
    return _TimeoutHttpClient(inner, _requestTimeout, _log, 'AthenaIoT');
  }

  Future<Map<String, dynamic>> getPrinterData() async {
    try {
      final baseNoSlash = baseUrl.replaceAll(RegExp(r'/+$'), '');
      final uri = Uri.parse('$baseNoSlash/athena-iot/orion/printer_data');
      final client = _createClient();
      _log.fine('received data: $uri');
      try {
        final resp = await client.get(uri);
        if (resp.statusCode != 200) return <String, dynamic>{};
        final decoded = json.decode(resp.body);
        if (decoded is Map<String, dynamic>) return decoded;
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
        return <String, dynamic>{};
      } finally {
        client.close();
      }
    } catch (e, st) {
      _log.fine('Failed to fetch Athena printer_data', e, st);
      return <String, dynamic>{};
    }
  }

  /// Typed parser for `printer_data` returning an [AthenaPrinterData].
  Future<AthenaPrinterData?> getPrinterDataModel() async {
    final raw = await getPrinterData();
    try {
      if (raw.isEmpty) return null;
      return AthenaPrinterData.fromJson(raw);
    } catch (e, st) {
      _log.fine('Failed to parse Athena printer_data into model', e, st);
      return null;
    }
  }

  Future<Map<String, dynamic>> getFeatureFlags() async {
    try {
      final baseNoSlash = baseUrl.replaceAll(RegExp(r'/+$'), '');
      final uri = Uri.parse('$baseNoSlash/athena-iot/orion/feature_flags');
      final client = _createClient();
      try {
        final resp = await client.get(uri);
        if (resp.statusCode != 200) return <String, dynamic>{};
        final decoded = json.decode(resp.body);
        if (decoded is Map<String, dynamic>) return decoded;
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
        return <String, dynamic>{};
      } finally {
        client.close();
      }
    } catch (e, st) {
      _log.fine('Failed to fetch Athena feature_flags', e, st);
      return <String, dynamic>{};
    }
  }

  /// Typed parser for `feature_flags` returning an [AthenaFeatureFlags].
  Future<AthenaFeatureFlags?> getFeatureFlagsModel() async {
    final raw = await getFeatureFlags();
    try {
      if (raw.isEmpty) return null;
      return AthenaFeatureFlags.fromJson(raw);
    } catch (e, st) {
      _log.fine('Failed to parse Athena feature_flags into model', e, st);
      return null;
    }
  }
}

class _TimeoutHttpClient extends http.BaseClient {
  _TimeoutHttpClient(this._inner, this._timeout, this._log, this._label);

  final http.Client _inner;
  final Duration _timeout;
  final Logger _log;
  final String _label;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    final future = _inner.send(request);
    return future.timeout(_timeout, onTimeout: () {
      final msg =
          '$_label ${request.method} ${request.url} timed out after ${_timeout.inSeconds}s';
      _log.warning(msg);
      throw TimeoutException(msg);
    });
  }

  @override
  void close() {
    _inner.close();
  }
}

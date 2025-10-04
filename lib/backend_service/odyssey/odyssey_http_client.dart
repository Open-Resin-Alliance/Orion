/*
* Orion - NanoDLP HTTP Client
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

import 'dart:typed_data';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';
import 'package:orion/backend_service/odyssey/odyssey_client.dart';
import 'package:orion/util/orion_config.dart';

class OdysseyHttpClient implements OdysseyClient {
  late final String apiUrl;
  final _log = Logger('OdysseyHttpClient');
  final http.Client Function() _clientFactory;
  final Duration _requestTimeout;

  OdysseyHttpClient(
      {http.Client Function()? clientFactory, Duration? requestTimeout})
      : _clientFactory = clientFactory ?? http.Client.new,
        _requestTimeout = requestTimeout ?? const Duration(seconds: 2) {
    try {
      OrionConfig config = OrionConfig();
      final customUrl = config.getString('customUrl', category: 'advanced');
      final useCustomUrl = config.getFlag('useCustomUrl', category: 'advanced');
      apiUrl = useCustomUrl ? customUrl : 'http://localhost:12357';
    } catch (e) {
      throw Exception('Failed to load orion.cfg: $e');
    }
  }

  http.Client _createClient() {
    final inner = _clientFactory();
    return _TimeoutHttpClient(inner, _requestTimeout, _log, 'Odyssey');
  }

  @override
  Future<Map<String, dynamic>> listItems(
      String location, int pageSize, int pageIndex, String subdirectory) async {
    final queryParams = {
      'location': location,
      'subdirectory': subdirectory,
      'page_index': pageIndex.toString(),
      'page_size': pageSize.toString(),
    };
    final resp = await _odysseyGet('/files', queryParams);
    return json.decode(resp.body) as Map<String, dynamic>;
  }

  @override
  Future<bool> usbAvailable() async {
    try {
      await listItems('Local', 1, 0, '');
    } catch (e) {
      return false;
    }

    try {
      await listItems('Usb', 1, 0, '');
      return true;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<Map<String, dynamic>> getFileMetadata(
      String location, String filePath) async {
    final queryParams = {'location': location, 'file_path': filePath};
    final resp = await _odysseyGet('/file/metadata', queryParams);
    return json.decode(resp.body) as Map<String, dynamic>;
  }

  @override
  Future<Map<String, dynamic>> getConfig() async {
    final resp = await _odysseyGet('/config', {});
    return json.decode(resp.body) as Map<String, dynamic>;
  }

  @override
  Future<Map<String, dynamic>> getStatus() async {
    final resp = await _odysseyGet('/status', {});
    return json.decode(resp.body) as Map<String, dynamic>;
  }

  @override
  Stream<Map<String, dynamic>> getStatusStream() async* {
    final uri = _dynUri(apiUrl, '/status/stream', {});
    final request = http.Request('GET', uri);

    final client = _createClient();
    try {
      final streamed = await client.send(request);
      final stream = streamed.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter());

      await for (final line in stream) {
        if (line.startsWith('data:')) {
          final payload = line.substring(5).trim();
          if (payload.isEmpty) continue;
          try {
            final jsonObj = json.decode(payload) as Map<String, dynamic>;
            yield jsonObj;
          } catch (e) {
            continue;
          }
        }
      }
    } finally {
      client.close();
    }
  }

  @override
  Future<void> cancelPrint() async {
    await _odysseyPost('/print/cancel', {});
  }

  @override
  Future<void> pausePrint() async {
    await _odysseyPost('/print/pause', {});
  }

  @override
  Future<void> resumePrint() async {
    await _odysseyPost('/print/resume', {});
  }

  @override
  Future<Map<String, dynamic>> move(double height) async {
    final resp = await _odysseyPost('/manual', {'z': height.toString()});
    return json.decode(resp.body == '' ? '{}' : resp.body)
        as Map<String, dynamic>;
  }

  @override
  Future<Map<String, dynamic>> moveDelta(double deltaMm) async {
    final resp = await _odysseyPost('/manual', {'dz': deltaMm.toString()});
    return json.decode(resp.body == '' ? '{}' : resp.body)
        as Map<String, dynamic>;
  }

  @override
  Future<bool> canMoveToTop() async => false;

  @override
  Future<Map<String, dynamic>> moveToTop() async =>
      throw UnimplementedError('moveToTop not supported by Odyssey backend');

  @override
  Future<Map<String, dynamic>> manualCure(bool cure) async {
    final resp = await _odysseyPost('/manual', {'cure': cure.toString()});
    return json.decode(resp.body == '' ? '{}' : resp.body)
        as Map<String, dynamic>;
  }

  @override
  Future<Map<String, dynamic>> manualHome() async {
    final resp = await _odysseyPost('/manual/home', {});
    return json.decode(resp.body == '' ? '{}' : resp.body)
        as Map<String, dynamic>;
  }

  @override
  Future<Map<String, dynamic>> manualCommand(String command) async {
    final resp =
        await _odysseyPost('/manual/hardware_command', {'command': command});
    return json.decode(resp.body == '' ? '{}' : resp.body)
        as Map<String, dynamic>;
  }

  @override
  Future<void> displayTest(String test) async {
    await _odysseyPost('/manual/display_test', {'test': test});
  }

  @override
  Future<Uint8List> getFileThumbnail(
      String location, String filePath, String size) async {
    final queryParams = {
      'location': location,
      'file_path': filePath,
      'size': size
    };
    final resp = await _odysseyGet('/file/thumbnail', queryParams);
    return resp.bodyBytes;
  }

  @override
  Future<void> startPrint(String location, String filePath) async {
    await _odysseyPost(
        '/print/start', {'location': location, 'file_path': filePath});
  }

  @override
  Future<Map<String, dynamic>> deleteFile(
      String location, String filePath) async {
    final resp = await _odysseyDelete(
        '/file', {'location': location, 'file_path': filePath});
    return json.decode(resp.body) as Map<String, dynamic>;
  }

  // Internal helpers
  Uri _dynUri(String apiUrl, String path, Map<String, dynamic> queryParams) {
    if (queryParams.containsKey('file_path')) {
      queryParams['file_path'] =
          queryParams['file_path'].toString().replaceAll('//', '');
    }

    if (apiUrl.startsWith('https://')) {
      return Uri.https(apiUrl.replaceFirst('https://', ''), path, queryParams);
    } else if (apiUrl.startsWith('http://')) {
      return Uri.http(apiUrl.replaceFirst('http://', ''), path, queryParams);
    } else {
      throw ArgumentError('apiUrl must start with either http:// or https://');
    }
  }

  Future<http.Response> _odysseyGet(
      String endpoint, Map<String, dynamic> queryParams) async {
    final uri = _dynUri(apiUrl, endpoint, queryParams);
    final client = _createClient();
    try {
      final response = await client.get(uri);
      if (response.statusCode == 200) return response;
      throw Exception(
          'Odyssey GET call failed: ${response.statusCode} ${response.body}');
    } finally {
      client.close();
    }
  }

  Future<http.Response> _odysseyPost(
      String endpoint, Map<String, dynamic> queryParams) async {
    final uri = _dynUri(apiUrl, endpoint, queryParams);
    final client = _createClient();
    try {
      final response = await client.post(uri);
      if (response.statusCode == 200) return response;
      throw Exception(
          'Odyssey POST call failed: ${response.statusCode} ${response.body}');
    } finally {
      client.close();
    }
  }

  Future<http.Response> _odysseyDelete(
      String endpoint, Map<String, dynamic> queryParams) async {
    final uri = _dynUri(apiUrl, endpoint, queryParams);
    final client = _createClient();
    try {
      final response = await client.delete(uri);
      if (response.statusCode == 200) return response;
      throw Exception(
          'Odyssey DELETE call failed: ${response.statusCode} ${response.body}');
    } finally {
      client.close();
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

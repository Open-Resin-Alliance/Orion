import 'dart:typed_data';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:orion/backend_service/odyssey/odyssey_client.dart';
import 'package:orion/util/orion_config.dart';

class OdysseyHttpClient implements OdysseyClient {
  late final String apiUrl;

  OdysseyHttpClient() {
    try {
      OrionConfig config = OrionConfig();
      final customUrl = config.getString('customUrl', category: 'advanced');
      final useCustomUrl = config.getFlag('useCustomUrl', category: 'advanced');
      apiUrl = useCustomUrl ? customUrl : 'http://localhost:12357';
    } catch (e) {
      throw Exception('Failed to load orion.cfg: $e');
    }
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

    final client = http.Client();
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
    final client = http.Client();
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
    final client = http.Client();
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
    final client = http.Client();
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

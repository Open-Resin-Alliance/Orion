import 'package:test/test.dart';
import 'dart:convert';

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

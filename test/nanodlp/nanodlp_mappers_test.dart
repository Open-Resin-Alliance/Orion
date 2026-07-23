import 'package:flutter_test/flutter_test.dart';
import 'package:orion/backend_service/nanodlp/models/nano_file.dart';
import 'package:orion/backend_service/nanodlp/models/nano_status.dart';
import 'package:orion/backend_service/nanodlp/nanodlp_mappers.dart';

void main() {
  test('nanoStatusToOdysseyMap maps printing status correctly', () {
    final file = NanoFile(
        path: '/files/model.stl',
        name: 'model.stl',
        layerCount: 120,
        printTime: 3600);
    final ns = NanoStatus(
        printing: true,
        paused: false,
        state: 'printing',
        progress: 0.5,
        file: file,
        z: 12.34,
        curing: true);

    final mapped = nanoStatusToOdysseyMap(ns);

    expect(mapped['status'], equals('Printing'));
    expect(mapped['paused'], equals(false));
    expect(mapped['physical_state'], isA<Map<String, dynamic>>());
    final phys = mapped['physical_state'] as Map<String, dynamic>;
    expect(phys['z'], equals(12.34));
    expect(phys['curing'], equals(true));

    final pd = mapped['print_data'] as Map<String, dynamic>?;
    expect(pd, isNotNull);
    expect(pd!['layer_count'], equals(120));
    final fileData = pd['file_data'] as Map<String, dynamic>;
    expect(fileData['name'], equals('model.stl'));
    expect(fileData['path'], equals('/files/model.stl'));
  });
}

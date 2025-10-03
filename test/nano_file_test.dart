import 'package:flutter_test/flutter_test.dart';
import 'package:orion/backend_service/nanodlp/models/nano_file.dart';

void main() {
  group('NanoFile.fromJson', () {
    test('parses print time, layer height, and odyssey mapping', () {
      final file = NanoFile.fromJson({
        'Path': 'plates/example.ctb',
        'LayerCount': '125',
        'PrintTime': '~01:02:03',
        'LastModified': '1690000000',
        'LayerThickness': '50.00µ',
        'Size': '123456',
        'used_material': '12.34',
        'Preview': true,
        'PlateID': '42',
      });

      expect(file.resolvedPath, 'plates/example.ctb');
      expect(file.name, 'example.ctb');
      expect(file.layerCount, 125);
      expect(file.printTime, closeTo(3723, 0.001));
      expect(file.layerHeight, closeTo(0.05, 1e-6));
      expect(file.previewAvailable, isTrue);
      expect(file.plateId, 42);

      final entry = file.toOdysseyFileEntry();
      expect(entry['file_data'], {
        'path': 'plates/example.ctb',
        'name': 'example.ctb',
        'last_modified': 1690000000,
        'parent_path': 'plates',
        'file_size': 123456,
      });
      expect(entry['print_time'], closeTo(3723, 0.001));
      expect(entry['layer_count'], 125);
      expect(entry['layer_height'], closeTo(0.05, 1e-6));
      expect(entry['used_material'], closeTo(12.34, 1e-6));
      expect(entry['preview_available'], isTrue);
      expect(entry['plate_id'], 42);

      final meta = file.toOdysseyMetadata();
      expect(meta['plate_id'], 42);
      expect(meta['preview_available'], isTrue);
    });

    test('derives defaults when name missing', () {
      final file = NanoFile.fromJson({
        'path': 'just-a-plate.cbddlp',
      });

      expect(file.name, 'just-a-plate.cbddlp');
      expect(file.resolvedPath, 'just-a-plate.cbddlp');
      expect(file.parentPath, isEmpty);

      final entry = file.toOdysseyFileEntry();
      expect(entry['file_data']['name'], 'just-a-plate.cbddlp');
      expect(entry['file_data']['path'], 'just-a-plate.cbddlp');
    });
  });
}

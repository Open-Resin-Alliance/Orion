import 'package:orion/backend_service/nanodlp/models/nano_status.dart';

/// Map NanoDLP DTOs into Odyssey-shaped maps expected by StatusModel.fromJson
Map<String, dynamic> nanoStatusToOdysseyMap(NanoStatus ns) {
  // Map NanoDLP-like state strings to Odyssey status strings.
  // If the device reports `paused` explicitly prefer the paused label so
  // the UI can reflect a paused state even when printing flag is present.
  String status;
  if (ns.paused == true) {
    status = 'Paused';
  } else {
    switch (ns.state.toLowerCase()) {
      case 'printing':
      case 'print':
        status = 'Printing';
        break;
      case 'idle':
      default:
        status = 'Idle';
    }
  }

  final file = ns.file;
  Map<String, dynamic>? printData;
  if (file != null) {
    printData = {
      // Prefer explicit layer_count from the file metadata; otherwise
      // fall back to the LayersCount reported in the status payload.
      'layer_count': file.layerCount ?? ns.layersCount ?? 0,
      'used_material': (file.usedMaterial ?? 0.0),
      'print_time': file.printTime ?? 0,
      'file_data': {
        'name': file.name ?? (file.path ?? ''),
        'path': file.path ?? (file.name ?? ''),
        'location_category': 'Local'
      }
    };
  } else if (ns.printing ||
      ns.paused ||
      ns.layerId != null ||
      ns.layersCount != null) {
    // Backend reports an active job but did not include file metadata yet.
    // Return a minimal PrintData object so the UI can render the status
    // screen (avoids showing "No Print Data Available" while job starts).
    printData = {
      'layer_count': ns.layersCount ?? 0,
      'used_material': 0.0,
      'print_time': 0,
      'file_data': null,
    };
  }

  return {
    'status': status,
    // Preserve the explicit paused boolean from the NanoStatus so the
    // StatusModel can determine paused vs printing correctly.
    'paused': ns.paused == true,
    'layer': ns.layerId,
    'print_data': printData,
    // Include the raw device 'Status' message (if present) so UI layers
    // can surface device-provided status text as an override for titles
    // or dialogs when appropriate.
    'device_status_message': ns.statusMessage,
    'physical_state': {'z': ns.z ?? 0.0, 'curing': ns.curing}
  };
}

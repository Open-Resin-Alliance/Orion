/*
* Orion - NanoDLP Status Mapper
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

import 'package:orion/backend_service/nanodlp/models/nano_status.dart';
import 'package:orion/backend_service/nanodlp/nanodlp_state_handler.dart';

/// Map NanoDLP DTOs into Odyssey-shaped maps expected by StatusModel.fromJson
Map<String, dynamic> nanoStatusToOdysseyMap(NanoStatus ns) {
  // Use the canonical NanoDLP state handler to determine authoritative
  // status and paused flags. This handles latching of cancel requests and
  // transient states described by the device's numeric `State` field.
  final canonical = nanoDlpStateHandler.canonicalize(ns);
  final String status = canonical['status'] as String? ?? 'Idle';
  final bool paused = canonical['paused'] as bool? ?? (ns.paused == true);
  final bool cancelLatched = canonical['cancel_latched'] as bool? ?? false;
  final bool finished = canonical['finished'] as bool? ?? false;

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

  // Special handling for cancel latching:
  // - When canonical status is 'Canceling' we should preserve the layer
  //   information (if any) so the UI shows the indeterminate spinner with
  //   the stop icon.
  // - When the handler reports that cancel completed (status == 'Idle' and
  //   cancel_latched == true) represent the snapshot as canceled by setting
  //   layer=null. This lets StatusModel.isCanceled be true and the UI show
  //   the finished/canceled appearance (full red circle + stop icon).
  int? mappedLayer = ns.layerId;
  if (status == 'Idle') {
    if (cancelLatched) {
      // indicate canceled snapshot
      mappedLayer = null;
    } else if (finished) {
      // For a canonical 'finished' snapshot, infer a final layer so the
      // UI renders a green finished state. Prefer file metadata, then
      // reported layersCount.
      if (mappedLayer == null) {
        if (file != null) {
          mappedLayer = file.layerCount ?? ns.layersCount;
        } else if (ns.layersCount != null) {
          mappedLayer = ns.layersCount;
        }
      }
    } else {
      // Not finished and not cancel-latched: keep mappedLayer as-is
      // (may be null if device didn't report it yet).
    }
  }

  final result = {
    'status': status,
    // Use handler-provided paused if available, otherwise fall back to
    // the explicit NanoStatus.paused field.
    'paused': paused,
    'layer': mappedLayer,
    'print_data': printData,
    // Include the raw device 'Status' message (if present) so UI layers
    // can surface device-provided status text as an override for titles
    // or dialogs when appropriate.
    'device_status_message': ns.statusMessage,
    'physical_state': {'z': ns.z ?? 0.0, 'curing': ns.curing},
    // Expose whether the state handler has an active cancel latch so callers
    // (e.g., StatusProvider) can decide UI transitional behavior.
    'cancel_latched': cancelLatched,
    'finished': finished,
  };

  return result;
}

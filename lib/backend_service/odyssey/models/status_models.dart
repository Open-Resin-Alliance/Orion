/*
* Orion - Odyssey Status Models
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

import 'package:flutter/material.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:orion/themes/themes.dart';

part 'status_models.g.dart';

/// Root model returned by the Odyssey `/status` endpoint.
///
/// Contains top-level printer state plus nested [PrintData] and [PhysicalState].
/// Convenience getters provide UI-centric interpretation of backend state
/// (e.g. [isPrinting], [isPaused], [progress], [displayLabel]).
@JsonSerializable(explicitToJson: true)
class StatusModel {
  final String status;
  final bool? paused;
  final int? layer;
  @JsonKey(name: 'cancel_latched')
  final bool? cancelLatched;
  @JsonKey(name: 'pause_latched')
  final bool? pauseLatched;
  final bool? finished;
  @JsonKey(name: 'print_data')
  final PrintData? printData;
  @JsonKey(name: 'physical_state')
  final PhysicalState physicalState;

  StatusModel({
    required this.status,
    required this.paused,
    required this.layer,
    this.cancelLatched,
    this.pauseLatched,
    this.finished,
    required this.printData,
    required this.physicalState,
  });

  factory StatusModel.fromJson(Map<String, dynamic> json) =>
      _$StatusModelFromJson(json);
  Map<String, dynamic> toJson() => _$StatusModelToJson(this);

  // Derived helpers
  bool get isPrinting => status == 'Printing' && !isCanceled;
  bool get isIdle => status == 'Idle';
  bool get isPaused => paused == true;
  bool get isCanceled =>
      layer == null && (printData != null || status != 'Printing');
  bool get isCuring => physicalState.curing == true;

  /// Print progress as 0.0 – 1.0 based on current [layer] and total layer count.
  double get progress {
    if (layer == null) return 0;
    final total = printData?.layerCount;
    if (total == null || total == 0) return 0;
    return layer!.clamp(0, total) / total;
  }

  /// Elapsed print time as reported by backend (converted to [Duration]).
  Duration get elapsedPrintTime =>
      Duration(seconds: (printData?.printTimeSeconds ?? 0));

  /// Formatted elapsed print time as HH:MM:SS (zero-padded).
  String get formattedElapsedPrintTime {
    final d = elapsedPrintTime;
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.inHours)}:${two(d.inMinutes.remainder(60))}:${two(d.inSeconds.remainder(60))}';
  }

  /// Human friendly label factoring in backend state and transitional UI flags.
  String displayLabel(
      {required bool transitionalCancel, required bool transitionalPause}) {
    if (transitionalCancel && !isCanceled) return 'Canceling';
    if (isCanceled) return 'Canceled';
    if (transitionalPause && !isPaused) return 'Pausing';
    if (isPaused) return 'Paused';
    if (isIdle && layer != null) return 'Finished';
    if (isCuring) return 'Curing';
    return status;
  }

  /// Returns an appropriate status color based on state and theme brightness.
  Color statusColor(BuildContext context,
      {required bool transitionalPause, required bool transitionalCancel}) {
    final brightness = Theme.of(context).brightness;
    final scheme = Theme.of(context).colorScheme;
    if (isCuring) {
      return brightness == Brightness.dark
          ? scheme.primaryContainer.withBrightness(1.7)
          : scheme.primary;
    }
    if (transitionalCancel || isCanceled) return Colors.red;
    if (transitionalPause || isPaused) return Colors.orange;
    if (isIdle && layer != null) return Colors.greenAccent;
    if (isPrinting) {
      return brightness == Brightness.dark ? scheme.primary : Colors.black54;
    }
    return Colors.black;
  }
}

/// Machine physical state: current Z position and curing flag.
@JsonSerializable()
class PhysicalState {
  final double z;
  final bool? curing;
  PhysicalState({required this.z, this.curing});

  factory PhysicalState.fromJson(Map<String, dynamic> json) =>
      _$PhysicalStateFromJson(json);
  Map<String, dynamic> toJson() => _$PhysicalStateToJson(this);
}

/// Active or last print metadata.
@JsonSerializable(explicitToJson: true)
class PrintData {
  @JsonKey(name: 'layer_count')
  final int layerCount;
  @JsonKey(name: 'used_material')
  final double usedMaterial;
  @JsonKey(name: 'print_time')
  final num printTime;
  @JsonKey(name: 'file_data')
  final FileData? fileData;

  PrintData({
    required this.layerCount,
    required this.usedMaterial,
    required this.printTime,
    required this.fileData,
  });

  factory PrintData.fromJson(Map<String, dynamic> json) =>
      _$PrintDataFromJson(json);
  Map<String, dynamic> toJson() => _$PrintDataToJson(this);

  /// Raw backend print time (seconds) coerced to int.
  int get printTimeSeconds => printTime.toInt();
}

/// Selected file metadata for the active print job.
@JsonSerializable()
class FileData {
  final String name;
  final String path;
  @JsonKey(name: 'location_category')
  final String? locationCategory;
  FileData({required this.name, required this.path, this.locationCategory});

  factory FileData.fromJson(Map<String, dynamic> json) =>
      _$FileDataFromJson(json);
  Map<String, dynamic> toJson() => _$FileDataToJson(this);
}

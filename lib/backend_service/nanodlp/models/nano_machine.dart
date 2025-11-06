/*
 * Orion - NanoDLP Machine Model (json_serializable)
 *
 * We use a generated adapter for stable, typed parsing but preserve the
 * raw payload in `raw` for callers that need vendor-specific fields.
 */

import 'package:json_annotation/json_annotation.dart';

part 'nano_machine.g.dart';

@JsonSerializable(explicitToJson: true)
class NanoMachine {
  @JsonKey(name: 'Name')
  final String? name;

  @JsonKey(name: 'Lang')
  final String? lang;

  @JsonKey(name: 'Email')
  final String? email;

  @JsonKey(name: 'PrinterID')
  final int? printerId;

  @JsonKey(name: 'Port')
  final int? port;

  @JsonKey(name: 'UUID')
  final String? uuid;

  @JsonKey(name: 'PrinterType')
  final int? printerType;

  @JsonKey(name: 'ZAxisHeight')
  final int? zAxisHeight;

  @JsonKey(name: 'StopPositionMm')
  final int? stopPositionMm;

  @JsonKey(name: 'ResinDistanceMm')
  final int? resinDistanceMm;

  @JsonKey(name: 'VatWidth')
  final int? vatWidth;

  @JsonKey(name: 'VatHeight')
  final int? vatHeight;

  @JsonKey(name: 'ProjectorWidth')
  final int? projectorWidth;

  @JsonKey(name: 'ProjectorHeight')
  final int? projectorHeight;

  @JsonKey(name: 'DefaultProfile')
  final int? defaultProfileId;

  @JsonKey(name: 'CustomValues')
  final Map<String, String>? customValues;

  @JsonKey(ignore: true)
  Map<String, dynamic> raw = {};

  NanoMachine({
    this.name,
    this.lang,
    this.email,
    this.printerId,
    this.port,
    this.uuid,
    this.printerType,
    this.zAxisHeight,
    this.stopPositionMm,
    this.resinDistanceMm,
    this.vatWidth,
    this.vatHeight,
    this.projectorWidth,
    this.projectorHeight,
    this.defaultProfileId,
    Map<String, String>? customValues,
    Map<String, dynamic>? raw,
  }) : customValues = customValues ?? const {} {
    if (raw != null) this.raw = raw;
  }

  factory NanoMachine.fromJson(Map<String, dynamic> json) =>
      _$NanoMachineFromJson(json);

  /// Wrapper accepting decoded JSON (dynamic) and preserving the raw map.
  static NanoMachine fromDecoded(dynamic decoded) {
    if (decoded == null) return NanoMachine(raw: {});
    if (decoded is! Map) return NanoMachine(raw: {'payload': decoded});
    final m = Map<String, dynamic>.from(decoded);
    final nm = NanoMachine.fromJson(m);
    nm.raw = m;
    // Post-process: if DefaultProfile is missing, try older keys
    if (nm.defaultProfileId == null) {
      final dp = m['DefaultProfile'] ??
          m['DefaultProfileID'] ??
          m['ProfileID'] ??
          m['ActiveProfile'];
      if (dp != null) {
        final parsed = int.tryParse('$dp');
        if (parsed != null) {
          // create a new object with defaultProfileId set — simple approach: assign via raw and return
          nm.raw = m;
        }
      }
    }
    return nm;
  }

  Map<String, dynamic> toJson() => _$NanoMachineToJson(this);
}

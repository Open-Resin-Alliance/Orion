/*
* Orion - Leveling Log Entry
* Copyright (C) 2026 Open Resin Alliance
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

import 'package:orion/backend_service/athena_iot/models/force_leveling_workflow.dart';

/// Per-corner log data extracted from a [ForceProbeMeasurements].
class CornerLogData {
  const CornerLogData({
    this.finalZ,
    this.firstStagePeakForce,
    this.secondStagePeakForce,
    this.firstStageOvershoot,
    this.secondStageOvershoot,
  });

  final double? finalZ;
  final double? firstStagePeakForce;
  final double? secondStagePeakForce;
  final double? firstStageOvershoot;
  final double? secondStageOvershoot;

  factory CornerLogData.fromMeasurements(ForceProbeMeasurements? m) {
    if (m == null) return const CornerLogData();
    return CornerLogData(
      finalZ: m.secondStageTriggerZ,
      firstStagePeakForce: m.firstStagePeakForce,
      secondStagePeakForce: m.secondStagePeakForce,
      firstStageOvershoot: m.firstStageOvershoot,
      secondStageOvershoot: m.secondStageOvershoot,
    );
  }

  Map<String, dynamic> toJson() => {
        'final_z_mm': finalZ,
        'first_stage_peak_force_gf': firstStagePeakForce,
        'second_stage_peak_force_gf': secondStagePeakForce,
        'first_stage_overshoot': firstStageOvershoot,
        'second_stage_overshoot': secondStageOvershoot,
      };
}

/// Snapshot of probe configuration parameters from the first probe response.
class ProbeConfigSnapshot {
  const ProbeConfigSnapshot({
    this.firstStageSpeed,
    this.secondStageSpeed,
    this.firstStageLiftHeight,
    this.secondStageLiftHeight,
    this.firstStageThreshold,
    this.secondStageThreshold,
    this.probeStartDistance,
    this.probeRetractDistance,
  });

  final double? firstStageSpeed;
  final double? secondStageSpeed;
  final double? firstStageLiftHeight;
  final double? secondStageLiftHeight;
  final double? firstStageThreshold;
  final double? secondStageThreshold;
  final double? probeStartDistance;
  final double? probeRetractDistance;

  factory ProbeConfigSnapshot.fromMeasurements(ForceProbeMeasurements? m) {
    if (m == null) return const ProbeConfigSnapshot();
    return ProbeConfigSnapshot(
      firstStageSpeed: m.firstStageSpeed,
      secondStageSpeed: m.secondStageSpeed,
      firstStageLiftHeight: m.firstStageLiftHeight,
      secondStageLiftHeight: m.secondStageLiftHeight,
      firstStageThreshold: m.firstStageThreshold,
      secondStageThreshold: m.secondStageThreshold,
      probeStartDistance: m.probeStartDistance,
      probeRetractDistance: m.probeRetractDistance,
    );
  }

  Map<String, dynamic> toJson() => {
        'first_stage_speed': firstStageSpeed,
        'second_stage_speed': secondStageSpeed,
        'first_stage_lift_height': firstStageLiftHeight,
        'second_stage_lift_height': secondStageLiftHeight,
        'first_stage_threshold': firstStageThreshold,
        'second_stage_threshold': secondStageThreshold,
        'probe_start_distance': probeStartDistance,
        'probe_retract_distance': probeRetractDistance,
      };
}

/// One complete corner-check session (4 corners probed, deviation computed).
class LevelingLogEntry {
  const LevelingLogEntry({
    required this.sessionId,
    required this.timestamp,
    required this.variant,
    required this.recheckNumber,
    required this.corners,
    required this.totalDeviationMm,
    required this.passed,
    this.probeConfig,
    this.estimatedCoupling,
    this.couplingIsSeed,
    this.preAdjustmentDeviation,
    this.commandedDeltaGf,
    this.gapAtCommandMm,
    this.measuredGapMoveMm,
    this.couplingSample,
    this.sampleOutcome,
    this.stictionEscalations,
  });

  final String sessionId;
  final String timestamp;
  final String variant;
  final int recheckNumber;
  final Map<String, CornerLogData> corners;
  final double totalDeviationMm;
  final bool passed;
  final ProbeConfigSnapshot? probeConfig;

  /// Current force→Z coupling estimate (mm/gf, gap-space, negative).
  final double? estimatedCoupling;

  /// True while [estimatedCoupling] is still the conservative seed
  /// (possibly stiction-scaled) rather than a measured value.
  final bool? couplingIsSeed;

  /// Deviation snapshot from *before* the adjustment that preceded this
  /// recheck.  Used to detect divergence (adjustment going the wrong way).
  final double? preAdjustmentDeviation;

  // ── Adjustment-cycle telemetry (back-screw cycles only) ──

  /// Force delta the gauge asked the user to reach (gf, negative = tighten).
  final double? commandedDeltaGf;

  /// Gap (frontAvgZ − backZ) the command was computed from (mm).
  final double? gapAtCommandMm;

  /// Relative back-vs-front movement achieved by the adjustment (mm).
  final double? measuredGapMoveMm;

  /// Raw coupling sample before clamping (mm/gf), when computable.
  final double? couplingSample;

  /// Name of the `CouplingUpdateOutcome` for this cycle.
  final String? sampleOutcome;

  /// Stiction escalations so far this session.
  final int? stictionEscalations;

  Map<String, dynamic> toJson() => {
        'session_id': sessionId,
        'timestamp': timestamp,
        'variant': variant,
        'recheck_number': recheckNumber,
        'corners': corners.map((k, v) => MapEntry(k, v.toJson())),
        'total_deviation_mm': totalDeviationMm,
        'passed': passed,
        'probe_config': probeConfig?.toJson(),
        'estimated_coupling_mm_per_gf': estimatedCoupling,
        'coupling_is_seed': couplingIsSeed,
        'pre_adjustment_deviation_mm': preAdjustmentDeviation,
        'commanded_delta_gf': commandedDeltaGf,
        'gap_at_command_mm': gapAtCommandMm,
        'measured_gap_move_mm': measuredGapMoveMm,
        'coupling_sample_mm_per_gf': couplingSample,
        'sample_outcome': sampleOutcome,
        'stiction_escalations': stictionEscalations,
      };
}

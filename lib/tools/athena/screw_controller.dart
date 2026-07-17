/*
* Orion - Leveling Screw Controller
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

import 'dart:math' as math;

/// Corner indexing used throughout leveling: 0=FL, 1=FR, 2=BR, 3=BL.
/// Screw mapping: corners 0/1 → the respective front screw, corners
/// 2/3 → the single shared back screw on the centerline.
///
/// Pick which corner (and therefore which screw) to adjust for the
/// given corner Z values.
///
/// Pure front-to-back tilt (both front corners on one side of both
/// back corners) → the shared back screw, represented by the back
/// corner furthest from the front-plane average (for puck placement
/// and gauge anchoring).
///
/// Anything else is a diagonal imbalance and is ALWAYS routed to the
/// FRONT corner of the worst diagonal pair.  The back screw sits on
/// the centerline and cannot twist the plate — it raises or lowers
/// BOTH back corners, so "fixing" a low back corner with it converts
/// the diagonal error into front-back tilt and the wizard ping-pongs
/// between tighten and loosen forever.  The front screws are the only
/// per-side actuators: tightening a front corner raises it and lowers
/// its diagonal-opposite rear corner via the cantilever pivot (and
/// vice versa), which is exactly the corrective motion a diagonal
/// needs.
int selectAdjustmentCorner(List<double> z) {
  assert(z.length >= 4);
  final frontAvg = (z[0] + z[1]) / 2;
  final allFrontHigher =
      z[0] > z[2] && z[0] > z[3] && z[1] > z[2] && z[1] > z[3];
  final allBackHigher =
      z[2] > z[0] && z[2] > z[1] && z[3] > z[0] && z[3] > z[1];

  if (allFrontHigher || allBackHigher) {
    // Front-to-back tilt → back screw; show the worst back outlier.
    return (z[2] - frontAvg).abs() >= (z[3] - frontAvg).abs() ? 2 : 3;
  }

  // Diagonal imbalance → the front corner of the worst pair.
  final diagFLBR = (z[0] - z[2]).abs(); // FL ↔ BR
  final diagFRBL = (z[1] - z[3]).abs(); // FR ↔ BL
  return diagFLBR >= diagFRBL ? 0 : 1;
}

/// Signed gap the screw for [cornerIndex] should close (mm).
///
/// Positive → the adjusted corner is LOW relative to its reference →
/// tighten; negative → high → loosen.
///
/// * Back screw (2/3): front average minus BACK AVERAGE — the shared
///   screw moves the whole back edge, so the edge average is the
///   controlled variable, not one outlier corner.
/// * Front screws: the two corners NOT on the adjusting corner's
///   diagonal sit on the pivot axis and form the reference plane
///   (FL ref = FR+BL, FR ref = FL+BR).
double adjustmentGapMm(int cornerIndex, List<double> z) {
  assert(z.length >= 4);
  switch (cornerIndex) {
    case 0:
      return (z[1] + z[3]) / 2 - z[0];
    case 1:
      return (z[0] + z[2]) / 2 - z[1];
    default:
      return (z[0] + z[1]) / 2 - (z[2] + z[3]) / 2;
  }
}

/// Adaptive force→Z coupling controller for ONE leveling screw.
/// Instantiate one per screw (FL, FR, back) — coupling is a physical
/// property of each screw's lever geometry and must not cross-mix.
///
/// SIGN CONVENTIONS (fixed by the hardware, documented once here):
///   * Probe forces are compressive and NEGATIVE (gram-force).
///   * Tightening a screw makes its corner force MORE negative
///     (ΔF < 0) and raises the corner relative to its reference plane.
///   * The gap is defined as `referenceZ − cornerZ` (see
///     [adjustmentGapMm]): positive → adjusted corner too low.
///   * Tightening therefore SHRINKS a positive gap, so the coupling
///     (relative Z movement per gram-force) is ALWAYS negative.
///
/// The controller works entirely in GAP space, not raw corner Z.
/// Adjusting a screw pivots the plate, so the reference corners move
/// opposite to the adjusted corner — the gap responds 2–3× more than
/// the raw corner Z.  Measuring coupling on raw Z (as earlier
/// revisions did) systematically underestimates sensitivity and
/// commands 2–3× too much force.  The gap also cancels the
/// common-mode Z frame drift between rechecks (±0.05 mm and more).
///
/// The coupling sample denominator is the COMMANDED force delta: the
/// live gauge is anchored to the same re-probe the command was computed
/// from and the user drives it into a ±20 gf green zone, so the
/// commanded delta is exact by construction.  (Earlier revisions
/// differenced two probe force readings, whose ±300–500 gf noise is the
/// same order as the delta itself and could even flip its sign.)
class ScrewController {
  /// Conservative first-cycle coupling (mm/gf).  Deliberately near the
  /// sensitive end of the observed field range so uncalibrated cycles
  /// undershoot: with [dampingRatio] 0.75 the loop tolerates the true
  /// coupling being up to 2.67× more sensitive than the estimate, and
  /// the most sensitive coupling seen in the field is −7.5e-4 (1.5×).
  static const double seedCouplingMmPerGf = -5e-4;

  /// Fraction of the gap corrected per cycle.  A perfect estimate
  /// leaves 25% of the gap; an estimate off by up to 2.67× in the
  /// sensitive direction still converges (multiplier stays above −1).
  static const double dampingRatio = 0.75;

  /// Absolute force delta ceiling shown on the gauge (gf).
  static const double maxForceDeltaGf = 3000.0;

  /// Commands smaller than this are never used to update the estimate:
  /// the numerator SNR would be dominated by the ±0.06 mm gap noise,
  /// and deltas this small only occur when the gap is nearly closed.
  static const double minCommandDeltaGf = 150.0;

  /// Gap movement below this is treated as "the plate did not move"
  /// (stiction / thread backlash) rather than a measurable response.
  /// This is below the worst-case gap noise, but any commanded back
  /// adjustment targets ≥ 0.075 mm of motion, so the gate only has to
  /// distinguish "moved" from "didn't".
  static const double minMeasurableMoveMm = 0.02;

  /// Plausibility band for accepted coupling samples (mm/gf).  Brackets
  /// the observed field range [−7.5e-4, −2.5e-5] with margin.
  static const double couplingMostSensitive = -8e-4;
  static const double couplingStiffest = -2e-5;

  /// Smoothing for samples after the first (the first measured sample
  /// replaces the seed outright — the seed carries no printer info).
  static const double emaAlpha = 0.5;

  /// On a stiction cycle the coupling estimate is multiplied by this,
  /// tripling the next commanded force until movement is measurable.
  static const double stictionFactor = 1.0 / 3.0;

  /// Stiction escalations allowed per session — bounds the damage when
  /// "no movement" is really a user not turning the screw.
  static const int maxStictionEscalations = 4;

  /// Corner-check pass threshold (mm), used for recheck prediction.
  static const double passGapMm = 0.100;
  static const int maxPredictedRechecks = 20;

  double _coupling = seedCouplingMmPerGf;
  bool _hasMeasuredSample = false;
  int _stictionEscalations = 0;
  double? _pendingGapMm;
  double? _pendingDeltaGf;

  /// Current coupling estimate (mm/gf, always negative).
  double get coupling => _coupling;

  /// Whether [coupling] is backed by at least one accepted measurement
  /// (false → it is still the seed, possibly stiction-scaled).
  bool get hasMeasuredSample => _hasMeasuredSample;

  int get stictionEscalations => _stictionEscalations;

  bool get hasPendingCommand => _pendingDeltaGf != null;

  /// Compute the force command for the current gap.  Pure — does not
  /// change controller state; call [recordCommand] once the command is
  /// actually shown to the user.
  ScrewCommand command({required double zGapMm}) {
    final targetZMm = zGapMm * dampingRatio;
    final rawDelta = targetZMm / _coupling;
    final forceDeltaGf =
        rawDelta.clamp(-maxForceDeltaGf, maxForceDeltaGf).toDouble();
    final clamped = rawDelta.abs() > maxForceDeltaGf;

    // Clamp-aware recheck prediction: per cycle the gap shrinks by the
    // damped target or by the most the force ceiling can move it,
    // whichever is smaller.
    var g = zGapMm.abs();
    var rechecks = 0;
    final maxMovePerCycle = _coupling.abs() * maxForceDeltaGf;
    while (g > passGapMm && rechecks < maxPredictedRechecks) {
      g -= math.min(g * dampingRatio, maxMovePerCycle);
      rechecks++;
    }

    return ScrewCommand(
      zGapMm: zGapMm,
      targetZMm: targetZMm,
      forceDeltaGf: forceDeltaGf,
      clamped: clamped,
      couplingUsedMmPerGf: _coupling,
      predictedGapAfterMm: zGapMm - _coupling * forceDeltaGf,
      predictedRechecks: rechecks,
    );
  }

  /// Snapshot a command that was shown to the user, so the next
  /// [onRecheck] can measure what it achieved.  A repeated call
  /// overwrites the previous pending command.
  void recordCommand(ScrewCommand cmd) {
    _pendingGapMm = cmd.zGapMm;
    _pendingDeltaGf = cmd.forceDeltaGf;
  }

  /// Discard the pending command without updating the estimate (e.g.
  /// when the recheck is missing the data needed to measure it).
  void abandonPending() {
    _pendingGapMm = null;
    _pendingDeltaGf = null;
  }

  /// Update the coupling estimate from a completed recheck.
  CouplingUpdateResult onRecheck({required double newGapMm}) {
    final pendingGap = _pendingGapMm;
    final pendingDelta = _pendingDeltaGf;
    _pendingGapMm = null;
    _pendingDeltaGf = null;

    if (pendingGap == null || pendingDelta == null) {
      return CouplingUpdateResult._(
        outcome: CouplingUpdateOutcome.noPendingCommand,
        couplingAfterMmPerGf: _coupling,
      );
    }

    // Relative movement of the adjusted corner toward its reference:
    // positive when the gap shrank in the commanded sense.
    final gapMove = pendingGap - newGapMm;

    if (pendingDelta.abs() < minCommandDeltaGf) {
      // Command too small to yield a usable sample; not a stiction
      // signal either — a small command was never expected to produce
      // measurable movement.
      return CouplingUpdateResult._(
        outcome: CouplingUpdateOutcome.rejectedSmallDelta,
        commandedDeltaGf: pendingDelta,
        gapAtCommandMm: pendingGap,
        measuredGapMoveMm: gapMove,
        couplingAfterMmPerGf: _coupling,
      );
    }

    if (gapMove.abs() < minMeasurableMoveMm) {
      // Substantial force commanded but the plate did not measurably
      // move: stiction or thread backlash.  Assume the printer is
      // stiffer than estimated and triple the next command.
      if (_stictionEscalations < maxStictionEscalations) {
        _stictionEscalations++;
        final escalated = _coupling * stictionFactor;
        _coupling = escalated.abs() < couplingStiffest.abs()
            ? couplingStiffest
            : escalated;
      }
      return CouplingUpdateResult._(
        outcome: CouplingUpdateOutcome.stictionEscalated,
        commandedDeltaGf: pendingDelta,
        gapAtCommandMm: pendingGap,
        measuredGapMoveMm: gapMove,
        couplingAfterMmPerGf: _coupling,
      );
    }

    final sample = gapMove / pendingDelta;
    if (sample >= 0) {
      // Physically impossible sign (tighten must shrink the gap):
      // measurement noise or the screw was turned the wrong way.
      // Keep the prior estimate.
      return CouplingUpdateResult._(
        outcome: CouplingUpdateOutcome.rejectedPositiveSample,
        commandedDeltaGf: pendingDelta,
        gapAtCommandMm: pendingGap,
        measuredGapMoveMm: gapMove,
        sample: sample,
        couplingAfterMmPerGf: _coupling,
      );
    }

    final clampedSample = sample
        .clamp(couplingMostSensitive, couplingStiffest)
        .toDouble();
    final wasClamped = clampedSample != sample;

    if (_hasMeasuredSample) {
      _coupling = _coupling * (1.0 - emaAlpha) + clampedSample * emaAlpha;
    } else {
      // First real measurement replaces the seed outright — averaging
      // against a value that carries no printer information would just
      // slow convergence (a 20×-off stiff printer would need ~4 cycles
      // to shake off the seed).
      _coupling = clampedSample;
      _hasMeasuredSample = true;
    }

    return CouplingUpdateResult._(
      outcome: wasClamped
          ? CouplingUpdateOutcome.acceptedClamped
          : CouplingUpdateOutcome.accepted,
      commandedDeltaGf: pendingDelta,
      gapAtCommandMm: pendingGap,
      measuredGapMoveMm: gapMove,
      sample: sample,
      couplingAfterMmPerGf: _coupling,
    );
  }
}

/// A force command for a leveling screw, expressed both as the desired
/// relative Z correction and the gauge force delta that should achieve it.
class ScrewCommand {
  const ScrewCommand({
    required this.zGapMm,
    required this.targetZMm,
    required this.forceDeltaGf,
    required this.clamped,
    required this.couplingUsedMmPerGf,
    required this.predictedGapAfterMm,
    required this.predictedRechecks,
  });

  /// Gap (see [adjustmentGapMm]) the command was computed from.
  final double zGapMm;

  /// Damped correction target (signed, gap-mm).
  final double targetZMm;

  /// Signed force delta for the gauge; negative = tighten.
  final double forceDeltaGf;

  /// Whether [forceDeltaGf] hit the ±[ScrewController.maxForceDeltaGf]
  /// ceiling.
  final bool clamped;

  /// Coupling estimate used to compute this command (mm/gf).
  final double couplingUsedMmPerGf;

  /// Gap expected after the user reaches the force target.
  final double predictedGapAfterMm;

  /// Estimated rechecks (including the upcoming one) until the gap is
  /// within [ScrewController.passGapMm].
  final int predictedRechecks;
}

enum CouplingUpdateOutcome {
  accepted,
  acceptedClamped,
  rejectedPositiveSample,
  rejectedSmallDelta,
  stictionEscalated,
  noPendingCommand,
}

/// Outcome of measuring a completed adjustment cycle, for telemetry.
class CouplingUpdateResult {
  const CouplingUpdateResult._({
    required this.outcome,
    required this.couplingAfterMmPerGf,
    this.commandedDeltaGf,
    this.gapAtCommandMm,
    this.measuredGapMoveMm,
    this.sample,
  });

  final CouplingUpdateOutcome outcome;
  final double? commandedDeltaGf;
  final double? gapAtCommandMm;

  /// Relative back-vs-front movement achieved (gapAtCommand − newGap).
  final double? measuredGapMoveMm;

  /// Raw coupling sample before clamping (mm/gf), when computable.
  final double? sample;

  final double couplingAfterMmPerGf;

  bool get accepted =>
      outcome == CouplingUpdateOutcome.accepted ||
      outcome == CouplingUpdateOutcome.acceptedClamped;
}

/*
* Orion - Back Screw Controller Tests
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

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:orion/tools/athena/screw_controller.dart';

/// Drive one closed-loop cycle against a simulated printer with true
/// coupling [trueC]: command → user reaches force target → plate moves
/// by trueC · delta → recheck.  Returns the new gap.
double _cycle(ScrewController ctrl, double gap, double trueC,
    {double noise = 0.0}) {
  final cmd = ctrl.command(zGapMm: gap);
  ctrl.recordCommand(cmd);
  final newGap = gap - trueC * cmd.forceDeltaGf;
  ctrl.onRecheck(newGapMm: newGap + noise);
  return newGap;
}

/// Build a controller escalated down to the stiffness floor via
/// repeated zero-movement rechecks.
ScrewController _flooredController() {
  final ctrl = ScrewController();
  for (int i = 0; i < 3; i++) {
    final cmd = ctrl.command(zGapMm: 0.25);
    ctrl.recordCommand(cmd);
    ctrl.onRecheck(newGapMm: 0.25); // no movement at all
  }
  return ctrl;
}

void main() {
  group('corner selection and gap (field-session regressions)', () {
    // Z order: FL, FR, BR, BL.
    // Selection decomposes into D1 = FL−BR (FL screw), D2 = FR−BL
    // (FR screw), pitch (back screw) and picks the screw leaving the
    // smallest residual diagonal error.
    test('b9ef2b8f #0: pure front-back tilt → back screw, tighten', () {
      const z = [0.88, 0.99, 0.47, 0.44]; // both fronts above both backs
      final corner = selectAdjustmentCorner(z);
      expect(corner, 3); // BL is the worst back outlier
      expect(adjustmentGapMm(corner, z), closeTo(0.48, 1e-9));
      // Positive gap → tighten: raises the whole back edge. Correct.
    });

    test('b9ef2b8f #1: FR↔BL diagonal → FR screw, LOOSEN (not back-tighten)',
        () {
      // Front-back was essentially level (gap 0.073) but FR sat 0.19
      // above BL.  The original logic picked BL → back screw →
      // tighten, which raised BOTH back corners and converted the
      // diagonal error into back-high tilt, ping-ponging forever.
      const z = [0.63, 0.79, 0.68, 0.60];
      final corner = selectAdjustmentCorner(z);
      expect(corner, 1); // FR — leaves only |D1| = 0.05 of residual
      final gap = adjustmentGapMm(corner, z); // BL − FR
      expect(gap, closeTo(-0.19, 1e-9));
      expect(gap, lessThan(0)); // FR high → LOOSEN
      // And the command must actually say loosen (positive delta):
      expect(ScrewController().command(zGapMm: gap).forceDeltaGf,
          greaterThan(0));
    });

    test('b9ef2b8f #2: FL↔BR dominates → FL screw (front comes up)', () {
      // Back higher on average, but the error is almost entirely the
      // FL↔BR diagonal (0.32) with D2 only 0.06.  Loosening the back
      // (the old pick) would leave ±0.13 of twist; tightening FL
      // leaves just 0.06.
      const z = [0.51, 0.68, 0.83, 0.74];
      final corner = selectAdjustmentCorner(z);
      expect(corner, 0);
      final gap = adjustmentGapMm(corner, z); // BR − FL
      expect(gap, closeTo(0.32, 1e-9));
      expect(gap, greaterThan(0)); // FL low → TIGHTEN (raises FL, lowers BR)
    });

    test('f2c9f74d #1: noise-level corner ordering must not pick the back',
        () {
      // BR (0.62) sat 0.02 above FL (0.60) — pure probe noise — but
      // the old "all back corners higher" gate routed this dominant
      // FR↔BL diagonal (0.12) to the back screw, commanding an
      // unexecutable 64 gf loosen.
      const z = [0.60, 0.58, 0.62, 0.70];
      expect(rankAdjustmentCandidates(z), [1, 3, 0]);
      final gap = adjustmentGapMm(1, z); // BL − FR
      expect(gap, closeTo(0.12, 1e-9)); // FR low on its diagonal → tighten
      // The full-diagonal gap makes the command executable (≥150 gf):
      final cmd = ScrewController().command(zGapMm: gap);
      expect(cmd.forceDeltaGf, lessThan(0)); // tighten
      expect(cmd.forceDeltaGf.abs(),
          greaterThanOrEqualTo(ScrewController.minCommandDeltaGf));
    });

    test('a low back corner in a diagonal routes to the front screw', () {
      // BL low but BR fine: not a front-back tilt, so the back screw
      // (which would raise BR too) must not be chosen.
      const z = [0.60, 0.80, 0.75, 0.58];
      expect(selectAdjustmentCorner(z), 1); // FR↔BL pair → FR
    });

    test('FL↔BR diagonal routes to FL', () {
      const z = [0.45, 0.68, 0.83, 0.60]; // FL low, BR high, BL below FR
      final corner = selectAdjustmentCorner(z);
      expect(corner, 0);
      // BR − FL = 0.38 → FL low → tighten
      expect(adjustmentGapMm(corner, z), closeTo(0.38, 1e-9));
    });

    test('back gap uses the back average, not one outlier corner', () {
      // Similar diagonals (D1 0.30, D2 0.20) → common-mode pitch →
      // back screw, shown at the worse corner.
      const z = [0.50, 0.50, 0.20, 0.30];
      final corner = selectAdjustmentCorner(z);
      expect(corner, 2); // BR shown for puck placement
      // Gap targets the edge average (0.25), not the BR outlier (0.30):
      expect(adjustmentGapMm(corner, z), closeTo(0.25, 1e-9));
    });

    test('pure roll is worked corner by corner, not via the back screw',
        () {
      // Left side high, right side low: the centerline back screw can
      // correct none of it (pitch is zero).
      const z = [0.60, 0.40, 0.40, 0.60];
      final ranked = rankAdjustmentCandidates(z);
      expect(ranked.first, isNot(anyOf(2, 3)));
    });
  });

  group('ScrewController command', () {
    test('seed command direction and magnitude', () {
      final ctrl = ScrewController();
      final cmd = ctrl.command(zGapMm: 0.18); // back too low → tighten
      expect(cmd.targetZMm, closeTo(0.135, 1e-9)); // 0.75 damping, no bias
      expect(cmd.forceDeltaGf, closeTo(-270.0, 1e-6)); // 0.135 / -5e-4
      expect(cmd.clamped, isFalse);
      expect(cmd.predictedGapAfterMm, closeTo(0.045, 1e-9)); // 25% left

      final loosen = ctrl.command(zGapMm: -0.18); // back too high → loosen
      expect(loosen.forceDeltaGf, closeTo(270.0, 1e-6));
    });

    test('force delta clamps at ±3000 gf with clamp-aware prediction', () {
      final ctrl = _flooredController();
      expect(ctrl.coupling, closeTo(-2e-5, 1e-12)); // at stiffness floor

      final cmd = ctrl.command(zGapMm: 0.25);
      expect(cmd.forceDeltaGf, -3000.0); // raw would be -9375
      expect(cmd.clamped, isTrue);
      // ±3000 gf at -2e-5 mm/gf moves at most 0.06 mm per cycle.
      expect(cmd.predictedGapAfterMm, closeTo(0.19, 1e-9));
      expect(cmd.predictedRechecks, 3); // 0.25 → 0.19 → 0.13 → 0.07
    });

    test('predicted rechecks is 1 when the estimate covers the gap', () {
      final cmd = ScrewController().command(zGapMm: 0.25);
      expect(cmd.predictedRechecks, 1); // 0.25 → 0.0625 ≤ 0.100
    });
  });

  group('ScrewController estimator', () {
    test('rejects physically-impossible positive samples', () {
      // Field-log regression: gap got WORSE by drift/noise after a
      // tighten command.  The old estimator fed this into the EMA and
      // reversed the gauge direction on the next cycle.
      final ctrl = ScrewController();
      final cmd = ctrl.command(zGapMm: 0.18);
      ctrl.recordCommand(cmd);
      final r = ctrl.onRecheck(newGapMm: 0.21); // moved the wrong way
      expect(r.outcome, CouplingUpdateOutcome.rejectedPositiveSample);
      expect(r.sample, greaterThan(0));
      expect(ctrl.coupling, ScrewController.seedCouplingMmPerGf);
      expect(ctrl.hasMeasuredSample, isFalse);
    });

    test('coupling stays negative and in band under adversarial rechecks',
        () {
      // Replay the field failure pattern: overshoots, drift reversals
      // and normal moves interleaved across 7 cycles.
      final ctrl = ScrewController();
      const cycles = <(double, double)>[
        (0.154, -0.139), // overshoot past zero (session 347417ed #0→#1)
        (-0.139, -0.099), // partial correction
        (-0.099, -0.198), // adversarial: drift made it worse
        (-0.198, 0.121), // overshoot back
        (0.121, 0.089), // undershoot
        (0.166, 0.111), // small move (session 88448afd #0→#1)
        (0.107, -0.250), // big overshoot (session 7e7ff88a #0→#1)
      ];
      for (final (gap, newGap) in cycles) {
        final cmd = ctrl.command(zGapMm: gap);
        // Command must always point at closing the gap.
        expect(cmd.forceDeltaGf.sign, -gap.sign,
            reason: 'gap $gap must command ${gap > 0 ? "tighten" : "loosen"}');
        ctrl.recordCommand(cmd);
        ctrl.onRecheck(newGapMm: newGap);
        expect(ctrl.coupling, lessThan(0));
        expect(
            ctrl.coupling,
            inInclusiveRange(ScrewController.couplingMostSensitive,
                ScrewController.couplingStiffest));
      }
    });

    test('overshoot self-corrects: first sample replaces the seed', () {
      final ctrl = ScrewController();
      const trueC = -7.5e-4; // most sensitive printer seen in the field

      final cmd = ctrl.command(zGapMm: 0.25);
      expect(cmd.forceDeltaGf, closeTo(-375.0, 1e-6));
      ctrl.recordCommand(cmd);
      final newGap = 0.25 - trueC * cmd.forceDeltaGf; // -0.03125 (flipped)
      final r = ctrl.onRecheck(newGapMm: newGap);
      expect(r.outcome, CouplingUpdateOutcome.accepted);
      expect(ctrl.coupling, closeTo(trueC, 1e-9)); // replaced, not averaged
      expect(ctrl.hasMeasuredSample, isTrue);

      // Next command flips direction (loosen) and shrinks > 10×.
      final next = ctrl.command(zGapMm: newGap);
      expect(next.forceDeltaGf, greaterThan(0));
      expect(next.forceDeltaGf.abs(), lessThan(cmd.forceDeltaGf.abs() / 10));
      expect(next.predictedGapAfterMm.abs(), lessThan(newGap.abs() * 0.3));
    });

    test('subsequent samples are EMA-smoothed', () {
      final ctrl = ScrewController();
      var gap = _cycle(ctrl, 0.25, -2.0e-4); // first sample replaces seed
      expect(ctrl.coupling, closeTo(-2.0e-4, 1e-9));
      _cycle(ctrl, gap, -1.0e-4); // second sample EMA 50/50
      expect(ctrl.coupling, closeTo(-1.5e-4, 1e-8));
    });

    test('stiction escalation triples force until movement is measurable',
        () {
      final ctrl = ScrewController();
      const trueC = -2.5e-5; // stiffest printer seen in the field

      // Cycle 1: seed command moves the plate < 0.02 mm → escalate.
      final cmd1 = ctrl.command(zGapMm: 0.25);
      ctrl.recordCommand(cmd1);
      var gap = 0.25 - trueC * cmd1.forceDeltaGf; // 0.2406
      final r1 = ctrl.onRecheck(newGapMm: gap);
      expect(r1.outcome, CouplingUpdateOutcome.stictionEscalated);
      expect(ctrl.stictionEscalations, 1);
      expect(ctrl.coupling, closeTo(-5e-4 / 3, 1e-9));

      // Cycle 2: ~3× the force → measurable move → true coupling captured.
      final cmd2 = ctrl.command(zGapMm: gap);
      expect(cmd2.forceDeltaGf.abs(),
          greaterThan(cmd1.forceDeltaGf.abs() * 2.5));
      ctrl.recordCommand(cmd2);
      gap = gap - trueC * cmd2.forceDeltaGf;
      final r2 = ctrl.onRecheck(newGapMm: gap);
      expect(r2.outcome, CouplingUpdateOutcome.accepted);
      expect(ctrl.coupling, closeTo(trueC, 1e-9));
    });

    test('stiction escalation floors at the stiffness bound and caps', () {
      final ctrl = ScrewController();
      for (int i = 0; i < 8; i++) {
        final cmd = ctrl.command(zGapMm: 0.25);
        expect(cmd.forceDeltaGf.abs(), lessThanOrEqualTo(3000.0));
        ctrl.recordCommand(cmd);
        ctrl.onRecheck(newGapMm: 0.25); // never moves
      }
      expect(ctrl.coupling, closeTo(-2e-5, 1e-12));
      expect(ctrl.stictionEscalations,
          ScrewController.maxStictionEscalations);
    });

    test('small commands are skipped without escalation', () {
      final ctrl = ScrewController();
      final cmd = ctrl.command(zGapMm: 0.09); // delta = 135 gf < 150
      expect(cmd.forceDeltaGf.abs(), lessThan(150));
      ctrl.recordCommand(cmd);
      final r = ctrl.onRecheck(newGapMm: 0.09); // no movement either
      expect(r.outcome, CouplingUpdateOutcome.rejectedSmallDelta);
      expect(ctrl.stictionEscalations, 0);
      expect(ctrl.coupling, ScrewController.seedCouplingMmPerGf);
    });

    test('out-of-band samples are clamped, not rejected', () {
      // Too sensitive: 0.35 mm move on a -375 gf command → -9.3e-4.
      final soft = ScrewController();
      final cmdS = soft.command(zGapMm: 0.25);
      soft.recordCommand(cmdS);
      final rS = soft.onRecheck(newGapMm: 0.25 - 0.35);
      expect(rS.outcome, CouplingUpdateOutcome.acceptedClamped);
      expect(soft.coupling, ScrewController.couplingMostSensitive);

      // Too stiff: 0.05 mm move on a -3000 gf command → -1.67e-5.
      final stiff = ScrewController();
      final cmdT = stiff.command(zGapMm: 2.0); // saturates at -3000 gf
      expect(cmdT.forceDeltaGf, -3000.0);
      stiff.recordCommand(cmdT);
      final rT = stiff.onRecheck(newGapMm: 2.0 - 0.05);
      expect(rT.outcome, CouplingUpdateOutcome.acceptedClamped);
      expect(stiff.coupling, ScrewController.couplingStiffest);
    });
  });

  group('ScrewController pending lifecycle', () {
    test('recheck without a pending command is a no-op', () {
      final ctrl = ScrewController();
      final r = ctrl.onRecheck(newGapMm: 0.1);
      expect(r.outcome, CouplingUpdateOutcome.noPendingCommand);
      expect(ctrl.coupling, ScrewController.seedCouplingMmPerGf);
    });

    test('recording a second command overwrites the first', () {
      final ctrl = ScrewController();
      ctrl.recordCommand(ctrl.command(zGapMm: 0.25));
      final cmd2 = ctrl.command(zGapMm: 0.30);
      ctrl.recordCommand(cmd2);
      final r = ctrl.onRecheck(newGapMm: 0.10);
      expect(r.gapAtCommandMm, 0.30);
      expect(r.commandedDeltaGf, cmd2.forceDeltaGf);
      expect(r.outcome, CouplingUpdateOutcome.accepted);
    });

    test('abandonPending discards the snapshot', () {
      final ctrl = ScrewController();
      ctrl.recordCommand(ctrl.command(zGapMm: 0.25));
      expect(ctrl.hasPendingCommand, isTrue);
      ctrl.abandonPending();
      expect(ctrl.hasPendingCommand, isFalse);
      final r = ctrl.onRecheck(newGapMm: 0.1);
      expect(r.outcome, CouplingUpdateOutcome.noPendingCommand);
    });

    test('pending is consumed by a recheck', () {
      final ctrl = ScrewController();
      ctrl.recordCommand(ctrl.command(zGapMm: 0.25));
      ctrl.onRecheck(newGapMm: 0.10);
      expect(ctrl.hasPendingCommand, isFalse);
      expect(ctrl.onRecheck(newGapMm: 0.05).outcome,
          CouplingUpdateOutcome.noPendingCommand);
    });
  });

  group('ScrewController convergence', () {
    const fieldRange = [-2.5e-5, -5e-5, -1e-4, -2.5e-4, -5e-4, -7.5e-4];

    test('noise-free: passes within 4 rechecks across the field range', () {
      for (final trueC in fieldRange) {
        final ctrl = ScrewController();
        var gap = 0.25;
        var rechecks = 0;
        while (gap.abs() > ScrewController.passGapMm && rechecks < 10) {
          gap = _cycle(ctrl, gap, trueC);
          rechecks++;
        }
        expect(rechecks, lessThanOrEqualTo(4),
            reason: 'trueC=$trueC took $rechecks rechecks');
      }
    });

    test('with ±0.03 mm recheck noise: never diverges, coupling in band',
        () {
      final rand = Random(42);
      for (final trueC in fieldRange) {
        final ctrl = ScrewController();
        var gap = 0.25;
        for (int i = 0; i < 12; i++) {
          final noise = (rand.nextDouble() * 2 - 1) * 0.03;
          gap = _cycle(ctrl, gap, trueC, noise: noise);
          expect(gap.abs(), lessThan(0.35),
              reason: 'trueC=$trueC diverged to $gap at cycle $i');
          expect(
              ctrl.coupling,
              inInclusiveRange(ScrewController.couplingMostSensitive,
                  ScrewController.couplingStiffest));
        }
      }
    });
  });
}

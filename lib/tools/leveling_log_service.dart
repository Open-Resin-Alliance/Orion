/*
* Orion - Leveling Log Service
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

import 'dart:io';

import 'package:logging/logging.dart';
import 'package:orion/tools/leveling_log_entry.dart';
import 'package:orion/util/orion_config.dart';
import 'package:path/path.dart' as path;

/// Persists corner-check results to `orion_level.log` in the same directory
/// as `orion.cfg`.  Each entry is a human-readable block.
class LevelingLogService {
  LevelingLogService._();

  static final _log = Logger('LevelingLogService');
  static String? _resolvedDir;

  static String _resolveLogDir() {
    final configDir = OrionConfig.configDirectory;
    if (configDir != null && configDir.isNotEmpty) return configDir;
    try {
      final execDir = path.dirname(Platform.resolvedExecutable);
      if (execDir.isNotEmpty) return execDir;
    } catch (_) {}
    try {
      return Directory.current.path;
    } catch (_) {}
    return '.';
  }

  static String get logFilePath {
    _resolvedDir ??= _resolveLogDir();
    return path.join(_resolvedDir!, 'orion_level.log');
  }

  /// Append a corner-check entry to the log file in human-readable format.
  static Future<void> logCornerCheck(LevelingLogEntry entry) async {
    try {
      final buf = StringBuffer();
      final sep = '=' * 70;
      final sub = '-' * 70;
      final cornerLabels = ['FL', 'FR', 'BR', 'BL'];
      final cornerNames = [
        'Front Left',
        'Front Right',
        'Back Right',
        'Back Left',
      ];
      final r = entry.corners;

      // ── Header ──
      buf.writeln(sep);
      buf.writeln('LEVELING SESSION  ${entry.sessionId}');
      buf.writeln('Timestamp          ${_formatTimestamp(entry.timestamp)}');
      buf.writeln('Variant            ${entry.variant}');
      buf.writeln('Recheck            #${entry.recheckNumber}${entry.recheckNumber == 0 ? " (initial)" : ""}');
      final resultTag = entry.passed ? 'PASSED' : 'FAILED';
      buf.writeln('Result             $resultTag — total deviation ${entry.totalDeviationMm.toStringAsFixed(3)} mm (limit 0.100 mm)');
      buf.writeln(sep);

      // ── Corner measurements table ──
      buf.writeln('Corner Measurements:');
      buf.writeln('  ${'Pos'.padRight(4)} ${'Corner'.padRight(13)} ${'Z (mm)'.padRight(11)} ${'1st Peak (gf)'.padRight(16)} ${'2nd Peak (gf)'.padRight(16)} ${'1st Over.'.padRight(12)} ${'2nd Over.'.padRight(12)}');
      final zValues = <double>[];
      for (int i = 0; i < 4; i++) {
        final c = r[cornerLabels[i]];
        final z = c?.finalZ;
        if (z != null) zValues.add(z);
        buf.writeln('  ${cornerLabels[i].padRight(4)} ${cornerNames[i].padRight(13)} ${_fmt(z, 10)} ${_fmt(c?.firstStagePeakForce, 15)} ${_fmt(c?.secondStagePeakForce, 15)} ${_fmt(c?.firstStageOvershoot, 11)} ${_fmt(c?.secondStageOvershoot, 11)}');
      }
      buf.writeln(sub);

      // ── Summary stats ──
      final frontZ = <double>[];
      final backZ = <double>[];
      if (r['FL']?.finalZ != null) frontZ.add(r['FL']!.finalZ!);
      if (r['FR']?.finalZ != null) frontZ.add(r['FR']!.finalZ!);
      if (r['BR']?.finalZ != null) backZ.add(r['BR']!.finalZ!);
      if (r['BL']?.finalZ != null) backZ.add(r['BL']!.finalZ!);

      if (frontZ.isNotEmpty && backZ.isNotEmpty) {
        final frontAvg =
            frontZ.reduce((a, b) => a + b) / frontZ.length;
        final backAvg =
            backZ.reduce((a, b) => a + b) / backZ.length;
        final gap = frontAvg - backAvg;
        final gapDir = gap > 0 ? 'back lower' : 'back higher';
        buf.write('Front Avg Z: ${frontAvg.toStringAsFixed(3)} mm');
        buf.write('    Back Avg Z: ${backAvg.toStringAsFixed(3)} mm');
        buf.writeln('    Gap: ${gap.abs().toStringAsFixed(3)} mm ($gapDir)');
      }

      if (zValues.isNotEmpty) {
        final minZ = zValues.reduce((a, b) => a < b ? a : b);
        final maxZ = zValues.reduce((a, b) => a > b ? a : b);
        buf.write('Min Z: ${minZ.toStringAsFixed(3)} mm');
        buf.write('    Max Z: ${maxZ.toStringAsFixed(3)} mm');
        buf.writeln('    Range: ${(maxZ - minZ).toStringAsFixed(3)} mm');
      }

      // ── Coupling estimate ──
      if (entry.estimatedCoupling != null) {
        final c = entry.estimatedCoupling!;
        buf.writeln('Coupling Est: ${c.toStringAsFixed(6)} mm/gf  (≈${(1.0 / c).toStringAsFixed(0)} gf needed per 1 mm of Z movement)');
      } else {
        buf.writeln('Coupling Est: -- (first cycle, no estimate yet)');
      }

      // ── Divergence detection ──
      if (entry.preAdjustmentDeviation != null) {
        final prev = entry.preAdjustmentDeviation!;
        final curr = entry.totalDeviationMm;
        final delta = curr - prev;
        if (delta > 0.02) {
          buf.writeln('⚠ DIVERGENCE: deviation INCREASED by ${delta.toStringAsFixed(3)} mm (was ${prev.toStringAsFixed(3)}, now ${curr.toStringAsFixed(3)})');
          buf.writeln('   The adjustment may have gone the wrong way.  Check that the');
          buf.writeln('   screw was turned in the direction indicated by the gauge.');
          buf.writeln('   Consider starting a fresh leveling session if this persists.');
        } else if (delta < -0.02) {
          buf.writeln('Convergence: deviation decreased by ${(-delta).toStringAsFixed(3)} mm');
        } else {
          buf.writeln('Deviation change: ${delta.toStringAsFixed(3)} mm (essentially unchanged)');
        }
      }

      // ── Probe config ──
      final cfg = entry.probeConfig;
      if (cfg != null &&
          (cfg.firstStageSpeed != null ||
              cfg.secondStageSpeed != null ||
              cfg.firstStageLiftHeight != null ||
              cfg.secondStageLiftHeight != null ||
              cfg.firstStageThreshold != null ||
              cfg.secondStageThreshold != null ||
              cfg.probeStartDistance != null ||
              cfg.probeRetractDistance != null)) {
        buf.writeln(sub);
        buf.writeln('Probe Configuration:');
        buf.writeln('  1st Stage Speed:       ${_fmt(cfg.firstStageSpeed, 0)}');
        buf.writeln('  2nd Stage Speed:       ${_fmt(cfg.secondStageSpeed, 0)}');
        buf.writeln('  1st Stage Lift Height: ${_fmt(cfg.firstStageLiftHeight, 0)}');
        buf.writeln('  2nd Stage Lift Height: ${_fmt(cfg.secondStageLiftHeight, 0)}');
        buf.writeln('  1st Stage Threshold:   ${_fmt(cfg.firstStageThreshold, 0)}');
        buf.writeln('  2nd Stage Threshold:   ${_fmt(cfg.secondStageThreshold, 0)}');
        buf.writeln('  Probe Start Distance:  ${_fmt(cfg.probeStartDistance, 0)}');
        buf.writeln('  Probe Retract Dist:    ${_fmt(cfg.probeRetractDistance, 0)}');
      } else {
        buf.writeln('Probe Config: (not reported by backend)');
      }

      buf.writeln(sep);
      buf.writeln(); // blank line between entries

      final file = File(logFilePath);
      await file.writeAsString(buf.toString(), mode: FileMode.append);
      _log.info('Corner check logged: session=${entry.sessionId} '
          'recheck=${entry.recheckNumber} deviation=${entry.totalDeviationMm.toStringAsFixed(3)} '
          'passed=${entry.passed}');
    } catch (e, st) {
      _log.warning('Failed to write leveling log entry', e, st);
    }
  }

  static String _fmt(double? v, int width) {
    if (v == null) return '--'.padRight(width);
    return v.toStringAsFixed(2).padRight(width);
  }

  /// Convert ISO 8601 UTC timestamp to a friendlier local-time-ish format.
  static String _formatTimestamp(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      final y = dt.year.toString();
      final m = dt.month.toString().padLeft(2, '0');
      final d = dt.day.toString().padLeft(2, '0');
      final h = dt.hour.toString().padLeft(2, '0');
      final min = dt.minute.toString().padLeft(2, '0');
      final s = dt.second.toString().padLeft(2, '0');
      return '$y-$m-$d $h:$min:$s (local)';
    } catch (_) {
      return iso;
    }
  }
}

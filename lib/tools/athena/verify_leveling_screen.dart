/*
* Orion - Verify Leveling Screen
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

import 'package:flutter/material.dart';
import 'package:flutter_i18n/flutter_i18n.dart';
import 'package:orion/glasser/glasser.dart';
import 'package:orion/tools/athena/c3d_athena2_wizard.dart';
import 'package:orion/tools/athena/leveling_configs.dart';
import 'package:orion/tools/athena/leveling_log_service.dart';
import 'package:orion/util/orion_config.dart';
import 'package:orion/util/orion_spacing.dart';
import 'package:orion/util/providers/theme_provider.dart';
import 'package:orion/util/widgets/system_status_widget.dart';
import 'package:orion/widgets/orion_app_bar.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';

class _ParsedSession {
  const _ParsedSession({
    required this.timestamp,
    required this.variant,
    required this.deviationMm,
    required this.cornerZs,
    required this.recheckNumber,
    required this.totalChecks,
    this.frontAvgZ,
    this.backAvgZ,
    this.rangeMm,
  });

  final String timestamp;
  final String variant;
  final double deviationMm;
  final Map<String, double> cornerZs;
  final int recheckNumber;
  final int totalChecks;
  final double? frontAvgZ;
  final double? backAvgZ;
  final double? rangeMm;
}

_ParsedSession? _parseLastPassedSession() {
  // Try the canonical log path first, then fall back to common dev locations.
  final candidates = <String>[
    LevelingLogService.logFilePath,
    'orion_level.log',
  ];
  File? file;
  for (final p in candidates) {
    final f = File(p);
    debugPrint('[VerifyLeveling] checking: $p (exists=${f.existsSync()})');
    if (f.existsSync()) {
      file = f;
      break;
    }
  }
  if (file == null) {
    debugPrint('[VerifyLeveling] no log file found');
    return null;
  }
  debugPrint('[VerifyLeveling] reading: ${file.path}');

  final text = file.readAsStringSync();
  final lines = text.split('\n');
  debugPrint('[VerifyLeveling] ${lines.length} lines');

  // Find the last PASSED Result line, then walk backward to the session
  // header, and forward to the closing separator to capture the full block.
  int? passedLine;
  for (int i = lines.length - 1; i >= 0; i--) {
    if (lines[i].contains('PASSED') && lines[i].contains('total deviation')) {
      passedLine = i;
      break;
    }
  }
  if (passedLine == null) {
    debugPrint('[VerifyLeveling] no PASSED Result line found');
    return null;
  }
  debugPrint('[VerifyLeveling] PASSED at line $passedLine');

  // Walk backward to find the session header.
  int? headerLine;
  for (int i = passedLine; i >= 0; i--) {
    if (lines[i].contains('LEVELING SESSION')) {
      headerLine = i;
      break;
    }
  }
  if (headerLine == null) {
    debugPrint(
        '[VerifyLeveling] no LEVELING SESSION header found before PASSED');
    return null;
  }

  // Walk forward to find the NEXT session header (or EOF), then back
  // up to the separator just before it — that's the true end of this
  // session's data (the first separator after header closes only the
  // header block; corner measurements follow it).
  final sep = '=' * 70;
  int closeLine = lines.length; // default: end of file
  for (int i = headerLine + 1; i < lines.length; i++) {
    if (lines[i].contains('LEVELING SESSION')) {
      // Back up to the separator just before the next session.
      for (int j = i - 1; j > headerLine; j--) {
        if (lines[j].startsWith(sep)) {
          closeLine = j;
          break;
        }
      }
      break;
    }
  }
  // If no next session found, use the last separator before EOF.
  if (closeLine == lines.length) {
    for (int j = lines.length - 1; j > headerLine; j--) {
      if (lines[j].startsWith(sep)) {
        closeLine = j;
        break;
      }
    }
  }

  // Build the session block from those lines.
  final block = lines.sublist(headerLine, closeLine).join('\n');
  debugPrint(
      '[VerifyLeveling] session block: lines $headerLine-$closeLine (${block.length} chars)');

  final sessionId = _extractLine(block, 'LEVELING SESSION');
  final timestampRaw = _extractLine(block, 'Timestamp');
  final timestamp = timestampRaw.replaceAll('(local)', '').trim();
  final variant = _extractLine(block, 'Variant');

  // Recheck number: "Recheck            #3" → 3
  final recheckStr = _extractLine(block, 'Recheck');
  final recheckMatch = RegExp(r'#(\d+)').firstMatch(recheckStr);
  final recheckNumber =
      recheckMatch != null ? int.tryParse(recheckMatch.group(1)!) ?? 0 : 0;

  // Count total blocks with the same session ID across the whole file.
  int totalChecks = 0;
  if (sessionId.isNotEmpty) {
    for (final line in lines) {
      if (line.contains(sessionId)) totalChecks++;
    }
  }

  final deviationStr = _extractLine(block, 'Result');
  debugPrint(
      '[VerifyLeveling] timestamp=$timestamp variant=$variant deviationStr=$deviationStr recheck=$recheckNumber totalChecks=$totalChecks');

  final deviationMatch =
      RegExp(r'total deviation (\d+\.\d+) mm').firstMatch(deviationStr);
  final deviationMm = deviationMatch != null
      ? double.tryParse(deviationMatch.group(1)!) ?? 0.0
      : 0.0;
  debugPrint('[VerifyLeveling] deviationMm=$deviationMm');

  final cornerZs = <String, double>{};
  const cornerLabels = ['FL', 'FR', 'BR', 'BL'];
  for (final label in cornerLabels) {
    final z = _extractCornerZ(block, label);
    debugPrint('[VerifyLeveling] corner $label: z=$z');
    if (z != null) cornerZs[label] = z;
  }

  double? frontAvgZ;
  double? backAvgZ;
  final frontMatch = RegExp(r'Front Avg Z: (\d+\.\d+) mm').firstMatch(block);
  final backMatch = RegExp(r'Back Avg Z: (\d+\.\d+) mm').firstMatch(block);
  if (frontMatch != null) frontAvgZ = double.tryParse(frontMatch.group(1)!);
  if (backMatch != null) backAvgZ = double.tryParse(backMatch.group(1)!);

  // Range: "Min Z: X.XXX mm    Max Z: Y.YYY mm    Range: Z.ZZZ mm"
  double? rangeMm;
  final rangeMatch = RegExp(r'Range: (\d+\.\d+) mm').firstMatch(block);
  if (rangeMatch != null) rangeMm = double.tryParse(rangeMatch.group(1)!);

  debugPrint(
      '[VerifyLeveling] frontAvgZ=$frontAvgZ backAvgZ=$backAvgZ rangeMm=$rangeMm');

  debugPrint('[VerifyLeveling] parsed OK, returning session');
  return _ParsedSession(
    timestamp: timestamp,
    variant: variant,
    deviationMm: deviationMm,
    cornerZs: cornerZs,
    recheckNumber: recheckNumber,
    totalChecks: totalChecks,
    frontAvgZ: frontAvgZ,
    backAvgZ: backAvgZ,
    rangeMm: rangeMm,
  );
}

String _extractLine(String block, String label) {
  // Match a line starting with the label, then skip whitespace (and
  // optional colon), then capture the rest.  Use \s* (not \s+) after
  // the colon so short gaps (e.g. "LEVELING SESSION  <uuid>") match.
  final pattern = RegExp('^\\s*$label\\s*:?\\s*(.+)', multiLine: true);
  return pattern.firstMatch(block)?.group(1)?.trim() ?? '';
}

double? _extractCornerZ(String block, String label) {
  // Find the line in the measurements table that starts with this label.
  // Table rows look like: "  FL   Front Left    0.79       -828.74   ..."
  // We scan line-by-line and extract the first number after the corner name.
  for (final line in block.split('\n')) {
    final trimmed = line.trimLeft();
    if (!trimmed.startsWith(label)) continue;
    // Ensure the next char is whitespace (not part of a longer word).
    if (trimmed.length > label.length &&
        trimmed[label.length] != ' ' &&
        trimmed[label.length] != '\t') {
      continue;
    }
    // Find all decimal numbers on this line; the first is the Z value.
    final numbers = RegExp(r'(-?\d+\.\d+)').allMatches(trimmed).toList();
    if (numbers.isNotEmpty) {
      return double.tryParse(numbers.first.group(1)!);
    }
  }
  return null;
}

class VerifyLevelingScreen extends StatefulWidget {
  const VerifyLevelingScreen({super.key});

  @override
  State<VerifyLevelingScreen> createState() => _VerifyLevelingScreenState();
}

class _VerifyLevelingScreenState extends State<VerifyLevelingScreen> {
  _ParsedSession? _session;

  @override
  void initState() {
    super.initState();
    _refreshSession();
  }

  void _refreshSession() {
    final session = _parseLastPassedSession();
    if (mounted) setState(() => _session = session);
  }

  @override
  Widget build(BuildContext context) {
    final isGlass =
        Provider.of<ThemeProvider>(context, listen: false).isGlassTheme;
    final primary = Theme.of(context).colorScheme.primary;
    final session = _session;

    return GlassApp(
      child: Scaffold(
        backgroundColor: isGlass
            ? Colors.transparent
            : Theme.of(context).colorScheme.surface,
        appBar: OrionAppBar(
          title: Text(
            FlutterI18n.translate(context, 'leveling.verify'),
          ),
          toolbarHeight: Theme.of(context).appBarTheme.toolbarHeight,
          actions: const [SystemStatusWidget()],
        ),
        body: SafeArea(
          child: Padding(
            padding: OrionSpacing.screenPaddingWithBottomNav,
            child: session != null
                ? _buildSessionView(context, session, primary)
                : _buildNoDataView(context, primary),
          ),
        ),
      ),
    );
  }

  Widget _buildSessionView(
      BuildContext context, _ParsedSession s, Color primary) {
    final theme = Theme.of(context);
    final frontGap = s.frontAvgZ != null && s.backAvgZ != null
        ? (s.frontAvgZ! - s.backAvgZ!).abs()
        : null;
    // Compact timestamp: drop seconds
    final compactTs =
        s.timestamp.length >= 16 ? s.timestamp.substring(0, 16) : s.timestamp;

    return Column(
      children: [
        Expanded(
          child: Center(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: OrionSpacing.screenHorizontal),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Deviation
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(bottom: 5),
                          child: Text(
                            'Δ',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: theme.colorScheme.onSurface
                                  .withValues(alpha: 0.45),
                            ),
                          ),
                        ),
                        const SizedBox(width: 2),
                        Text(
                          s.deviationMm.toStringAsFixed(3),
                          style: const TextStyle(
                            fontSize: 34,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(width: 4),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 5),
                    child: Text(
                      'mm',
                      style: TextStyle(
                        fontSize: 18,
                        color:
                            theme.colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 5),
                    child: Text(
                      '/ 0.100 mm',
                      style: TextStyle(
                        fontSize: 16,
                        color:
                            theme.colorScheme.onSurface.withValues(alpha: 0.35),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: (s.deviationMm / 0.100).clamp(0.0, 1.0),
                  minHeight: 8,
                  backgroundColor:
                      theme.colorScheme.onSurface.withValues(alpha: 0.06),
                  valueColor:
                      const AlwaysStoppedAnimation<Color>(Colors.greenAccent),
                ),
              ),
              const SizedBox(height: 32),
              // Corner Z row
              Row(
                children: [
                  for (final label in const ['FL', 'FR', 'BR', 'BL']) ...[
                    if (label != 'FL')
                      Container(
                        width: 1,
                        height: 24,
                        color:
                            theme.colorScheme.onSurface.withValues(alpha: 0.12),
                      ),
                    Expanded(
                      child: _compactCorner(
                          context, label, s.cornerZs[label], primary),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 32),
              // Stat chips
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _statChip(theme, PhosphorIcons.clock(), compactTs),
                  _statChip(theme, PhosphorIcons.cube(), s.variant),
                  _statChip(theme, PhosphorIcons.arrowsCounterClockwise(),
                      '${s.totalChecks} checks'),
                  if (frontGap != null)
                    _statChip(theme, PhosphorIcons.arrowsVertical(),
                        '${frontGap.toStringAsFixed(3)} mm'),
                  if (s.rangeMm != null)
                    _statChip(theme, PhosphorIcons.arrowsHorizontal(),
                        '${s.rangeMm!.toStringAsFixed(3)} mm'),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
        ),
        // Re-Check Leveling button — bottom-aligned
        Padding(
          padding: const EdgeInsets.fromLTRB(
              OrionSpacing.screenHorizontal, 4,
              OrionSpacing.screenHorizontal, OrionSpacing.controlGap),
          child: SizedBox(
            width: double.infinity,
            child: GlassButton(
              tint: GlassButtonTint.positive,
              onPressed: () async {
                final config = OrionConfig();
                final levelingConfig = getLevelingConfigForMachine(
                  config.getMachineModelName(),
                );
                if (levelingConfig != null) {
                  await Navigator.of(context).push(
                    PageRouteBuilder<void>(
                      opaque: false,
                      barrierDismissible: false,
                      barrierColor:
                          Colors.black.withValues(alpha: 0.35),
                      transitionDuration:
                          const Duration(milliseconds: 300),
                      reverseTransitionDuration:
                          const Duration(milliseconds: 250),
                      pageBuilder: (_, __, ___) =>
                          Athena2LevelingWizard(
                        config: levelingConfig,
                        recheck: true,
                      ),
                      transitionsBuilder: (_, animation, __, child) {
                        return FadeTransition(
                          opacity: CurvedAnimation(
                              parent: animation, curve: Curves.easeOut),
                          child: child,
                        );
                      },
                    ),
                  );
                  _refreshSession();
                }
              },
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 65),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(PhosphorIcons.arrowsCounterClockwise(),
                      size: 20),
                  const SizedBox(width: 8),
                  Text(
                    FlutterI18n.translate(
                        context, 'leveling.recheckLeveling'),
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _statChip(ThemeData theme, IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon,
              size: 18,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.55)),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _compactCorner(
      BuildContext context, String label, double? z, Color primary) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: primary,
          ),
        ),
        const SizedBox(height: 1),
        Text(
          z != null ? z.toStringAsFixed(2) : '--',
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  Widget _buildNoDataView(BuildContext context, Color primary) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: primary.withValues(alpha: 0.12),
            ),
            child: Icon(PhosphorIcons.info(),
                size: 32, color: primary.withValues(alpha: 0.5)),
          ),
          const SizedBox(height: 16),
          Text(
            'No leveling data found',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: primary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Complete an assisted leveling session first.',
            style: TextStyle(
              fontSize: 14,
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }
}

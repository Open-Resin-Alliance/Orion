/*
* Orion - Font Variation Probe
* Detects whether variable fonts (e.g. wght axis) are applied at runtime.
*/

import 'package:flutter/material.dart';
import 'package:logging/logging.dart';

class FontProbeResult {
  final String family;
  final double width300;
  final double width700;
  final bool applied;
  final String note;

  FontProbeResult({
    required this.family,
    required this.width300,
    required this.width700,
    required this.applied,
    required this.note,
  });

  @override
  String toString() =>
      'family=$family w300=${width300.toStringAsFixed(2)} w700=${width700.toStringAsFixed(2)} applied=$applied note=$note';
}

Future<List<FontProbeResult>> runFontVariationProbe(BuildContext context) async {
  final log = Logger('FontProbe');
  final families = <String>[
    'AtkinsonHyperlegibleNext',
    'NotoSansSC',
    'NotoSansJP',
    'NotoSansKR',
  ];

  final sample = 'VariableFontTest-0123456789';
  final results = <FontProbeResult>[];

  for (final family in families) {
    final r = _measureWidths(family, sample);
    results.add(r);
    log.info(r.toString());
  }

  // Quick summary
  final appliedFamilies = results.where((r) => r.applied).map((r) => r.family).toList();
  final ignoredFamilies = results.where((r) => !r.applied).map((r) => r.family).toList();
  log.info('Variable axis applied for: ${appliedFamilies.join(', ')}');
  log.info('Variable axis ignored for: ${ignoredFamilies.join(', ')}');
  return results;
}

FontProbeResult _measureWidths(String family, String text) {
  double w300 = _layoutWidth(text, TextStyle(
    fontFamily: family,
    fontVariations: const [FontVariation('wght', 300)],
  ));
  double w700 = _layoutWidth(text, TextStyle(
    fontFamily: family,
    fontVariations: const [FontVariation('wght', 700)],
  ));

  // If the axis is applied, widths should differ slightly due to glyph metrics.
  final diff = (w700 - w300).abs();
  final applied = diff > 0.5; // tolerant threshold
  final note = applied
      ? 'axis wght appears active'
      : 'axis wght appears ignored (or family not variable)';
  return FontProbeResult(
    family: family,
    width300: w300,
    width700: w700,
    applied: applied,
    note: note,
  );
}

double _layoutWidth(String text, TextStyle style) {
  final painter = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: TextDirection.ltr,
  );
  painter.layout();
  return painter.size.width;
}

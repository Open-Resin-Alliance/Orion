// Mapping of NanoDLP analytic metric ids (T) to canonical keys used by the UI.
const List<Map<String, dynamic>> allChartConfig = [
  {'key': 'LayerHeight', 'id': 0},
  {'key': 'SolidArea', 'id': 1},
  {'key': 'AreaCount', 'id': 2},
  {'key': 'LargestArea', 'id': 3},
  {'key': 'Speed', 'id': 4},
  {'key': 'Cure', 'id': 5},
  {'key': 'Pressure', 'id': 6},
  {'key': 'TemperatureInside', 'id': 7},
  {'key': 'TemperatureOutside', 'id': 8},
  {'key': 'LayerTime', 'id': 9},
  {'key': 'LiftHeight', 'id': 10},
  {'key': 'TemperatureMCU', 'id': 11},
  {'key': 'TemperatureInsideTarget', 'id': 12},
  {'key': 'TemperatureOutsideTarget', 'id': 13},
  {'key': 'TemperatureMCUTarget', 'id': 14},
  {'key': 'MCUFanRPM', 'id': 15},
  {'key': 'UVFanRPM', 'id': 16},
  {'key': 'DynamicWait', 'id': 17},
  {'key': 'TemperatureVat', 'id': 18},
  {'key': 'TemperatureVatTarget', 'id': 19},
  {'key': 'PTCFanRPM', 'id': 20},
  {'key': 'AEGISFanRPM', 'id': 21},
  {'key': 'TemperatureChamber', 'id': 22},
  {'key': 'TemperatureChamberTarget', 'id': 23},
  {'key': 'TemperaturePTC', 'id': 24},
  {'key': 'TemperaturePTCTarget', 'id': 25},
  {'key': 'VOCInlet', 'id': 26},
  {'key': 'VOCOutlet', 'id': 27},
];

String? idToKey(int id) {
  for (final e in allChartConfig) {
    final val = e['id'];
    if (val is int && val == id) return e['key'] as String?;
  }
  return null;
}

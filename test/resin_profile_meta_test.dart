import 'package:flutter_test/flutter_test.dart';
import 'package:orion/backend_service/nanodlp/models/nano_profiles.dart';
import 'package:orion/backend_service/providers/resins_provider.dart';

/// The materials list reads layer height and cure time straight out of the
/// backend's profile payload. These cases pin the payload shape that goes in
/// (a real NanoDLP profile, verbatim from the printer's profiles.json) and the
/// parameters that come out.
void main() {
  test('reads layer height and cure time from a NanoDLP profile', () {
    final merged = NanoProfile.parseFromJson([
      {
        'ProfileID': 1,
        'Title': 'General Purpose / Standard Resin',
        'Depth': 50,
        'CureTime': 2,
        'SupportCureTime': 65,
        'WaitHeight': 5,
        'ZResPerc': 0,
        'CustomValues': {'Viscosity': '3800', 'Matteo': '1'},
      }
    ]).first.toMap();

    final resin = ResinProfile('General Purpose / Standard Resin', meta: merged);

    expect(resin.layerHeightUm, 50);
    expect(resin.normalExposureSeconds, 2);
  });

  test('reads a flattened payload and normalises the key spelling', () {
    final resin = ResinProfile('Flat', meta: {
      'depth': 30,
      'normal_cure_time': 1.5,
    });

    expect(resin.layerHeightUm, 30);
    expect(resin.normalExposureSeconds, 1.5);
  });

  test('treats a sub-1 layer height as millimetres', () {
    final resin = ResinProfile('Mm', meta: {'LayerHeight': 0.05});

    expect(resin.layerHeightUm, 50);
  });

  test('returns null when the profile carries no such parameter', () {
    final resin = ResinProfile('Bare', meta: const {});

    expect(resin.layerHeightUm, isNull);
    expect(resin.normalExposureSeconds, isNull);
  });
}

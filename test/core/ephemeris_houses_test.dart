// End-to-end houses through the ephemeris facade (this package's GAST and true
// obliquity feeding lib/src/houses/), checked against closed-form definitions
// that do not share code with the implementation: Meeus' ascendant and
// midheaven formulas (Astronomical Algorithms, ch. 14), equal and whole-sign
// houses, and the defining semi-arc condition of Placidus cusps.
// ignore_for_file: avoid_print

import 'dart:math' as math;

import 'package:test/test.dart';
import 'package:astro_ephemeris/astro_ephemeris.dart';

const double _d2r = math.pi / 180;

double _norm(double a) => ((a % 360) + 360) % 360;

double _diff(double a, double b) {
  final double d = _norm(a - b);
  return d > 180 ? 360 - d : d;
}

void main() {
  final math.Random rnd = math.Random(20261113);

  test('ascendant, midheaven, equal and whole-sign houses', () {
    double worstAsc = 0, worstMc = 0;
    for (int n = 0; n < 2000; n++) {
      final double jd = 2415020.5 + rnd.nextDouble() * 73049;
      final double lat = (rnd.nextDouble() * 2 - 1) * 64;
      final double lon = (rnd.nextDouble() * 2 - 1) * 180;
      final double armc = _norm(gastHours(jd) * 15 + lon);
      final double eps = trueObliquity(jd) * _d2r;
      final double th = armc * _d2r, ph = lat * _d2r;

      final double asc = _norm(
        math.atan2(
              math.cos(th),
              -(math.sin(th) * math.cos(eps) + math.tan(ph) * math.sin(eps)),
            ) /
            _d2r,
      );
      final double mc = _norm(
        math.atan2(math.sin(th), math.cos(th) * math.cos(eps)) / _d2r,
      );

      final HouseCusps h = houses(jd, lat, lon, HouseSystem.placidus);
      expect(_diff(h.armc, armc), lessThan(1e-9));
      worstAsc = math.max(worstAsc, _diff(h.ascendant, asc));
      worstMc = math.max(worstMc, _diff(h.mc, mc));

      final HouseCusps e = houses(jd, lat, lon, HouseSystem.equal);
      for (int i = 0; i < 12; i++) {
        expect(_diff(e.cusps[i], asc + 30.0 * i), lessThan(1e-6));
      }
      final HouseCusps w = houses(jd, lat, lon, HouseSystem.wholeSign);
      final double first = (asc ~/ 30) * 30.0;
      for (int i = 0; i < 12; i++) {
        expect(_diff(w.cusps[i], first + 30.0 * i), lessThan(1e-9));
      }
    }
    print('ascendant max diff $worstAsc deg, midheaven $worstMc deg');
    expect(worstAsc, lessThan(1e-9));
    expect(worstMc, lessThan(1e-9));
  });

  test('Placidus cusps satisfy the semi-arc condition', () {
    double worst = 0;
    for (int n = 0; n < 2000; n++) {
      final double jd = 2415020.5 + rnd.nextDouble() * 73049;
      final double lat = (rnd.nextDouble() * 2 - 1) * 60;
      final double lon = (rnd.nextDouble() * 2 - 1) * 180;
      final HouseCusps h = houses(jd, lat, lon, HouseSystem.placidus);
      final double eps = trueObliquity(jd) * _d2r;
      // cusp number -> (offset from the meridian in semi-arcs, above horizon).
      const Map<int, (double, bool)> spec = {
        11: (1 / 3, true),
        12: (2 / 3, true),
        2: (-2 / 3, false),
        3: (-1 / 3, false),
      };
      spec.forEach((int cusp, (double, bool) s) {
        final double lam = h.cusp(cusp) * _d2r;
        final double ra = _norm(
          math.atan2(math.sin(lam) * math.cos(eps), math.cos(lam)) / _d2r,
        );
        final double dec = math.asin(math.sin(eps) * math.sin(lam));
        final double dsa =
            math.acos(-math.tan(lat * _d2r) * math.tan(dec)) / _d2r;
        final double expected =
            s.$2 ? h.armc + s.$1 * dsa : h.armc + 180 + s.$1 * (180 - dsa);
        worst = math.max(worst, _diff(ra, expected));
      });
    }
    print('Placidus semi-arc residual max $worst deg');
    expect(worst, lessThan(1e-6));
  });
}

// Facade behaviour that the Horizons comparison (test/horizons/) does not
// cover: retrograde flags at well-known dates, the lunar points against
// published mean elements, and the Chiron table range.
// ignore_for_file: avoid_print

import 'package:test/test.dart';
import 'package:astro_ephemeris/astro_ephemeris.dart';

double _jd(int y, int m, int d) => julianDayUt(DateTime.utc(y, m, d, 12));

double _diff(double a, double b) {
  double d = (a - b) % 360.0;
  if (d > 180.0) d -= 360.0;
  return d;
}

void main() {
  test('retrograde flags at well-known dates', () {
    // Mercury retrograde 2024-04-01 to 2024-04-25; Mars 2024-12-06 to
    // 2025-02-24 (published almanac dates).
    expect(position(Body.mercury, _jd(2024, 4, 10)).isRetrograde, isTrue);
    expect(position(Body.mercury, _jd(2024, 5, 10)).isRetrograde, isFalse);
    expect(position(Body.mars, _jd(2025, 1, 15)).isRetrograde, isTrue);
    expect(position(Body.mars, _jd(2025, 4, 15)).isRetrograde, isFalse);
    // The Sun and the Moon never are; the nodes always are.
    for (int i = 0; i < 60; i++) {
      final double jd = _jd(2024, 1, 1) + i * 6.1;
      expect(position(Body.sun, jd).isRetrograde, isFalse);
      expect(position(Body.moon, jd).isRetrograde, isFalse);
      expect(position(Body.meanNode, jd).isRetrograde, isTrue);
    }
  });

  test('speed matches a central difference of the longitude', () {
    for (final Body b in Body.values) {
      for (int i = 0; i < 20; i++) {
        final double jd = _jd(1990, 1, 1) + i * 997.3;
        const double h = 0.02;
        final double fd = _diff(
              position(b, jd + h).longitude,
              position(b, jd - h).longitude,
            ) /
            (2 * h);
        expect(
          position(b, jd).speedLongitude,
          closeTo(fd, 0.01),
          reason: '${b.name} $jd',
        );
      }
    }
  });

  group('lunar points', () {
    test('mean node follows Meeus (Omega = 125.0445 deg at J2000)', () {
      // Apparent longitude: Meeus' mean value plus nutation (|dpsi| < 20").
      final double lon = position(Body.meanNode, 2451545.0).longitude;
      print('mean node at J2000: $lon');
      expect(_diff(lon, 125.0445479), closeTo(0, 0.01));
      // Regression of 19.3549 deg per Julian year (-0.0529539 deg/day).
      expect(
        position(Body.meanNode, 2451545.0).speedLongitude,
        closeTo(-0.0529539, 0.001),
      );
      expect(position(Body.meanNode, 2451545.0).latitude, 0);
    });

    test('true node stays within 2.2 degrees of the mean node, latitude 0', () {
      double worst = 0;
      for (int i = 0; i < 2000; i++) {
        final double jd = 2415020.5 + i * 36.5;
        final BodyPosition t = position(Body.trueNode, jd);
        final BodyPosition m = position(Body.meanNode, jd);
        worst = worst < _diff(t.longitude, m.longitude).abs()
            ? _diff(t.longitude, m.longitude).abs()
            : worst;
        expect(t.latitude, 0);
      }
      print('true - mean node, max: $worst deg');
      expect(worst, lessThan(2.2));
    });

    test('mean apogee: Meeus mean perigee + 180, latitude within 5.15 deg', () {
      final BodyPosition p = position(Body.meanApogee, 2451545.0);
      print('mean apogee at J2000: ${p.longitude}, lat ${p.latitude}');
      // Mean perigee at J2000 = 83.3532465 deg (Meeus). The apogee is
      // projected onto the ecliptic through the mean inclination, which
      // shifts the longitude by up to ~0.1 degree.
      expect(_diff(p.longitude, 83.3532465 + 180), closeTo(0, 0.2));
      for (int i = 0; i < 400; i++) {
        final BodyPosition q = position(Body.meanApogee, 2415020.5 + i * 180);
        expect(q.latitude.abs(), lessThanOrEqualTo(5.1454));
        expect(q.speedLongitude, greaterThan(0.1)); // ~0.111 deg/day
        expect(q.speedLongitude, lessThan(0.12));
      }
    });
  });

  test('Chiron outside the 1800-2201 table throws RangeError', () {
    expect(() => position(Body.chiron, 2378400.5), throwsRangeError);
    expect(position(Body.chiron, 2451545.0).distance, greaterThan(10));
  });
}

// Geocentric apparent Chiron (Astronomy Engine path + JPL table) against
// NASA/JPL Horizons observer ephemeris (test/fixtures/horizons/chiron.csv.gz:
// every 37 days, 1900-2100, apparent, true ecliptic and equinox of date, UT).
//
// Measured (README.md): longitude max 0.49", latitude max 0.21", distance
// relative max 1.8e-6. Part of the longitude residual is the IAU 1976/80
// ecliptic Horizons uses vs IAU 2006 here (~0.2" drift over 200 years) and
// the solar light deflection that Astronomy Engine does not model.
// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:test/test.dart';
import 'package:astro_ephemeris/src/astronomy/astronomy.dart' as ae;
import 'package:astro_ephemeris/src/chiron/chiron_geo.dart';
import 'package:astro_ephemeris/src/ephemeris.dart' show installEphemerisDeltaT;

double _angleDiff(double a, double b) {
  double d = (a - b) % 360.0;
  if (d > 180.0) d -= 360.0;
  return d;
}

class _Stats {
  final List<double> v = <double>[];
  void add(double x) => v.add(x.abs());
  double get max => v.reduce(math.max);
  double get p95 {
    final List<double> s = List<double>.of(v)..sort();
    return s[((s.length - 1) * 0.95).round()];
  }
}

void main() {
  test('Chiron vs JPL Horizons, 1900-2100', () {
    final List<String> lines = const LineSplitter().convert(
      utf8.decode(
        gzip.decode(
          File('test/fixtures/horizons/chiron.csv.gz').readAsBytesSync(),
        ),
      ),
    );
    installEphemerisDeltaT();
    final _Stats lon = _Stats(), lat = _Stats(), dist = _Stats();
    for (final String l in lines.skip(1).where((String l) => l.isNotEmpty)) {
      final List<double> x = l.split(',').map(double.parse).toList();
      final ChironGeoEcliptic c = chironGeoEclipticOfDate(
        ae.AstroTime.fromJulianDayUt(x[0]),
      );
      lon.add(_angleDiff(c.lon, x[1]) * 3600.0);
      lat.add((c.lat - x[2]) * 3600.0);
      dist.add((c.distAu - x[3]) / x[3]);
      expect(c.lon, inInclusiveRange(0.0, 360.0));
    }
    print(
      'Chiron vs Horizons (${lines.length - 1} rows): '
      'dlon max ${lon.max.toStringAsFixed(3)}" p95 ${lon.p95.toStringAsFixed(3)}"; '
      'dlat max ${lat.max.toStringAsFixed(3)}"; '
      'ddist rel max ${dist.max.toStringAsExponential(2)}',
    );
    expect(lon.max, lessThan(0.55));
    expect(lat.max, lessThan(0.24));
    expect(dist.max, lessThan(2e-6));
  });

  test('retrograde speed sign and range errors', () {
    installEphemerisDeltaT();
    // 2024-07-26 Chiron stationed retrograde at ~23.7 Aries; mid-Sept it is
    // retrograde.
    final ChironGeoEcliptic r = chironGeoEclipticOfDate(
      ae.AstroTime.fromJulianDayUt(2460570.5),
    );
    expect(r.lonSpeedDegPerDay, lessThan(0));
    expect(r.lon, inInclusiveRange(20.0, 24.0));
    expect(
      () => chironGeoEclipticOfDate(ae.AstroTime.fromJulianDayUt(2378400.5)),
      throwsRangeError,
    );
  });
}

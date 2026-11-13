// Chiron Chebyshev table vs held-out NASA/JPL Horizons states.
//
// test/fixtures/chiron/horizons_holdout.csv.gz: 5000 random fractional
// epochs (1800-2201) fetched from Horizons separately from the fitted 2-day
// grid (tool/chiron/fetch_horizons.py tlist), never used in the fit.
// Measured when generated: position max 1.9e-9 AU, velocity max 3.9e-10 AU/d.
// Required: position < 1e-8 AU (0.0003" seen from the Sun), velocity < 2e-9.

import 'dart:io';
import 'dart:math' as math;

import 'package:test/test.dart';
import 'package:astro_ephemeris/src/chiron/chiron.dart';

void main() {
  final List<List<double>> rows = <List<double>>[];
  setUpAll(() {
    final String text = utf8Gunzip(
      'test/fixtures/chiron/horizons_holdout.csv.gz',
    );
    for (final String line in text.split('\n')) {
      if (line.isEmpty || line.startsWith('#')) continue;
      rows.add(line.split(',').map(double.parse).toList());
    }
  });

  test(
    '5000 held-out Horizons epochs: position < 1e-8 AU, velocity < 2e-9 AU/d',
    () {
      expect(rows.length, 5000);
      double maxP = 0, maxV = 0;
      for (final List<double> r in rows) {
        final ChironStateHelio s = chironHelioEqj(r[0]);
        final double dp = _norm(s.x - r[1], s.y - r[2], s.z - r[3]);
        final double dv = _norm(s.vx - r[4], s.vy - r[5], s.vz - r[6]);
        maxP = math.max(maxP, dp);
        maxV = math.max(maxV, dv);
      }
      // ignore: avoid_print
      print(
        'Chiron table vs Horizons hold-out: max |dpos| ${maxP.toStringAsExponential(2)} AU, '
        'max |dvel| ${maxV.toStringAsExponential(2)} AU/d',
      );
      expect(maxP, lessThan(1e-8));
      expect(maxV, lessThan(2e-9));
    },
  );

  test('covered range and RangeError outside it', () {
    expect(kChironJdStart, 2378496.5); // 1800-01-01 TDB
    expect(kChironJdEnd, 2525184.5); // 2201-08-15 TDB
    expect(() => chironHelioEqj(kChironJdStart), returnsNormally);
    expect(() => chironHelioEqj(kChironJdEnd), returnsNormally);
    expect(() => chironHelioEqj(kChironJdStart - 1e-6), throwsRangeError);
    expect(() => chironHelioEqj(kChironJdEnd + 1e-6), throwsRangeError);
    expect(() => chironHelioEqj(double.nan), throwsRangeError);
  });

  test('continuous across segment joints, velocity = d(position)/dt', () {
    for (int s = 1; s < 573; s += 7) {
      final double jd = kChironJdStart + s * 256.0;
      final ChironStateHelio a = chironHelioEqj(jd - 1e-9);
      final ChironStateHelio b = chironHelioEqj(jd);
      expect(_norm(a.x - b.x, a.y - b.y, a.z - b.z), lessThan(1e-9));
      const double h = 0.05;
      final ChironStateHelio m = chironHelioEqj(jd - 3 * h);
      final ChironStateHelio p = chironHelioEqj(jd - h);
      final ChironStateHelio c = chironHelioEqj(jd - 2 * h);
      expect((p.x - m.x) / (2 * h) - c.vx, closeTo(0, 1e-10));
      expect((p.y - m.y) / (2 * h) - c.vy, closeTo(0, 1e-10));
      expect((p.z - m.z) / (2 * h) - c.vz, closeTo(0, 1e-10));
    }
  });

  test('sanity: perihelion 1996 at ~8.45 AU, aphelion ~2021 at ~18.9 AU', () {
    double r(double jd) {
      final ChironStateHelio s = chironHelioEqj(jd);
      return _norm(s.x, s.y, s.z);
    }

    expect(r(2450143.7), closeTo(8.45, 0.05)); // TP 1996-02-14 (JPL#171)
    expect(r(2459200.5), inInclusiveRange(18.5, 19.0));
  });
}

double _norm(double x, double y, double z) => math.sqrt(x * x + y * y + z * z);

String utf8Gunzip(String path) =>
    String.fromCharCodes(gzip.decode(File(path).readAsBytesSync()));

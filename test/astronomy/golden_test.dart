// Agreement of the Dart port of Astronomy Engine with the official
// Astronomy Engine 2.1.19 Python package (the oracle), on 2000 instants
// 1800-2200 (mostly 1900-2100). See
// test/fixtures/astronomy_engine_golden/README.md for how the goldens are made.
//
// Tolerances (fixed by the porting brief, do not loosen):
//   vectors <= 1e-9 AU, angles <= 1e-7 degree.
// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:test/test.dart';
import 'package:astro_ephemeris/src/astronomy/astronomy.dart';

const double _auTol = 1e-9;
const double _degTol = 1e-7;

const Map<String, Body> _bodies = {
  'Sun': Body.sun,
  'Moon': Body.moon,
  'Mercury': Body.mercury,
  'Venus': Body.venus,
  'Mars': Body.mars,
  'Jupiter': Body.jupiter,
  'Saturn': Body.saturn,
  'Uranus': Body.uranus,
  'Neptune': Body.neptune,
  'Pluto': Body.pluto,
};

const Map<String, Body> _helioBodies = {
  'Mercury': Body.mercury,
  'Venus': Body.venus,
  'Earth': Body.earth,
  'Mars': Body.mars,
  'Jupiter': Body.jupiter,
  'Saturn': Body.saturn,
  'Uranus': Body.uranus,
  'Neptune': Body.neptune,
  'Pluto': Body.pluto,
  'Moon': Body.moon,
  'EMB': Body.emb,
  'SSB': Body.ssb,
};

/// Signed angle difference a-b in degrees, wrapped to (-180, 180].
double angleDiff(double a, double b) {
  double d = (a - b) % 360.0;
  if (d > 180.0) d -= 360.0;
  return d;
}

/// Tracks the largest error of one quantity and where it happened.
class MaxErr {
  MaxErr(this.name, this.tol, this.unit);
  final String name;
  final double tol;
  final String unit;
  double max = 0;
  double atUt = double.nan;
  int count = 0;

  void add(double err, double ut) {
    count++;
    final double e = err.abs();
    if (e.isNaN || e > max) {
      max = e;
      atUt = ut;
    }
  }

  void addVec(List<double> got, List<dynamic> want, double ut) {
    for (int i = 0; i < got.length; i++) {
      add(got[i] - (want[i] as num).toDouble(), ut);
    }
  }
}

void main() {
  late List<dynamic> records;
  final Map<String, MaxErr> errs = {};

  MaxErr err(String name, double tol, String unit) =>
      errs.putIfAbsent(name, () => MaxErr(name, tol, unit));

  setUpAll(() {
    final File f = File('test/fixtures/astronomy_engine_golden/golden.json.gz');
    final Map<String, dynamic> doc =
        json.decode(utf8.decode(gzip.decode(f.readAsBytesSync())))
            as Map<String, dynamic>;
    records = doc['records'] as List<dynamic>;

    for (final dynamic r in records) {
      final Map<String, dynamic> rec = r as Map<String, dynamic>;
      final double ut = (rec['ut'] as num).toDouble();
      final AstroTime time = AstroTime(ut);

      err('tt', 1e-12, 'day').add(time.tt - (rec['tt'] as num), ut);
      err(
        'deltaT',
        1e-9,
        's',
      ).add(deltaTEspenakMeeus(ut) - (rec['deltaT'] as num), ut);

      final double gastDiffH = angleDiff(
            siderealTime(AstroTime(ut)) * 15,
            (rec['gast'] as num) * 15,
          ) /
          15;
      err('GAST', _degTol, 'deg').add(gastDiffH * 15, ut);

      final EarthTiltInfo et = eTilt(AstroTime(ut));
      final List<dynamic> tilt = rec['tilt'] as List<dynamic>;
      err('e_tilt.mobl', _degTol, 'deg').add(et.mobl - (tilt[0] as num), ut);
      err('e_tilt.tobl', _degTol, 'deg').add(et.tobl - (tilt[1] as num), ut);
      // dpsi/deps/ee are in arcsec / seconds of time: compare as degrees.
      err(
        'e_tilt.dpsi',
        _degTol,
        'deg',
      ).add((et.dpsi - (tilt[2] as num)) / 3600, ut);
      err(
        'e_tilt.deps',
        _degTol,
        'deg',
      ).add((et.deps - (tilt[3] as num)) / 3600, ut);
      err(
        'e_tilt.ee',
        _degTol,
        'deg',
      ).add((et.ee - (tilt[4] as num)) * 15 / 3600, ut);

      final Map<String, dynamic> geo = rec['geo'] as Map<String, dynamic>;
      _bodies.forEach((String name, Body body) {
        final Map<String, dynamic> g = geo[name] as Map<String, dynamic>;
        final Vector ab = geoVector(body, AstroTime(ut), true);
        final Vector noab = geoVector(body, AstroTime(ut), false);
        err(
          'GeoVector $name aberr',
          _auTol,
          'AU',
        ).addVec([ab.x, ab.y, ab.z], g['ab'] as List<dynamic>, ut);
        err(
          'GeoVector $name noaberr',
          _auTol,
          'AU',
        ).addVec([noab.x, noab.y, noab.z], g['noab'] as List<dynamic>, ut);
        final EclipticCoordinates ecl = ecliptic(ab);
        final List<dynamic> want = g['ecl'] as List<dynamic>;
        err(
          'Ecliptic $name elon',
          _degTol,
          'deg',
        ).add(angleDiff(ecl.elon, (want[0] as num).toDouble()), ut);
        err(
          'Ecliptic $name elat',
          _degTol,
          'deg',
        ).add(ecl.elat - (want[1] as num), ut);
        err(
          'Ecliptic $name dist',
          _auTol,
          'AU',
        ).add(ab.length() - (want[2] as num), ut);
      });

      final Map<String, dynamic> helio = rec['helio'] as Map<String, dynamic>;
      _helioBodies.forEach((String name, Body body) {
        final dynamic want = helio[name];
        if (want == null) return;
        final Vector h = helioVector(body, AstroTime(ut));
        err(
          'HelioVector $name',
          _auTol,
          'AU',
        ).addVec([h.x, h.y, h.z], want as List<dynamic>, ut);
      });

      final Spherical m = eclipticGeoMoon(AstroTime(ut));
      final List<dynamic> mw = rec['moonEcl'] as List<dynamic>;
      err(
        'EclipticGeoMoon lon',
        _degTol,
        'deg',
      ).add(angleDiff(m.lon, (mw[0] as num).toDouble()), ut);
      err(
        'EclipticGeoMoon lat',
        _degTol,
        'deg',
      ).add(m.lat - (mw[1] as num), ut);
      err(
        'EclipticGeoMoon dist',
        _auTol,
        'AU',
      ).add(m.dist - (mw[2] as num), ut);

      final StateVector s = geoMoonState(AstroTime(ut));
      final List<dynamic> sw = rec['moonState'] as List<dynamic>;
      err(
        'GeoMoonState pos',
        _auTol,
        'AU',
      ).addVec([s.x, s.y, s.z], sw.sublist(0, 3), ut);
      err(
        'GeoMoonState vel',
        _auTol,
        'AU/day',
      ).addVec([s.vx, s.vy, s.vz], sw.sublist(3, 6), ut);

      final EclipticCoordinates sp = sunPosition(AstroTime(ut));
      final List<dynamic> spw = rec['sunPos'] as List<dynamic>;
      err(
        'SunPosition elon',
        _degTol,
        'deg',
      ).add(angleDiff(sp.elon, (spw[0] as num).toDouble()), ut);
      err(
        'SunPosition elat',
        _degTol,
        'deg',
      ).add(sp.elat - (spw[1] as num), ut);
    }

    print('Astronomy Engine golden agreement (${records.length} instants):');
    for (final MaxErr e in errs.values) {
      print(
        '  ${e.name.padRight(28)} max ${e.max.toStringAsExponential(2)} '
        '${e.unit} (tol ${e.tol.toStringAsExponential(0)}, n=${e.count}, '
        'worst ut=${e.atUt})',
      );
    }
  });

  test('golden file has the expected coverage', () {
    expect(records.length, 2000);
    final List<double> uts = records
        .map((dynamic r) => ((r as Map)['ut'] as num).toDouble())
        .toList();
    expect(uts.reduce(math.min), lessThan(-73000)); // 1800
    expect(uts.reduce(math.max), greaterThan(73000)); // 2200
  });

  test('every quantity agrees with the oracle within tolerance', () {
    expect(errs, isNotEmpty);
    for (final MaxErr e in errs.values) {
      expect(e.count, greaterThan(0), reason: e.name);
      expect(
        e.max,
        lessThanOrEqualTo(e.tol),
        reason: '${e.name}: max error ${e.max} ${e.unit} at ut=${e.atUt}',
      );
    }
  });
}

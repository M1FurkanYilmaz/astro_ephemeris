// MIT License
//
// Copyright (c) 2019-2023 Don Cross <cosinekitty@gmail.com>
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.
//
// Ported to Dart from Astronomy Engine v2.1.19 (commit 03084ee).
// https://github.com/cosinekitty/astronomy
//

part of 'astronomy.dart';

// Moon: CalcMoon, GeoMoon, EclipticGeoMoon, GeoMoonState, GeoEmbState
// (astronomy.ts 1492-1793, 3046-3186).
//
// CalcMoon is Astronomy Engine's translation of the Pascal lunar theory in
// "Astronomy on the Personal Computer" (Montenbruck & Pfleger), with the
// AddSol/ADDN term tables in moon_tables.dart.

class _MoonResult {
  _MoonResult(this.geoEclipLon, this.geoEclipLat, this.distanceAu);

  /// Geocentric ecliptic longitude, mean equinox of date, radians.
  final double geoEclipLon;

  /// Geocentric ecliptic latitude, radians.
  final double geoEclipLat;

  /// Distance in AU.
  final double distanceAu;
}

/// Number of times [_calcMoon] has run in this isolate (`CalcMoonCount`).
int calcMoonCount = 0;

// Pascal arrays CO[-6..6, 1..4] and SI[-6..6, 1..4], flattened.
int _moonIdx(int x, int y) => (x + 6) * 5 + y;

double _sine(double phi) => math.sin(_pi2 * phi);

_MoonResult _calcMoon(AstroTime time) {
  ++calcMoonCount;

  final double t = time.tt / 36525;

  final Float64List co = Float64List(13 * 5);
  final Float64List si = Float64List(13 * 5);

  final double t2 = t * t;
  double dlam = 0;
  double ds = 0;
  double gam1c = 0;
  double sinpi = 3422.7000;

  final double s1 = _sine(0.19833 + 0.05611 * t);
  final double s2 = _sine(0.27869 + 0.04508 * t);
  final double s3 = _sine(0.16827 - 0.36903 * t);
  final double s4 = _sine(0.34734 - 5.37261 * t);
  final double s5 = _sine(0.10498 - 5.37899 * t);
  final double s6 = _sine(0.42681 - 0.41855 * t);
  final double s7 = _sine(0.14943 - 5.37511 * t);
  final double dl0 =
      0.84 * s1 + 0.31 * s2 + 14.27 * s3 + 7.26 * s4 + 0.28 * s5 + 0.24 * s6;
  final double dl =
      2.94 * s1 + 0.31 * s2 + 14.27 * s3 + 9.34 * s4 + 1.12 * s5 + 0.83 * s6;
  final double dls = -6.40 * s1 - 1.89 * s6;
  final double df = 0.21 * s1 +
      0.31 * s2 +
      14.27 * s3 -
      88.70 * s4 -
      15.30 * s5 +
      0.24 * s6 -
      1.86 * s7;
  final double dd = dl0 - dls;
  final double dgam = (-3332E-9 * _sine(0.59734 - 5.37261 * t) -
      539E-9 * _sine(0.35498 - 5.37899 * t) -
      64E-9 * _sine(0.39943 - 5.37511 * t));

  final double l0 =
      _pi2 * _frac(0.60643382 + 1336.85522467 * t - 0.00000313 * t2) +
          dl0 / _arc;
  final double l =
      _pi2 * _frac(0.37489701 + 1325.55240982 * t + 0.00002565 * t2) +
          dl / _arc;
  final double ls =
      _pi2 * _frac(0.99312619 + 99.99735956 * t - 0.00000044 * t2) + dls / _arc;
  final double f =
      _pi2 * _frac(0.25909118 + 1342.22782980 * t - 0.00000892 * t2) +
          df / _arc;
  final double d =
      _pi2 * _frac(0.82736186 + 1236.85308708 * t - 0.00000397 * t2) +
          dd / _arc;

  for (int i = 1; i <= 4; ++i) {
    double arg;
    int max;
    double fac;
    switch (i) {
      case 1:
        arg = l;
        max = 4;
        fac = 1.000002208;
      case 2:
        arg = ls;
        max = 3;
        fac = 0.997504612 - 0.002495388 * t;
      case 3:
        arg = f;
        max = 4;
        fac = 1.000002708 + 139.978 * dgam;
      default:
        arg = d;
        max = 6;
        fac = 1.0;
    }
    co[_moonIdx(0, i)] = 1;
    co[_moonIdx(1, i)] = math.cos(arg) * fac;
    si[_moonIdx(0, i)] = 0;
    si[_moonIdx(1, i)] = math.sin(arg) * fac;
    for (int j = 2; j <= max; ++j) {
      // AddThe(CO(J-1,I), SI(J-1,I), CO(1,I), SI(1,I))
      final double c1 = co[_moonIdx(j - 1, i)];
      final double sn1 = si[_moonIdx(j - 1, i)];
      final double c2 = co[_moonIdx(1, i)];
      final double sn2 = si[_moonIdx(1, i)];
      co[_moonIdx(j, i)] = c1 * c2 - sn1 * sn2;
      si[_moonIdx(j, i)] = sn1 * c2 + c1 * sn2;
    }
    for (int j = 1; j <= max; ++j) {
      co[_moonIdx(-j, i)] = co[_moonIdx(j, i)];
      si[_moonIdx(-j, i)] = -si[_moonIdx(j, i)];
    }
  }

  // Term(p, q, r, s): returns the complex product as (x, y) in termX/termY.
  double termX = 1;
  double termY = 0;
  void term(int p, int q, int r, int s) {
    termX = 1;
    termY = 0;
    final List<int> idx = <int>[0, p, q, r, s]; // idx[0] is a placeholder
    for (int k = 1; k <= 4; ++k) {
      if (idx[k] != 0) {
        final double c2 = co[_moonIdx(idx[k], k)];
        final double s2 = si[_moonIdx(idx[k], k)];
        final double c1 = termX;
        final double sn1 = termY;
        termX = c1 * c2 - sn1 * s2;
        termY = sn1 * c2 + c1 * s2;
      }
    }
  }

  for (final MoonSolTerm a in moonSolTerms) {
    // AddSol(coeffl, coeffs, coeffg, coeffp, p, q, r, s)
    term(a.p, a.q, a.r, a.s);
    dlam += a.coeffl * termY;
    ds += a.coeffs * termY;
    gam1c += a.coeffg * termX;
    sinpi += a.coeffp * termX;
  }

  double n = 0;
  for (final MoonNodeTerm a in moonNodeTerms) {
    // ADDN(coeffn, p, q, r, s)
    term(a.p, a.q, a.r, a.s);
    n += a.coeffn * termY;
  }

  dlam += (0.82 * _sine(0.7736 - 62.5512 * t) +
      0.31 * _sine(0.0466 - 125.1025 * t) +
      0.35 * _sine(0.5785 - 25.1042 * t) +
      0.66 * _sine(0.4591 + 1335.8075 * t) +
      0.64 * _sine(0.3130 - 91.5680 * t) +
      1.14 * _sine(0.1480 + 1331.2898 * t) +
      0.21 * _sine(0.5918 + 1056.5859 * t) +
      0.44 * _sine(0.5784 + 1322.8595 * t) +
      0.24 * _sine(0.2275 - 5.7374 * t) +
      0.28 * _sine(0.2965 + 2.6929 * t) +
      0.33 * _sine(0.3132 + 6.3368 * t));

  final double s = f + ds / _arc;

  final double latSeconds = (1.000002708 + 139.978 * dgam) *
          (18518.511 + 1.189 + gam1c) *
          math.sin(s) -
      6.24 * math.sin(3 * s) +
      n;

  return _MoonResult(
    _pi2 * _frac((l0 + dlam / _arc) / _pi2),
    (math.pi / (180 * 3600)) * latSeconds,
    (_arc * _earthEquatorialRadiusAu) / (0.999953253 * sinpi),
  );
}

/// The Moon's geocentric position as a J2000 mean equator (EQJ) vector, in AU
/// (`GeoMoon`). Not corrected for light time (about 1.3 s).
Vector geoMoon(AstroTime time) {
  final _MoonResult moon = _calcMoon(time);

  // Convert geocentric ecliptic spherical coords to cartesian coords.
  final double distCosLat = moon.distanceAu * math.cos(moon.geoEclipLat);
  final _ArrayVector gepos = <double>[
    distCosLat * math.cos(moon.geoEclipLon),
    distCosLat * math.sin(moon.geoEclipLon),
    moon.distanceAu * math.sin(moon.geoEclipLat),
  ];

  // Convert ecliptic coordinates to equatorial coordinates, both in mean equinox of date.
  final _ArrayVector mpos1 = _ecl2EquVec(time, gepos);

  // Convert from mean equinox of date to J2000...
  final _ArrayVector mpos2 = _precession(
    mpos1,
    time,
    _PrecessDirection.into2000,
  );

  return Vector(mpos2[0], mpos2[1], mpos2[2], time);
}

/// The Moon's geocentric ecliptic coordinates in the true equinox of date
/// (`EclipticGeoMoon`): lat/lon in degrees, dist in AU.
Spherical eclipticGeoMoon(AstroTime time) {
  final _MoonResult moon = _calcMoon(time);

  // Convert spherical coordinates to a vector.
  // The MoonResult angles are already expressed in radians.
  final double distCosLat = moon.distanceAu * math.cos(moon.geoEclipLat);
  final _ArrayVector ecm = <double>[
    distCosLat * math.cos(moon.geoEclipLon),
    distCosLat * math.sin(moon.geoEclipLon),
    moon.distanceAu * math.sin(moon.geoEclipLat),
  ];

  // Obtain true and mean obliquity angles for the given time.
  // This serves to pre-calculate the nutation also, and cache it in `time`.
  final EarthTiltInfo et = eTilt(time);

  // Convert ecliptic coordinates to equatorial coordinates, both in mean equinox of date.
  final _ArrayVector eqm = _oblEcl2EquVec(et.mobl, ecm);

  // Add nutation to convert ECM to true equatorial coordinates of date (EQD).
  final _ArrayVector eqd = _nutation(eqm, time, _PrecessDirection.from2000);
  final Vector eqdVec = _vectorFromArray(eqd, time);

  // Convert back to ecliptic, this time in true equinox of date (ECT).
  final double toblRad = et.tobl * deg2Rad;
  final double cosTobl = math.cos(toblRad);
  final double sinTobl = math.sin(toblRad);
  final EclipticCoordinates eclip = _rotateEquatorialToEcliptic(
    eqdVec,
    cosTobl,
    sinTobl,
  );

  return Spherical(eclip.elat, eclip.elon, moon.distanceAu);
}

/// The Moon's geocentric EQJ position (AU) and velocity (AU/day)
/// (`GeoMoonState`), by symmetric differencing over +/- 0.864 seconds.
StateVector geoMoonState(AstroTime time) {
  // This is a hack, because trying to figure out how to derive a time
  // derivative for CalcMoon() would be extremely painful!
  // Calculate just before and just after the given time.
  // Average to find position, subtract to find velocity.
  const double dt = 1.0e-5; // 0.864 seconds

  final AstroTime t1 = time.addDays(-dt);
  final AstroTime t2 = time.addDays(dt);
  final Vector r1 = geoMoon(t1);
  final Vector r2 = geoMoon(t2);

  return StateVector(
    (r1.x + r2.x) / 2,
    (r1.y + r2.y) / 2,
    (r1.z + r2.z) / 2,
    (r2.x - r1.x) / (2 * dt),
    (r2.y - r1.y) / (2 * dt),
    (r2.z - r1.z) / (2 * dt),
    time,
  );
}

/// Geocentric EQJ state of the Earth/Moon barycenter (`GeoEmbState`).
StateVector geoEmbState(AstroTime time) {
  final StateVector s = geoMoonState(time);
  const double d = 1.0 + _earthMoonMassRatio;
  return StateVector(
    s.x / d,
    s.y / d,
    s.z / d,
    s.vx / d,
    s.vy / d,
    s.vz / d,
    time,
  );
}

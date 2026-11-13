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

// Earth orientation and reference frames: nutation (IAU 2000B), obliquity,
// precession, sidereal time and rotation matrices
// (astronomy.ts 1387-1490, 1928-2232, 2980-3044, 6860-6910, 7012-7066,
// 7267-7460, 7720-7760).

enum _PrecessDirection { from2000, into2000 }

class _NutationAngles {
  _NutationAngles(this.dpsi, this.deps);

  final double dpsi;
  final double deps;
}

/// IAU 2000B nutation model (`iau2000b`). Angles in arcseconds.
_NutationAngles _iau2000b(AstroTime time) {
  double mod(double x) => _jsMod(x, _asec360) * _asec2Rad;

  final double t = time.tt / 36525;
  final double elp = mod(1287104.79305 + t * 129596581.0481);
  final double f = mod(335779.526232 + t * 1739527262.8478);
  final double d = mod(1072260.70369 + t * 1602961601.2090);
  final double om = mod(450160.398036 - t * 6962890.5431);

  double sarg = math.sin(om);
  double carg = math.cos(om);
  double dp = (-172064161.0 - 174666.0 * t) * sarg + 33386.0 * carg;
  double de = (92052331.0 + 9086.0 * t) * carg + 15377.0 * sarg;

  double arg = 2.0 * (f - d + om);
  sarg = math.sin(arg);
  carg = math.cos(arg);
  dp += (-13170906.0 - 1675.0 * t) * sarg - 13696.0 * carg;
  de += (5730336.0 - 3015.0 * t) * carg - 4587.0 * sarg;

  arg = 2.0 * (f + om);
  sarg = math.sin(arg);
  carg = math.cos(arg);
  dp += (-2276413.0 - 234.0 * t) * sarg + 2796.0 * carg;
  de += (978459.0 - 485.0 * t) * carg + 1374.0 * sarg;

  arg = 2.0 * om;
  sarg = math.sin(arg);
  carg = math.cos(arg);
  dp += (2074554.0 + 207.0 * t) * sarg - 698.0 * carg;
  de += (-897492.0 + 470.0 * t) * carg - 291.0 * sarg;

  sarg = math.sin(elp);
  carg = math.cos(elp);
  dp += (1475877.0 - 3633.0 * t) * sarg + 11817.0 * carg;
  de += (73871.0 - 184.0 * t) * carg - 1924.0 * sarg;

  return _NutationAngles(-0.000135 + (dp * 1.0e-7), 0.000388 + (de * 1.0e-7));
}

/// Mean obliquity of the ecliptic in degrees (`mean_obliq`).
double _meanObliq(AstroTime time) {
  final double t = time.tt / 36525;
  final double asec =
      ((((-0.0000000434 * t - 0.000000576) * t + 0.00200340) * t - 0.0001831) *
                      t -
                  46.836769) *
              t +
          84381.406;
  return asec / 3600.0;
}

/// Earth tilt: nutation angles and obliquity for one instant (`e_tilt`).
class EarthTiltInfo {
  EarthTiltInfo({
    required this.tt,
    required this.dpsi,
    required this.deps,
    required this.ee,
    required this.mobl,
    required this.tobl,
  });

  /// Terrestrial Time days since J2000.
  final double tt;

  /// Nutation in longitude, arcseconds.
  final double dpsi;

  /// Nutation in obliquity, arcseconds.
  final double deps;

  /// Equation of the equinoxes, in seconds of time.
  final double ee;

  /// Mean obliquity of the ecliptic, degrees.
  final double mobl;

  /// True obliquity of the ecliptic, degrees.
  final double tobl;
}

/// Nutation and obliquity for [time] (`e_tilt`).
///
/// TS keeps one global cache entry (reused within 1e-6 day); this port caches
/// the value inside the [AstroTime] object, as the C# and Python editions do.
EarthTiltInfo eTilt(AstroTime time) {
  final EarthTiltInfo? cached = time._etilt;
  if (cached != null) return cached;
  final _NutationAngles nut = _iau2000b(time);
  final double meanOb = _meanObliq(time);
  final double trueOb = meanOb + (nut.deps / 3600);
  final EarthTiltInfo et = EarthTiltInfo(
    tt: time.tt,
    dpsi: nut.dpsi,
    deps: nut.deps,
    ee: nut.dpsi * math.cos(meanOb * deg2Rad) / 15,
    mobl: meanOb,
    tobl: trueOb,
  );
  time._etilt = et;
  return et;
}

_ArrayVector _oblEcl2EquVec(double oblDegrees, _ArrayVector pos) {
  final double obl = oblDegrees * deg2Rad;
  final double cosObl = math.cos(obl);
  final double sinObl = math.sin(obl);
  return <double>[
    pos[0],
    pos[1] * cosObl - pos[2] * sinObl,
    pos[1] * sinObl + pos[2] * cosObl,
  ];
}

_ArrayVector _ecl2EquVec(AstroTime time, _ArrayVector pos) =>
    _oblEcl2EquVec(_meanObliq(time), pos);

_ArrayVector _rotate(RotationMatrix rotation, _ArrayVector vec) {
  final List<List<double>> rot = rotation.rot;
  return <double>[
    rot[0][0] * vec[0] + rot[1][0] * vec[1] + rot[2][0] * vec[2],
    rot[0][1] * vec[0] + rot[1][1] * vec[1] + rot[2][1] * vec[2],
    rot[0][2] * vec[0] + rot[1][2] * vec[1] + rot[2][2] * vec[2],
  ];
}

_ArrayVector _precession(
  _ArrayVector pos,
  AstroTime time,
  _PrecessDirection dir,
) =>
    _rotate(_precessionRot(time, dir), pos);

/// IAU 2006 precession matrix (`precession_rot`).
RotationMatrix _precessionRot(AstroTime time, _PrecessDirection dir) {
  final double t = time.tt / 36525;

  double eps0 = 84381.406;

  double psia =
      (((((-0.0000000951 * t + 0.000132851) * t - 0.00114045) * t - 1.0790069) *
                  t +
              5038.481507) *
          t);

  double omegaa =
      (((((0.0000003337 * t - 0.000000467) * t - 0.00772503) * t + 0.0512623) *
                      t -
                  0.025754) *
              t +
          eps0);

  double chia =
      (((((-0.0000000560 * t + 0.000170663) * t - 0.00121197) * t - 2.3814292) *
                  t +
              10.556403) *
          t);

  eps0 *= _asec2Rad;
  psia *= _asec2Rad;
  omegaa *= _asec2Rad;
  chia *= _asec2Rad;

  final double sa = math.sin(eps0);
  final double ca = math.cos(eps0);
  final double sb = math.sin(-psia);
  final double cb = math.cos(-psia);
  final double sc = math.sin(-omegaa);
  final double cc = math.cos(-omegaa);
  final double sd = math.sin(chia);
  final double cd = math.cos(chia);

  final double xx = cd * cb - sb * sd * cc;
  final double yx = cd * sb * ca + sd * cc * cb * ca - sa * sd * sc;
  final double zx = cd * sb * sa + sd * cc * cb * sa + ca * sd * sc;
  final double xy = -sd * cb - sb * cd * cc;
  final double yy = -sd * sb * ca + cd * cc * cb * ca - sa * cd * sc;
  final double zy = -sd * sb * sa + cd * cc * cb * sa + ca * cd * sc;
  final double xz = sb * sc;
  final double yz = -sc * cb * ca - sa * cc;
  final double zz = -sc * cb * sa + cc * ca;

  switch (dir) {
    case _PrecessDirection.into2000:
      // Perform rotation from epoch to J2000.0.
      return RotationMatrix(<List<double>>[
        <double>[xx, yx, zx],
        <double>[xy, yy, zy],
        <double>[xz, yz, zz],
      ]);
    case _PrecessDirection.from2000:
      // Perform rotation from J2000.0 to epoch.
      return RotationMatrix(<List<double>>[
        <double>[xx, xy, xz],
        <double>[yx, yy, yz],
        <double>[zx, zy, zz],
      ]);
  }
}

/// Earth Rotation Angle in degrees (`era`).
double _era(AstroTime time) {
  final double thet1 = 0.7790572732640 + 0.00273781191135448 * time.ut;
  final double thet3 = _jsMod(time.ut, 1);
  double theta = 360 * _jsMod(thet1 + thet3, 1);
  if (theta < 0) {
    theta += 360;
  }
  return theta;
}

/// Greenwich Apparent Sidereal Time in sidereal hours, [0, 24) (`sidereal_time`).
double _siderealTime(AstroTime time) {
  final double? cached = time._st;
  if (cached != null) return cached;
  final double t = time.tt / 36525;
  // Replace with eqeq=0 to get GMST instead of GAST (if we ever need it).
  final double eqeq = 15 * eTilt(time).ee;
  final double theta = _era(time);
  final double st = (eqeq +
      0.014506 +
      ((((-0.0000000368 * t - 0.000029956) * t - 0.00000044) * t + 1.3915817) *
                  t +
              4612.156534) *
          t);

  double gst = _jsMod(st / 3600 + theta, 360) / 15;
  if (gst < 0) {
    gst += 24;
  }
  time._st = gst;
  return gst;
}

/// Calculates Greenwich Apparent Sidereal Time (GAST) in sidereal hours,
/// in the half-open range [0, 24). Multiply by 15 for degrees (`SiderealTime`).
double siderealTime(AstroTime time) => _siderealTime(time);

_ArrayVector _nutation(
  _ArrayVector pos,
  AstroTime time,
  _PrecessDirection dir,
) =>
    _rotate(_nutationRot(time, dir), pos);

/// Nutation rotation matrix (`nutation_rot`).
RotationMatrix _nutationRot(AstroTime time, _PrecessDirection dir) {
  final EarthTiltInfo tilt = eTilt(time);
  final double oblm = tilt.mobl * deg2Rad;
  final double oblt = tilt.tobl * deg2Rad;
  final double psi = tilt.dpsi * _asec2Rad;
  final double cobm = math.cos(oblm);
  final double sobm = math.sin(oblm);
  final double cobt = math.cos(oblt);
  final double sobt = math.sin(oblt);
  final double cpsi = math.cos(psi);
  final double spsi = math.sin(psi);

  final double xx = cpsi;
  final double yx = -spsi * cobm;
  final double zx = -spsi * sobm;
  final double xy = spsi * cobt;
  final double yy = cpsi * cobm * cobt + sobm * sobt;
  final double zy = cpsi * sobm * cobt - cobm * sobt;
  final double xz = spsi * sobt;
  final double yz = cpsi * cobm * sobt - sobm * cobt;
  final double zz = cpsi * sobm * sobt + cobm * cobt;

  switch (dir) {
    case _PrecessDirection.from2000:
      // convert J2000 to of-date
      return RotationMatrix(<List<double>>[
        <double>[xx, xy, xz],
        <double>[yx, yy, yz],
        <double>[zx, zy, zz],
      ]);
    case _PrecessDirection.into2000:
      // convert of-date to J2000
      return RotationMatrix(<List<double>>[
        <double>[xx, yx, zx],
        <double>[xy, yy, zy],
        <double>[xz, yz, zz],
      ]);
  }
}

/// Precession and nutation combined (`gyration`). The order depends on the
/// direction, because the two directions are mutual inverses.
_ArrayVector _gyration(
  _ArrayVector pos,
  AstroTime time,
  _PrecessDirection dir,
) =>
    (dir == _PrecessDirection.into2000)
        ? _precession(_nutation(pos, time, dir), time, dir)
        : _nutation(_precession(pos, time, dir), time, dir);

/// Rotates an equatorial vector into ecliptic coordinates using the given
/// obliquity cosine/sine (`RotateEquatorialToEcliptic`).
EclipticCoordinates _rotateEquatorialToEcliptic(
  Vector equ,
  double cosOb,
  double sinOb,
) {
  // Rotate equatorial vector to obtain ecliptic vector.
  final double ex = equ.x;
  final double ey = equ.y * cosOb + equ.z * sinOb;
  final double ez = -equ.y * sinOb + equ.z * cosOb;

  final double xyproj = _hypot2(ex, ey);
  double elon = 0;
  if (xyproj > 0) {
    elon = rad2Deg * math.atan2(ey, ex);
    if (elon < 0) elon += 360;
  }
  final double elat = rad2Deg * math.atan2(ez, xyproj);
  final Vector ecl = Vector(ex, ey, ez, equ.t);
  return EclipticCoordinates(ecl, elat, elon);
}

/// `Math.hypot(a, b)` for finite inputs.
double _hypot2(double a, double b) => math.sqrt(a * a + b * b);

/// Converts a J2000 mean equator (EQJ) vector to true ecliptic of date (ECT)
/// coordinates (`Ecliptic`).
EclipticCoordinates ecliptic(Vector eqj) {
  // Calculate nutation and obliquity for this time.
  // The nutation angles are cached in `time` and reused by `_nutation` below.
  final EarthTiltInfo et = eTilt(eqj.t);

  // Convert mean J2000 equator (EQJ) to true equator of date (EQD).
  final _ArrayVector eqjPos = <double>[eqj.x, eqj.y, eqj.z];
  final _ArrayVector meanPos = _precession(
    eqjPos,
    eqj.t,
    _PrecessDirection.from2000,
  );
  final _ArrayVector p = _nutation(meanPos, eqj.t, _PrecessDirection.from2000);
  final Vector eqd = Vector(p[0], p[1], p[2], eqj.t);

  // Rotate from EQD to true ecliptic of date (ECT).
  final double tobl = et.tobl * deg2Rad;
  return _rotateEquatorialToEcliptic(eqd, math.cos(tobl), math.sin(tobl));
}

/// Inverts a rotation matrix (`InverseRotation`).
RotationMatrix inverseRotation(RotationMatrix rotation) {
  final List<List<double>> r = rotation.rot;
  return RotationMatrix(<List<double>>[
    <double>[r[0][0], r[1][0], r[2][0]],
    <double>[r[0][1], r[1][1], r[2][1]],
    <double>[r[0][2], r[1][2], r[2][2]],
  ]);
}

/// Creates a rotation that applies [a] first, then [b] (`CombineRotation`).
RotationMatrix combineRotation(RotationMatrix a, RotationMatrix b) {
  // Matrix multiplication: c = b*a.
  final List<List<double>> ar = a.rot;
  final List<List<double>> br = b.rot;
  return RotationMatrix(<List<double>>[
    <double>[
      br[0][0] * ar[0][0] + br[1][0] * ar[0][1] + br[2][0] * ar[0][2],
      br[0][1] * ar[0][0] + br[1][1] * ar[0][1] + br[2][1] * ar[0][2],
      br[0][2] * ar[0][0] + br[1][2] * ar[0][1] + br[2][2] * ar[0][2],
    ],
    <double>[
      br[0][0] * ar[1][0] + br[1][0] * ar[1][1] + br[2][0] * ar[1][2],
      br[0][1] * ar[1][0] + br[1][1] * ar[1][1] + br[2][1] * ar[1][2],
      br[0][2] * ar[1][0] + br[1][2] * ar[1][1] + br[2][2] * ar[1][2],
    ],
    <double>[
      br[0][0] * ar[2][0] + br[1][0] * ar[2][1] + br[2][0] * ar[2][2],
      br[0][1] * ar[2][0] + br[1][1] * ar[2][1] + br[2][1] * ar[2][2],
      br[0][2] * ar[2][0] + br[1][2] * ar[2][1] + br[2][2] * ar[2][2],
    ],
  ]);
}

/// Applies a rotation to a vector (`RotateVector`).
Vector rotateVector(RotationMatrix rotation, Vector vector) {
  final List<List<double>> r = rotation.rot;
  return Vector(
    r[0][0] * vector.x + r[1][0] * vector.y + r[2][0] * vector.z,
    r[0][1] * vector.x + r[1][1] * vector.y + r[2][1] * vector.z,
    r[0][2] * vector.x + r[1][2] * vector.y + r[2][2] * vector.z,
    vector.t,
  );
}

/// Applies a rotation to a state vector (`RotateState`).
StateVector rotateState(RotationMatrix rotation, StateVector state) {
  final List<List<double>> r = rotation.rot;
  return StateVector(
    r[0][0] * state.x + r[1][0] * state.y + r[2][0] * state.z,
    r[0][1] * state.x + r[1][1] * state.y + r[2][1] * state.z,
    r[0][2] * state.x + r[1][2] * state.y + r[2][2] * state.z,
    r[0][0] * state.vx + r[1][0] * state.vy + r[2][0] * state.vz,
    r[0][1] * state.vx + r[1][1] * state.vy + r[2][1] * state.vz,
    r[0][2] * state.vx + r[1][2] * state.vy + r[2][2] * state.vz,
    state.t,
  );
}

/// J2000 mean equator (EQJ) to true equator of date (EQD) (`Rotation_EQJ_EQD`).
RotationMatrix rotationEqjEqd(AstroTime time) {
  final RotationMatrix prec = _precessionRot(time, _PrecessDirection.from2000);
  final RotationMatrix nut = _nutationRot(time, _PrecessDirection.from2000);
  return combineRotation(prec, nut);
}

/// True equator of date (EQD) to J2000 mean equator (EQJ) (`Rotation_EQD_EQJ`).
RotationMatrix rotationEqdEqj(AstroTime time) {
  final RotationMatrix nut = _nutationRot(time, _PrecessDirection.into2000);
  final RotationMatrix prec = _precessionRot(time, _PrecessDirection.into2000);
  return combineRotation(nut, prec);
}

/// True equator of date (EQD) to true ecliptic of date (ECT) (`Rotation_EQD_ECT`).
RotationMatrix rotationEqdEct(AstroTime time) {
  final EarthTiltInfo et = eTilt(time);
  final double tobl = et.tobl * deg2Rad;
  final double c = math.cos(tobl);
  final double s = math.sin(tobl);
  return RotationMatrix(<List<double>>[
    <double>[1.0, 0.0, 0.0],
    <double>[0.0, c, -s],
    <double>[0.0, s, c],
  ]);
}

/// True ecliptic of date (ECT) to true equator of date (EQD) (`Rotation_ECT_EQD`).
RotationMatrix rotationEctEqd(AstroTime time) {
  final EarthTiltInfo et = eTilt(time);
  final double tobl = et.tobl * deg2Rad;
  final double c = math.cos(tobl);
  final double s = math.sin(tobl);
  return RotationMatrix(<List<double>>[
    <double>[1.0, 0.0, 0.0],
    <double>[0.0, c, s],
    <double>[0.0, -s, c],
  ]);
}

/// J2000 mean equator (EQJ) to true ecliptic of date (ECT) (`Rotation_EQJ_ECT`).
RotationMatrix rotationEqjEct(AstroTime time) {
  final RotationMatrix rot = rotationEqjEqd(time);
  final RotationMatrix step = rotationEqdEct(time);
  return combineRotation(rot, step);
}

/// True ecliptic of date (ECT) to J2000 mean equator (EQJ) (`Rotation_ECT_EQJ`).
RotationMatrix rotationEctEqj(AstroTime time) {
  final RotationMatrix rot = rotationEctEqd(time);
  final RotationMatrix step = rotationEqdEqj(time);
  return combineRotation(rot, step);
}

/// Converts spherical coordinates to a Cartesian vector (`VectorFromSphere`).
Vector vectorFromSphere(Spherical sphere, AstroTime time) {
  final double radlat = sphere.lat * deg2Rad;
  final double radlon = sphere.lon * deg2Rad;
  final double rcoslat = sphere.dist * math.cos(radlat);
  return Vector(
    rcoslat * math.cos(radlon),
    rcoslat * math.sin(radlon),
    sphere.dist * math.sin(radlat),
    time,
  );
}

/// Converts a Cartesian vector to spherical coordinates (`SphereFromVector`).
Spherical sphereFromVector(Vector vector) {
  final double xyproj = vector.x * vector.x + vector.y * vector.y;
  final double dist = math.sqrt(xyproj + vector.z * vector.z);
  double lat, lon;
  if (xyproj == 0.0) {
    if (vector.z == 0.0) {
      throw ArgumentError('Zero-length vector not allowed.');
    }
    lon = 0.0;
    lat = (vector.z < 0.0) ? -90.0 : 90.0;
  } else {
    lon = rad2Deg * math.atan2(vector.y, vector.x);
    if (lon < 0.0) lon += 360.0;
    lat = rad2Deg * math.atan2(vector.z, math.sqrt(xyproj));
  }
  return Spherical(lat, lon, dist);
}

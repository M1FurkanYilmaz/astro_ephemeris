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

// Body positions: HelioVector, HelioDistance, CorrectLightTravel,
// BackdatePosition, GeoVector, SunPosition (astronomy.ts 2735-2770,
// 4069-4354).

/// Heliocentric position of [body] as a J2000 mean equator (EQJ) vector, in
/// AU, not corrected for light travel time (`HelioVector`).
Vector helioVector(Body body, AstroTime time) {
  final _VsopModel? model = _vsopModel(body);
  if (model != null) return _calcVsop(model, time);
  switch (body) {
    case Body.pluto:
      final StateVector p = _calcPluto(time, true);
      return Vector(p.x, p.y, p.z, time);
    case Body.sun:
      return Vector(0, 0, 0, time);
    case Body.moon:
      final Vector e = _calcVsop(vsopEarth, time);
      final Vector m = geoMoon(time);
      return Vector(e.x + m.x, e.y + m.y, e.z + m.z, time);
    case Body.emb:
      final Vector e = _calcVsop(vsopEarth, time);
      final Vector m = geoMoon(time);
      const double denom = 1.0 + _earthMoonMassRatio;
      return Vector(
        e.x + (m.x / denom),
        e.y + (m.y / denom),
        e.z + (m.z / denom),
        time,
      );
    case Body.ssb:
      return _calcSolarSystemBarycenter(time);
    default:
      throw ArgumentError('HelioVector: Unknown body "$body"');
  }
}

/// Distance in AU between [body] and the Sun's center (`HelioDistance`).
double helioDistance(Body body, AstroTime time) {
  final _VsopModel? model = _vsopModel(body);
  if (model != null) {
    return _vsopFormula(model[_radIndex], time.tt / _daysPerMillennium, false);
  }
  return helioVector(body, time).length();
}

/// Solves for light travel time: returns `func` evaluated at the time light
/// left the object so as to arrive at the observer at [time]
/// (`CorrectLightTravel`). The returned vector's `t` is that backdated time.
Vector correctLightTravel(Vector Function(AstroTime t) func, AstroTime time) {
  AstroTime ltime = time;
  double dt = 0;
  for (int iter = 0; iter < 10; ++iter) {
    final Vector pos = func(ltime);
    final double lt = pos.length() / cAuDay;

    // This solver does not support more than one light-day of distance,
    // because that would cause convergence problems and inaccurate
    // values for stellar aberration angles.
    if (lt > 1.0) {
      throw StateError('Object is too distant for light-travel solver.');
    }

    final AstroTime ltime2 = time.addDays(-lt);
    dt = (ltime2.tt - ltime.tt).abs();
    if (dt < 1.0e-9) {
      // 86.4 microseconds
      return pos;
    }
    ltime = ltime2;
  }
  throw StateError('Light-travel time solver did not converge: dt = $dt');
}

/// `BodyPosition` helper class of BackdatePosition.
class _BodyPosition {
  _BodyPosition(
    this.observerBody,
    this.targetBody,
    this.aberration,
    this.observerPos,
  );

  final Body observerBody;
  final Body targetBody;
  final bool aberration;
  Vector observerPos;

  Vector position(AstroTime time) {
    if (aberration) {
      // To include aberration, make a good first-order approximation
      // by backdating the Earth's position also.
      // This works for objects within the Solar System because the distance
      // the Earth moves in that small amount of light travel time (a few
      // minutes to a few hours) is well approximated by a line segment that
      // subtends the angle seen from the remote body viewing Earth. That angle
      // is pretty close to the aberration angle of the moving Earth viewing
      // the remote body. Both of the following approximate the aberration angle:
      //     (transverse distance Earth moves) / (distance to body)
      //     (transverse speed of Earth) / (speed of light).
      observerPos = helioVector(observerBody, time);
    } else {
      // No aberration, so use the pre-calculated initial position of
      // the observer body that is already stored in `observerPos`.
    }
    final Vector targetPos = helioVector(targetBody, time);
    return Vector(
      targetPos.x - observerPos.x,
      targetPos.y - observerPos.y,
      targetPos.z - observerPos.z,
      time,
    );
  }
}

/// Position of [targetBody] seen from [observerBody], backdated for light
/// travel time, as an EQJ vector (`BackdatePosition`). The vector's `t` is
/// the backdated time. User-defined stars are not supported in this port.
Vector backdatePosition(
  AstroTime time,
  Body observerBody,
  Body targetBody,
  bool aberration,
) {
  final Vector observerPos;
  if (aberration) {
    // With aberration, `backdatePosition` will calculate `observerPos` at different times.
    // Therefore, do not waste time calculating it now.
    // Create a placeholder value that will be ignored.
    observerPos = Vector(0, 0, 0, time);
  } else {
    observerPos = helioVector(observerBody, time);
  }
  final _BodyPosition bpos = _BodyPosition(
    observerBody,
    targetBody,
    aberration,
    observerPos,
  );
  return correctLightTravel(bpos.position, time);
}

/// Geocentric position of [body] as a J2000 mean equator (EQJ) vector, in AU,
/// corrected for light travel time (and, if [aberration], for aberration)
/// (`GeoVector`). The Moon is returned without light-time correction, as in
/// Astronomy Engine. The returned vector's `t` is [time].
Vector geoVector(Body body, AstroTime time, bool aberration) {
  switch (body) {
    case Body.earth:
      return Vector(0, 0, 0, time);
    case Body.moon:
      return geoMoon(time);
    default:
      final Vector vec = backdatePosition(time, Body.earth, body, aberration);
      vec.t =
          time; // tricky: return the observation time, not the backdated time
      return vec;
  }
}

/// The Sun's apparent geocentric ecliptic position in the true equinox of
/// date (`SunPosition`), corrected for light travel time.
EclipticCoordinates sunPosition(AstroTime date) {
  // Correct for light travel time from the Sun.
  // This is really the same as correcting for aberration.
  // Otherwise season calculations (equinox, solstice) will all be early by about 8 minutes!
  final AstroTime time = date.addDays(-1 / cAuDay);

  // Get heliocentric cartesian coordinates of Earth in J2000.
  final Vector earth2000 = _calcVsop(vsopEarth, time);

  // Convert to geocentric location of the Sun.
  final _ArrayVector sun2000 = <double>[
    -earth2000.x,
    -earth2000.y,
    -earth2000.z,
  ];

  // Convert to equator-of-date equatorial cartesian coordinates.
  final _ArrayVector g = _gyration(sun2000, time, _PrecessDirection.from2000);

  // Convert to ecliptic coordinates of date.
  final double trueObliq = deg2Rad * eTilt(time).tobl;
  final double cosOb = math.cos(trueObliq);
  final double sinOb = math.sin(trueObliq);

  final Vector vec = Vector(g[0], g[1], g[2], time);
  final EclipticCoordinates sunEcliptic = _rotateEquatorialToEcliptic(
    vec,
    cosOb,
    sinOb,
  );
  return sunEcliptic;
}

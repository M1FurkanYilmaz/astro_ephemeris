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

// Bodies and vector/rotation types (astronomy.ts 293-317, 2250-2500, 3392-3477).

/// Solar System bodies supported by this port (the TS `Body` enum, without
/// user-defined stars).
enum Body {
  sun,
  moon,
  mercury,
  venus,
  earth,
  mars,
  jupiter,
  saturn,
  uranus,
  neptune,
  pluto,

  /// Solar System Barycenter.
  ssb,

  /// Earth/Moon Barycenter.
  emb,
}

/// Returns the product of mass and universal gravitational constant of a
/// Solar System body, in au^3/day^2 (`MassProduct`).
double massProduct(Body body) {
  switch (body) {
    case Body.sun:
      return _sunGm;
    case Body.mercury:
      return _mercuryGm;
    case Body.venus:
      return _venusGm;
    case Body.earth:
      return _earthGm;
    case Body.moon:
      return _moonGm;
    case Body.emb:
      return _earthGm + _moonGm;
    case Body.mars:
      return _marsGm;
    case Body.jupiter:
      return _jupiterGm;
    case Body.saturn:
      return _saturnGm;
    case Body.uranus:
      return _uranusGm;
    case Body.neptune:
      return _neptuneGm;
    case Body.pluto:
      return _plutoGm;
    case Body.ssb:
      throw ArgumentError('Do not know mass product for body: $body');
  }
}

/// A 3D Cartesian vector with a time attached to it.
///
/// Units are AU unless stated otherwise. [t] is the time at which the vector
/// is valid (`Vector`).
class Vector {
  Vector(this.x, this.y, this.z, this.t);

  double x;
  double y;
  double z;
  AstroTime t;

  /// The length of the vector (`Length`; `Math.hypot` in TS).
  double length() => math.sqrt(x * x + y * y + z * z);

  @override
  String toString() => 'Vector($x, $y, $z, $t)';
}

/// A combination of a position vector, a velocity vector and a time
/// (`StateVector`). Position in AU, velocity in AU/day.
class StateVector {
  StateVector(this.x, this.y, this.z, this.vx, this.vy, this.vz, this.t);

  double x;
  double y;
  double z;
  double vx;
  double vy;
  double vz;
  AstroTime t;

  @override
  String toString() => 'StateVector($x, $y, $z, $vx, $vy, $vz, $t)';
}

/// Spherical coordinates: [lat] and [lon] in degrees, [dist] in AU.
class Spherical {
  Spherical(this.lat, this.lon, this.dist) {
    _verifyNumber(lat);
    _verifyNumber(lon);
    _verifyNumber(dist);
  }

  final double lat;
  final double lon;
  final double dist;

  @override
  String toString() => 'Spherical(lat: $lat, lon: $lon, dist: $dist)';
}

/// Ecliptic angular and Cartesian coordinates (`EclipticCoordinates`).
///
/// [vec] is the ecliptic Cartesian vector, [elat] the latitude and [elon] the
/// longitude in degrees (0 <= elon < 360).
class EclipticCoordinates {
  EclipticCoordinates(this.vec, this.elat, this.elon) {
    _verifyNumber(elat);
    _verifyNumber(elon);
  }

  final Vector vec;
  final double elat;
  final double elon;

  @override
  String toString() => 'EclipticCoordinates(elat: $elat, elon: $elon)';
}

/// A 3x3 rotation matrix (`RotationMatrix`). The layout follows Astronomy
/// Engine: `rot[i][j]` multiplies vector component `i` into result `j`.
class RotationMatrix {
  RotationMatrix(this.rot);

  final List<List<double>> rot;
}

double _verifyNumber(double x) {
  if (!x.isFinite) {
    throw ArgumentError('Value is not a finite number: $x');
  }
  return x;
}

/// `ArrayVector` in TS: a 3-element list.
typedef _ArrayVector = List<double>;

Vector _vectorFromArray(_ArrayVector av, AstroTime time) =>
    Vector(av[0], av[1], av[2], time);

/// Lightweight mutable vector used by the VSOP and Pluto code (`TerseVector`).
class _TerseVector {
  _TerseVector(this.x, this.y, this.z);

  double x;
  double y;
  double z;

  _TerseVector clone() => _TerseVector(x, y, z);

  Vector toAstroVector(AstroTime t) => Vector(x, y, z, t);

  double quadrature() => x * x + y * y + z * z;

  _TerseVector add(_TerseVector other) =>
      _TerseVector(x + other.x, y + other.y, z + other.z);

  _TerseVector sub(_TerseVector other) =>
      _TerseVector(x - other.x, y - other.y, z - other.z);

  void incr(_TerseVector other) {
    x += other.x;
    y += other.y;
    z += other.z;
  }

  void decr(_TerseVector other) {
    x -= other.x;
    y -= other.y;
    z -= other.z;
  }

  _TerseVector mul(double scalar) =>
      _TerseVector(scalar * x, scalar * y, scalar * z);

  _TerseVector div(double scalar) =>
      _TerseVector(x / scalar, y / scalar, z / scalar);

  _TerseVector mean(_TerseVector other) =>
      _TerseVector((x + other.x) / 2, (y + other.y) / 2, (z + other.z) / 2);

  _TerseVector neg() => _TerseVector(-x, -y, -z);
}

/// `body_state_t`: position and velocity at a TT instant.
class _BodyState {
  _BodyState(this.tt, this.r, this.v);

  final double tt;
  _TerseVector r;
  _TerseVector v;

  _BodyState clone() => _BodyState(tt, r, v);

  _BodyState sub(_BodyState other) =>
      _BodyState(tt, r.sub(other.r), v.sub(other.v));
}

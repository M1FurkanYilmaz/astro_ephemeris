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

// VSOP87 planetary series (astronomy.ts 3188-3328).

/// `VsopModel`: [longitude, latitude, radius] -> series -> flat
/// `amplitude, phase, frequency` triples.
typedef _VsopModel = List<List<List<double>>>;

const int _lonIndex = 0;
const int _latIndex = 1;
const int _radIndex = 2;

_VsopModel? _vsopModel(Body body) {
  switch (body) {
    case Body.mercury:
      return vsopMercury;
    case Body.venus:
      return vsopVenus;
    case Body.earth:
      return vsopEarth;
    case Body.mars:
      return vsopMars;
    case Body.jupiter:
      return vsopJupiter;
    case Body.saturn:
      return vsopSaturn;
    case Body.uranus:
      return vsopUranus;
    case Body.neptune:
      return vsopNeptune;
    case Body.sun:
    case Body.moon:
    case Body.pluto:
    case Body.ssb:
    case Body.emb:
      return null;
  }
}

double _vsopFormula(List<List<double>> formula, double t, bool clampAngle) {
  double tpower = 1;
  double coord = 0;
  for (final List<double> series in formula) {
    double sum = 0;
    for (int i = 0; i < series.length; i += 3) {
      final double ampl = series[i];
      final double phas = series[i + 1];
      final double freq = series[i + 2];
      sum += ampl * math.cos(phas + (t * freq));
    }
    double incr = tpower * sum;
    if (clampAngle) {
      // improve precision for longitudes: they can be hundreds of radians
      incr = _jsMod(incr, _pi2);
    }
    coord += incr;
    tpower *= t;
  }
  return coord;
}

double _vsopDeriv(List<List<double>> formula, double t) {
  double tpower = 1; // t^s
  double dpower = 0; // t^(s-1)
  double deriv = 0;
  int s = 0;
  for (final List<double> series in formula) {
    double sinSum = 0;
    double cosSum = 0;
    for (int i = 0; i < series.length; i += 3) {
      final double ampl = series[i];
      final double phas = series[i + 1];
      final double freq = series[i + 2];
      final double angle = phas + (t * freq);
      sinSum += ampl * freq * math.sin(angle);
      if (s > 0) cosSum += ampl * math.cos(angle);
    }
    deriv += (s * dpower * cosSum) - (tpower * sinSum);
    dpower = tpower;
    tpower *= t;
    ++s;
  }
  return deriv;
}

/// Converts ecliptic (VSOP87 J2000 dynamical) Cartesian coordinates to
/// equatorial J2000 (EQJ) (`VsopRotate`).
_TerseVector _vsopRotate(_ArrayVector eclip) => _TerseVector(
      eclip[0] + 0.000000440360 * eclip[1] - 0.000000190919 * eclip[2],
      -0.000000479966 * eclip[0] +
          0.917482137087 * eclip[1] -
          0.397776982902 * eclip[2],
      0.397776982902 * eclip[1] + 0.917482137087 * eclip[2],
    );

_ArrayVector _vsopSphereToRect(double lon, double lat, double radius) {
  // Convert spherical coordinates to ecliptic cartesian coordinates.
  final double rCoslat = radius * math.cos(lat);
  final double coslon = math.cos(lon);
  final double sinlon = math.sin(lon);
  return <double>[rCoslat * coslon, rCoslat * sinlon, radius * math.sin(lat)];
}

/// Heliocentric EQJ position of a planet from its VSOP87 model (`CalcVsop`).
Vector _calcVsop(_VsopModel model, AstroTime time) {
  final double t = time.tt / _daysPerMillennium; // millennia since 2000
  final double lon = _vsopFormula(model[_lonIndex], t, true);
  final double lat = _vsopFormula(model[_latIndex], t, false);
  final double rad = _vsopFormula(model[_radIndex], t, false);
  final _ArrayVector eclip = _vsopSphereToRect(lon, lat, rad);
  return _vsopRotate(eclip).toAstroVector(time);
}

/// Heliocentric EQJ position and velocity from VSOP87 (`CalcVsopPosVel`).
_BodyState _calcVsopPosVel(_VsopModel model, double tt) {
  final double t = tt / _daysPerMillennium;

  // Calculate the VSOP "B" trigonometric series to obtain ecliptic spherical coordinates.
  final double lon = _vsopFormula(model[_lonIndex], t, true);
  final double lat = _vsopFormula(model[_latIndex], t, false);
  final double rad = _vsopFormula(model[_radIndex], t, false);

  final double dlonDt = _vsopDeriv(model[_lonIndex], t);
  final double dlatDt = _vsopDeriv(model[_latIndex], t);
  final double dradDt = _vsopDeriv(model[_radIndex], t);

  // Use spherical coords and spherical derivatives to calculate
  // the velocity vector in rectangular coordinates.
  final double coslon = math.cos(lon);
  final double sinlon = math.sin(lon);
  final double coslat = math.cos(lat);
  final double sinlat = math.sin(lat);

  final double vx = (dradDt * coslat * coslon) -
      (rad * sinlat * coslon * dlatDt) -
      (rad * coslat * sinlon * dlonDt);

  final double vy = (dradDt * coslat * sinlon) -
      (rad * sinlat * sinlon * dlatDt) +
      (rad * coslat * coslon * dlonDt);

  final double vz = (dradDt * sinlat) + (rad * coslat * dlatDt);

  final _ArrayVector eclipPos = _vsopSphereToRect(lon, lat, rad);

  // Convert speed units from [AU/millennium] to [AU/day].
  final _ArrayVector eclipVel = <double>[
    vx / _daysPerMillennium,
    vy / _daysPerMillennium,
    vz / _daysPerMillennium,
  ];

  // Rotate the vectors from ecliptic to equatorial coordinates.
  final _TerseVector equPos = _vsopRotate(eclipPos);
  final _TerseVector equVel = _vsopRotate(eclipVel);
  return _BodyState(tt, equPos, equVel);
}

void _adjustBarycenter(Vector ssb, AstroTime time, Body body, double pmass) {
  final double shift = pmass / (pmass + _sunGm);
  final Vector planet = _calcVsop(_vsopModel(body)!, time);
  ssb.x += shift * planet.x;
  ssb.y += shift * planet.y;
  ssb.z += shift * planet.z;
}

/// Heliocentric position of the Solar System Barycenter (`CalcSolarSystemBarycenter`).
Vector _calcSolarSystemBarycenter(AstroTime time) {
  final Vector ssb = Vector(0.0, 0.0, 0.0, time);
  _adjustBarycenter(ssb, time, Body.jupiter, _jupiterGm);
  _adjustBarycenter(ssb, time, Body.saturn, _saturnGm);
  _adjustBarycenter(ssb, time, Body.uranus, _uranusGm);
  _adjustBarycenter(ssb, time, Body.neptune, _neptuneGm);
  return ssb;
}

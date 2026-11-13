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

// Physical and numeric constants (astronomy.ts lines 42-178).

/// The speed of light in AU/day.
const double cAuDay = 173.1446326846693;

/// The number of kilometers per astronomical unit.
const double kmPerAu = 1.4959787069098932e+8;

/// The number of astronomical units per light-year.
const double auPerLy = 63241.07708807546;

/// The factor to convert degrees to radians.
const double deg2Rad = 0.017453292519943296;

/// The factor to convert sidereal hours to radians.
const double hour2Rad = 0.2617993877991494365;

/// The factor to convert radians to degrees.
const double rad2Deg = 57.295779513082321;

/// The factor to convert radians to sidereal hours.
const double rad2Hour = 3.819718634205488;

const double _daysPerTropicalYear = 365.24217;

/// 2 * pi.
const double _pi2 = 2 * math.pi;

/// Arcseconds per radian.
const double _arc = 3600 * (180 / math.pi);

const double _asec2Rad = 4.848136811095359935899141e-6;

/// Arcseconds per 180 degrees (or pi radians).
const double _asec180 = 180.0 * 60 * 60;

/// Arcseconds per 360 degrees (or 2*pi radians).
const double _asec360 = 2 * _asec180;

const double _earthEquatorialRadiusKm = 6378.1366;
const double _earthEquatorialRadiusAu = _earthEquatorialRadiusKm / kmPerAu;

const double _earthMoonMassRatio = 81.30056;

// Gravitational parameters G*M in au^3/day^2 (DE405, JPL memorandum page 10).
const double _sunGm = 0.2959122082855911e-03;
const double _mercuryGm = 0.4912547451450812e-10;
const double _venusGm = 0.7243452486162703e-09;
const double _earthGm = 0.8887692390113509e-09;
const double _marsGm = 0.9549535105779258e-10;
const double _jupiterGm = 0.2825345909524226e-06;
const double _saturnGm = 0.8459715185680659e-07;
const double _uranusGm = 0.1292024916781969e-07;
const double _neptuneGm = 0.1524358900784276e-07;
const double _plutoGm = 0.2188699765425970e-11;
const double _moonGm = _earthGm / _earthMoonMassRatio;

/// Days per Julian millennium, the VSOP87 time unit.
const double _daysPerMillennium = 365250;

/// `Frac(x)`: the fractional part of [x], always in [0, 1).
double _frac(double x) => x - x.floorToDouble();

/// JavaScript's `%` operator (truncated remainder, sign of the dividend).
///
/// Dart's `%` is Euclidean (never negative); `remainder` matches C `fmod`,
/// JavaScript `%` and Python `math.fmod`.
double _jsMod(double x, double y) => x.remainder(y);

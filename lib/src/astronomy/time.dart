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

// Time: DeltaT, TerrestrialTime, AstroTime, MakeTime (astronomy.ts 1098-1385).

/// Delta T = TT - UT in seconds, by the Espenak-Meeus polynomials
/// (https://eclipse.gsfc.nasa.gov/SEhelp/deltatpoly2004.html).
///
/// [ut] is Universal Time in days since the J2000 epoch.
double deltaTEspenakMeeus(double ut) {
  double u, u2, u3, u4, u5, u6, u7;

  // y = 2000 corresponds to the UTC date 15-January-2000.
  // Convert difference in days to mean tropical years.
  final double y = 2000 + ((ut - 14) / _daysPerTropicalYear);

  if (y < -500) {
    u = (y - 1820) / 100;
    return -20 + (32 * u * u);
  }
  if (y < 500) {
    u = y / 100;
    u2 = u * u;
    u3 = u * u2;
    u4 = u2 * u2;
    u5 = u2 * u3;
    u6 = u3 * u3;
    return 10583.6 -
        1014.41 * u +
        33.78311 * u2 -
        5.952053 * u3 -
        0.1798452 * u4 +
        0.022174192 * u5 +
        0.0090316521 * u6;
  }
  if (y < 1600) {
    u = (y - 1000) / 100;
    u2 = u * u;
    u3 = u * u2;
    u4 = u2 * u2;
    u5 = u2 * u3;
    u6 = u3 * u3;
    return 1574.2 -
        556.01 * u +
        71.23472 * u2 +
        0.319781 * u3 -
        0.8503463 * u4 -
        0.005050998 * u5 +
        0.0083572073 * u6;
  }
  if (y < 1700) {
    u = y - 1600;
    u2 = u * u;
    u3 = u * u2;
    return 120 - 0.9808 * u - 0.01532 * u2 + u3 / 7129.0;
  }
  if (y < 1800) {
    u = y - 1700;
    u2 = u * u;
    u3 = u * u2;
    u4 = u2 * u2;
    return 8.83 + 0.1603 * u - 0.0059285 * u2 + 0.00013336 * u3 - u4 / 1174000;
  }
  if (y < 1860) {
    u = y - 1800;
    u2 = u * u;
    u3 = u * u2;
    u4 = u2 * u2;
    u5 = u2 * u3;
    u6 = u3 * u3;
    u7 = u3 * u4;
    return 13.72 -
        0.332447 * u +
        0.0068612 * u2 +
        0.0041116 * u3 -
        0.00037436 * u4 +
        0.0000121272 * u5 -
        0.0000001699 * u6 +
        0.000000000875 * u7;
  }
  if (y < 1900) {
    u = y - 1860;
    u2 = u * u;
    u3 = u * u2;
    u4 = u2 * u2;
    u5 = u2 * u3;
    return 7.62 +
        0.5737 * u -
        0.251754 * u2 +
        0.01680668 * u3 -
        0.0004473624 * u4 +
        u5 / 233174;
  }
  if (y < 1920) {
    u = y - 1900;
    u2 = u * u;
    u3 = u * u2;
    u4 = u2 * u2;
    return -2.79 +
        1.494119 * u -
        0.0598939 * u2 +
        0.0061966 * u3 -
        0.000197 * u4;
  }
  if (y < 1941) {
    u = y - 1920;
    u2 = u * u;
    u3 = u * u2;
    return 21.20 + 0.84493 * u - 0.076100 * u2 + 0.0020936 * u3;
  }
  if (y < 1961) {
    u = y - 1950;
    u2 = u * u;
    u3 = u * u2;
    return 29.07 + 0.407 * u - u2 / 233 + u3 / 2547;
  }
  if (y < 1986) {
    u = y - 1975;
    u2 = u * u;
    u3 = u * u2;
    return 45.45 + 1.067 * u - u2 / 260 - u3 / 718;
  }
  if (y < 2005) {
    u = y - 2000;
    u2 = u * u;
    u3 = u * u2;
    u4 = u2 * u2;
    u5 = u2 * u3;
    return 63.86 +
        0.3345 * u -
        0.060374 * u2 +
        0.0017275 * u3 +
        0.000651814 * u4 +
        0.00002373599 * u5;
  }
  if (y < 2050) {
    u = y - 2000;
    return 62.92 + 0.32217 * u + 0.005589 * u * u;
  }
  if (y < 2150) {
    u = (y - 1820) / 100;
    return -20 + 32 * u * u - 0.5628 * (2150 - y);
  }

  // all years after 2150
  u = (y - 1820) / 100;
  return -20 + (32 * u * u);
}

/// A function that returns Delta T (seconds) for a UT day value.
typedef DeltaTimeFunction = double Function(double ut);

/// Delta T as JPL Horizons models it: Espenak-Meeus frozen after 2017.
double deltaTJplHorizons(double ut) =>
    deltaTEspenakMeeus(math.min(ut, 17.0 * _daysPerTropicalYear));

DeltaTimeFunction _deltaT = deltaTEspenakMeeus;

/// Replaces the Delta T model (default: [deltaTEspenakMeeus]).
///
/// The setting is per isolate. [AstroTime] objects created before the change
/// keep the TT they were constructed with.
void setDeltaTFunction(DeltaTimeFunction func) {
  _deltaT = func;
}

/// Terrestrial Time (days since J2000 TT) from Universal Time (days since J2000 UT).
double _terrestrialTime(double ut) => ut + _deltaT(ut) / 86400;

/// The J2000 epoch, 2000-01-01T12:00:00Z, in microseconds since the Unix epoch.
const int _j2000Micros = 946728000000000;

const double _microsPerDay = 86400.0 * 1000000;

/// The date and time of an astronomical observation.
///
/// [ut] is Universal Time (UT1/UTC, treated as the same) in fractional days
/// since the J2000 epoch (noon UTC on 2000-01-01). [tt] is Terrestrial Time in
/// days since J2000, derived from [ut] with the active Delta T model.
///
/// Like the C#/Python editions of Astronomy Engine, an `AstroTime` lazily caches
/// its Earth-tilt (nutation/obliquity) values and its sidereal time, so passing
/// one object to several calls avoids recomputation. The cache is per object,
/// which keeps it safe across isolates and free of shared mutable state.
class AstroTime {
  /// Creates a time from Universal Time days since J2000 (`new AstroTime(ut)`).
  AstroTime(this.ut) : tt = _terrestrialTime(ut);

  /// Creates a time from a [DateTime]; local times are converted to UTC.
  ///
  /// Full microsecond resolution is kept (JavaScript `Date` only has
  /// milliseconds; for whole milliseconds the result is bit-identical).
  factory AstroTime.fromDateTime(DateTime date) {
    final int micros = date.toUtc().microsecondsSinceEpoch - _j2000Micros;
    return AstroTime(micros / _microsPerDay);
  }

  /// Creates a time from a Julian Date expressed in Universal Time.
  factory AstroTime.fromJulianDayUt(double jdUt) => AstroTime(jdUt - 2451545.0);

  /// Creates a time from a Terrestrial Time day value (`FromTerrestrialTime`).
  factory AstroTime.fromTerrestrialTime(double tt) {
    AstroTime time = AstroTime(tt);
    for (;;) {
      final double err = tt - time.tt;
      if (err.abs() < 1.0e-12) return time;
      time = time.addDays(err);
    }
  }

  /// Universal Time in days since J2000.
  final double ut;

  /// Terrestrial Time in days since J2000.
  final double tt;

  EarthTiltInfo? _etilt;
  double? _st;

  /// The Julian Date in Universal Time.
  double get julianDayUt => ut + 2451545.0;

  /// The UTC [DateTime] for [ut], rounded to the microsecond.
  DateTime get date => DateTime.fromMicrosecondsSinceEpoch(
        _j2000Micros + (ut * _microsPerDay).round(),
        isUtc: true,
      );

  /// Returns a new time [days] later (UT is adjusted; TT is recomputed).
  AstroTime addDays(double days) => AstroTime(ut + days);

  @override
  String toString() => date.toIso8601String();
}

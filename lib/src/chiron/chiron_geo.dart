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
// Follows the geocentric position and aberration pipeline of Astronomy Engine v2.1.19 (commit 03084ee),
// https://github.com/cosinekitty/astronomy
// on top of the Dart port in ../astronomy/.

/// Geocentric apparent Chiron in the true ecliptic and equinox of date,
/// computed exactly like Astronomy Engine computes a planet:
/// `Ecliptic(GeoVector(body, t, aberration: true))`, with Chiron's
/// heliocentric position taken from the JPL Horizons table ([chironHelioEqj])
/// and the Earth from the Astronomy Engine port.
///
/// * Light time: [ae.correctLightTravel] back-dates Chiron AND the Earth
///   (Astronomy Engine's first-order aberration, `BackdatePosition` with
///   aberration = true).
/// * Frame: EQJ -> true ecliptic of date via [ae.ecliptic] (IAU 2006
///   precession + IAU 2000B nutation).
/// * Not modelled (as in Astronomy Engine): gravitational deflection by the
///   Sun (< 0.3" except within a few degrees of the Sun).
/// * Distance: the light-time (true) distance, Earth at t, Chiron at t - tau,
///   no aberration, as the ephemeris facade does for the planets.
/// * Speed: central difference of the longitude over +-0.01 day.
///
/// Measured against JPL Horizons apparent positions (every 37 days,
/// 1900-2100, observed Delta T): see README.md and test/chiron/.
///
/// Call `installEphemerisDeltaT()` (ephemeris.dart) before building the
/// [ae.AstroTime] so Delta T matches the rest of the package.
library;

import '../astronomy/astronomy.dart' as ae;
import 'chiron.dart';

/// Geocentric apparent ecliptic-of-date position of Chiron.
class ChironGeoEcliptic {
  const ChironGeoEcliptic({
    required this.lon,
    required this.lat,
    required this.distAu,
    required this.lonSpeedDegPerDay,
  });

  /// Ecliptic longitude, degrees [0, 360), true equinox of date.
  final double lon;

  /// Ecliptic latitude, degrees.
  final double lat;

  /// Light-time corrected geocentric distance, AU.
  final double distAu;

  /// d(lon)/dt, degrees per day (negative = retrograde).
  final double lonSpeedDegPerDay;

  @override
  String toString() => 'ChironGeoEcliptic(lon: $lon, lat: $lat, '
      'dist: $distAu, speed: $lonSpeedDegPerDay)';
}

/// Half-width of the longitude-speed central difference, days (same as the
/// ephemeris facade uses for the planets).
const double _speedStep = 0.01;

const double _jdJ2000 = 2451545.0;

ae.Vector _chironHelio(ae.AstroTime t) {
  // TT is used as TDB (|TDB - TT| < 2 ms, < 1e-10 AU for Chiron).
  final ChironStateHelio s = chironHelioEqj(t.tt + _jdJ2000);
  return ae.Vector(s.x, s.y, s.z, t);
}

/// Mirror of `GeoVector(body, time, aberration)` for Chiron. The returned
/// vector carries the observation time [t] (as upstream GeoVector does).
ae.Vector chironGeoVector(ae.AstroTime t, {required bool aberration}) {
  ae.Vector observer = ae.helioVector(ae.Body.earth, t);
  final ae.Vector v = ae.correctLightTravel((ae.AstroTime lt) {
    if (aberration) observer = ae.helioVector(ae.Body.earth, lt);
    final ae.Vector c = _chironHelio(lt);
    return ae.Vector(c.x - observer.x, c.y - observer.y, c.z - observer.z, lt);
  }, t);
  return ae.Vector(v.x, v.y, v.z, t);
}

double _apparentLon(ae.AstroTime t) =>
    ae.ecliptic(chironGeoVector(t, aberration: true)).elon;

/// Geocentric apparent Chiron at [t]: longitude/latitude in the true
/// ecliptic and equinox of date, light-time distance, longitude speed.
///
/// Throws [RangeError] when the back-dated instants leave the table
/// (1800-01-01 .. 2201-08-15 TDB; in practice keep t at least one day
/// inside that range).
ChironGeoEcliptic chironGeoEclipticOfDate(ae.AstroTime t) {
  final ae.EclipticCoordinates e = ae.ecliptic(
    chironGeoVector(t, aberration: true),
  );
  final double dist = chironGeoVector(t, aberration: false).length();
  final double lo = _apparentLon(t.addDays(-_speedStep));
  final double hi = _apparentLon(t.addDays(_speedStep));
  double d = hi - lo;
  if (d > 180.0) d -= 360.0;
  if (d < -180.0) d += 360.0;
  return ChironGeoEcliptic(
    lon: e.elon,
    lat: e.elat,
    distAu: dist,
    lonSpeedDegPerDay: d / (2.0 * _speedStep),
  );
}

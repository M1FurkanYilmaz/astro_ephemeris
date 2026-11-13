/// Astrology-facing ephemeris: the public API. Pure Dart on top of the Astronomy Engine port
/// (`astronomy/astronomy.dart`); no Flutter imports, usable in isolates.
///
/// All positions are geocentric, apparent, in the true ecliptic and equinox of
/// date (the frame astrology software normally uses):
/// longitude 0..360°, latitude in degrees, distance in AU, longitude speed in
/// degrees per day. Times are Julian Days in UT ([julianDayUt]).
///
/// Delta T (TT − UT1) comes from observed USNO/IERS values
/// ([deltaTModelSeconds]); it is installed into Astronomy Engine on first use.
/// Accuracy against JPL Horizons and every known residual are documented in
/// the package `README.md` and pinned by `test/horizons/`.
library;

import 'dart:math' as math;
import 'dart:typed_data';

import 'astronomy/astronomy.dart' as ae;
import 'chiron/chiron_geo.dart' as chiron;
import 'delta_t_table.dart';
import 'houses/houses.dart';

export 'houses/houses.dart' show HouseCusps, HouseSystem;

part 'delta_t.dart';
part 'lunar_points.dart';

const double _d2r = math.pi / 180.0;
const double _r2d = 180.0 / math.pi;

/// Julian Day of the Unix epoch (1970-01-01T00:00Z).
const double _jdUnixEpoch = 2440587.5;

/// Julian Day of J2000 (2000-01-01T12:00Z).
const double _jdJ2000 = 2451545.0;

/// Bodies and points. [id] is the numbering common in astrology software;
/// these integers are stable. The south node has no id: derive it as [trueNode] + 180°.
enum Body {
  sun(0),
  moon(1),
  mercury(2),
  venus(3),
  mars(4),
  jupiter(5),
  saturn(6),
  uranus(7),
  neptune(8),
  pluto(9),
  meanNode(10),
  trueNode(11),

  /// Mean lunar apogee, "Black Moon Lilith".
  meanApogee(12),
  chiron(15);

  const Body(this.id);

  /// Stable integer id (Sun = 0 ... Pluto = 9, nodes 10-11, Lilith 12, Chiron 15).
  final int id;

  /// The body with persisted id [id], or null if there is none.
  static Body? fromId(int id) {
    for (final Body b in Body.values) {
      if (b.id == id) return b;
    }
    return null;
  }
}

/// A body's geocentric apparent position, true ecliptic and equinox of date.
class BodyPosition {
  const BodyPosition({
    required this.longitude,
    required this.latitude,
    required this.distance,
    required this.speedLongitude,
  });

  /// Ecliptic longitude, degrees, [0, 360).
  final double longitude;

  /// Ecliptic latitude, degrees.
  final double latitude;

  /// Distance from the Earth's centre, AU (see README for the conventions of
  /// the lunar points).
  final double distance;

  /// Rate of change of [longitude], degrees per day (negative = retrograde).
  final double speedLongitude;

  /// True when the longitude is decreasing.
  bool get isRetrograde => speedLongitude < 0;

  @override
  String toString() =>
      'BodyPosition(lon: $longitude, lat: $latitude, dist: $distance, '
      'speed: $speedLongitude)';
}

/// Signature of an external body provider (used for Chiron).
typedef BodyPositionProvider = BodyPosition Function(double jdUt);

/// Override for Chiron (tests). Null = the built-in Chiron module
/// (`chiron/`: JPL Horizons Chebyshev table 1800-2201, apparent geocentric,
/// see tool/chiron/README.md). Outside the table [position] throws a
/// [RangeError] for [Body.chiron].
BodyPositionProvider? chironProvider;

BodyPosition _builtInChiron(double jdUt) {
  final chiron.ChironGeoEcliptic c = chiron.chironGeoEclipticOfDate(
    _time(jdUt),
  );
  return BodyPosition(
    longitude: c.lon,
    latitude: c.lat,
    distance: c.distAu,
    speedLongitude: c.lonSpeedDegPerDay,
  );
}

/// Julian Day (UT) of a [DateTime]; local times are converted to UTC.
/// (A double Julian Day near the present resolves about 40 microseconds.)
double julianDayUt(DateTime dateTime) =>
    dateTime.toUtc().microsecondsSinceEpoch / 86400000000.0 + _jdUnixEpoch;

/// UTC [DateTime] for a Julian Day in UT, rounded to the microsecond.
DateTime dateTimeFromJulianDayUt(double jdUt) =>
    DateTime.fromMicrosecondsSinceEpoch(
      ((jdUt - _jdUnixEpoch) * 86400000000.0).round(),
      isUtc: true,
    );

ae.AstroTime _time(double jdUt) {
  installEphemerisDeltaT();
  return ae.AstroTime(jdUt - _jdJ2000);
}

/// Delta T = TT − UT1 in seconds at [jdUt] (see [deltaTModelSeconds]).
double deltaTSeconds(double jdUt) => deltaTModelSeconds(jdUt - _jdJ2000);

/// Greenwich apparent sidereal time, hours [0, 24): IAU 2006 GMST (Earth
/// rotation angle + precession polynomial) plus the equation of the equinoxes
/// from IAU 2000B nutation.
double gastHours(double jdUt) => ae.siderealTime(_time(jdUt));

/// True obliquity of the ecliptic (mean IAU 2006 + nutation), degrees.
double trueObliquity(double jdUt) => ae.eTilt(_time(jdUt)).tobl;

/// Mean obliquity of the ecliptic (IAU 2006), degrees.
double meanObliquity(double jdUt) => ae.eTilt(_time(jdUt)).mobl;

/// Nutation in longitude (IAU 2000B), degrees.
double nutationLongitude(double jdUt) => ae.eTilt(_time(jdUt)).dpsi / 3600.0;

/// Nutation in obliquity (IAU 2000B), degrees.
double nutationObliquity(double jdUt) => ae.eTilt(_time(jdUt)).deps / 3600.0;

/// Equation of time E = local apparent solar time − local mean solar time, in
/// days, for the UT instant [jdUt] (E is
/// about +16 minutes in early November). Computed as the Greenwich hour angle
/// of the apparent Sun minus that of the mean Sun (UT1 − 12 h).
double equationOfTimeDays(double jdUt) {
  final ae.AstroTime t = _time(jdUt);
  final ae.Vector eqj = ae.geoVector(ae.Body.sun, t, true);
  final ae.Vector eqd = ae.rotateVector(ae.rotationEqjEqd(t), eqj);
  final double raHours = math.atan2(eqd.y, eqd.x) * _r2d / 15.0;
  final double ut = jdUt - _jdJ2000; // days since J2000 noon = UT − 12 h
  final double meanHourAngle = (ut - ut.floorToDouble()) * 24.0;
  double e = ae.siderealTime(t) - raHours - meanHourAngle; // hours
  e = e - 24.0 * (e / 24.0).roundToDouble();
  return e / 24.0;
}

/// House cusps for the UT instant [jdUt] at geographic latitude [latDeg]
/// (north +) and longitude [lonDeg] (east +): ARMC = GAST·15° + longitude,
/// true obliquity of date (see houses/houses.dart for systems and the polar
/// fallback).
HouseCusps houses(
  double jdUt,
  double latDeg,
  double lonDeg,
  HouseSystem system,
) {
  final ae.AstroTime t = _time(jdUt);
  return computeHouses(
    armcDeg: armcFromGast(gastHours: ae.siderealTime(t), lonEastDeg: lonDeg),
    latDeg: latDeg,
    trueObliquityDeg: ae.eTilt(t).tobl,
    system: system,
  );
}

/// Half-width of the central difference used for the longitude speed, days.
double _speedStep(Body body) {
  switch (body) {
    case Body.moon:
    case Body.trueNode:
      return 1.0 / 1440.0; // 1 minute
    case Body.meanNode:
    case Body.meanApogee:
      return 0.05;
    default:
      return 0.01;
  }
}

/// Position of [body] at [t]. [withDistance] = false skips work that only the
/// distance needs (used for the speed samples).
_LonLatDist _raw(Body body, ae.AstroTime t, {bool withDistance = true}) {
  switch (body) {
    case Body.moon:
      // Astronomy Engine's Moon is geometric. The apparent geocentric Moon is
      // the geometric one at t - tau (tau = light time, ~1.3 s, ~0.7"): the
      // annual aberration and the Earth's barycentric motion during tau cancel
      // for a geocentric body, leaving only the relative light time.
      final ae.Spherical g = ae.eclipticGeoMoon(t);
      final ae.Spherical m = ae.eclipticGeoMoon(t.addDays(-g.dist / ae.cAuDay));
      return _LonLatDist(m.lon, m.lat, g.dist);
    case Body.meanNode:
      return _meanNode(t);
    case Body.trueNode:
      return _trueNode(t);
    case Body.meanApogee:
      return _meanApogee(t);
    case Body.chiron:
      throw StateError('unreachable');
    default:
      final ae.Body b = _aeBody(body);
      final ae.EclipticCoordinates e = ae.ecliptic(ae.geoVector(b, t, true));
      // Distance: the light-time (true) distance. The aberration shift that
      // geoVector adds to the vector (v_earth * tau) is a change of direction,
      // not of distance, but it lengthens the vector by up to 1e-4 relative.
      final double dist =
          withDistance ? ae.geoVector(b, t, false).length() : double.nan;
      return _LonLatDist(e.elon, e.elat, dist);
  }
}

ae.Body _aeBody(Body body) {
  switch (body) {
    case Body.sun:
      return ae.Body.sun;
    case Body.moon:
      return ae.Body.moon;
    case Body.mercury:
      return ae.Body.mercury;
    case Body.venus:
      return ae.Body.venus;
    case Body.mars:
      return ae.Body.mars;
    case Body.jupiter:
      return ae.Body.jupiter;
    case Body.saturn:
      return ae.Body.saturn;
    case Body.uranus:
      return ae.Body.uranus;
    case Body.neptune:
      return ae.Body.neptune;
    case Body.pluto:
      return ae.Body.pluto;
    default:
      throw ArgumentError.value(body, 'body', 'not an Astronomy Engine body');
  }
}

/// Signed difference a − b of two angles in degrees, in (−180, 180].
double _angleDiff(double a, double b) {
  double d = (a - b) % 360.0;
  if (d > 180.0) d -= 360.0;
  return d;
}

/// Geocentric apparent position of [body] at [jdUt] (Julian Day, UT): true
/// ecliptic and equinox of date, with the longitude speed from a central
/// difference of the same function.
BodyPosition position(Body body, double jdUt) {
  if (body == Body.chiron) {
    return (chironProvider ?? _builtInChiron)(jdUt);
  }
  final ae.AstroTime t = _time(jdUt);
  final _LonLatDist here = _raw(body, t);
  final double h = _speedStep(body);
  final double plus = _raw(body, t.addDays(h), withDistance: false).lon;
  final double minus = _raw(body, t.addDays(-h), withDistance: false).lon;
  return BodyPosition(
    longitude: here.lon,
    latitude: here.lat,
    distance: here.dist,
    speedLongitude: _angleDiff(plus, minus) / (2 * h),
  );
}

/// Longitude only: the same value as `position(body, jdUt).longitude`, about
/// three times cheaper (no speed samples, no distance). For searches that
/// evaluate many instants (lunations, eclipses' points, year scans).
double eclipticLongitude(Body body, double jdUt) {
  if (body == Body.chiron) return position(body, jdUt).longitude;
  return _raw(body, _time(jdUt), withDistance: false).lon;
}

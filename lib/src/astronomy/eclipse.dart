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

// Global solar and lunar eclipses: EclipseKind, LunarEclipseInfo, ShadowInfo,
// CalcShadow, EarthShadow, MoonShadow, ShadowDistanceSlope, PeakEarthShadow,
// PeakMoonShadow, ShadowSemiDurationMinutes, MoonEclipticLatitudeDegrees,
// Obscuration, SolarEclipseObscuration, SearchLunarEclipse,
// GlobalSolarEclipseInfo, EclipseKindFromUmbra, GeoidIntersect,
// NextLunarEclipse, SearchGlobalSolarEclipse, NextGlobalSolarEclipse
// (astronomy.ts 129-150, 8320-9025). Local (observer) eclipses, transits and
// planet shadows are not ported.

const double _sunRadiusKm = 695700.0;
const double _sunRadiusAu = _sunRadiusKm / kmPerAu;

const double _earthFlattening = 0.996647180302104;
const double _earthFlatteningSquared = _earthFlattening * _earthFlattening;

/// Mean radius of the Earth's geoid, without atmosphere.
const double _earthMeanRadiusKm = 6371.0;

/// Effective atmosphere thickness for lunar eclipses.
const double _earthAtmosphereKm = 88.0;
const double _earthEclipseRadiusKm = _earthMeanRadiusKm + _earthAtmosphereKm;

const double _moonMeanRadiusKm = 1737.4;
const double _moonPolarRadiusKm = 1736.0;
const double _moonPolarRadiusAu = _moonPolarRadiusKm / kmPerAu;

/// The different kinds of lunar/solar eclipses (`EclipseKind`).
enum EclipseKind { penumbral, partial, annular, total }

/// Information about a lunar eclipse (`LunarEclipseInfo`).
///
/// [peak] is the time of greatest eclipse (the Moon's centre closest to the
/// Earth's shadow axis). [sdPenum], [sdPartial], [sdTotal] are semi-durations
/// in minutes (0 when that phase does not occur). [obscuration] is the
/// fraction of the Moon's disc inside the umbra at [peak] (0 for penumbral,
/// 1 for total).
class LunarEclipseInfo {
  LunarEclipseInfo(
    this.kind,
    this.obscuration,
    this.peak,
    this.sdPenum,
    this.sdPartial,
    this.sdTotal,
  );

  final EclipseKind kind;
  final double obscuration;
  final AstroTime peak;
  final double sdPenum;
  final double sdPartial;
  final double sdTotal;
}

/// `ShadowInfo` (internal in upstream). Public here so higher layers can
/// examine the Moon's shadow (e.g. to classify hybrid eclipses).
///
/// [u]: shadow-axis parameter of the target's projection; [r]: distance (km)
/// from the target to the shadow axis; [k]: umbra radius (km) at the
/// target's plane (negative = antumbra); [p]: penumbra radius (km);
/// [target]: target position relative to the shadow-casting body;
/// [dir]: shadow-axis direction (Sun -> body), AU.
class ShadowInfo {
  ShadowInfo(this.time, this.u, this.r, this.k, this.p, this.target, this.dir);

  final AstroTime time;
  final double u;
  final double r;
  final double k;
  final double p;
  final Vector target;
  final Vector dir;
}

ShadowInfo _calcShadow(
  double bodyRadiusKm,
  AstroTime time,
  Vector target,
  Vector dir,
) {
  final double u = (dir.x * target.x + dir.y * target.y + dir.z * target.z) /
      (dir.x * dir.x + dir.y * dir.y + dir.z * dir.z);
  final double dx = (u * dir.x) - target.x;
  final double dy = (u * dir.y) - target.y;
  final double dz = (u * dir.z) - target.z;
  final double r = kmPerAu * math.sqrt(dx * dx + dy * dy + dz * dz);
  final double k = _sunRadiusKm - (1.0 + u) * (_sunRadiusKm - bodyRadiusKm);
  final double p = -_sunRadiusKm + (1.0 + u) * (_sunRadiusKm + bodyRadiusKm);
  return ShadowInfo(time, u, r, k, p, target, dir);
}

/// The Earth's shadow relative to the Moon (`EarthShadow`).
ShadowInfo earthShadow(AstroTime time) {
  // Light-travel and aberration corrected vector from the Earth to the Sun.
  final Vector s = geoVector(Body.sun, time, true);
  // The vector e = -s is thus the path of sunlight through the center of the Earth.
  final Vector e = Vector(-s.x, -s.y, -s.z, s.t);
  // Geocentric moon.
  final Vector m = geoMoon(time);
  return _calcShadow(_earthEclipseRadiusKm, time, m, e);
}

/// The Moon's shadow relative to the Earth (`MoonShadow`).
ShadowInfo moonShadow(AstroTime time) {
  final Vector s = geoVector(Body.sun, time, true);
  final Vector m = geoMoon(time); // geocentric Moon
  // Calculate lunacentric Earth.
  final Vector e = Vector(-m.x, -m.y, -m.z, m.t);
  // Convert geocentric moon to heliocentric Moon.
  m.x -= s.x;
  m.y -= s.y;
  m.z -= s.z;
  return _calcShadow(_moonMeanRadiusKm, time, e, m);
}

double _shadowDistanceSlope(
  ShadowInfo Function(AstroTime t) shadowfunc,
  AstroTime time,
) {
  const double dt = 1.0 / 86400.0;
  final AstroTime t1 = time.addDays(-dt);
  final AstroTime t2 = time.addDays(dt);
  final ShadowInfo shadow1 = shadowfunc(t1);
  final ShadowInfo shadow2 = shadowfunc(t2);
  return (shadow2.r - shadow1.r) / dt;
}

ShadowInfo _peakEarthShadow(AstroTime searchCenterTime) {
  const double window =
      0.03; // initial search window, in days, before/after given time
  final AstroTime t1 = searchCenterTime.addDays(-window);
  final AstroTime t2 = searchCenterTime.addDays(window);
  final AstroTime? tx = search(
    (AstroTime time) => _shadowDistanceSlope(earthShadow, time),
    t1,
    t2,
  );
  if (tx == null) throw StateError('Failed to find peak Earth shadow time.');
  return earthShadow(tx);
}

ShadowInfo _peakMoonShadow(AstroTime searchCenterTime) {
  const double window =
      0.03; // initial search window, in days, before/after given time
  final AstroTime t1 = searchCenterTime.addDays(-window);
  final AstroTime t2 = searchCenterTime.addDays(window);
  final AstroTime? tx = search(
    (AstroTime time) => _shadowDistanceSlope(moonShadow, time),
    t1,
    t2,
  );
  if (tx == null) throw StateError('Failed to find peak Moon shadow time.');
  return moonShadow(tx);
}

double _shadowSemiDurationMinutes(
  AstroTime centerTime,
  double radiusLimit,
  double windowMinutes,
) {
  // Search backwards and forwards from the center time until shadow axis distance crosses radius limit.
  final double window = windowMinutes / (24.0 * 60.0);
  final AstroTime before = centerTime.addDays(-window);
  final AstroTime after = centerTime.addDays(window);
  final AstroTime? t1 = search(
    (AstroTime time) => -(earthShadow(time).r - radiusLimit),
    before,
    centerTime,
  );
  final AstroTime? t2 = search(
    (AstroTime time) => earthShadow(time).r - radiusLimit,
    centerTime,
    after,
  );
  if (t1 == null || t2 == null) {
    throw StateError('Failed to find shadow semiduration');
  }
  // Convert days to minutes and average the semi-durations.
  return (t2.ut - t1.ut) * ((24.0 * 60.0) / 2.0);
}

double _moonEclipticLatitudeDegrees(AstroTime time) {
  final _MoonResult moon = _calcMoon(time);
  return rad2Deg * moon.geoEclipLat;
}

/// Area of intersection of two discs (radii [a], [b], centres [c] apart)
/// divided by the area of the first disc (`Obscuration`).
double _obscuration(double a, double b, double c) {
  if (a <= 0.0) throw ArgumentError('Radius of first disc must be positive.');

  if (b <= 0.0) throw ArgumentError('Radius of second disc must be positive.');

  if (c < 0.0) {
    throw ArgumentError(
      'Distance between discs is not allowed to be negative.',
    );
  }

  if (c >= a + b) {
    // The discs are too far apart to have any overlapping area.
    return 0.0;
  }

  if (c == 0.0) {
    // The discs have a common center. Therefore, one disc is inside the other.
    return (a <= b) ? 1.0 : (b * b) / (a * a);
  }

  final double x = (a * a - b * b + c * c) / (2 * c);
  final double radicand = a * a - x * x;
  if (radicand <= 0.0) {
    // The circumferences do not intersect, or are tangent.
    // We already ruled out the case of non-overlapping discs.
    // Therefore, one disc is inside the other.
    return (a <= b) ? 1.0 : (b * b) / (a * a);
  }

  // The discs overlap fractionally in a pair of lens-shaped areas.

  final double y = math.sqrt(radicand);

  // Return the overlapping fractional area.
  // There are two lens-shaped areas, one to the left of x, the other to the right of x.
  // Each part is calculated by subtracting a triangular area from a sector's area.
  final double lens1 = a * a * math.acos(x / a) - x * y;
  final double lens2 = b * b * math.acos((c - x) / b) - (c - x) * y;

  // Find the fractional area with respect to the first disc.
  return (lens1 + lens2) / (math.pi * a * a);
}

double _solarEclipseObscuration(
  Vector hm, // heliocentric Moon
  Vector lo, // lunacentric observer
) {
  // Find heliocentric observer.
  final Vector ho = Vector(hm.x + lo.x, hm.y + lo.y, hm.z + lo.z, hm.t);

  // Calculate the apparent angular radius of the Sun for the observer.
  final double sunRadius = math.asin(_sunRadiusAu / ho.length());

  // Calculate the apparent angular radius of the Moon for the observer.
  final double moonRadius = math.asin(_moonPolarRadiusAu / lo.length());

  // Calculate the apparent angular separation between the Sun's center and the Moon's center.
  final double sunMoonSeparation = angleBetween(lo, ho);

  // Find the fraction of the Sun's apparent disc area that is covered by the Moon.
  final double obscuration = _obscuration(
    sunRadius,
    moonRadius,
    sunMoonSeparation * deg2Rad,
  );

  // HACK: In marginal cases, we need to clamp obscuration to less than 1.0.
  // This function is never called for total eclipses, so it should never return 1.0.
  return math.min(0.9999, obscuration);
}

/// Searches for the first lunar eclipse whose peak is after [date]
/// (`SearchLunarEclipse`). Penumbral eclipses are included.
LunarEclipseInfo searchLunarEclipse(AstroTime date) {
  const double pruneLatitude =
      1.8; // full Moon's ecliptic latitude above which eclipse is impossible
  AstroTime fmtime = date;
  for (int fmcount = 0; fmcount < 12; ++fmcount) {
    // Search for the next full moon. Any eclipse will be near it.
    final AstroTime? fullmoon = searchMoonPhase(180, fmtime, 40);
    if (fullmoon == null) throw StateError('Cannot find full moon.');

    // Pruning: if the full Moon's ecliptic latitude is too large,
    // a lunar eclipse is not possible. Avoid needless work searching for
    // the minimum moon distance.
    final double eclipLat = _moonEclipticLatitudeDegrees(fullmoon);
    if (eclipLat.abs() < pruneLatitude) {
      // Search near the full moon for the time when the center of the Moon
      // is closest to the line passing through the centers of the Sun and Earth.
      final ShadowInfo shadow = _peakEarthShadow(fullmoon);
      if (shadow.r < shadow.p + _moonMeanRadiusKm) {
        // This is at least a penumbral eclipse. We will return a result.
        EclipseKind kind = EclipseKind.penumbral;
        double obscuration = 0.0;
        double sdTotal = 0.0;
        double sdPartial = 0.0;
        final double sdPenum = _shadowSemiDurationMinutes(
          shadow.time,
          shadow.p + _moonMeanRadiusKm,
          200.0,
        );

        if (shadow.r < shadow.k + _moonMeanRadiusKm) {
          // This is at least a partial eclipse.
          kind = EclipseKind.partial;
          sdPartial = _shadowSemiDurationMinutes(
            shadow.time,
            shadow.k + _moonMeanRadiusKm,
            sdPenum,
          );

          if (shadow.r + _moonMeanRadiusKm < shadow.k) {
            // This is a total eclipse.
            kind = EclipseKind.total;
            obscuration = 1.0;
            sdTotal = _shadowSemiDurationMinutes(
              shadow.time,
              shadow.k - _moonMeanRadiusKm,
              sdPartial,
            );
          } else {
            obscuration = _obscuration(_moonMeanRadiusKm, shadow.k, shadow.r);
          }
        }
        return LunarEclipseInfo(
          kind,
          obscuration,
          shadow.time,
          sdPenum,
          sdPartial,
          sdTotal,
        );
      }
    }

    // We didn't find an eclipse on this full moon, so search for the next one.
    fmtime = fullmoon.addDays(10);
  }

  // This should never happen because there are always at least 2 full moons per year.
  throw StateError('Failed to find lunar eclipse within 12 full moons.');
}

/// Reports the time and geographic location of the peak of a solar eclipse
/// (`GlobalSolarEclipseInfo`).
///
/// [kind] is partial, annular or total as seen at the point of greatest
/// eclipse. [distance] (km) is the distance between the Moon's shadow axis
/// and the Earth's centre at [peak]. [latitude]/[longitude] (degrees) are the
/// geoid intersection of the shadow axis, null for partial eclipses (the axis
/// misses the Earth). [obscuration] is null for partial eclipses.
class GlobalSolarEclipseInfo {
  GlobalSolarEclipseInfo(
    this.kind,
    this.obscuration,
    this.peak,
    this.distance, [
    this.latitude,
    this.longitude,
  ]);

  final EclipseKind kind;
  final double? obscuration;
  final AstroTime peak;
  final double distance;
  final double? latitude;
  final double? longitude;
}

EclipseKind _eclipseKindFromUmbra(double k) {
  // The umbra radius tells us what kind of eclipse the observer sees.
  // If the umbra radius is positive, this is a total eclipse. Otherwise, it's annular.
  // HACK: I added a tiny bias (14 meters) to match Espenak test data.
  return (k > 0.014) ? EclipseKind.total : EclipseKind.annular;
}

/// Where the Moon's shadow axis meets the Earth's geoid (upstream: inside
/// `GeoidIntersect`): the surface point and the umbra radius there.
class ShadowAxisSurfacePoint {
  ShadowAxisSurfacePoint(
    this.latitude,
    this.longitude,
    this.observer,
    this.umbraKm,
  );

  /// Geodetic latitude, degrees.
  final double latitude;

  /// Longitude, degrees east, (-180, 180].
  final double longitude;

  /// Lunacentric observer vector, EQJ, AU.
  final Vector observer;

  /// Umbra radius (km) at the surface point (`surface.k`; > 0.014 = total,
  /// otherwise annular, as upstream's `EclipseKindFromUmbra`).
  final double umbraKm;

  /// The kind of central eclipse seen at this point.
  EclipseKind get kind => _eclipseKindFromUmbra(umbraKm);
}

/// The geoid intersection of [shadow]'s axis, or null if the axis misses the
/// Earth. This is the first half of upstream `GeoidIntersect`, unchanged,
/// exposed so higher layers can follow the centre line (hybrid detection).
ShadowAxisSurfacePoint? shadowAxisSurfacePoint(ShadowInfo shadow) {
  // We want to calculate the intersection of the shadow axis with the Earth's geoid.
  // First we must convert EQJ (equator of J2000) coordinates to EQD (equator of date)
  // coordinates that are perfectly aligned with the Earth's equator at this
  // moment in time.
  final RotationMatrix rot = rotationEqjEqd(shadow.time);
  final Vector v = rotateVector(
    rot,
    shadow.dir,
  ); // shadow-axis vector in equator-of-date coordinates
  final Vector e = rotateVector(
    rot,
    shadow.target,
  ); // lunacentric Earth in equator-of-date coordinates

  // Convert all distances from AU to km.
  // But dilate the z-coordinates so that the Earth becomes a perfect sphere.
  // Then find the intersection of the vector with the sphere.
  // See p 184 in Montenbruck & Pfleger's "Astronomy on the Personal Computer", second edition.
  v.x *= kmPerAu;
  v.y *= kmPerAu;
  v.z *= kmPerAu / _earthFlattening;
  e.x *= kmPerAu;
  e.y *= kmPerAu;
  e.z *= kmPerAu / _earthFlattening;

  // Solve the quadratic equation that finds whether and where
  // the shadow axis intersects with the Earth in the dilated coordinate system.
  const double R = _earthEquatorialRadiusKm;
  final double A = v.x * v.x + v.y * v.y + v.z * v.z;
  final double B = -2.0 * (v.x * e.x + v.y * e.y + v.z * e.z);
  final double C = (e.x * e.x + e.y * e.y + e.z * e.z) - R * R;
  final double radic = B * B - 4 * A * C;

  if (!(radic > 0.0)) return null;

  // Calculate the closer of the two intersection points.
  // This will be on the day side of the Earth.
  final double u = (-B - math.sqrt(radic)) / (2 * A);

  // Convert lunacentric dilated coordinates to geocentric coordinates.
  final double px = u * v.x - e.x;
  final double py = u * v.y - e.y;
  final double pz = (u * v.z - e.z) * _earthFlattening;

  // Convert cartesian coordinates into geodetic latitude/longitude.
  final double proj = math.sqrt(px * px + py * py) * _earthFlatteningSquared;
  final double latitude;
  if (proj == 0.0) {
    latitude = (pz > 0.0) ? 90.0 : -90.0;
  } else {
    latitude = rad2Deg * math.atan(pz / proj);
  }

  // Adjust longitude for Earth's rotation at the given UT.
  final double gast = _siderealTime(shadow.time);
  double longitude = _jsMod(rad2Deg * math.atan2(py, px) - (15 * gast), 360.0);
  if (longitude <= -180.0) {
    longitude += 360.0;
  } else if (longitude > 180.0) {
    longitude -= 360.0;
  }

  // We want to determine whether the observer sees a total eclipse or an annular eclipse.
  // We need to perform a series of vector calculations...
  // Calculate the inverse rotation matrix, so we can convert EQD to EQJ.
  final RotationMatrix inv = inverseRotation(rot);

  // Put the EQD geocentric coordinates of the observer into the vector 'o'.
  // Also convert back from kilometers to astronomical units.
  Vector o = Vector(px / kmPerAu, py / kmPerAu, pz / kmPerAu, shadow.time);

  // Rotate the observer's geocentric EQD back to the EQJ system.
  o = rotateVector(inv, o);

  // Convert geocentric vector to lunacentric vector.
  o.x += shadow.target.x;
  o.y += shadow.target.y;
  o.z += shadow.target.z;

  // Recalculate the shadow using a vector from the Moon's center toward the observer.
  final ShadowInfo surface = _calcShadow(
    _moonPolarRadiusKm,
    shadow.time,
    o,
    shadow.dir,
  );

  // If we did everything right, the shadow distance should be very close to zero.
  // That's because we already determined the observer 'o' is on the shadow axis!
  if (surface.r > 1.0e-9 || surface.r < 0.0) {
    throw StateError(
      'Unexpected shadow distance from geoid intersection = ${surface.r}',
    );
  }

  return ShadowAxisSurfacePoint(latitude, longitude, o, surface.k);
}

GlobalSolarEclipseInfo _geoidIntersect(ShadowInfo shadow) {
  final ShadowAxisSurfacePoint? point = shadowAxisSurfacePoint(shadow);
  if (point == null) {
    // This is a partial solar eclipse. It does not make practical sense to calculate obscuration.
    // Anyone who wants obscuration should use Astronomy.SearchLocalSolarEclipse for a specific location on the Earth.
    return GlobalSolarEclipseInfo(
      EclipseKind.partial,
      null,
      shadow.time,
      shadow.r,
    );
  }
  final EclipseKind kind = point.kind;
  final double obscuration = (kind == EclipseKind.total)
      ? 1.0
      : _solarEclipseObscuration(shadow.dir, point.observer);
  return GlobalSolarEclipseInfo(
    kind,
    obscuration,
    shadow.time,
    shadow.r,
    point.latitude,
    point.longitude,
  );
}

/// The first lunar eclipse more than 10 days after [prevEclipseTime]
/// (`NextLunarEclipse`).
LunarEclipseInfo nextLunarEclipse(AstroTime prevEclipseTime) {
  final AstroTime startTime = prevEclipseTime.addDays(10);
  return searchLunarEclipse(startTime);
}

/// Searches for the first solar eclipse visible anywhere on the Earth's
/// surface after [startTime] (`SearchGlobalSolarEclipse`).
GlobalSolarEclipseInfo searchGlobalSolarEclipse(AstroTime startTime) {
  const double pruneLatitude =
      1.8; // Moon's ecliptic latitude beyond which eclipse is impossible
  // Iterate through consecutive new moons until we find a solar eclipse visible somewhere on Earth.
  AstroTime nmtime = startTime;
  for (int nmcount = 0; nmcount < 12; ++nmcount) {
    // Search for the next new moon. Any eclipse will be near it.
    final AstroTime? newmoon = searchMoonPhase(0.0, nmtime, 40.0);
    if (newmoon == null) throw StateError('Cannot find new moon');

    // Pruning: if the new moon's ecliptic latitude is too large, a solar eclipse is not possible.
    final double eclipLat = _moonEclipticLatitudeDegrees(newmoon);
    if (eclipLat.abs() < pruneLatitude) {
      // Search near the new moon for the time when the center of the Earth
      // is closest to the line passing through the centers of the Sun and Moon.
      final ShadowInfo shadow = _peakMoonShadow(newmoon);
      if (shadow.r < shadow.p + _earthMeanRadiusKm) {
        // This is at least a partial solar eclipse visible somewhere on Earth.
        // Try to find an intersection between the shadow axis and the Earth's oblate geoid.
        return _geoidIntersect(shadow);
      }
    }

    // We didn't find an eclipse on this new moon, so search for the next one.
    nmtime = newmoon.addDays(10.0);
  }

  // Safety valve to prevent infinite loop.
  // This should never happen, because at least 2 solar eclipses happen per year.
  throw StateError('Failed to find solar eclipse within 12 full moons.');
}

/// The first global solar eclipse more than 10 days after [prevEclipseTime]
/// (`NextGlobalSolarEclipse`).
GlobalSolarEclipseInfo nextGlobalSolarEclipse(AstroTime prevEclipseTime) {
  final AstroTime startTime = prevEclipseTime.addDays(10.0);
  return searchGlobalSolarEclipse(startTime);
}

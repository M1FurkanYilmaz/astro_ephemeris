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
// Adapted from the eclipse search of Astronomy Engine v2.1.19 (commit 03084ee),
// https://github.com/cosinekitty/astronomy
// on top of the Dart port in ../astronomy/.

/// Solar and lunar eclipse search, built on the pure-Dart port of
/// Astronomy Engine (`../astronomy/`, MIT).
///
/// * [nextSolarEclipse] / [nextLunarEclipse]: the first eclipse whose
///   greatest eclipse (peak) is at or after a UTC instant.
/// * [solarEclipsesBetween] / [lunarEclipsesBetween]: all of them in a span.
///
/// Two refinements on top of Astronomy Engine's global solar search, both
/// following NASA's catalogue conventions:
/// * **Hybrid** (annular-total): Astronomy Engine reports the kind seen at
///   the point of greatest eclipse only. Here the shadow axis is followed
///   along the whole centre line (2-minute steps, plus both ends located to
///   about a second); if the umbra is total at some points and annular at
///   others, the eclipse is [EclipseCategory.hybrid].
/// * **Non-central** total/annular: when the shadow axis misses the Earth but
///   the umbra or antumbra still touches it, Astronomy Engine says partial;
///   here it is total/annular (as in NASA's catalogue).
///
/// Delta T: every public function here installs the observed Delta T
/// model ([installEphemerisDeltaT]) before it builds an `AstroTime`, so peak
/// times are UT exactly as in the rest of the ephemeris.
///
/// Pure Dart. Synchronous: one search costs a few ms.
library;

import 'dart:math' as math;

import '../astronomy/astronomy.dart' hide nextLunarEclipse;
import '../astronomy/astronomy.dart' as ae show nextLunarEclipse;
import '../ephemeris.dart' show installEphemerisDeltaT;

/// Eclipse kinds.
enum EclipseCategory { total, annular, hybrid, partial, penumbral }

/// A global solar eclipse.
class SolarEclipse {
  SolarEclipse._(this.peak, this.kind, this.info, this.nonCentral);

  /// Greatest eclipse: the Moon's shadow axis closest to the Earth's centre.
  final AstroTime peak;

  /// total / annular / hybrid / partial.
  final EclipseCategory kind;

  /// The raw Astronomy Engine result (kind at the peak point only, geographic
  /// position of greatest eclipse for central eclipses).
  final GlobalSolarEclipseInfo info;

  /// The umbra/antumbra touches the Earth but its axis does not.
  final bool nonCentral;

  /// [peak] as a UTC DateTime (microsecond resolution).
  DateTime get peakUtc => peak.date;

  /// Julian day (UT) of [peak].
  double get jdUt => peak.julianDayUt;

  /// Apparent geocentric ecliptic longitude of the Sun at [peak], degrees
  /// (true ecliptic and equinox of date).
  double get sunLongitude => ecliptic(geoVector(Body.sun, peak, true)).elon;

  @override
  String toString() => 'SolarEclipse(${kind.name}, $peakUtc)';
}

/// A lunar eclipse.
class LunarEclipse {
  LunarEclipse._(this.kind, this.info);

  /// total / partial / penumbral.
  final EclipseCategory kind;

  /// The raw Astronomy Engine result (semi-durations, obscuration).
  final LunarEclipseInfo info;

  /// Greatest eclipse: the Moon's centre closest to the Earth's shadow axis.
  AstroTime get peak => info.peak;

  DateTime get peakUtc => info.peak.date;

  double get jdUt => info.peak.julianDayUt;

  /// Geocentric ecliptic longitude of the Moon at [peak], degrees (true
  /// equinox of date).
  double get moonLongitude => eclipticGeoMoon(info.peak).lon;

  @override
  String toString() => 'LunarEclipse(${kind.name}, $peakUtc)';
}

/// How far before the requested instant the new/full Moon search starts.
/// Astronomy Engine looks for syzygies after its start time and the peak can
/// be up to ~1 hour from the syzygy, so starting a day early (and skipping
/// peaks before [fromUtc]) catches an eclipse whose syzygy precedes it.
const double _lookBackDays = 1.0;

/// The first solar eclipse whose peak is at or after [fromUtc].
SolarEclipse nextSolarEclipse(DateTime fromUtc) {
  installEphemerisDeltaT();
  final double fromUt = AstroTime.fromDateTime(fromUtc).ut;
  GlobalSolarEclipseInfo e = searchGlobalSolarEclipse(
    AstroTime(fromUt - _lookBackDays),
  );
  while (e.peak.ut < fromUt) {
    e = nextGlobalSolarEclipse(e.peak);
  }
  return _classifySolar(e);
}

/// The first lunar eclipse (penumbral included) whose peak is at or after
/// [fromUtc].
LunarEclipse nextLunarEclipse(DateTime fromUtc) {
  installEphemerisDeltaT();
  final double fromUt = AstroTime.fromDateTime(fromUtc).ut;
  LunarEclipseInfo e = searchLunarEclipse(AstroTime(fromUt - _lookBackDays));
  while (e.peak.ut < fromUt) {
    e = ae.nextLunarEclipse(e.peak);
  }
  return _lunar(e);
}

/// Solar eclipses with peak in [fromUtc, toUtc), in time order.
List<SolarEclipse> solarEclipsesBetween(DateTime fromUtc, DateTime toUtc) {
  installEphemerisDeltaT();
  final double toUt = AstroTime.fromDateTime(toUtc).ut;
  final List<SolarEclipse> out = <SolarEclipse>[];
  SolarEclipse e = nextSolarEclipse(fromUtc);
  while (e.peak.ut < toUt) {
    out.add(e);
    e = _classifySolar(nextGlobalSolarEclipse(e.peak));
  }
  return out;
}

/// Lunar eclipses with peak in [fromUtc, toUtc), in time order.
List<LunarEclipse> lunarEclipsesBetween(DateTime fromUtc, DateTime toUtc) {
  installEphemerisDeltaT();
  final double toUt = AstroTime.fromDateTime(toUtc).ut;
  final List<LunarEclipse> out = <LunarEclipse>[];
  LunarEclipse e = nextLunarEclipse(fromUtc);
  while (e.peak.ut < toUt) {
    out.add(e);
    e = _lunar(ae.nextLunarEclipse(e.peak));
  }
  return out;
}

/// Shadow-size convention offset for the lunar kind, km (see [_lunar]).
const double _lunarShadowOffsetKm = 16.0;

const double _moonMeanRadiusKm = 1737.4;

/// The kind of a lunar eclipse.
///
/// Astronomy Engine enlarges the Earth by an 88 km atmosphere; its shadows
/// come out about 16 km larger at the Moon than in NASA's Five Millennium
/// Canon (Espenak, Chauvenet's 2 % rule), i.e. 15-18 km of shadow radius.
/// Without a correction it calls grazing eclipses partial that the Canon
/// calls penumbral: 1988-03-03 (AE umbral magnitude +0.0039, NASA -0.0017),
/// 2042-09-29 (+0.0022 vs -0.0031) and 1900-06-13 (NASA -0.0040).
/// So the umbral boundaries (partial, total) are tested with the umbra
/// shrunk by [_lunarShadowOffsetKm]; this can only downgrade a kind, and in
/// 1900-2100 it changes exactly those three (the smallest true partial has
/// AE umbral magnitude 0.014, i.e. a 49 km margin). Peak time and
/// penumbral detection stay Astronomy Engine's.
LunarEclipse _lunar(LunarEclipseInfo e) {
  if (e.kind == EclipseKind.penumbral) {
    return LunarEclipse._(EclipseCategory.penumbral, e);
  }
  final ShadowInfo s = earthShadow(e.peak);
  final double k = s.k - _lunarShadowOffsetKm;
  final EclipseCategory kind = (s.r + _moonMeanRadiusKm < k)
      ? EclipseCategory.total
      : (s.r < k + _moonMeanRadiusKm)
          ? EclipseCategory.partial
          : EclipseCategory.penumbral;
  // Never upgrade Astronomy Engine's kind.
  if (e.kind == EclipseKind.partial && kind == EclipseCategory.total) {
    return LunarEclipse._(EclipseCategory.partial, e);
  }
  return LunarEclipse._(kind, e);
}

// --- solar classification ---------------------------------------------------

/// Step of the centre-line walk, days (2 minutes).
const double _stepDays = 2.0 / 1440.0;

/// Precision of the centre-line ends, days (about 0.5 s).
const double _edgeDays = 0.5 / 86400.0;

/// Umbra threshold of upstream `EclipseKindFromUmbra` (14 m bias).
const double _umbraBiasKm = 0.014;

/// Mirrors the private constants of astronomy/eclipse.dart (upstream values).
const double _earthEquatorialRadiusKm = 6378.1366;
const double _earthFlattening = 0.996647180302104;
const double _sunRadiusKm = 695700.0;
const double _moonPolarRadiusKm = 1736.0;

SolarEclipse _classifySolar(GlobalSolarEclipseInfo e) {
  final ShadowInfo shadow = moonShadow(e.peak);
  if (e.kind == EclipseKind.partial) {
    final EclipseCategory? nc = _nonCentralKind(shadow);
    if (nc != null) return SolarEclipse._(e.peak, nc, e, true);
    return SolarEclipse._(e.peak, EclipseCategory.partial, e, false);
  }
  final Set<EclipseKind> seen = <EclipseKind>{e.kind};
  // Walk the centre line backwards and forwards from the peak.
  for (final double dir in const <double>[-1.0, 1.0]) {
    double inside = 0; // offset (days) known to be on the Earth
    double outside = double.nan;
    for (double dt = _stepDays; dt < 0.5; dt += _stepDays) {
      final ShadowAxisSurfacePoint? p = shadowAxisSurfacePoint(
        moonShadow(e.peak.addDays(dir * dt)),
      );
      if (p == null) {
        outside = dt;
        break;
      }
      inside = dt;
      seen.add(p.kind);
    }
    if (outside.isNaN) continue; // cannot happen: the axis leaves within hours
    // Locate the end of the centre line and take the kind there (the umbra
    // is smallest/antumbra largest at the ends, farthest from the Moon).
    ShadowAxisSurfacePoint? last;
    while (outside - inside > _edgeDays) {
      final double mid = 0.5 * (inside + outside);
      final ShadowAxisSurfacePoint? p = shadowAxisSurfacePoint(
        moonShadow(e.peak.addDays(dir * mid)),
      );
      if (p == null) {
        outside = mid;
      } else {
        inside = mid;
        last = p;
      }
    }
    if (last != null) seen.add(last.kind);
  }
  final EclipseCategory kind =
      seen.contains(EclipseKind.total) && seen.contains(EclipseKind.annular)
          ? EclipseCategory.hybrid
          : (e.kind == EclipseKind.total
              ? EclipseCategory.total
              : EclipseCategory.annular);
  return SolarEclipse._(e.peak, kind, e, false);
}

/// Total/annular kind of a non-central eclipse, or null for a true partial.
///
/// The shadow axis misses the Earth (Astronomy Engine's partial). The Earth
/// is made a sphere of the equatorial radius by stretching z by 1/flattening,
/// as in upstream `GeoidIntersect`; the gap between that sphere and the axis
/// is compared with the umbra/antumbra radius in the plane through the
/// Earth's centre perpendicular to the axis (where the closest surface point
/// lies), computed with the Moon's polar radius as upstream does at the
/// surface.
EclipseCategory? _nonCentralKind(ShadowInfo shadow) {
  final RotationMatrix rot = rotationEqjEqd(shadow.time);
  final Vector v = rotateVector(rot, shadow.dir);
  final Vector e = rotateVector(rot, shadow.target);
  const double au = kmPerAu;
  final double vx = v.x * au, vy = v.y * au, vz = v.z * au / _earthFlattening;
  final double ex = e.x * au, ey = e.y * au, ez = e.z * au / _earthFlattening;
  // Distance from the (dilated) Earth centre to the axis line.
  final double vv = vx * vx + vy * vy + vz * vz;
  final double s = (vx * ex + vy * ey + vz * ez) / vv;
  final double dx = s * vx - ex, dy = s * vy - ey, dz = s * vz - ez;
  final double gap =
      math.sqrt(dx * dx + dy * dy + dz * dz) - _earthEquatorialRadiusKm;
  final double k =
      _sunRadiusKm - (1.0 + shadow.u) * (_sunRadiusKm - _moonPolarRadiusKm);
  if (gap >= k.abs()) return null;
  return k > _umbraBiasKm ? EclipseCategory.total : EclipseCategory.annular;
}

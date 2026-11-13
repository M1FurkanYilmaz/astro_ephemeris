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

// Root finder and Moon phase search: QuadInterp, SearchOptions, Search,
// LongitudeOffset, NormalizeLongitude, AngleBetween, PairLongitude, MoonPhase,
// SearchMoonPhase (astronomy.ts 256-275, 4520-4740, 4828-4842, 5218-5300).

/// Average number of days for the Moon to return to the same phase.
const double _meanSynodicMonth = 29.530588;

const double _secondsPerDay = 24.0 * 3600.0;

class _InterpResult {
  _InterpResult(this.t, this.dfDt);
  final double t;
  final double dfDt;
}

_InterpResult? _quadInterp(
  double tm,
  double dt,
  double fa,
  double fm,
  double fb,
) {
  final double q = (fb + fa) / 2 - fm;
  final double r = (fb - fa) / 2;
  final double s = fm;
  double x;

  if (q == 0) {
    // This is a line, not a parabola.
    if (r == 0) {
      // This is a HORIZONTAL line... can't make progress!
      return null;
    }
    x = -s / r;
    if (x < -1 || x > 1) return null; // out of bounds
  } else {
    // It really is a parabola. Find roots x1, x2.
    final double u = r * r - 4 * q * s;
    if (u <= 0) return null;
    final double ru = math.sqrt(u);
    final double x1 = (-r + ru) / (2 * q);
    final double x2 = (-r - ru) / (2 * q);

    if (-1 <= x1 && x1 <= 1) {
      if (-1 <= x2 && x2 <= 1) return null;
      x = x1;
    } else if (-1 <= x2 && x2 <= 1) {
      x = x2;
    } else {
      return null;
    }
  }

  final double t = tm + x * dt;
  final double dfDt = (2 * q * x + r) / dt;
  return _InterpResult(t, dfDt);
}

/// Options for [search] (`SearchOptions`).
class SearchOptions {
  const SearchOptions({
    this.dtToleranceSeconds,
    this.initF1,
    this.initF2,
    this.iterLimit,
  });

  /// Time window (seconds) below which the search has converged; default 1.
  final double? dtToleranceSeconds;

  /// Optional precomputed `func(t1)`.
  final double? initF1;

  /// Optional precomputed `func(t2)`.
  final double? initF2;

  /// Maximum number of iterations; default 20.
  final int? iterLimit;
}

/// `InterpolateTime`.
AstroTime _interpolateTime(AstroTime time1, AstroTime time2, double fraction) =>
    AstroTime(time1.ut + fraction * (time2.ut - time1.ut));

/// Finds the time in [t1]..[t2] when [f] ascends through zero (`Search`).
///
/// Returns null if there is no ascending zero crossing in the window (or the
/// window is too wide). Throws [StateError] on excessive iteration.
///
/// JavaScript quirk kept: `options.init_f1 || f(t1)` treats a supplied 0 as
/// absent (and likewise for `initF2`, `dtToleranceSeconds`, `iterLimit`).
AstroTime? search(
  double Function(AstroTime t) f,
  AstroTime t1,
  AstroTime t2, [
  SearchOptions? options,
]) {
  final double dtToleranceSeconds = _verifyNumber(
    _orIfFalsy(options?.dtToleranceSeconds, 1),
  );

  final double dtDays = (dtToleranceSeconds / _secondsPerDay).abs();

  final double? initF1 = options?.initF1;
  final double? initF2 = options?.initF2;
  double f1 = (initF1 != null && initF1 != 0) ? initF1 : f(t1);
  double f2 = (initF2 != null && initF2 != 0) ? initF2 : f(t2);
  double fmid = double.nan;

  int iter = 0;
  final int? limitOpt = options?.iterLimit;
  final int iterLimit = (limitOpt != null && limitOpt != 0) ? limitOpt : 20;
  bool calcFmid = true;
  for (;;) {
    if (++iter > iterLimit) {
      throw StateError('Excessive iteration in Search()');
    }

    final AstroTime tmid = _interpolateTime(t1, t2, 0.5);
    final double dt = tmid.ut - t1.ut;

    if (dt.abs() < dtDays) {
      // We are close enough to the event to stop the search.
      return tmid;
    }

    if (calcFmid) {
      fmid = f(tmid);
    } else {
      calcFmid =
          true; // we already have the correct value of fmid from the previous loop
    }

    // Quadratic interpolation:
    // Try to find a parabola that passes through the 3 points we have sampled:
    // (t1,f1), (tmid,fmid), (t2,f2).
    final _InterpResult? q = _quadInterp(
      tmid.ut,
      t2.ut - tmid.ut,
      f1,
      fmid,
      f2,
    );

    // Did we find an approximate root-crossing?
    if (q != null) {
      // Evaluate the function at our candidate solution.
      final AstroTime tq = AstroTime(q.t);
      final double fq = f(tq);

      if (q.dfDt != 0) {
        if ((fq / q.dfDt).abs() < dtDays) {
          // The estimated time error is small enough that we can quit now.
          return tq;
        }

        // Try guessing a tighter boundary with the interpolated root at the center.
        final double dtGuess = 1.2 * (fq / q.dfDt).abs();
        if (dtGuess < dt / 10) {
          final AstroTime tleft = tq.addDays(-dtGuess);
          final AstroTime tright = tq.addDays(dtGuess);
          if ((tleft.ut - t1.ut) * (tleft.ut - t2.ut) < 0) {
            if ((tright.ut - t1.ut) * (tright.ut - t2.ut) < 0) {
              final double fleft = f(tleft);
              final double fright = f(tright);
              if (fleft < 0 && fright >= 0) {
                f1 = fleft;
                f2 = fright;
                t1 = tleft;
                t2 = tright;
                fmid = fq;
                calcFmid = false;
                continue;
              }
            }
          }
        }
      }
    }

    if (f1 < 0 && fmid >= 0) {
      t2 = tmid;
      f2 = fmid;
      continue;
    }

    if (fmid < 0 && f2 >= 0) {
      t1 = tmid;
      f1 = fmid;
      continue;
    }

    // Either there is no ascending zero-crossing in this range
    // or the search window is too wide.
    return null;
  }
}

double _orIfFalsy(double? value, double fallback) =>
    (value == null || value == 0 || value.isNaN) ? fallback : value;

double _longitudeOffset(double diff) {
  double offset = diff;
  while (offset <= -180) {
    offset += 360;
  }
  while (offset > 180) {
    offset -= 360;
  }
  return offset;
}

double _normalizeLongitude(double lon) {
  while (lon < 0) {
    lon += 360;
  }
  while (lon >= 360) {
    lon -= 360;
  }
  return lon;
}

/// The angle in degrees between two vectors (`AngleBetween`).
double angleBetween(Vector a, Vector b) {
  final double aa = a.x * a.x + a.y * a.y + a.z * a.z;
  if (aa.abs() < 1.0e-8) {
    throw ArgumentError('AngleBetween: first vector is too short.');
  }

  final double bb = b.x * b.x + b.y * b.y + b.z * b.z;
  if (bb.abs() < 1.0e-8) {
    throw ArgumentError('AngleBetween: second vector is too short.');
  }

  final double dot = (a.x * b.x + a.y * b.y + a.z * b.z) / math.sqrt(aa * bb);

  if (dot <= -1.0) return 180;

  if (dot >= 1.0) return 0;

  return rad2Deg * math.acos(dot);
}

/// Difference of the geocentric ecliptic longitudes `body1 - body2` in
/// degrees, in [0, 360) (`PairLongitude`). No aberration, as upstream.
double pairLongitude(Body body1, Body body2, AstroTime time) {
  if (body1 == Body.earth || body2 == Body.earth) {
    throw ArgumentError(
      'The Earth does not have a longitude as seen from itself.',
    );
  }

  final Vector vector1 = geoVector(body1, time, false);
  final EclipticCoordinates eclip1 = ecliptic(vector1);

  final Vector vector2 = geoVector(body2, time, false);
  final EclipticCoordinates eclip2 = ecliptic(vector2);

  return _normalizeLongitude(eclip1.elon - eclip2.elon);
}

/// The Moon's phase angle (Moon minus Sun ecliptic longitude) in degrees,
/// [0, 360): 0 new, 90 first quarter, 180 full, 270 third quarter (`MoonPhase`).
double moonPhase(AstroTime time) => pairLongitude(Body.moon, Body.sun, time);

/// Finds the next (or, with negative [limitDays], previous) time the Moon
/// reaches phase [targetLon] degrees, within [limitDays] of [dateStart]
/// (`SearchMoonPhase`). Null if it does not happen within the window.
AstroTime? searchMoonPhase(
  double targetLon,
  AstroTime dateStart,
  double limitDays,
) {
  double moonOffset(AstroTime t) {
    final double mlon = moonPhase(t);
    return _longitudeOffset(mlon - targetLon);
  }

  _verifyNumber(targetLon);
  _verifyNumber(limitDays);

  // To avoid discontinuities in the moon_offset function causing problems,
  // we need to approximate when that function will next return 0.
  // We probe it with the start time and take advantage of the fact
  // that every lunar phase repeats roughly every 29.5 days.
  // There is a surprising uncertainty in the quarter timing,
  // due to the eccentricity of the moon's orbit.
  // I have seen more than 0.9 days away from the simple prediction.
  // To be safe, we take the predicted time of the event and search
  // +/-1.5 days around it (a 3.0-day wide window).
  // But we must return null if the final result goes beyond limitDays after dateStart.
  const double uncertainty = 1.5;
  final AstroTime ta = dateStart;
  double ya = moonOffset(ta);
  double estDt, dt1, dt2;
  if (limitDays < 0) {
    // Search backward in time.
    if (ya < 0) ya += 360;
    estDt = -(_meanSynodicMonth * ya) / 360;
    dt2 = estDt + uncertainty;
    if (dt2 < limitDays) {
      return null; // not possible for moon phase to occur within the specified window
    }
    dt1 = math.max(limitDays, estDt - uncertainty);
  } else {
    // Search forward in time.
    if (ya > 0) ya -= 360;
    estDt = -(_meanSynodicMonth * ya) / 360;
    dt1 = estDt - uncertainty;
    if (dt1 > limitDays) {
      return null; // not possible for moon phase to occur within the specified window
    }
    dt2 = math.min(limitDays, estDt + uncertainty);
  }
  final AstroTime t1 = ta.addDays(dt1);
  final AstroTime t2 = ta.addDays(dt2);
  return search(
    moonOffset,
    t1,
    t2,
    const SearchOptions(dtToleranceSeconds: 0.1),
  );
}

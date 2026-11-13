part of 'ephemeris.dart';

// Lunar nodes and the mean lunar apogee (Black Moon Lilith).
//
// Written from published definitions (J. Meeus, "Astronomical Algorithms",
// 2nd ed., ch. 47: mean elements of the lunar orbit, from Chapront's ELP-2000/82
// mean arguments) and the standard two-body relations for osculating elements.
// Frames and distance conventions: see test/core/ephemeris_bodies_test.dart.

/// Mean Earth-Moon distance used for the mean node's "distance", km
/// (the conventional value for the mean node).
const double _moonMeanDistanceKm = 384400.0;

/// Mean eccentricity of the lunar orbit; the mean apogee distance is
/// a(1 + e) (the conventional value for the mean apogee).
const double _moonMeanEccentricity = 0.054900489;

/// Mean inclination of the lunar orbit to the ecliptic, degrees (5°08'43.4").
const double _moonMeanInclinationDeg = 5.1453964;

const double _kmPerAu = 149597870.7;

/// Mean longitude of the ascending node, mean equinox of date, degrees
/// (Meeus 47.7). [t] = Julian centuries TT since J2000.
double _meanNodeMeanEquinox(double t) =>
    125.0445479 -
    1934.1362891 * t +
    0.0020754 * t * t +
    t * t * t / 467441.0 -
    t * t * t * t / 60616000.0;

/// Mean longitude of the lunar perigee, mean equinox of date, degrees
/// (Meeus ch. 47). [t] = Julian centuries TT since J2000.
double _meanPerigeeMeanEquinox(double t) =>
    83.3532465 +
    4069.0137287 * t -
    0.0103200 * t * t -
    t * t * t / 80053.0 +
    t * t * t * t / 18999000.0;

class _LonLatDist {
  const _LonLatDist(this.lon, this.lat, this.dist);
  final double lon;
  final double lat;
  final double dist;
}

double _norm360(double x) {
  final double r = x % 360.0;
  return r < 0 ? r + 360.0 : r;
}

/// Mean node: ecliptic of date, true equinox (mean longitude + nutation in
/// longitude), latitude 0.
_LonLatDist _meanNode(ae.AstroTime t) {
  final double tc = t.tt / 36525.0;
  final double dpsiDeg = ae.eTilt(t).dpsi / 3600.0;
  return _LonLatDist(
    _norm360(_meanNodeMeanEquinox(tc) + dpsiDeg),
    0.0,
    _moonMeanDistanceKm / _kmPerAu,
  );
}

/// Mean apogee: the point of the mean lunar orbit 180° from the mean perigee.
/// The orbital longitude (node + argument) is projected onto the ecliptic
/// through the mean inclination, which gives the latitude of up to ±5.145°.
_LonLatDist _meanApogee(ae.AstroTime t) {
  final double tc = t.tt / 36525.0;
  final double node = _meanNodeMeanEquinox(tc);
  final double apogee = _meanPerigeeMeanEquinox(tc) + 180.0;
  final double u = (apogee - node) * _d2r; // argument of latitude
  final double inc = _moonMeanInclinationDeg * _d2r;
  final double lon =
      node + math.atan2(math.cos(inc) * math.sin(u), math.cos(u)) * _r2d;
  final double lat = math.asin(math.sin(inc) * math.sin(u)) * _r2d;
  final double dpsiDeg = ae.eTilt(t).dpsi / 3600.0;
  return _LonLatDist(
    _norm360(lon + dpsiDeg),
    lat,
    _moonMeanDistanceKm * (1 + _moonMeanEccentricity) / _kmPerAu,
  );
}

/// True (osculating) ascending node: the intersection of the instantaneous
/// plane of the Moon's geocentric orbit (position x velocity) with the true
/// ecliptic of date. Distance = radius of the osculating ellipse at the node.
///
/// Astronomy Engine's lunar theory carries older mean arguments whose secular
/// node (L0 − F) differs from the modern Chapront mean node by −4.3″ − 5.6″·T;
/// the osculating node inherits that (amplified ~11× relative to the Moon's
/// position, 1/sin i), so the secular difference is added back here.
_LonLatDist _trueNode(ae.AstroTime t) {
  final ae.StateVector eqj = ae.geoMoonState(t);
  final ae.StateVector s = ae.rotateState(ae.rotationEqjEct(t), eqj);
  // Specific angular momentum h = r x v.
  final double hx = s.y * s.vz - s.z * s.vy;
  final double hy = s.z * s.vx - s.x * s.vz;
  final double hz = s.x * s.vy - s.y * s.vx;
  // Node direction n = k x h = (-hy, hx, 0).
  final double nx = -hy;
  final double ny = hx;
  final double lon = math.atan2(ny, nx) * _r2d;

  // Osculating ellipse: eccentricity vector e = (v x h)/mu - r/|r|.
  final double mu = ae.massProduct(ae.Body.emb);
  final double r = math.sqrt(s.x * s.x + s.y * s.y + s.z * s.z);
  final double ex = (s.vy * hz - s.vz * hy) / mu - s.x / r;
  final double ey = (s.vz * hx - s.vx * hz) / mu - s.y / r;
  final double ez = (s.vx * hy - s.vy * hx) / mu - s.z / r;
  final double h2 = hx * hx + hy * hy + hz * hz;
  final double p = h2 / mu;
  final double hLen = math.sqrt(h2);
  // True anomaly of the node: angle from e to n, positive along the motion.
  final double cosNu = ex * nx + ey * ny;
  // (e x n) . h with n_z = 0.
  final double sinNu =
      (-ez * ny * hx + ez * nx * hy + (ex * ny - ey * nx) * hz) / hLen;
  final double eLen = math.sqrt(ex * ex + ey * ey + ez * ez);
  final double nu = math.atan2(sinNu, cosNu);
  final double dist = p / (1 + eLen * math.cos(nu));
  final double tc = t.tt / 36525.0;
  return _LonLatDist(
    _norm360(lon + _meanNodeMeanEquinox(tc) - _aeTheoryMeanNode(tc)),
    0.0,
    dist,
  );
}

/// Secular part of the mean node implied by the mean arguments of Astronomy
/// Engine's lunar theory (mean longitude L0 minus argument of latitude F in
/// `CalcMoon`), degrees.
double _aeTheoryMeanNode(double t) =>
    360.0 *
    ((0.60643382 - 0.25909118) +
        (1336.85522467 - 1342.22782980) * t +
        (-0.00000313 + 0.00000892) * t * t);

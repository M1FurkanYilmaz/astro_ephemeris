// Astrological house cusps, pure Dart.
//
// Written from the standard published definitions of the house systems
// (J. Meeus, "Astronomical Algorithms", 2nd ed., ch. 13 for the coordinate
// transformations; R. W. Holden, "The Elements of House Division", for the
// definitions of the individual systems). The quadrant systems are solved with
// plain spherical geometry: each house circle is a great circle through the
// north and south points of the horizon, and the cusp is the eastern
// intersection of that circle with the ecliptic. Placidus is solved by
// fixed-point iteration on the semi-arc condition; Koch is closed form.
//
// Conventions (checked by test/core/ephemeris_houses_test.dart and
// test/houses/houses_test.dart):
//  * Longitudes are ecliptic of date (true equinox), degrees in [0, 360).
//  * Equal: 30° steps from the Ascendant. Whole sign: cusp 1 = 0° of the
//    Ascendant's sign.
//  * Placidus and Koch are undefined when |lat| >= 90° − ε (the polar circle).
//    There the result is Porphyry and [HouseCusps.usedFallback] is true
//    (the usual convention for the polar case).
//  * Beyond the polar circle the eastern horizon/ecliptic intersection can lie
//    west of the MC (this happens exactly when the MC is below the horizon).
//    Then the Ascendant is replaced by its opposite point. For Campanus and
//    Regiomontanus the MC is replaced by the IC as well; the intermediate cusps
//    of those two systems are unchanged. Equal, Whole sign and the Porphyry
//    fallback use the replaced Ascendant and the unreplaced MC.
//
// No Flutter imports: usable from isolates and plain `dart test`.

import 'dart:math' as math;

/// House systems supported by [computeHouses]. [code] is the conventional
/// single-letter identifier (the letters common in astrology software).
enum HouseSystem {
  placidus('P'),
  koch('K'),
  equal('E'),
  campanus('C'),
  regiomontanus('R'),
  wholeSign('W'),
  porphyry('O');

  const HouseSystem(this.code);

  /// Single-letter identifier ('P', 'K', 'E', 'C', 'R', 'W', 'O').
  final String code;

  /// The system with the given single-letter [code], or null.
  static HouseSystem? fromCode(String code) {
    for (final s in HouseSystem.values) {
      if (s.code == code) return s;
    }
    return null;
  }

  /// Quadrant systems have cusp 1 = Ascendant and cusp 10 = MC.
  bool get isQuadrant =>
      this != HouseSystem.equal && this != HouseSystem.wholeSign;
}

/// Result of [computeHouses].
class HouseCusps {
  const HouseCusps._({
    required this.cusps,
    required this.ascendant,
    required this.mc,
    required this.armc,
    required this.vertex,
    required this.requestedSystem,
    required this.system,
    required this.polarFlip,
  });

  /// The 12 cusps, index 0 = house 1 ... index 11 = house 12. Degrees, [0, 360).
  final List<double> cusps;

  /// Ascendant, degrees. Equals cusp 1 for every system except Whole sign.
  final double ascendant;

  /// Midheaven, degrees. Equals cusp 10 for the quadrant systems.
  final double mc;

  /// ARMC used, degrees in [0, 360).
  final double armc;

  /// Vertex (western intersection of the prime vertical with the ecliptic).
  final double vertex;

  /// System that was asked for.
  final HouseSystem requestedSystem;

  /// System that was actually computed (Porphyry after a polar fallback).
  final HouseSystem system;

  /// True beyond the polar circle when the Ascendant (and, for Campanus and
  /// Regiomontanus, the MC) was replaced by its opposite point; see the file
  /// header. Always false for |lat| < 90° − ε.
  final bool polarFlip;

  /// True when Placidus/Koch could not be computed (|lat| >= 90° − ε) and
  /// Porphyry cusps were returned instead.
  bool get usedFallback => system != requestedSystem;

  /// Cusp of [house] (1..12).
  double cusp(int house) {
    if (house < 1 || house > 12) {
      throw RangeError.range(house, 1, 12, 'house');
    }
    return cusps[house - 1];
  }

  @override
  String toString() => 'HouseCusps(${system.code}'
      '${usedFallback ? ' fallback from ${requestedSystem.code}' : ''}, '
      'asc: $ascendant, mc: $mc, cusps: $cusps)';
}

/// ARMC (right ascension of the MC) in degrees from Greenwich apparent sidereal
/// time in hours and geographic longitude in degrees (east positive).
double armcFromGast({required double gastHours, required double lonEastDeg}) =>
    _norm(gastHours * 15.0 + lonEastDeg);

/// Computes the house cusps.
///
/// [armcDeg]: right ascension of the MC (= GAST·15 + east longitude), degrees.
/// [latDeg]: geographic latitude, north positive, in [-90, 90].
/// [trueObliquityDeg]: true obliquity of the ecliptic of date, degrees.
HouseCusps computeHouses({
  required double armcDeg,
  required double latDeg,
  required double trueObliquityDeg,
  required HouseSystem system,
}) {
  if (!armcDeg.isFinite || !trueObliquityDeg.isFinite || !latDeg.isFinite) {
    throw ArgumentError(
      'computeHouses: non-finite input '
      '(armc $armcDeg, lat $latDeg, obliquity $trueObliquityDeg)',
    );
  }
  if (latDeg.abs() > 90.0) {
    throw ArgumentError.value(latDeg, 'latDeg', 'must be within [-90, 90]');
  }
  final armc = _norm(armcDeg);
  final g = _Geometry(armc, latDeg, trueObliquityDeg);

  var asc = g.ascendantAt(armc);
  var mc = g.mc();
  // Beyond the polar circle the eastern intersection can fall west of the MC
  // (MC below the horizon); see the file header.
  final polarFlip = _norm(asc - mc) > 180.0;
  if (polarFlip) {
    asc = _norm(asc + 180.0);
    if (system == HouseSystem.campanus || system == HouseSystem.regiomontanus) {
      mc = _norm(mc + 180.0);
    }
  }

  var used = system;
  if ((system == HouseSystem.placidus || system == HouseSystem.koch) &&
      latDeg.abs() >= 90.0 - trueObliquityDeg) {
    used = HouseSystem.porphyry;
  }

  final List<double> cusps;
  switch (used) {
    case HouseSystem.equal:
      cusps = List<double>.generate(12, (i) => _norm(asc + 30.0 * i));
    case HouseSystem.wholeSign:
      final start = (asc / 30.0).floorToDouble() * 30.0;
      cusps = List<double>.generate(12, (i) => _norm(start + 30.0 * i));
    case HouseSystem.porphyry:
      // Trisect the ecliptic arcs MC→Asc and Asc→IC.
      final upper = _norm(asc - mc);
      final lower = 180.0 - upper;
      cusps = _fromEastern(
        asc: asc,
        mc: mc,
        c11: mc + upper / 3.0,
        c12: mc + 2.0 * upper / 3.0,
        c2: asc + lower / 3.0,
        c3: asc + 2.0 * lower / 3.0,
      );
    case HouseSystem.campanus:
      // House circles through the N/S horizon points that divide the prime
      // vertical into 30° arcs, counted from the zenith towards the east.
      cusps = _fromEastern(
        asc: asc,
        mc: mc,
        c11: g.cuspThroughPrimeVertical(30.0),
        c12: g.cuspThroughPrimeVertical(60.0),
        c2: g.cuspThroughPrimeVertical(120.0),
        c3: g.cuspThroughPrimeVertical(150.0),
      );
    case HouseSystem.regiomontanus:
      // House circles through the N/S horizon points that divide the celestial
      // equator into 30° arcs, counted from the upper meridian.
      cusps = _fromEastern(
        asc: asc,
        mc: mc,
        c11: g.cuspThroughEquator(30.0),
        c12: g.cuspThroughEquator(60.0),
        c2: g.cuspThroughEquator(120.0),
        c3: g.cuspThroughEquator(150.0),
      );
    case HouseSystem.koch:
      // Koch (birthplace): trisect the time the MC degree needs to rise to
      // the meridian (its diurnal semi-arc at the birthplace latitude); the
      // cusps are the Ascendants of those intermediate sidereal times.
      final dsa = 90.0 + g.ascensionalDifference(g.declinationOf(mc));
      cusps = _fromEastern(
        asc: asc,
        mc: mc,
        c11: g.ascendantAt(armc - 2.0 * dsa / 3.0),
        c12: g.ascendantAt(armc - dsa / 3.0),
        c2: g.ascendantAt(armc + dsa / 3.0),
        c3: g.ascendantAt(armc + 2.0 * dsa / 3.0),
      );
    case HouseSystem.placidus:
      // Placidus: cusp 11/12 trisect the diurnal semi-arc of their own
      // ecliptic degree (hour angle -1/3 and -2/3 of it); cusp 2/3 trisect the
      // nocturnal semi-arc measured from the lower meridian.
      cusps = _fromEastern(
        asc: asc,
        mc: mc,
        c11: g.placidusCusp(1.0 / 3.0, upper: true),
        c12: g.placidusCusp(2.0 / 3.0, upper: true),
        c2: g.placidusCusp(2.0 / 3.0, upper: false),
        c3: g.placidusCusp(1.0 / 3.0, upper: false),
      );
  }

  return HouseCusps._(
    cusps: List<double>.unmodifiable(cusps),
    ascendant: asc,
    mc: mc,
    armc: armc,
    vertex: g.vertex(),
    requestedSystem: system,
    system: used,
    polarFlip: polarFlip,
  );
}

/// Builds the 12 cusps from the eastern ones; the western cusps are opposite.
List<double> _fromEastern({
  required double asc,
  required double mc,
  required double c11,
  required double c12,
  required double c2,
  required double c3,
}) {
  final c = List<double>.filled(12, 0.0);
  c[0] = _norm(asc);
  c[1] = _norm(c2);
  c[2] = _norm(c3);
  c[9] = _norm(mc);
  c[10] = _norm(c11);
  c[11] = _norm(c12);
  for (final i in const [0, 1, 2]) {
    c[i + 6] = _norm(c[i] + 180.0);
  }
  for (final i in const [9, 10, 11]) {
    c[i - 6] = _norm(c[i] + 180.0);
  }
  return c;
}

const double _d2r = math.pi / 180.0;
const double _r2d = 180.0 / math.pi;

/// Angle normalised to [0, 360).
double _norm(double deg) {
  var r = deg % 360.0;
  if (r < 0) r += 360.0;
  if (r >= 360.0) r -= 360.0;
  return r;
}

double _clampUnit(double x) => x > 1.0 ? 1.0 : (x < -1.0 ? -1.0 : x);

/// Unit vectors in the equatorial frame of date (x = vernal equinox,
/// z = north celestial pole) for one place and sidereal time.
class _Geometry {
  _Geometry(this.armc, this.lat, this.eps)
      : _sinE = math.sin(eps * _d2r),
        _cosE = math.cos(eps * _d2r),
        _tanLat = math.tan(lat * _d2r) {
    final t = armc * _d2r;
    final f = lat * _d2r;
    final st = math.sin(t), ct = math.cos(t);
    final sf = math.sin(f), cf = math.cos(f);
    _zenith = [cf * ct, cf * st, sf];
    _north = [-sf * ct, -sf * st, cf]; // north point of the horizon
    _east = [-st, ct, 0.0]; // east point of the horizon
    _eclipticPole = [0.0, -_sinE, _cosE];
  }

  final double armc, lat, eps;
  final double _sinE, _cosE, _tanLat;
  late final List<double> _zenith, _north, _east, _eclipticPole;

  /// Eastern intersection of the ecliptic with the horizon of this latitude
  /// for sidereal angle [ramc] (the classic Ascendant formula).
  double ascendantAt(double ramc) {
    final t = ramc * _d2r;
    return _norm(
      math.atan2(math.cos(t), -(math.sin(t) * _cosE + _tanLat * _sinE)) * _r2d,
    );
  }

  /// Ecliptic point on the upper meridian (right ascension = ARMC).
  double mc() {
    final t = armc * _d2r;
    return _norm(math.atan2(math.sin(t), math.cos(t) * _cosE) * _r2d);
  }

  /// Declination of the ecliptic point at longitude [lonDeg] (latitude 0).
  double declinationOf(double lonDeg) =>
      math.asin(_clampUnit(_sinE * math.sin(lonDeg * _d2r))) * _r2d;

  /// Ascensional difference (degrees) of a point with declination [decDeg]:
  /// diurnal semi-arc = 90° + AD.
  double ascensionalDifference(double decDeg) =>
      math.asin(_clampUnit(_tanLat * math.tan(decDeg * _d2r))) * _r2d;

  /// Ecliptic longitude of the point with right ascension [raDeg].
  double _lonFromRa(double raDeg) {
    final a = raDeg * _d2r;
    return math.atan2(math.sin(a), math.cos(a) * _cosE) * _r2d;
  }

  double placidusCusp(double fraction, {required bool upper}) {
    // Unknown: right ascension of the cusp. Fixed-point iteration converges
    // everywhere inside the polar circle (< 100 steps at its edge).
    var ra = upper ? armc + fraction * 90.0 : armc + 180.0 - fraction * 90.0;
    for (var i = 0; i < 1000; i++) {
      final ad = ascensionalDifference(declinationOf(_lonFromRa(ra)));
      final next = upper
          ? armc + fraction * (90.0 + ad)
          : armc + 180.0 - fraction * (90.0 - ad);
      final done = (next - ra).abs() < 1e-11;
      ra = next;
      if (done) break;
    }
    return _norm(_lonFromRa(ra));
  }

  double cuspThroughPrimeVertical(double fromZenithDeg) {
    final h = fromZenithDeg * _d2r;
    final c = math.cos(h), s = math.sin(h);
    return _houseCircleCusp([
      c * _zenith[0] + s * _east[0],
      c * _zenith[1] + s * _east[1],
      c * _zenith[2] + s * _east[2],
    ]);
  }

  double cuspThroughEquator(double fromMeridianDeg) {
    final a = (armc + fromMeridianDeg) * _d2r;
    return _houseCircleCusp([math.cos(a), math.sin(a), 0.0]);
  }

  /// Eastern intersection with the ecliptic of the great circle through the
  /// north/south horizon points and [p].
  double _houseCircleCusp(List<double> p) {
    final normal = _cross(_north, p);
    final d = _cross(normal, _eclipticPole);
    final sign = _dot(d, _east) < 0 ? -1.0 : 1.0;
    return _eclipticLon(d, sign);
  }

  /// Western intersection of the prime vertical with the ecliptic.
  double vertex() {
    final d = _cross(_north, _eclipticPole);
    final sign = _dot(d, _east) > 0 ? -1.0 : 1.0;
    return _eclipticLon(d, sign);
  }

  double _eclipticLon(List<double> d, double sign) {
    final y = sign * (d[1] * _cosE + d[2] * _sinE);
    final x = sign * d[0];
    return _norm(math.atan2(y, x) * _r2d);
  }

  static List<double> _cross(List<double> a, List<double> b) => [
        a[1] * b[2] - a[2] * b[1],
        a[2] * b[0] - a[0] * b[2],
        a[0] * b[1] - a[1] * b[0],
      ];

  static double _dot(List<double> a, List<double> b) =>
      a[0] * b[0] + a[1] * b[1] + a[2] * b[2];
}

/// Heliocentric position and velocity of 2060 Chiron (95P) from a compact
/// Chebyshev table fitted to NASA/JPL Horizons. Pure Dart, no Flutter.
///
/// Data: NASA/JPL Horizons On-Line Ephemeris System (Giorgini & JPL Solar
/// System Dynamics Group), orbit solution JPL#171, retrieved 2026-11-04.
/// Courtesy NASA/JPL-Caltech. Table, fit and checks: `chiron_table.dart`,
/// `tool/chiron/README.md`.
///
/// Covered range: JD TDB [kChironJdStart, kChironJdEnd] =
/// 1800-01-01 00:00 TDB .. 2201-08-15 00:00 TDB. Outside it [chironHelioEqj]
/// throws a [RangeError].
///
/// Frame: ICRF axes = J2000 mean equator (Astronomy Engine EQJ), origin the
/// Sun's body centre (Astronomy Engine's heliocentric convention), geometric
/// (no light time, no aberration). Units AU and AU/day. Accuracy vs Horizons:
/// position <= 2e-9 AU, velocity <= 4e-10 AU/day (5000 held-out epochs).
library;

import 'dart:convert' show base64;
import 'dart:typed_data';

import 'chiron_table.dart';

export 'chiron_table.dart' show kChironJdStart, kChironJdEnd;

/// Heliocentric EQJ state of Chiron: position (AU) and velocity (AU/day).
class ChironStateHelio {
  const ChironStateHelio(this.x, this.y, this.z, this.vx, this.vy, this.vz);

  final double x;
  final double y;
  final double z;
  final double vx;
  final double vy;
  final double vz;

  @override
  String toString() => 'ChironStateHelio($x, $y, $z; $vx, $vy, $vz)';
}

Float64List? _coefficients;

/// Decoded once per isolate (316 KB of float64).
Float64List _table() {
  final Float64List? cached = _coefficients;
  if (cached != null) return cached;
  final Uint8List bytes = base64.decode(kChironCoefficientsB64);
  final ByteData data = ByteData.sublistView(bytes);
  final int n = bytes.length ~/ 8;
  final Float64List out = Float64List(n);
  for (int i = 0; i < n; i++) {
    out[i] = data.getFloat64(i * 8, Endian.little);
  }
  const int expected = kChironSegCount * 3 * (kChironDegree + 1);
  if (n != expected) {
    throw StateError('Chiron table has $n coefficients, expected $expected');
  }
  return _coefficients = out;
}

/// Heliocentric geometric state of Chiron at [jdTdb] (Julian Day, TDB; TT
/// may be used instead: |TDB - TT| < 2 ms moves Chiron < 1e-10 AU).
///
/// Throws [RangeError] when [jdTdb] is outside
/// [kChironJdStart, kChironJdEnd] (1800-01-01 .. 2201-08-15 TDB) or NaN.
ChironStateHelio chironHelioEqj(double jdTdb) {
  if (!(jdTdb >= kChironJdStart && jdTdb <= kChironJdEnd)) {
    throw RangeError.value(
      jdTdb,
      'jdTdb',
      'Chiron table covers JD TDB $kChironJdStart..$kChironJdEnd '
          '(1800-01-01..2201-08-15)',
    );
  }
  final Float64List c = _table();
  final double u = (jdTdb - kChironJdStart) / kChironSegDays;
  int seg = u.floor();
  if (seg >= kChironSegCount) seg = kChironSegCount - 1; // jdTdb == end
  final double x = 2.0 * (u - seg) - 1.0;

  // T_j(x) and T_j'(x) by the three-term recurrences, shared by all axes.
  const int n = kChironDegree + 1;
  final Float64List t = Float64List(n);
  final Float64List dt = Float64List(n);
  t[0] = 1.0;
  t[1] = x;
  dt[0] = 0.0;
  dt[1] = 1.0;
  for (int j = 2; j < n; j++) {
    t[j] = 2.0 * x * t[j - 1] - t[j - 2];
    dt[j] = 2.0 * t[j - 1] + 2.0 * x * dt[j - 1] - dt[j - 2];
  }

  final List<double> p = <double>[0, 0, 0];
  final List<double> v = <double>[0, 0, 0];
  const double dxdt = 2.0 / kChironSegDays; // d x / d day
  for (int axis = 0; axis < 3; axis++) {
    final int base = (seg * 3 + axis) * n;
    // Sum from the smallest terms up for a little less rounding error.
    double sp = 0.0;
    double sv = 0.0;
    for (int j = n - 1; j >= 0; j--) {
      final double cj = c[base + j];
      sp += cj * t[j];
      sv += cj * dt[j];
    }
    p[axis] = sp;
    v[axis] = sv * dxdt;
  }
  return ChironStateHelio(p[0], p[1], p[2], v[0], v[1], v[2]);
}

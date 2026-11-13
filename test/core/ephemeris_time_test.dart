// Time scales, Earth orientation and the equation of time of the ephemeris
// facade (lib/src/ephemeris.dart), against published constants and the Delta T
// source table. Positions are validated against JPL Horizons in
// test/horizons/.
// ignore_for_file: avoid_print

import 'dart:math' as math;

import 'package:test/test.dart';
import 'package:astro_ephemeris/src/delta_t_table.dart';
import 'package:astro_ephemeris/src/ephemeris.dart';

void main() {
  test(
      'Body ids are stable (Sun = 0 ... Pluto = 9, nodes 10-11, Lilith 12, Chiron 15)',
      () {
    expect(
      <int>[for (final Body b in Body.values) b.id],
      <int>[0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 15],
    );
    for (final Body b in Body.values) {
      expect(Body.fromId(b.id), b);
    }
    expect(Body.fromId(13), isNull);
  });

  test('julianDayUt round trip and epochs', () {
    expect(julianDayUt(DateTime.utc(2000, 1, 1, 12)), 2451545.0);
    expect(julianDayUt(DateTime.utc(1970)), 2440587.5);
    final DateTime d = DateTime.utc(1987, 7, 13, 4, 21, 9, 123, 456);
    // A double Julian Day resolves ~40 microseconds near the present.
    expect(
      dateTimeFromJulianDayUt(
        julianDayUt(d),
      ).difference(d).inMicroseconds.abs(),
      lessThan(50),
    );
  });

  test('Delta T reproduces the USNO/IERS table at its nodes', () {
    expect(deltaTTableUt.length, deltaTTableSeconds.length);
    for (int i = 0; i < deltaTTableUt.length; i += 7) {
      expect(
        deltaTSeconds(deltaTTableUt[i] + 2451545.0),
        closeTo(deltaTTableSeconds[i], 1e-6),
        reason: 'node $i',
      );
    }
  });

  test('Delta T model is continuous at the table edges', () {
    final double first = deltaTTableUt.first + 2451545.0;
    final double last = deltaTTableUt.last + 2451545.0;
    for (final double jd in <double>[first, last]) {
      final double a = deltaTSeconds(jd - 1e-6);
      final double b = deltaTSeconds(jd + 1e-6);
      expect((a - b).abs(), lessThan(1e-6), reason: 'value jump at $jd');
    }
    // Slope continuity at the end (C1 join of the extrapolation), s/day.
    const double h = 0.01;
    final double left = (deltaTSeconds(last) - deltaTSeconds(last - h)) / h;
    final double right = (deltaTSeconds(last + h) - deltaTSeconds(last)) / h;
    expect((left - right).abs(), lessThan(1e-6));
    expect(right, closeTo(deltaTEndSlopePerDay, 1e-6));
    // Plausible long-range values (no blow-up), and finite everywhere.
    for (double y = -500; y <= 3000; y += 50) {
      final double jd = 2451545.0 + (y - 2000) * 365.25;
      expect(deltaTSeconds(jd).isFinite, isTrue);
    }
    expect(deltaTSeconds(2451545.0), closeTo(63.83, 0.05));
  });

  test('sidereal time, obliquity and nutation against published constants', () {
    const double j2000 = 2451545.0;
    // GMST at 2000-01-01 12:00 UT = 18h 41m 50.5484s = 18.697374558 h (the
    // IAU 2006 value). GAST = GMST + equation of the equinoxes.
    final double ee = nutationLongitude(j2000) *
        math.cos(trueObliquity(j2000) * math.pi / 180) /
        15;
    expect(gastHours(j2000) - ee, closeTo(18.697374558, 1e-5));
    // Mean obliquity at J2000 (IAU 2006) = 84381.406 arcsec.
    expect(meanObliquity(j2000), closeTo(84381.406 / 3600, 1e-6));
    expect(nutationLongitude(j2000).abs() * 3600, lessThan(20));
    expect(
      trueObliquity(j2000) - meanObliquity(j2000),
      closeTo(nutationObliquity(j2000), 1e-9),
    );
    // Sidereal time gains 3m 56.555s per solar day (0.0657098 h).
    for (int i = 0; i < 100; i++) {
      final double jd = 2415020.5 + i * 733.7;
      final double gain = (gastHours(jd + 1) - gastHours(jd)) % 24.0;
      expect(gain, closeTo(0.0657098, 2e-5), reason: 'jd $jd');
    }
    // Mean obliquity decreases by ~46.8 arcsec per century.
    expect(
      (meanObliquity(j2000 + 36525) - meanObliquity(j2000)) * 3600,
      closeTo(-46.836769, 0.01),
    );
  });

  test('equation of time at published extremes and zero crossings', () {
    // Sign: +16 min in early November, -14 min in mid February.
    expect(
      equationOfTimeDays(julianDayUt(DateTime.utc(2024, 11, 3))) * 1440,
      closeTo(16.4, 0.2),
    );
    expect(
      equationOfTimeDays(julianDayUt(DateTime.utc(2024, 2, 11))) * 1440,
      closeTo(-14.2, 0.2),
    );
    // Zero near 16 April, 13 June, 1 September and 25 December.
    for (final DateTime d in <DateTime>[
      DateTime.utc(2024, 4, 15),
      DateTime.utc(2024, 6, 13),
      DateTime.utc(2024, 9, 1),
      DateTime.utc(2024, 12, 25),
    ]) {
      expect(equationOfTimeDays(julianDayUt(d)) * 1440, closeTo(0, 1.0),
          reason: '$d');
    }
  });
}

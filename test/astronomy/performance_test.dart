// Timing report for one chart's worth of positions (Sun..Pluto).
// The bounds are generous smoke limits for CI machines; the printed numbers
// are what matters. `flutter test` runs the Dart VM in JIT mode, so release
// (AOT) builds are faster than what is printed here.
// ignore_for_file: avoid_print

import 'package:test/test.dart';
import 'package:astro_ephemeris/src/astronomy/astronomy.dart';

const List<Body> _planets = [
  Body.sun,
  Body.mercury,
  Body.venus,
  Body.mars,
  Body.jupiter,
  Body.saturn,
  Body.uranus,
  Body.neptune,
  Body.pluto,
];

/// Apparent ecliptic longitudes of Sun..Pluto plus the Moon for one instant.
List<double> chartLongitudes(AstroTime t) {
  final List<double> out = [];
  for (final Body b in _planets) {
    out.add(ecliptic(geoVector(b, t, true)).elon);
  }
  out.add(eclipticGeoMoon(t).lon);
  return out;
}

double _ms(Stopwatch sw) => sw.elapsedMicroseconds / 1000.0;

void main() {
  test('10 bodies for one instant: cold and warm timings', () {
    final DateTime when = DateTime.utc(1990, 5, 17, 8, 30);

    final Stopwatch cold = Stopwatch()..start();
    final List<double> first = chartLongitudes(AstroTime.fromDateTime(when));
    cold.stop();

    // Same instant again (Pluto segment cached, code warmed up).
    final Stopwatch warm1 = Stopwatch()..start();
    chartLongitudes(AstroTime.fromDateTime(when));
    warm1.stop();

    // Warm loop over nearby instants (same Pluto segment).
    const int n = 200;
    final Stopwatch loop = Stopwatch()..start();
    for (int i = 0; i < n; i++) {
      chartLongitudes(AstroTime.fromDateTime(when).addDays(i * 0.37));
    }
    loop.stop();

    // A far instant whose Pluto segment is not cached yet.
    final Stopwatch newSeg = Stopwatch()..start();
    chartLongitudes(AstroTime.fromDateTime(DateTime.utc(2150, 1, 1)));
    newSeg.stop();

    print(
      'cold first call: ${_ms(cold).toStringAsFixed(1)} ms; '
      'same instant again: ${_ms(warm1).toStringAsFixed(2)} ms; '
      'warm average: ${(_ms(loop) / n).toStringAsFixed(3)} ms; '
      'new Pluto segment: ${_ms(newSeg).toStringAsFixed(1)} ms',
    );
    expect(first.length, 10);
    expect(_ms(loop) / n, lessThan(50));
    expect(_ms(cold), lessThan(5000));
  });
}

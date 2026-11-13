import 'package:astro_ephemeris/astro_ephemeris.dart';

void main() {
  // 2024-04-08 18:00 UTC.
  final when = DateTime.utc(2024, 4, 8, 18);
  final jd = julianDayUt(when);

  print('Ecliptic longitudes at $when (true equinox of date):');
  for (final body in Body.values) {
    final p = position(body, jd);
    print('  ${body.name.padRight(10)} ${p.longitude.toStringAsFixed(4)} deg'
        '${p.isRetrograde ? '  (retrograde)' : ''}');
  }

  // Placidus houses for Greenwich (51.4769 N, 0.0005 W).
  final cusps = houses(jd, 51.4769, -0.0005, HouseSystem.placidus);
  print('\nPlacidus cusps, Greenwich:');
  print('  Ascendant ${cusps.ascendant.toStringAsFixed(3)}, '
      'MC ${cusps.mc.toStringAsFixed(3)}');

  // Next eclipses after that instant.
  final solar = nextSolarEclipse(when);
  final lunar = nextLunarEclipse(when);
  print('\nNext solar eclipse: ${solar.kind.name} at ${solar.peakUtc}');
  print('Next lunar eclipse: ${lunar.kind.name} at ${lunar.peakUtc}');
}

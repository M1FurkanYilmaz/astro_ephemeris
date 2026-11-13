# astro_ephemeris

A pure-Dart astronomical ephemeris for astrology and astronomy software. No
native libraries, no asset files, no Flutter dependency: it runs wherever Dart
runs, including Flutter on iOS, Android, web and desktop, and inside isolates.

It is built on a Dart port of [Astronomy Engine](https://github.com/cosinekitty/astronomy)
by Don Cross (v2.1.19), plus an astrology-facing layer, a Chiron table fitted to
NASA/JPL Horizons data and an observed Delta T table. This package is not
affiliated with Astronomy Engine or its author.

## What it computes

- Geocentric, apparent positions (true ecliptic and equinox of date) with
  longitude, latitude, distance and longitude speed, plus a retrograde flag, for
  the Sun, Moon, Mercury to Pluto, mean node, true node, mean apogee (Lilith)
  and Chiron (1800 to 2201).
- House cusps: Placidus, Koch, Equal, Campanus, Regiomontanus, Whole Sign
  (Porphyry fallback beyond the polar circle, flagged in the result).
- Greenwich apparent sidereal time (IAU 2006), true and mean obliquity, IAU 2000B
  nutation, equation of time.
- Delta T (TT - UT1) from observed USNO/IERS values, with a documented
  extrapolation.
- Global solar and lunar eclipse search (total, annular, hybrid, partial,
  penumbral).
- The low-level Astronomy Engine port in `package:astro_ephemeris/astronomy.dart`.

Body ids use the numbering common in astrology software (`Body.sun` = 0, ... `Body.pluto` = 9,
nodes 10 and 11, mean apogee 12, `Body.chiron` = 15).

Not included: topocentric positions, rise/set times, asteroids other than
Chiron, fixed stars, Jupiter's moons, and everything else Astronomy Engine has
that was not ported (see below).

## Usage

```dart
import 'package:astro_ephemeris/astro_ephemeris.dart';

void main() {
  final jd = julianDayUt(DateTime.utc(2024, 4, 8, 18));

  final mars = position(Body.mars, jd);
  print('${mars.longitude} ${mars.speedLongitude} ${mars.isRetrograde}');

  final cusps = houses(jd, 51.4769, -0.0005, HouseSystem.placidus);
  print('ASC ${cusps.ascendant}, MC ${cusps.mc}');

  final next = nextSolarEclipse(DateTime.utc(2024, 4, 8, 18));
  print('${next.kind.name} ${next.peakUtc}');
}
```

See `example/astro_ephemeris_example.dart` for a longer one. Times are Julian
Days in UT (`julianDayUt`, `dateTimeFromJulianDayUt`). Delta T is installed
automatically on first use.

## Accuracy

Reference for positions: NASA/JPL Horizons (DE441 planets, JPL#171 for Chiron),
observer ephemeris at the geocentre, apparent ecliptic longitude and latitude
of date (Horizons quantity 31) and range (quantity 20), times in UT. The
fixtures are in `test/fixtures/horizons/`; `tool/horizons/fetch.py` regenerates
them, and `queries.json` holds the exact request parameters. One request was
made per series (never many single-epoch requests). The package uses its own
USNO/IERS Delta T table; Horizons applies its own Delta T.

Measured maximum differences, this package minus Horizons, 1975 samples per
body every 37 days from 1900-01-01 to 2100-01-01 (arcseconds; distance is
relative):

| Body | lon 1900-2025 | lon 2025-2050 | lon 2050-2100 | lat | distance |
|---|---|---|---|---|---|
| Sun | 2.26 | 2.01 | 2.77 | 1.85 | 1.4e-5 |
| Mercury | 12.09 | 8.75 | 12.13 | 8.58 | 5.0e-5 |
| Venus | 18.99 | 16.63 | 14.68 | 11.96 | 6.1e-5 |
| Mars | 10.54 | 12.52 | 12.70 | 15.44 | 8.4e-5 |
| Jupiter | 10.08 | 6.21 | 9.63 | 13.82 | 7.4e-5 |
| Saturn | 12.94 | 10.55 | 9.32 | 21.80 | 7.1e-5 |
| Uranus | 12.02 | 7.48 | 4.77 | 18.94 | 4.6e-5 |
| Neptune | 18.53 | 12.22 | 18.89 | 10.01 | 4.6e-5 |
| Pluto | 3.74 | 5.07 | 8.49 | 1.53 | 3.5e-5 |
| Chiron | 0.49 | 0.37 | 0.46 | 0.21 | 1.8e-6 |
| Moon (every 7.3 days, 10,007 samples) | 4.56 | 4.35 | 17.67 | 2.84 | 1.4e-4 |

Moon every 6 hours over 2024-2025 (2925 samples): longitude max 4.35, latitude
max 1.06 arcseconds. The Moon's longitude speed differs from a central
difference of the 6-hourly Horizons longitudes by at most 7.1 arcsec/day (95th
percentile 5.5); that includes the finite-difference error of the reference.

The planet residuals come mainly from Astronomy Engine's truncated VSOP87
series and its Pluto integrator compared with DE441. The Moon's growth after
2050 (up to 17.7 arcsec in 2075-2100) appears only in the future, where Delta T
is extrapolated and the two sources diverge; the Moon moves about 0.5
arcsec per second of time. Chiron is lower because its table is fitted
directly to Horizons.

**Chiron table fit**: on 5000 held-out random epochs the fit error is at most
1.9e-9 AU in position and 3.9e-10 AU/day in velocity
(`test/fixtures/chiron/horizons_holdout.csv.gz`, `tool/chiron/README.md`).

**Astronomy Engine port**: against the official `astronomy-engine==2.1.19`
Python package on 2000 instants from 1800 to 2200, the maximum difference is
4.2e-13 AU for geocentric vectors and 3.5e-11 degrees for ecliptic longitude;
the Moon, time scales and sidereal time are bit-identical
(`test/fixtures/astronomy_engine_golden/`). The same package's 454 solar and
459 lunar eclipses from 1900 to 2100 are reproduced with identical sequence
and kinds, peak times within 0.0005 s (before the NASA-convention adjustments
described below).

**Delta T**: the table reproduces the USNO/IERS values at its nodes (tested),
is continuous in value and slope where the extrapolation starts, and gives
63.83 s at J2000.

**Sidereal time, obliquity, nutation, equation of time**: tested against
published constants (GMST 18.697374558 h and mean obliquity 84381.406 arcsec at
J2000, the daily sidereal gain of 0.0657098 h, the equation of time at its
published extremes and zeros), not against an ephemeris.

**Houses**: no external reference data is used. The tests check the
ascendant and midheaven against Meeus' closed-form formulas (maximum difference
3.4e-13 degrees over 2000 random cases), equal and whole-sign houses against
their definitions, Placidus cusps against the semi-arc condition (maximum
residual 4.7e-12 degrees), and structural invariants for all six systems.

**Lunar points**: the mean node, true node and mean apogee have no Horizons
counterpart and were not compared with an external ephemeris. The tests check
the mean node and mean apogee against Meeus' published mean elements at J2000
and the node motion, and that the true node stays within 2.2 degrees of the mean
node.

**Eclipses**: the tests check peak times of four well-known eclipses against
published greatest-eclipse times (differences under 10 seconds: 2017-08-21,
2023-10-14, 2024-04-08 and the lunar 2022-11-08). Hybrid and non-central
solar eclipses, and three grazing lunar eclipses (1900-06-13, 1988-03-03,
2042-09-29) that are penumbral in NASA's Five Millennium Canon, follow NASA's
catalogue conventions; the 2005, 2013, 2023 and 2031 hybrids are checked
explicitly. A full eclipse-by-eclipse comparison with the NASA catalogue is not
part of the test suite.

**Speed**: one chart (13 bodies with speeds plus Placidus houses) took about
0.9 ms on the development machine.

## Known limits

- Astronomy Engine does not model the Sun's gravitational light deflection. It
  matters only within a few degrees of the Sun.
- Planet distances are light-time distances (no aberration); the measured
  differences from Horizons are in the table above.
- Chiron is only available from 1800 to 2201 (a `RangeError` outside).
- Delta T after the last observation is extrapolated; the table needs a yearly
  refresh (`python3 tool/deltat/gen_deltat.py --fetch`).
- Nothing here is certified for navigation or scientific publication.

## Layout

`lib/src/astronomy/` is the Astronomy Engine port (with its generated tables),
`lib/src/chiron/` the Chebyshev table and evaluator, `lib/src/houses/` the house
math, `lib/src/eclipses/` the eclipse classification, `lib/src/ephemeris.dart`
the public facade. `tool/` holds the generators for the Delta T and Chiron
tables and the Horizons test fixtures. Tests: `dart test` (the fixtures are about 3 MB).

## Credits

- Astronomy Engine by Don Cross, MIT licence (https://github.com/cosinekitty/astronomy).
- Chiron data: NASA/JPL Horizons On-Line Ephemeris System (Giorgini and JPL Solar
  System Dynamics Group). Courtesy NASA/JPL-Caltech.
- Delta T: US Naval Observatory and IERS observations; extrapolation curvature
  from Stephenson, Morrison and Hohenkerk (2016); pre-1657 from Espenak and Meeus.
- Mean lunar elements: J. Meeus, Astronomical Algorithms, 2nd ed.

## Licence

MIT. See `LICENSE`; it keeps Don Cross's copyright and permission notice for the
ported code and adds the notice for this package's own code.

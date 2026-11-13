# Chiron (2060 Chiron = 95P) from NASA/JPL Horizons

Chiron (2060 Chiron = 95P) table for the Astronomy Engine pipeline.
Output: `lib/src/chiron/` (`chiron_table.dart` generated,
`chiron.dart` table evaluator, `chiron_geo.dart` apparent geocentric position
via the Astronomy Engine port). Tests: `test/chiron/`.

Data: NASA/JPL Horizons On-Line Ephemeris System (Giorgini & JPL Solar System
Dynamics Group), retrieved 2026-11-04. Courtesy NASA/JPL-Caltech. Orbit
solution **JPL#171** (soln. date 2026-06-05, 6026 obs 1895-2026), planets
DE441, small-body perturbers SB441-N16. NASA/JPL data is not copyrighted;
the credit line is the one JPL asks for.

## Reproduce
```
python3 -m venv venv && venv/bin/pip install numpy astronomy-engine==2.1.19
cd tool/chiron
../../venv/bin/python fetch_horizons.py grid  RAW        # 1 request, 2-day states 1800-01-01..2201-08-15 TDB
../../venv/bin/python fetch_horizons.py tlist RAWT 5000  # 103 requests, held-out random epochs
../../venv/bin/python fit_chiron.py RAW/grid.txt RAWT \
    ../../lib/src/chiron/chiron_table.dart \
    ../../test/fixtures/chiron/horizons_holdout.csv.gz coef.npy
# apparent-position check data: python3 ../horizons/fetch.py (test/fixtures/horizons/chiron.csv.gz)
```
Horizons query: `COMMAND='2060;'` (the numbered asteroid; `DES=2060;` finds
nothing), `EPHEM_TYPE=VECTORS CENTER='500@10'` (Sun body centre = Astronomy
Engine's heliocentric origin) `REF_PLANE=FRAME REF_SYSTEM=ICRF` (= EQJ)
`OUT_UNITS=AU-D VEC_TABLE=2 VEC_CORR=NONE TIME_TYPE=TDB CSV_FORMAT=YES`.
A newer orbit solution changes the numbers by far less than the
differences below; refit when JPL publishes one you want.

## Table
573 segments x 256 days (JD TDB 2378496.5 .. 2525184.5 = 1800-01-01 ..
2201-08-15), Chebyshev degree 22 per axis, fitted by weighted least squares
to positions and velocities (2-day grid, 8-day overhang per side). 39,537
float64 = 316 KB, stored losslessly as base64 (462 KB source, decoded once).

| check | max |
|---|---|
| fitted epochs (73,345) | 1.9e-9 AU position, 3.9e-10 AU/day velocity |
| 5000 held-out random epochs (`test/fixtures/chiron/horizons_holdout.csv.gz`) | 1.9e-9 AU, 3.9e-10 AU/day |
| jump at segment joints | 2.2e-10 AU |

1e-9 AU is 0.00005" seen from the Sun. Residuals are unbiased; what remains
is mostly the Sun's 88-/225-/365-day reflex motion (Mercury, Venus, Earth),
which a heliocentric table has to carry.

**Horizons reproducibility trap.** Every Horizons request is its own
numerical integration from the solution epoch (2017) to the request's first
epoch. Two requests with different start epochs disagree by up to 8e-8 AU
(~0.1-0.2 s along-track) on the same instant: chunked fetches show steps at
the chunk joints. So the table comes from ONE request, and every held-out
TLIST request starts with the grid's first epoch (that row is dropped),
which reproduces the grid run bit-for-bit / to 1e-9 AU. Irrelevant
astronomically (Chiron's orbit uncertainty is far larger), but it would
otherwise mask the fit error.

## Apparent geocentric position vs JPL Horizons
`chironGeoEclipticOfDate` = Astronomy Engine's `Ecliptic(GeoVector(body, t,
true))` path (light time with the Earth back-dated too = AE's first-order
aberration; EQJ -> true ecliptic of date), Chiron from the table (TT used as
TDB), distance = light-time distance without aberration, speed = central
difference +-0.01 d. Compared with Horizons' observer ephemeris (quantities 20
and 31, geocentre, UT; `tool/horizons/fetch.py`, 1975 rows every 37 days,
1900-2100), observed Delta T:

| | max |
|---|---|
| longitude | 0.49" (p95 0.31") |
| latitude | 0.21" |
| distance, relative | 1.8e-6 |

The remainder is the IAU 1976/80 ecliptic Horizons uses vs Astronomy Engine's
IAU 2006/2000B (a slow drift of ~0.2" over 200 years), solar light deflection
(not modelled by Astronomy Engine, up to ~0.3" within a few degrees of the
Sun), the first-order aberration, and Astronomy Engine's truncated VSOP87 Earth
(up to ~1.4e-5 AU from DE441, ~0.3").

## Upstream (Astronomy Engine) assessment
Astronomy Engine has no asteroids: the maintainer pointed people to
Stellarium for minor bodies (issue #349) and added `GravitySimulator` (#207)
so users can integrate their own small bodies from a state vector. A
contribution that fits that philosophy and the project's multi-language
layout (C, C#, JS/TS, Python, Kotlin, generated from shared templates):

1. **Data, not code, per body**: a language-neutral Chebyshev table format
   (plain text: JD start, segment length, degree, coefficients) plus the
   Python generator in `generate/` that fetches Horizons (one request, the
   trap above) and fits it, with the held-out check. Chiron would be the
   example body; the same tool works for Ceres, Pallas, Juno, Vesta, Pholus,
   Eris...
2. **One small evaluator per language** (~40 lines: segment lookup + Chebyshev
   value/derivative), returning a heliocentric EQJ `StateVector`, and a hook
   so `HelioVector`/`GeoVector`/`BackdatePosition` accept such a "table body"
   like they accept user-defined stars (`DefineStar`).
3. Tests against held-out Horizons epochs, as here.

Open questions for the maintainer: table size (316 KB per body for 400 years
at 1e-9 AU; ~1e-7 AU would be ample for astrology/astronomy display and much
smaller), whether bundled data for specific bodies is welcome at all, and the
JPL credit line. Nothing has been filed upstream.

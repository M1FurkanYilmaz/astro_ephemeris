# Astronomy Engine goldens (data only)

`golden.json.gz` holds reference values computed by the **official Astronomy Engine
Python package, `astronomy-engine==2.1.19` from PyPI** (same release as the TypeScript
source ported to `lib/src/astronomy/`). It is consumed by
`test/astronomy/golden_test.dart`.

## How it was produced
Generator: `tool/golden/gen_golden.py`, run with
`python -I` in a venv holding only `astronomy-engine==2.1.19` (Python 3.13). Output is
deterministic (fixed seed, gzip mtime 0).

Instants (`ut` = UT days since J2000, 2000-01-01T12:00Z): 0, 1900-01-01, 2100-01-01,
-0.5, 9131.25, 17 tropical years; then uniform random in [1900, 2100) up to 1980
instants (`random.Random(20261104)`), plus 10 in 1800 and 10 in 2200.

Per instant (`records[]`):
* `ut`, `tt`, `deltaT` (`DeltaT_EspenakMeeus`, s), `gast` (`SiderealTime`, sidereal hours)
* `tilt` = `[mobl deg, tobl deg, dpsi arcsec, deps arcsec, ee s]` (`_e_tilt`)
* `geo[body]` for Sun, Moon, Mercury..Pluto: `ab` = `GeoVector(body, t, True)`,
  `noab` = `GeoVector(body, t, False)` (EQJ, AU), `ecl` = `Ecliptic(GeoVector(body, t, True))`
  as `[elon, elat, |vector|]`
* `helio[body]` = `HelioVector` (EQJ, AU) for Mercury..Pluto, Earth, Moon, EMB, SSB,
  on every 10th record only (size)
* `moonEcl` = `EclipticGeoMoon` `[lon, lat, dist]`; `moonState` = `GeoMoonState`
  `[x, y, z, vx, vy, vz]` (AU, AU/day); `sunPos` = `SunPosition` `[elon, elat]`

Numbers are full double precision (Python `repr`). Note: Python >= 3.12 sums floats
with compensated summation inside `_VsopFormula`, so the oracle's VSOP values can
differ from naive summation (JS/Dart) in the last bits; observed effect <= 4.2e-13 AU.

## `eclipses.json.gz`
Generator: `tool/golden/gen_eclipse_golden.py` (same venv, `python -I`,
gzip mtime 0). Every global solar eclipse (`SearchGlobalSolarEclipse(1900-01-01)` then
`NextGlobalSolarEclipse(prev.peak)`) and lunar eclipse (`SearchLunarEclipse` /
`NextLunarEclipse`) with peak before 2101-01-01 UT: 454 solar (163 partial, 149 total,
142 annular) and 459 lunar (168 penumbral, 166 total, 125 partial).
* `solar[]`: `ut`, `tt` (days since J2000), `iso`, `kind`, `obscuration` (null for
  partial), `distance` (km, shadow axis to Earth centre), `latitude`/`longitude`
  (null for partial).
* `lunar[]`: `ut`, `tt`, `iso`, `kind`, `obscuration`, `sd_penum`, `sd_partial`,
  `sd_total` (minutes).
Consumed by `test/eclipses/astronomy_golden_test.dart` and
`eclipses_api_test.dart`.

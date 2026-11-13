#!/usr/bin/env python3
"""Generate Astronomy Engine golden values for the Dart port's tests.

Run with the oracle venv:  ae-venv/bin/python -I gen_golden.py <out.json.gz>
Oracle: PyPI astronomy-engine==2.1.19 (same release as the ported TS source).
"""
import gzip
import json
import random
import sys

import astronomy as A
import astronomy.astronomy as AI  # internal helpers (_e_tilt) for e_tilt values

BODIES = ['Sun', 'Moon', 'Mercury', 'Venus', 'Mars', 'Jupiter', 'Saturn',
          'Uranus', 'Neptune', 'Pluto']
HELIO = ['Mercury', 'Venus', 'Earth', 'Mars', 'Jupiter', 'Saturn', 'Uranus',
         'Neptune', 'Pluto', 'Moon', 'EMB', 'SSB']

J1900 = -36524.5          # 1900-01-01T00:00Z in UT days since J2000
J2100 = 36525.5           # 2100-01-01T00:00Z
J1800 = -73048.5          # 1800-01-01T00:00Z
J2200 = 73049.5           # 2200-01-01T00:00Z


def instants():
    rng = random.Random(20261104)
    uts = [0.0, J1900, J2100, -0.5, 9131.25, 17.0 * 365.24217]
    while len(uts) < 1980:
        uts.append(rng.uniform(J1900, J2100))
    for _ in range(10):
        uts.append(J1800 + rng.uniform(0.0, 366.0))
    for _ in range(10):
        uts.append(J2200 + rng.uniform(0.0, 366.0))
    return uts


def vec3(v):
    return [v.x, v.y, v.z]


def main():
    out_path = sys.argv[1]
    records = []
    for index, ut in enumerate(instants()):
        t = A.Time(ut)
        et = AI._e_tilt(t)
        rec = {
            'ut': ut,
            'tt': t.tt,
            'deltaT': A.DeltaT_EspenakMeeus(ut),
            'gast': A.SiderealTime(A.Time(ut)),
            'tilt': [et.mobl, et.tobl, et.dpsi, et.deps, et.ee],
            'geo': {},
            'helio': {},   # filled on every 10th record only (size)
        }
        for name in BODIES:
            body = A.Body[name]
            ab = A.GeoVector(body, A.Time(ut), True)
            noab = A.GeoVector(body, A.Time(ut), False)
            ecl = A.Ecliptic(ab)
            rec['geo'][name] = {
                'ab': vec3(ab),
                'noab': vec3(noab),
                'ecl': [ecl.elon, ecl.elat, ab.Length()],
            }
        for name in (HELIO if index % 10 == 0 else []):
            rec['helio'][name] = vec3(A.HelioVector(A.Body[name], A.Time(ut)))
        m = A.EclipticGeoMoon(A.Time(ut))
        rec['moonEcl'] = [m.lon, m.lat, m.dist]
        s = A.GeoMoonState(A.Time(ut))
        rec['moonState'] = [s.x, s.y, s.z, s.vx, s.vy, s.vz]
        sp = A.SunPosition(A.Time(ut))
        rec['sunPos'] = [sp.elon, sp.elat]
        records.append(rec)

    doc = {
        'generator': 'astronomy-engine (PyPI) ' + getattr(A, '__version__', '2.1.19'),
        'notes': 'ut = UT days since J2000 (2000-01-01T12:00Z). Vectors EQJ, AU; '
                 'moonState velocity AU/day; angles degrees; gast sidereal hours; '
                 'tilt = [mobl deg, tobl deg, dpsi arcsec, deps arcsec, ee sec]; '
                 'ecl = Ecliptic(GeoVector(body, aberration=True)) [elon, elat, dist].',
        'records': records,
    }
    data = json.dumps(doc, separators=(',', ':')).encode('utf-8')
    with open(out_path, 'wb') as raw:
        with gzip.GzipFile(fileobj=raw, mode='wb', compresslevel=9, mtime=0) as f:
            f.write(data)
    print(f'wrote {len(records)} records to {out_path}')


if __name__ == '__main__':
    main()

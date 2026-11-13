#!/usr/bin/env python3
"""Fetch 2060 Chiron heliocentric ICRF state vectors from the NASA/JPL
Horizons API.

  fetch_horizons.py grid OUT_DIR        2-day grid over the whole range in ONE
                                        request -> OUT_DIR/grid.txt
  fetch_horizons.py tlist OUT_DIR N     N random fractional epochs (seed 2060)
                                        for the held-out test fixture

Output: OUT_DIR/*.txt = the full Horizons 'result' text (header included, so
the solution ID and retrieval date are kept). Requests are serial with a
pause. Data source: NASA/JPL Horizons On-Line Ephemeris System (Giorgini &
JPL Solar System Dynamics Group). Courtesy NASA/JPL-Caltech.

Why one request: each Horizons request is its own numerical integration
(from the orbit-solution epoch to the request's first epoch, then onward),
and two requests that start at different epochs disagree by up to ~2e-8 AU
(~0.1-0.2 s along-track; measured 2026-11-04). One request keeps the whole
table on one smooth trajectory. A 2-day step stays under the API's output
line limit; the fit uses positions AND velocities, so 2 days is ample.
The TLIST check requests all start with the grid's first epoch, which
reproduces the grid trajectory to ~1e-9 AU (the anchor row is not used).
"""
import json, os, random, sys, time, urllib.parse, urllib.request

from chiron_grid import JD_START, JD_END, SEG_DAYS, N_SEG

API = 'https://ssd.jpl.nasa.gov/api/horizons.api'
BASE = {
    'format': 'json',
    'COMMAND': "'2060;'",          # numbered asteroid 2060 Chiron (1977 UB) = 95P
    'OBJ_DATA': 'YES',
    'MAKE_EPHEM': 'YES',
    'EPHEM_TYPE': 'VECTORS',
    'CENTER': "'500@10'",          # Sun body centre
    'REF_PLANE': 'FRAME',          # ICRF equatorial axes (= Astronomy Engine EQJ)
    'REF_SYSTEM': 'ICRF',
    'OUT_UNITS': 'AU-D',
    'VEC_TABLE': '2',              # position + velocity
    'VEC_CORR': 'NONE',            # geometric states
    'CSV_FORMAT': 'YES',
    'TIME_TYPE': 'TDB',
}

def get(params, path, target='2060 Chiron'):
    if os.path.exists(path) and '$$EOE' in open(path).read():
        print('have', path); return
    url = API + '?' + urllib.parse.urlencode(params)
    for attempt in range(4):
        try:
            with urllib.request.urlopen(url, timeout=600) as r:
                d = json.load(r)
            break
        except Exception as e:  # network hiccup: back off and retry
            print('retry', e); time.sleep(15 * (attempt + 1))
    else:
        sys.exit('failed: ' + path)
    res = d.get('result', '')
    if '$$SOE' not in res:
        sys.exit(json.dumps(d)[:3000])
    if 'Target body name: ' + target not in res:
        sys.exit('unexpected target body')
    with open(path, 'w') as f:
        f.write(res)
    print('wrote', path, res.count('\n'))
    time.sleep(3)

def grid(out):
    p = dict(BASE, STEP_SIZE="'2 d'",
             START_TIME=f"'JD{JD_START:.1f}'", STOP_TIME=f"'JD{JD_END:.1f}'")
    get(p, os.path.join(out, 'grid.txt'))

def tlist(out, n):
    rnd = random.Random(2060)
    span = N_SEG * SEG_DAYS
    eps = sorted(round(JD_START + rnd.random() * span, 6) for _ in range(n))
    per = 49
    for k, i in enumerate(range(0, n, per)):
        p = dict(BASE, TLIST_TYPE='JD',
                 TLIST=' '.join(f"'{e:.6f}'" for e in [JD_START] + eps[i:i + per]))
        get(p, os.path.join(out, f'tlist_{k:03d}.txt'))

if __name__ == '__main__':
    os.makedirs(sys.argv[2], exist_ok=True)
    if sys.argv[1] == 'grid':
        grid(sys.argv[2])
    else:
        tlist(sys.argv[2], int(sys.argv[3]))

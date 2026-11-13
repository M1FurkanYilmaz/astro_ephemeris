#!/usr/bin/env python3
"""Regenerate test/fixtures/horizons/*.csv.gz from the NASA/JPL Horizons API.

One request per series (START/STOP/STEP), never many single-epoch requests:
each Horizons request is its own integration, so separate requests differ
slightly (see tool/chiron/README.md). Quantities: 31 (observer ecliptic
longitude and latitude, apparent, true ecliptic and equinox of date) and 20
(range, AU). Observer = geocentre (500@399), times in UT (Horizons applies its
own Delta T), angles in degrees.

  python3 tool/horizons/fetch.py            # writes fixtures + queries.json

Output rows: jd_ut,lon_deg,lat_deg,range_au. queries.json keeps the exact
request parameters, the Horizons orbit-solution lines and the retrieval date.
Data: NASA/JPL Horizons On-Line Ephemeris System (Giorgini and JPL Solar System
Dynamics Group). Courtesy NASA/JPL-Caltech.
"""
import gzip, json, os, re, sys, time, urllib.parse, urllib.request, datetime

API = 'https://ssd.jpl.nasa.gov/api/horizons.api'
HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, '..', '..', 'test', 'fixtures', 'horizons')

# (file, COMMAND, start JD, stop JD, step). 1900-01-01 .. 2100-01-01 UT.
JD_1900, JD_2100 = 2415020.5, 2488069.5
SERIES = [(n, c, JD_1900, JD_2100, '37 d') for n, c in [
    ('sun', '10'), ('mercury', '199'), ('venus', '299'), ('mars', '499'),
    ('jupiter', '599'), ('saturn', '699'), ('uranus', '799'),
    ('neptune', '899'), ('pluto', '999'), ('chiron', '2060;')]]
SERIES += [
    ('moon_long', '301', JD_1900, JD_2100, '10512 m'),
    # 2024-01-01 .. 2026-01-01, every 6 hours
    ('moon_fine', '301', 2460310.5, 2461041.5, '6 h'),
]

def fetch(cmd, a, b, step):
    p = {
        'format': 'json', 'COMMAND': f"'{cmd}'", 'OBJ_DATA': 'NO',
        'MAKE_EPHEM': 'YES', 'EPHEM_TYPE': 'OBSERVER', 'CENTER': "'500@399'",
        'START_TIME': f"'JD{a:.1f}'", 'STOP_TIME': f"'JD{b:.1f}'",
        'STEP_SIZE': f"'{step}'", 'QUANTITIES': "'20,31'",
        'TIME_TYPE': 'UT', 'EXTRA_PREC': 'YES', 'ANG_FORMAT': 'DEG',
        'CAL_FORMAT': 'JD', 'CSV_FORMAT': 'YES',
    }
    url = API + '?' + urllib.parse.urlencode(p)
    for k in range(4):
        try:
            with urllib.request.urlopen(url, timeout=600) as r:
                return p, json.load(r)['result']
        except Exception as e:
            print('retry', e); time.sleep(15 * (k + 1))
    sys.exit('failed ' + cmd)

def parse(res):
    body = res.split('$$SOE')[1].split('$$EOE')[0]
    rows = []
    for line in body.strip().splitlines():
        f = [x.strip() for x in line.split(',')]
        # columns: jd, 2 flag columns, delta, deldot, ObsEcLon, ObsEcLat
        rows.append((f[0], f[5], f[6], f[3]))
    return rows

def main():
    os.makedirs(OUT, exist_ok=True)
    meta = {'retrieved': datetime.date.today().isoformat(), 'api': API, 'series': {}}
    for name, cmd, a, b, step in SERIES:
        p, res = fetch(cmd, a, b, step)
        if '$$SOE' not in res:
            sys.exit(res[:2000])
        rows = parse(res)
        with gzip.GzipFile(os.path.join(OUT, name + '.csv.gz'), 'wb', mtime=0) as f:
            f.write(('jd_ut,lon_deg,lat_deg,range_au\n' +
                     '\n'.join(','.join(r) for r in rows) + '\n').encode())
        sol = [l.strip() for l in res.splitlines()
               if re.search(r'Target body name|Soln\.? date|JPL#|Ephemeris / ', l)]
        meta['series'][name] = {'params': p, 'rows': len(rows), 'header': sol[:4]}
        print(name, len(rows)); time.sleep(3)
    json.dump(meta, open(os.path.join(OUT, 'queries.json'), 'w'), indent=1)

if __name__ == '__main__':
    main()

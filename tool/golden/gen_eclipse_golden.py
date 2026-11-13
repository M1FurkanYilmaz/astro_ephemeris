"""Eclipse goldens from the official astronomy-engine==2.1.19 Python package.

Every global solar eclipse and lunar eclipse with peak in [1900-01-01, 2101-01-01) UT,
found by the canonical loop Search*(1900-01-01) then Next*(prev.peak).
Output: gzip (mtime 0) JSON, deterministic. Run with python -I in the oracle venv.
"""
import gzip, json, sys
import astronomy as A

out_path = sys.argv[1]
start = A.Time.Make(1900, 1, 1, 0, 0, 0)
stop = A.Time.Make(2101, 1, 1, 0, 0, 0)

def iso(t):
    return str(t)

solar = []
e = A.SearchGlobalSolarEclipse(start)
while e.peak.ut < stop.ut:
    solar.append({
        'ut': e.peak.ut, 'tt': e.peak.tt, 'iso': iso(e.peak),
        'kind': e.kind.name.lower(),
        'obscuration': None if e.obscuration is None or e.obscuration != e.obscuration else e.obscuration,
        'distance': e.distance,
        'latitude': None if e.latitude != e.latitude else e.latitude,
        'longitude': None if e.longitude != e.longitude else e.longitude,
    })
    e = A.NextGlobalSolarEclipse(e.peak)

lunar = []
e = A.SearchLunarEclipse(start)
while e.peak.ut < stop.ut:
    lunar.append({
        'ut': e.peak.ut, 'tt': e.peak.tt, 'iso': iso(e.peak),
        'kind': e.kind.name.lower(),
        'obscuration': e.obscuration,
        'sd_penum': e.sd_penum, 'sd_partial': e.sd_partial, 'sd_total': e.sd_total,
    })
    e = A.NextLunarEclipse(e.peak)

doc = {
    'generator': 'astronomy-engine==2.1.19 (PyPI), tool/golden/gen_eclipse_golden.py',
    'range': '1900-01-01T00:00Z .. 2101-01-01T00:00Z (peak UT)',
    'solar': solar, 'lunar': lunar,
}
data = json.dumps(doc, separators=(',', ':')).encode()
with open(out_path, 'wb') as f:
    with gzip.GzipFile(fileobj=f, mode='wb', mtime=0, filename='') as g:
        g.write(data)
from collections import Counter
print(len(solar), Counter(x['kind'] for x in solar), len(lunar), Counter(x['kind'] for x in lunar))

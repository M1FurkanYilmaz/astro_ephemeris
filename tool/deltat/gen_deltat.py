#!/usr/bin/env python3
"""Generate lib/src/delta_t_table.dart (Delta T = TT - UT1).

Sources (US Naval Observatory / IERS; US-government work, public domain):
  historic_deltat.data  https://maia.usno.navy.mil/ser7/historic_deltat.data
                        half-yearly TT-UT1, 1657.0 .. 1984.5 (used up to 1972.5)
  deltat.data           https://maia.usno.navy.mil/ser7/deltat.data
                        monthly TT-UT1 on the 1st of each month, 1973-02 .. latest
  finals2000A.data      https://maia.usno.navy.mil/ser7/finals2000A.data
                        IERS Bulletin A UT1-UTC, daily, observed (I) + ~1 year of
                        predictions (P); only rows after the last deltat.data month
                        are kept (data/finals2000A.tail).
  tai-utc.dat           https://maia.usno.navy.mil/ser7/tai-utc.dat  (leap seconds)

Usage:
  python3 tool/deltat/gen_deltat.py --fetch   # download fresh copies into data/, then generate
  python3 tool/deltat/gen_deltat.py           # regenerate from the cached files in data/
The output depends only on the files in data/ (byte-identical reruns).

Model (implemented in lib/src/delta_t.dart, which reads this table):
  * inside the table: C1 piecewise cubic Hermite interpolation;
  * after the last row: dT = dT_end + s*(y - y_end) + 32.5*((y - y_end)/100)^2
    (y in years). s = least-squares trend of the last 3 years of the table (cancels
    the annual/semi-annual term), also used as the Hermite slope of the last row,
    so value and slope are continuous. 32.5 s/cy^2 is the curvature of the
    Stephenson-Morrison-Hohenkerk (2016) long-term parabola (tidal braking).
  * before the first row (1657): Espenak-Meeus polynomial with a fading offset.
"""
import datetime
import math
import os
import sys
import urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
DATA = os.path.join(HERE, 'data')
OUT = os.path.join(HERE, '..', '..', 'lib', 'src', 'delta_t_table.dart')
BASE = 'https://maia.usno.navy.mil/ser7/'
FILES = ['historic_deltat.data', 'deltat.data', 'tai-utc.dat', 'finals2000A.data']
J2000 = datetime.datetime(2000, 1, 1, 12)


def ut_days(dt):
    return (dt - J2000).total_seconds() / 86400.0


def ut_of_decimal_year(yf):
    y = int(math.floor(yf))
    a = ut_days(datetime.datetime(y, 1, 1))
    b = ut_days(datetime.datetime(y + 1, 1, 1))
    return a + (yf - y) * (b - a)


def _century(yy):
    # finals2000A.data has two-digit years, 1973 .. 2072.
    return 1900 + yy if yy >= 73 else 2000 + yy


def fetch():
    os.makedirs(DATA, exist_ok=True)
    for name in FILES:
        with urllib.request.urlopen(BASE + name, timeout=120) as r:
            body = r.read().decode('ascii', 'replace')
        if name == 'finals2000A.data':
            # Keep only rows from the last deltat.data month on (the rest is unused).
            last = open(os.path.join(DATA, 'deltat.data')).read().split()[-4:-1]
            ly, lm = int(last[0]), int(last[1])
            keep = []
            for line in body.splitlines():
                if len(line) < 68 or line[57] not in 'IP':
                    continue
                yy, mm = int(line[0:2]), int(line[2:4])
                if (_century(yy), mm) >= (ly, lm):
                    keep.append(line.rstrip())
            body = '\n'.join(keep) + '\n'
            name = 'finals2000A.tail'
        with open(os.path.join(DATA, name), 'w') as f:
            f.write(body)
    with open(os.path.join(DATA, 'RETRIEVED.txt'), 'w') as f:
        f.write(datetime.datetime.now(datetime.timezone.utc).strftime('%Y-%m-%d') + '\n')


def tai_minus_utc(mjd):
    val = None
    for line in open(os.path.join(DATA, 'tai-utc.dat')):
        jd = float(line[17:26])
        if mjd + 2400000.5 >= jd:
            off = float(line.split('TAI-UTC=')[1].split()[0])
            mjd0 = float(line.split('(MJD -')[1].split(')')[0])
            rate = float(line.split(' X ')[1].strip().rstrip('S').strip())
            val = off + (mjd - mjd0) * rate
    return val


def build():
    rows = []
    for line in open(os.path.join(DATA, 'historic_deltat.data')).read().splitlines()[2:]:
        p = line.split()
        if len(p) < 2:
            continue
        y = float(p[0])
        if y >= 1973.0:
            break
        rows.append((ut_of_decimal_year(y), float(p[1]), 'historic %s' % p[0]))
    last = None
    for line in open(os.path.join(DATA, 'deltat.data')):
        p = line.split()
        if len(p) < 4:
            continue
        d = datetime.datetime(int(p[0]), int(p[1]), int(p[2]))
        rows.append((ut_days(d), float(p[3]), 'deltat %s' % d.date()))
        last = d
    observed_end = rows[-1][0]
    n_pred = 0
    for line in open(os.path.join(DATA, 'finals2000A.tail')):
        if len(line) < 68 or line[57] not in 'IP' or line[4:6] != ' 1':
            continue
        y, m = _century(int(line[0:2])), int(line[2:4])
        d = datetime.datetime(y, m, 1)
        if d <= last:
            continue
        mjd = float(line[7:15])
        dut1 = float(line[58:68])
        dt = 32.184 + tai_minus_utc(mjd) - dut1
        rows.append((ut_days(d), round(dt, 4), 'bulletinA %s %s' % (d.date(), line[57])))
        if line[57] == 'P':
            n_pred += 1
    # Trend slope over the last 3 years (seconds per day).
    end = rows[-1][0]
    pts = [(x, v) for x, v, _ in rows if x >= end - 3 * 365.25]
    mx = sum(x for x, _ in pts) / len(pts)
    my = sum(v for _, v in pts) / len(pts)
    slope = sum((x - mx) * (v - my) for x, v in pts) / sum((x - mx) ** 2 for x, _ in pts)
    return rows, observed_end, slope, n_pred


def main():
    if '--fetch' in sys.argv:
        fetch()
    rows, observed_end, slope, n_pred = build()
    retrieved = open(os.path.join(DATA, 'RETRIEVED.txt')).read().strip()
    o = []
    o.append('// GENERATED by tool/deltat/gen_deltat.py. Do not edit by hand.')
    o.append('//')
    o.append('// Delta T = TT - UT1 in seconds, observed values from the US Naval Observatory')
    o.append('// and IERS (US-government / IERS data, public domain), retrieved %s:' % retrieved)
    o.append('//   %shistoric_deltat.data  (1657.0 .. 1972.5, half-yearly)' % BASE)
    o.append('//   %sdeltat.data           (1973-02 .. %s, monthly)' % (BASE, (J2000 + datetime.timedelta(days=observed_end)).date()))
    o.append('//   %sfinals2000A.data      (IERS Bulletin A UT1-UTC, monthly samples after that;' % BASE)
    o.append('//                           %d of them are Bulletin A predictions)' % n_pred)
    o.append('//   %stai-utc.dat           (TAI-UTC; TT = TAI + 32.184 s)' % BASE)
    o.append('// See lib/src/delta_t.dart for interpolation and extrapolation.')
    o.append('')
    o.append('/// UT days since J2000 (2000-01-01T12:00Z) of each table row, ascending.')
    o.append('const List<double> deltaTTableUt = <double>[')
    for x, _, _ in rows:
        o.append('  %r,' % round(x, 6))
    o.append('];')
    o.append('')
    o.append('/// Delta T in seconds at [deltaTTableUt].')
    o.append('const List<double> deltaTTableSeconds = <double>[')
    for _, v, _ in rows:
        o.append('  %r,' % v)
    o.append('];')
    o.append('')
    o.append('/// Last row of observed (non-predicted) USNO monthly data, UT days since J2000.')
    o.append('const double deltaTObservedEndUt = %r;' % round(observed_end, 6))
    o.append('')
    o.append('/// Least-squares Delta T trend over the last 3 years of the table, s/day.')
    o.append('const double deltaTEndSlopePerDay = %r;' % float('%.6e' % slope))
    o.append('')
    open(OUT, 'w').write('\n'.join(o))
    print('rows', len(rows), 'end', rows[-1][2], 'slope s/yr', slope * 365.25, 'predicted', n_pred)


if __name__ == '__main__':
    main()

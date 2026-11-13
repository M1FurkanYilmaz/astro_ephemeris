#!/usr/bin/env python3
"""Parse Horizons vector-table text (fetch_horizons.py output).
Rows: [jd_tdb, x, y, z, vx, vy, vz] (AU, AU/day, ICRF/EQJ, heliocentric)."""
import re
import numpy as np

def parse(path):
    txt = open(path).read()
    body = txt.split('$$SOE', 1)[1].split('$$EOE', 1)[0]
    rows = []
    for line in body.strip().splitlines():
        f = [s.strip() for s in line.split(',')]
        rows.append([float(f[0])] + [float(v) for v in f[2:8]])
    return np.array(rows)

def solution_info(path):
    """(soln id, soln date, retrieval timestamp, perturbers, centre source)."""
    txt = open(path).read()
    src = re.search(r'Target body name: (.*?)\s+\{source: ([^}]+)\}', txt)
    sol = re.search(r'Soln\.date: (\S+)', txt)
    ret = re.search(r'Ephemeris / API_USER (.*?) Pasadena', txt)
    per = re.search(r'Small perturbers: .*?\{source: ([^}]+)\}', txt)
    cen = re.search(r'Center body name: .*?\{source: ([^}]+)\}', txt)
    return dict(target=src.group(1).strip(), soln=src.group(2),
                soln_date=sol.group(1), retrieved=ret.group(1).strip(),
                perturbers=per.group(1), planets=cen.group(1))

if __name__ == '__main__':
    import sys
    for p in sys.argv[1:]:
        a = parse(p)
        print(p, a.shape, a[0, 0], a[-1, 0], solution_info(p))

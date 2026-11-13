"""Segment grid shared by the fetch and fit scripts."""
JD_START = 2378496.5      # 1800-01-01 00:00 TDB
SEG_DAYS = 256            # Chebyshev segment length (days)
N_SEG = 573               # -> JD_END = 2525184.5 = 2201-08-15 00:00 TDB
DEGREE = 22               # 23 coefficients per coordinate per segment
JD_END = JD_START + N_SEG * SEG_DAYS
PAD_DAYS = 8             # fit window overhang on each side (days)

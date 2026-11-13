// MIT License
//
// Copyright (c) 2019-2023 Don Cross <cosinekitty@gmail.com>
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.
//
// Ported to Dart from Astronomy Engine v2.1.19 (commit 03084ee).
// https://github.com/cosinekitty/astronomy
//
// GENERATED FILE - do not edit by hand. The numbers were extracted
// mechanically from source/js/astronomy.ts by a conversion script.

/// Lunar series terms for CalcMoon (AddSol and ADDN calls, in source order).
library;

/// One `AddSol(coeffl, coeffs, coeffg, coeffp, p, q, r, s)` call.
class MoonSolTerm {
  const MoonSolTerm(this.coeffl, this.coeffs, this.coeffg, this.coeffp, this.p,
      this.q, this.r, this.s);
  final double coeffl;
  final double coeffs;
  final double coeffg;
  final double coeffp;
  final int p;
  final int q;
  final int r;
  final int s;
}

/// One `ADDN(coeffn, p, q, r, s)` call.
class MoonNodeTerm {
  const MoonNodeTerm(this.coeffn, this.p, this.q, this.r, this.s);
  final double coeffn;
  final int p;
  final int q;
  final int r;
  final int s;
}

const List<MoonSolTerm> moonSolTerms = [
  MoonSolTerm(13.9020, 14.0600, -0.0010, 0.2607, 0, 0, 0, 4),
  MoonSolTerm(0.4030, -4.0100, 0.3940, 0.0023, 0, 0, 0, 3),
  MoonSolTerm(2369.9120, 2373.3600, 0.6010, 28.2333, 0, 0, 0, 2),
  MoonSolTerm(-125.1540, -112.7900, -0.7250, -0.9781, 0, 0, 0, 1),
  MoonSolTerm(1.9790, 6.9800, -0.4450, 0.0433, 1, 0, 0, 4),
  MoonSolTerm(191.9530, 192.7200, 0.0290, 3.0861, 1, 0, 0, 2),
  MoonSolTerm(-8.4660, -13.5100, 0.4550, -0.1093, 1, 0, 0, 1),
  MoonSolTerm(22639.5000, 22609.0700, 0.0790, 186.5398, 1, 0, 0, 0),
  MoonSolTerm(18.6090, 3.5900, -0.0940, 0.0118, 1, 0, 0, -1),
  MoonSolTerm(-4586.4650, -4578.1300, -0.0770, 34.3117, 1, 0, 0, -2),
  MoonSolTerm(3.2150, 5.4400, 0.1920, -0.0386, 1, 0, 0, -3),
  MoonSolTerm(-38.4280, -38.6400, 0.0010, 0.6008, 1, 0, 0, -4),
  MoonSolTerm(-0.3930, -1.4300, -0.0920, 0.0086, 1, 0, 0, -6),
  MoonSolTerm(-0.2890, -1.5900, 0.1230, -0.0053, 0, 1, 0, 4),
  MoonSolTerm(-24.4200, -25.1000, 0.0400, -0.3000, 0, 1, 0, 2),
  MoonSolTerm(18.0230, 17.9300, 0.0070, 0.1494, 0, 1, 0, 1),
  MoonSolTerm(-668.1460, -126.9800, -1.3020, -0.3997, 0, 1, 0, 0),
  MoonSolTerm(0.5600, 0.3200, -0.0010, -0.0037, 0, 1, 0, -1),
  MoonSolTerm(-165.1450, -165.0600, 0.0540, 1.9178, 0, 1, 0, -2),
  MoonSolTerm(-1.8770, -6.4600, -0.4160, 0.0339, 0, 1, 0, -4),
  MoonSolTerm(0.2130, 1.0200, -0.0740, 0.0054, 2, 0, 0, 4),
  MoonSolTerm(14.3870, 14.7800, -0.0170, 0.2833, 2, 0, 0, 2),
  MoonSolTerm(-0.5860, -1.2000, 0.0540, -0.0100, 2, 0, 0, 1),
  MoonSolTerm(769.0160, 767.9600, 0.1070, 10.1657, 2, 0, 0, 0),
  MoonSolTerm(1.7500, 2.0100, -0.0180, 0.0155, 2, 0, 0, -1),
  MoonSolTerm(-211.6560, -152.5300, 5.6790, -0.3039, 2, 0, 0, -2),
  MoonSolTerm(1.2250, 0.9100, -0.0300, -0.0088, 2, 0, 0, -3),
  MoonSolTerm(-30.7730, -34.0700, -0.3080, 0.3722, 2, 0, 0, -4),
  MoonSolTerm(-0.5700, -1.4000, -0.0740, 0.0109, 2, 0, 0, -6),
  MoonSolTerm(-2.9210, -11.7500, 0.7870, -0.0484, 1, 1, 0, 2),
  MoonSolTerm(1.2670, 1.5200, -0.0220, 0.0164, 1, 1, 0, 1),
  MoonSolTerm(-109.6730, -115.1800, 0.4610, -0.9490, 1, 1, 0, 0),
  MoonSolTerm(-205.9620, -182.3600, 2.0560, 1.4437, 1, 1, 0, -2),
  MoonSolTerm(0.2330, 0.3600, 0.0120, -0.0025, 1, 1, 0, -3),
  MoonSolTerm(-4.3910, -9.6600, -0.4710, 0.0673, 1, 1, 0, -4),
  MoonSolTerm(0.2830, 1.5300, -0.1110, 0.0060, 1, -1, 0, 4),
  MoonSolTerm(14.5770, 31.7000, -1.5400, 0.2302, 1, -1, 0, 2),
  MoonSolTerm(147.6870, 138.7600, 0.6790, 1.1528, 1, -1, 0, 0),
  MoonSolTerm(-1.0890, 0.5500, 0.0210, 0.0000, 1, -1, 0, -1),
  MoonSolTerm(28.4750, 23.5900, -0.4430, -0.2257, 1, -1, 0, -2),
  MoonSolTerm(-0.2760, -0.3800, -0.0060, -0.0036, 1, -1, 0, -3),
  MoonSolTerm(0.6360, 2.2700, 0.1460, -0.0102, 1, -1, 0, -4),
  MoonSolTerm(-0.1890, -1.6800, 0.1310, -0.0028, 0, 2, 0, 2),
  MoonSolTerm(-7.4860, -0.6600, -0.0370, -0.0086, 0, 2, 0, 0),
  MoonSolTerm(-8.0960, -16.3500, -0.7400, 0.0918, 0, 2, 0, -2),
  MoonSolTerm(-5.7410, -0.0400, 0.0000, -0.0009, 0, 0, 2, 2),
  MoonSolTerm(0.2550, 0.0000, 0.0000, 0.0000, 0, 0, 2, 1),
  MoonSolTerm(-411.6080, -0.2000, 0.0000, -0.0124, 0, 0, 2, 0),
  MoonSolTerm(0.5840, 0.8400, 0.0000, 0.0071, 0, 0, 2, -1),
  MoonSolTerm(-55.1730, -52.1400, 0.0000, -0.1052, 0, 0, 2, -2),
  MoonSolTerm(0.2540, 0.2500, 0.0000, -0.0017, 0, 0, 2, -3),
  MoonSolTerm(0.0250, -1.6700, 0.0000, 0.0031, 0, 0, 2, -4),
  MoonSolTerm(1.0600, 2.9600, -0.1660, 0.0243, 3, 0, 0, 2),
  MoonSolTerm(36.1240, 50.6400, -1.3000, 0.6215, 3, 0, 0, 0),
  MoonSolTerm(-13.1930, -16.4000, 0.2580, -0.1187, 3, 0, 0, -2),
  MoonSolTerm(-1.1870, -0.7400, 0.0420, 0.0074, 3, 0, 0, -4),
  MoonSolTerm(-0.2930, -0.3100, -0.0020, 0.0046, 3, 0, 0, -6),
  MoonSolTerm(-0.2900, -1.4500, 0.1160, -0.0051, 2, 1, 0, 2),
  MoonSolTerm(-7.6490, -10.5600, 0.2590, -0.1038, 2, 1, 0, 0),
  MoonSolTerm(-8.6270, -7.5900, 0.0780, -0.0192, 2, 1, 0, -2),
  MoonSolTerm(-2.7400, -2.5400, 0.0220, 0.0324, 2, 1, 0, -4),
  MoonSolTerm(1.1810, 3.3200, -0.2120, 0.0213, 2, -1, 0, 2),
  MoonSolTerm(9.7030, 11.6700, -0.1510, 0.1268, 2, -1, 0, 0),
  MoonSolTerm(-0.3520, -0.3700, 0.0010, -0.0028, 2, -1, 0, -1),
  MoonSolTerm(-2.4940, -1.1700, -0.0030, -0.0017, 2, -1, 0, -2),
  MoonSolTerm(0.3600, 0.2000, -0.0120, -0.0043, 2, -1, 0, -4),
  MoonSolTerm(-1.1670, -1.2500, 0.0080, -0.0106, 1, 2, 0, 0),
  MoonSolTerm(-7.4120, -6.1200, 0.1170, 0.0484, 1, 2, 0, -2),
  MoonSolTerm(-0.3110, -0.6500, -0.0320, 0.0044, 1, 2, 0, -4),
  MoonSolTerm(0.7570, 1.8200, -0.1050, 0.0112, 1, -2, 0, 2),
  MoonSolTerm(2.5800, 2.3200, 0.0270, 0.0196, 1, -2, 0, 0),
  MoonSolTerm(2.5330, 2.4000, -0.0140, -0.0212, 1, -2, 0, -2),
  MoonSolTerm(-0.3440, -0.5700, -0.0250, 0.0036, 0, 3, 0, -2),
  MoonSolTerm(-0.9920, -0.0200, 0.0000, 0.0000, 1, 0, 2, 2),
  MoonSolTerm(-45.0990, -0.0200, 0.0000, -0.0010, 1, 0, 2, 0),
  MoonSolTerm(-0.1790, -9.5200, 0.0000, -0.0833, 1, 0, 2, -2),
  MoonSolTerm(-0.3010, -0.3300, 0.0000, 0.0014, 1, 0, 2, -4),
  MoonSolTerm(-6.3820, -3.3700, 0.0000, -0.0481, 1, 0, -2, 2),
  MoonSolTerm(39.5280, 85.1300, 0.0000, -0.7136, 1, 0, -2, 0),
  MoonSolTerm(9.3660, 0.7100, 0.0000, -0.0112, 1, 0, -2, -2),
  MoonSolTerm(0.2020, 0.0200, 0.0000, 0.0000, 1, 0, -2, -4),
  MoonSolTerm(0.4150, 0.1000, 0.0000, 0.0013, 0, 1, 2, 0),
  MoonSolTerm(-2.1520, -2.2600, 0.0000, -0.0066, 0, 1, 2, -2),
  MoonSolTerm(-1.4400, -1.3000, 0.0000, 0.0014, 0, 1, -2, 2),
  MoonSolTerm(0.3840, -0.0400, 0.0000, 0.0000, 0, 1, -2, -2),
  MoonSolTerm(1.9380, 3.6000, -0.1450, 0.0401, 4, 0, 0, 0),
  MoonSolTerm(-0.9520, -1.5800, 0.0520, -0.0130, 4, 0, 0, -2),
  MoonSolTerm(-0.5510, -0.9400, 0.0320, -0.0097, 3, 1, 0, 0),
  MoonSolTerm(-0.4820, -0.5700, 0.0050, -0.0045, 3, 1, 0, -2),
  MoonSolTerm(0.6810, 0.9600, -0.0260, 0.0115, 3, -1, 0, 0),
  MoonSolTerm(-0.2970, -0.2700, 0.0020, -0.0009, 2, 2, 0, -2),
  MoonSolTerm(0.2540, 0.2100, -0.0030, 0.0000, 2, -2, 0, -2),
  MoonSolTerm(-0.2500, -0.2200, 0.0040, 0.0014, 1, 3, 0, -2),
  MoonSolTerm(-3.9960, 0.0000, 0.0000, 0.0004, 2, 0, 2, 0),
  MoonSolTerm(0.5570, -0.7500, 0.0000, -0.0090, 2, 0, 2, -2),
  MoonSolTerm(-0.4590, -0.3800, 0.0000, -0.0053, 2, 0, -2, 2),
  MoonSolTerm(-1.2980, 0.7400, 0.0000, 0.0004, 2, 0, -2, 0),
  MoonSolTerm(0.5380, 1.1400, 0.0000, -0.0141, 2, 0, -2, -2),
  MoonSolTerm(0.2630, 0.0200, 0.0000, 0.0000, 1, 1, 2, 0),
  MoonSolTerm(0.4260, 0.0700, 0.0000, -0.0006, 1, 1, -2, -2),
  MoonSolTerm(-0.3040, 0.0300, 0.0000, 0.0003, 1, -1, 2, 0),
  MoonSolTerm(-0.3720, -0.1900, 0.0000, -0.0027, 1, -1, -2, 2),
  MoonSolTerm(0.4180, 0.0000, 0.0000, 0.0000, 0, 0, 4, 0),
  MoonSolTerm(-0.3300, -0.0400, 0.0000, 0.0000, 3, 0, 2, 0),
];

const List<MoonNodeTerm> moonNodeTerms = [
  MoonNodeTerm(-526.069, 0, 0, 1, -2),
  MoonNodeTerm(-3.352, 0, 0, 1, -4),
  MoonNodeTerm(44.297, 1, 0, 1, -2),
  MoonNodeTerm(-6.000, 1, 0, 1, -4),
  MoonNodeTerm(20.599, -1, 0, 1, 0),
  MoonNodeTerm(-30.598, -1, 0, 1, -2),
  MoonNodeTerm(-24.649, -2, 0, 1, 0),
  MoonNodeTerm(-2.000, -2, 0, 1, -2),
  MoonNodeTerm(-22.571, 0, 1, 1, -2),
  MoonNodeTerm(10.985, 0, -1, 1, -2),
];

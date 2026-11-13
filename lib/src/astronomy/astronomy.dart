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

/// Pure-Dart port of the core of Astronomy Engine v2.1.19 (Don Cross, MIT):
/// time scales, Earth orientation (precession, nutation, sidereal time),
/// VSOP87 planets, the Pluto integrator, the Moon, and geocentric/ecliptic
/// positions. See README.md in this folder for scope and verification.
///
/// Names mirror Astronomy Engine in lowerCamelCase so upstream fixes can be
/// mirrored: `GeoVector` -> [geoVector], `Rotation_EQJ_ECT` ->
/// [rotationEqjEct], `e_tilt` -> [eTilt], and so on.
library;

import 'dart:math' as math;
import 'dart:typed_data';

import 'moon_tables.dart';
import 'pluto_table.dart';
import 'vsop_tables.dart';

part 'constants.dart';
part 'time.dart';
part 'types.dart';
part 'frames.dart';
part 'vsop.dart';
part 'pluto.dart';
part 'moon.dart';
part 'positions.dart';
part 'search.dart';
part 'eclipse.dart';

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

part of 'astronomy.dart';

// Pluto integrator (astronomy.ts 3330-3736).
//
// Pluto is computed by numerically integrating its motion under the gravity
// of the Sun and the four giant planets, starting from tabulated state
// vectors (`PlutoStateTable`) every 29200 days. Each 29200-day segment is
// integrated in 146-day steps, forward and backward, and the two runs are
// fade-mixed. Segments are cached once computed.

const int _plutoNumStates = 51;
const double _plutoTimeStep = 29200;
const double _plutoDt = 146;
const int _plutoNsteps = 201;

_BodyState _bodyStateFromTable(List<double> entry) => _BodyState(
      entry[0],
      _TerseVector(entry[1], entry[2], entry[3]),
      _TerseVector(entry[4], entry[5], entry[6]),
    );

_BodyState _adjustBarycenterPosVel(
  _BodyState ssb,
  double tt,
  Body body,
  double planetGm,
) {
  final double shift = planetGm / (planetGm + _sunGm);
  final _BodyState planet = _calcVsopPosVel(_vsopModel(body)!, tt);
  ssb.r.incr(planet.r.mul(shift));
  ssb.v.incr(planet.v.mul(shift));
  return planet;
}

_TerseVector _accelerationIncrement(
  _TerseVector smallPos,
  double gm,
  _TerseVector majorPos,
) {
  final _TerseVector delta = majorPos.sub(smallPos);
  final double r2 = delta.quadrature();
  return delta.mul(gm / (r2 * math.sqrt(r2)));
}

/// Barycentric states of the Sun and the giant planets (`major_bodies_t`).
class _MajorBodies {
  factory _MajorBodies(double tt) {
    // Accumulate the Solar System Barycenter position.
    final _BodyState ssb = _BodyState(
      tt,
      _TerseVector(0, 0, 0),
      _TerseVector(0, 0, 0),
    );

    final _BodyState jupiter = _adjustBarycenterPosVel(
      ssb,
      tt,
      Body.jupiter,
      _jupiterGm,
    );
    final _BodyState saturn = _adjustBarycenterPosVel(
      ssb,
      tt,
      Body.saturn,
      _saturnGm,
    );
    final _BodyState uranus = _adjustBarycenterPosVel(
      ssb,
      tt,
      Body.uranus,
      _uranusGm,
    );
    final _BodyState neptune = _adjustBarycenterPosVel(
      ssb,
      tt,
      Body.neptune,
      _neptuneGm,
    );

    // Convert planets' [pos, vel] vectors from heliocentric to barycentric.
    jupiter.r.decr(ssb.r);
    jupiter.v.decr(ssb.v);

    saturn.r.decr(ssb.r);
    saturn.v.decr(ssb.v);

    uranus.r.decr(ssb.r);
    uranus.v.decr(ssb.v);

    neptune.r.decr(ssb.r);
    neptune.v.decr(ssb.v);

    // Convert heliocentric SSB to barycentric Sun.
    final _BodyState sun = _BodyState(tt, ssb.r.mul(-1), ssb.v.mul(-1));
    return _MajorBodies._(jupiter, saturn, uranus, neptune, sun);
  }

  _MajorBodies._(
    this.jupiter,
    this.saturn,
    this.uranus,
    this.neptune,
    this.sun,
  );

  final _BodyState jupiter;
  final _BodyState saturn;
  final _BodyState uranus;
  final _BodyState neptune;
  final _BodyState sun;

  /// Gravitational acceleration at barycentric position [pos].
  _TerseVector acceleration(_TerseVector pos) {
    final _TerseVector acc = _accelerationIncrement(pos, _sunGm, sun.r);
    acc.incr(_accelerationIncrement(pos, _jupiterGm, jupiter.r));
    acc.incr(_accelerationIncrement(pos, _saturnGm, saturn.r));
    acc.incr(_accelerationIncrement(pos, _uranusGm, uranus.r));
    acc.incr(_accelerationIncrement(pos, _neptuneGm, neptune.r));
    return acc;
  }
}

/// `body_grav_calc_t`: barycentric position, velocity and acceleration.
class _BodyGravCalc {
  _BodyGravCalc(this.tt, this.r, this.v, this.a);

  final double tt;
  _TerseVector r;
  _TerseVector v;
  _TerseVector a;
}

/// `grav_sim_t`.
class _GravSim {
  _GravSim(this.bary, this.grav);

  final _MajorBodies bary;
  final _BodyGravCalc grav;
}

_TerseVector _updatePosition(
  double dt,
  _TerseVector r,
  _TerseVector v,
  _TerseVector a,
) =>
    _TerseVector(
      r.x + dt * (v.x + dt * a.x / 2),
      r.y + dt * (v.y + dt * a.y / 2),
      r.z + dt * (v.z + dt * a.z / 2),
    );

_TerseVector _updateVelocity(double dt, _TerseVector v, _TerseVector a) =>
    _TerseVector(v.x + dt * a.x, v.y + dt * a.y, v.z + dt * a.z);

_GravSim _gravSimStep(double tt2, _BodyGravCalc calc1) {
  final double dt = tt2 - calc1.tt;

  // Calculate where the major bodies (Sun, Jupiter...Neptune) will be at tt2.
  final _MajorBodies bary2 = _MajorBodies(tt2);

  // Estimate position of small body as if current acceleration applies across the whole time interval.
  final _TerseVector approxPos = _updatePosition(dt, calc1.r, calc1.v, calc1.a);

  // Calculate the average acceleration of the endpoints.
  // This becomes our estimate of the mean effective acceleration over the whole interval.
  final _TerseVector meanAcc = bary2.acceleration(approxPos).mean(calc1.a);

  // Refine the estimates of [pos, vel, acc] at tt2 using the mean acceleration.
  final _TerseVector pos = _updatePosition(dt, calc1.r, calc1.v, meanAcc);
  final _TerseVector vel = calc1.v.add(meanAcc.mul(dt));
  final _TerseVector acc = bary2.acceleration(pos);
  final _BodyGravCalc grav = _BodyGravCalc(tt2, pos, vel, acc);
  return _GravSim(bary2, grav);
}

/// Cached integration segments, filled lazily (`pluto_cache`).
///
/// Dart isolates do not share memory, so each isolate has its own cache and
/// no locking is needed; within an isolate code runs single-threaded. A
/// segment is fully built before it is stored, so a reader never sees a
/// half-filled segment. Cached segments are never mutated afterwards.
final List<List<_BodyGravCalc>?> _plutoCache =
    List<List<_BodyGravCalc>?>.filled(_plutoNumStates - 1, null);

int _clampIndex(double frac, int nsteps) {
  final int index = frac.floor();
  if (index < 0) return 0;
  if (index >= nsteps) return nsteps - 1;
  return index;
}

_GravSim _gravFromState(List<double> entry) {
  final _BodyState state = _bodyStateFromTable(entry);
  final _MajorBodies bary = _MajorBodies(state.tt);
  final _TerseVector r = state.r.add(bary.sun.r);
  final _TerseVector v = state.v.add(bary.sun.v);
  final _TerseVector a = bary.acceleration(r);
  final _BodyGravCalc grav = _BodyGravCalc(state.tt, r, v, a);
  return _GravSim(bary, grav);
}

List<_BodyGravCalc>? _getSegment(List<List<_BodyGravCalc>?> cache, double tt) {
  final double t0 = plutoStateTable[0][0];

  if (tt < t0 || tt > plutoStateTable[_plutoNumStates - 1][0]) {
    // Don't bother calculating a segment. Let the caller crawl backward/forward to this time.
    return null;
  }

  final int segIndex = _clampIndex(
    (tt - t0) / _plutoTimeStep,
    _plutoNumStates - 1,
  );
  final List<_BodyGravCalc>? cached = cache[segIndex];
  if (cached != null) return cached;

  final List<_BodyGravCalc?> seg = List<_BodyGravCalc?>.filled(
    _plutoNsteps,
    null,
  );

  // Each endpoint is exact.
  seg[0] = _gravFromState(plutoStateTable[segIndex]).grav;
  seg[_plutoNsteps - 1] = _gravFromState(plutoStateTable[segIndex + 1]).grav;

  // Simulate forwards from the lower time bound.
  double stepTt = seg[0]!.tt;
  for (int i = 1; i < _plutoNsteps - 1; ++i) {
    stepTt += _plutoDt;
    seg[i] = _gravSimStep(stepTt, seg[i - 1]!).grav;
  }

  // Simulate backwards from the upper time bound.
  stepTt = seg[_plutoNsteps - 1]!.tt;
  final List<_BodyGravCalc?> reverse = List<_BodyGravCalc?>.filled(
    _plutoNsteps,
    null,
  );
  reverse[_plutoNsteps - 1] = seg[_plutoNsteps - 1];
  for (int i = _plutoNsteps - 2; i > 0; --i) {
    stepTt -= _plutoDt;
    reverse[i] = _gravSimStep(stepTt, reverse[i + 1]!).grav;
  }

  // Fade-mix the two series so that there are no discontinuities.
  for (int i = _plutoNsteps - 2; i > 0; --i) {
    final double ramp = i / (_plutoNsteps - 1);
    final _BodyGravCalc s = seg[i]!;
    final _BodyGravCalc rv = reverse[i]!;
    s.r = s.r.mul(1 - ramp).add(rv.r.mul(ramp));
    s.v = s.v.mul(1 - ramp).add(rv.v.mul(ramp));
    s.a = s.a.mul(1 - ramp).add(rv.a.mul(ramp));
  }

  final List<_BodyGravCalc> done = List<_BodyGravCalc>.unmodifiable(
    seg.map((_BodyGravCalc? g) => g!),
  );
  cache[segIndex] = done;
  return done;
}

_GravSim _calcPlutoOneWay(List<double> entry, double targetTt, double dt) {
  _GravSim sim = _gravFromState(entry);
  final int n = ((targetTt - sim.grav.tt) / dt).ceil();
  for (int i = 0; i < n; ++i) {
    sim = _gravSimStep((i + 1 == n) ? targetTt : (sim.grav.tt + dt), sim.grav);
  }
  return sim;
}

/// Pluto's barycentric (or heliocentric, if [helio]) EQJ state (`CalcPluto`).
StateVector _calcPluto(AstroTime time, bool helio) {
  _TerseVector r, v;
  _MajorBodies? bary;
  final List<_BodyGravCalc>? seg = _getSegment(_plutoCache, time.tt);
  if (seg == null) {
    // The target time is outside the year range 0000..4000.
    // Calculate it by crawling backward from 0000 or forward from 4000.
    // FIXFIXFIX - This is super slow. Could optimize this with extra caching if needed.
    final _GravSim sim;
    if (time.tt < plutoStateTable[0][0]) {
      sim = _calcPlutoOneWay(plutoStateTable[0], time.tt, -_plutoDt);
    } else {
      sim = _calcPlutoOneWay(
        plutoStateTable[_plutoNumStates - 1],
        time.tt,
        _plutoDt,
      );
    }
    r = sim.grav.r;
    v = sim.grav.v;
    bary = sim.bary;
  } else {
    final int left = _clampIndex(
      (time.tt - seg[0].tt) / _plutoDt,
      _plutoNsteps - 1,
    );
    final _BodyGravCalc s1 = seg[left];
    final _BodyGravCalc s2 = seg[left + 1];

    // Find mean acceleration vector over the interval.
    final _TerseVector acc = s1.a.mean(s2.a);

    // Use Newtonian mechanics to extrapolate away from t1 in the positive time direction.
    final _TerseVector ra = _updatePosition(time.tt - s1.tt, s1.r, s1.v, acc);
    final _TerseVector va = _updateVelocity(time.tt - s1.tt, s1.v, acc);

    // Use Newtonian mechanics to extrapolate away from t2 in the negative time direction.
    final _TerseVector rb = _updatePosition(time.tt - s2.tt, s2.r, s2.v, acc);
    final _TerseVector vb = _updateVelocity(time.tt - s2.tt, s2.v, acc);

    // Use fade in/out idea to blend the two position estimates.
    final double ramp = (time.tt - s1.tt) / _plutoDt;
    r = ra.mul(1 - ramp).add(rb.mul(ramp));
    v = va.mul(1 - ramp).add(vb.mul(ramp));
  }

  if (helio) {
    // Convert barycentric vectors to heliocentric vectors.
    bary ??= _MajorBodies(time.tt);
    r = r.sub(bary.sun.r);
    v = v.sub(bary.sun.v);
  }

  return StateVector(r.x, r.y, r.z, v.x, v.y, v.z, time);
}

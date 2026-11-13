// House module: polar fallback, structural invariants of all six systems,
// and input validation. Definition-level checks of the ascendant, midheaven,
// equal, whole-sign and Placidus cusps are in test/core/ephemeris_houses_test.dart.

import 'dart:math' as math;

import 'package:test/test.dart';
import 'package:astro_ephemeris/src/houses/houses.dart';

double _angDiff(double a, double b) {
  final d = ((a - b) % 360.0 + 360.0) % 360.0;
  return d > 180.0 ? 360.0 - d : d;
}

/// Forward arc from [a] to [b], [0, 360).
double _arc(double a, double b) => ((b - a) % 360.0 + 360.0) % 360.0;

void main() {
  group('polar behaviour', () {
    test('Placidus/Koch fall back to Porphyry from |lat| = 90 - eps', () {
      const eps = 23.44;
      for (final s in [HouseSystem.placidus, HouseSystem.koch]) {
        for (final lat in [90 - eps, -(90 - eps), 70.0, -89.9]) {
          final h = computeHouses(
            armcDeg: 123.4,
            latDeg: lat,
            trueObliquityDeg: eps,
            system: s,
          );
          final o = computeHouses(
            armcDeg: 123.4,
            latDeg: lat,
            trueObliquityDeg: eps,
            system: HouseSystem.porphyry,
          );
          expect(h.usedFallback, isTrue);
          expect(h.system, HouseSystem.porphyry);
          expect(h.requestedSystem, s);
          expect(h.cusps, o.cusps);
        }
        final inside = computeHouses(
          armcDeg: 123.4,
          latDeg: 89.999999 - eps,
          trueObliquityDeg: eps,
          system: s,
        );
        expect(inside.usedFallback, isFalse);
      }
    });

    test(
      'no polar flip inside the polar circle; flip keeps asc east of mc',
      () {
        final rnd = math.Random(7);
        for (var n = 0; n < 5000; n++) {
          const eps = 23.44;
          final lat = (rnd.nextDouble() * 2 - 1) * 89.9;
          final h = computeHouses(
            armcDeg: rnd.nextDouble() * 360,
            latDeg: lat,
            trueObliquityDeg: eps,
            system: HouseSystem.equal,
          );
          if (lat.abs() < 90 - eps) expect(h.polarFlip, isFalse);
          expect(_arc(h.mc, h.ascendant), lessThan(180.0));
        }
      },
    );
  });

  group('invariants', () {
    final rnd = math.Random(20261104);
    const eps = 23.4392911;
    for (final system in HouseSystem.values) {
      test('${system.code}: opposite cusps, order, asc/mc', () {
        for (var n = 0; n < 3000; n++) {
          // Inside the polar circle, including the equator and its edge.
          final lat = n % 10 == 0
              ? 0.0
              : n % 10 == 1
                  ? (rnd.nextBool() ? 1 : -1) * (66.0 + rnd.nextDouble() * 0.5)
                  : (rnd.nextDouble() * 2 - 1) * 66.5;
          final armc = rnd.nextDouble() * 360;
          final h = computeHouses(
            armcDeg: armc,
            latDeg: lat,
            trueObliquityDeg: eps,
            system: system,
          );
          final where = '${system.code} lat $lat armc $armc ${h.cusps}';
          expect(h.cusps.length, 12);
          expect(h.usedFallback, isFalse);
          var total = 0.0;
          for (var i = 0; i < 12; i++) {
            final c = h.cusps[i];
            expect(c >= 0 && c < 360, isTrue, reason: where);
            if (i < 6) {
              expect(
                _angDiff(h.cusps[i + 6], c + 180),
                lessThan(1e-9),
                reason: where,
              );
            }
            final step = _arc(c, h.cusps[(i + 1) % 12]);
            expect(step, greaterThan(0), reason: where);
            expect(step, lessThan(180), reason: where);
            total += step;
          }
          // Increasing zodiacal order = the forward steps go round once.
          expect(total, closeTo(360, 1e-9), reason: where);
          if (system.isQuadrant) {
            expect(h.cusp(1), h.ascendant, reason: where);
            expect(h.cusp(10), h.mc, reason: where);
          } else if (system == HouseSystem.equal) {
            expect(h.cusp(1), h.ascendant, reason: where);
          } else {
            expect(h.cusp(1) % 30, 0);
            expect(h.ascendant - h.cusp(1), inInclusiveRange(0, 30));
          }
        }
      });
    }
  });

  group('API', () {
    test('armcFromGast', () {
      expect(
        armcFromGast(
          gastHours: 0.5590796871349234,
          lonEastDeg: -106.60305012330241,
        ),
        closeTo(261.78314518372144, 1e-9),
      );
      expect(
        armcFromGast(gastHours: 23.0, lonEastDeg: 30.0),
        closeTo(15.0, 1e-12),
      );
    });
    test('rejects bad input', () {
      expect(
        () => computeHouses(
          armcDeg: 0,
          latDeg: 91,
          trueObliquityDeg: 23.4,
          system: HouseSystem.equal,
        ),
        throwsArgumentError,
      );
      expect(
        () => computeHouses(
          armcDeg: double.nan,
          latDeg: 0,
          trueObliquityDeg: 23.4,
          system: HouseSystem.equal,
        ),
        throwsArgumentError,
      );
    });
    test('codes round-trip', () {
      for (final s in HouseSystem.values) {
        expect(HouseSystem.fromCode(s.code), s);
      }
      expect(HouseSystem.fromCode('X'), isNull);
    });
  });
}

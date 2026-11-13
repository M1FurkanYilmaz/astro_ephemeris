import 'package:test/test.dart';
import 'package:astro_ephemeris/src/astronomy/astronomy.dart';

void main() {
  group('AstroTime', () {
    test('J2000 epoch and Julian Date conversions', () {
      final AstroTime j2000 = AstroTime.fromDateTime(
        DateTime.utc(2000, 1, 1, 12),
      );
      expect(j2000.ut, 0.0);
      expect(j2000.julianDayUt, 2451545.0);
      expect(AstroTime.fromJulianDayUt(2451545.0).ut, 0.0);
      expect(AstroTime.fromDateTime(DateTime.utc(1900, 1, 1)).ut, -36524.5);
      // tt = ut + DeltaT/86400 (Espenak-Meeus: ~63.8 s at J2000).
      expect((j2000.tt - j2000.ut) * 86400, closeTo(63.847, 1e-3));
    });

    test('local DateTime is converted to UTC', () {
      final DateTime utc = DateTime.utc(1985, 7, 3, 4, 5, 6, 7, 8);
      expect(
        AstroTime.fromDateTime(utc.toLocal()).ut,
        AstroTime.fromDateTime(utc).ut,
      );
      expect(AstroTime.fromDateTime(utc).date, utc);
    });

    test('fromTerrestrialTime inverts tt', () {
      for (final double tt in [-73000.25, -1234.5, 0.0, 8000.75, 73000.0]) {
        expect(AstroTime.fromTerrestrialTime(tt).tt, closeTo(tt, 1e-12));
      }
    });

    test('addDays shifts UT', () {
      final AstroTime t = AstroTime(100.25);
      expect(t.addDays(-0.5).ut, 99.75);
    });
  });

  group('rotations', () {
    test('rotationEqjEct agrees with ecliptic()', () {
      for (final double ut in [-36000.3, -100.0, 0.0, 9131.25, 36000.7]) {
        final AstroTime t = AstroTime(ut);
        final Vector v = geoVector(Body.mars, t, true);
        final EclipticCoordinates e = ecliptic(v);
        final Vector r = rotateVector(rotationEqjEct(t), v);
        final Spherical s = sphereFromVector(r);
        expect(s.lon, closeTo(e.elon, 1e-11));
        expect(s.lat, closeTo(e.elat, 1e-11));
        expect(r.x, closeTo(e.vec.x, 1e-14));
        expect(r.y, closeTo(e.vec.y, 1e-14));
        expect(r.z, closeTo(e.vec.z, 1e-14));
      }
    });

    test('inverse rotations round-trip', () {
      final AstroTime t = AstroTime(5000.5);
      final Vector v = Vector(0.3, -1.2, 0.7, t);
      final Vector a = rotateVector(
        rotationEctEqj(t),
        rotateVector(rotationEqjEct(t), v),
      );
      final Vector b = rotateVector(
        inverseRotation(rotationEqjEqd(t)),
        rotateVector(rotationEqjEqd(t), v),
      );
      for (final Vector w in [a, b]) {
        expect(w.x, closeTo(v.x, 1e-15));
        expect(w.y, closeTo(v.y, 1e-15));
        expect(w.z, closeTo(v.z, 1e-15));
      }
      final Vector c = rotateVector(
        rotationEqdEqj(t),
        rotateVector(rotationEqjEqd(t), v),
      );
      expect(c.length(), closeTo(v.length(), 1e-15));
      expect(c.x, closeTo(v.x, 1e-15));
    });

    test('vectorFromSphere / sphereFromVector round-trip', () {
      final AstroTime t = AstroTime(0);
      final Spherical s = Spherical(-23.5, 301.25, 2.5);
      final Spherical back = sphereFromVector(vectorFromSphere(s, t));
      expect(back.lat, closeTo(s.lat, 1e-12));
      expect(back.lon, closeTo(s.lon, 1e-12));
      expect(back.dist, closeTo(s.dist, 1e-15));
    });
  });

  test('sun position at J2000 is near 280.37 deg', () {
    final EclipticCoordinates sun = sunPosition(AstroTime(0));
    expect(sun.elon, closeTo(280.37, 0.01));
    // Geocentric Sun via geoVector + ecliptic gives the same answer.
    final double e = ecliptic(geoVector(Body.sun, AstroTime(0), true)).elon;
    expect((e - sun.elon).abs() * 3600, lessThan(1.0));
    expect(massProduct(Body.sun), greaterThan(0));
  });
}

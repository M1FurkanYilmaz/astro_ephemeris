// The Dart port of Astronomy Engine's eclipse searches against the official
// astronomy-engine==2.1.19 Python package (the oracle): every global solar
// and lunar eclipse 1900-2100, found with the canonical loop
// Search*(1900-01-01) then Next*(previous peak). See
// test/fixtures/astronomy_engine_golden/README.md.
//
// Required: identical sequence, identical kinds, peak times within 1 s.
// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:astro_ephemeris/src/astronomy/astronomy.dart';

Map<String, dynamic> _load() {
  final bytes = File(
    'test/fixtures/astronomy_engine_golden/eclipses.json.gz',
  ).readAsBytesSync();
  return jsonDecode(utf8.decode(gzip.decode(bytes))) as Map<String, dynamic>;
}

void main() {
  final golden = _load();
  final start = AstroTime.fromDateTime(DateTime.utc(1900));
  final stopUt = AstroTime.fromDateTime(DateTime.utc(2101)).ut;

  test('global solar eclipses 1900-2100 match the oracle', () {
    final rows = (golden['solar'] as List).cast<Map<String, dynamic>>();
    var e = searchGlobalSolarEclipse(start);
    var maxDt = 0.0, maxDist = 0.0, maxLat = 0.0, maxLon = 0.0, maxObs = 0.0;
    var i = 0;
    for (; e.peak.ut < stopUt; i++, e = nextGlobalSolarEclipse(e.peak)) {
      expect(i, lessThan(rows.length), reason: 'extra eclipse ${e.peak}');
      final g = rows[i];
      final dt = (e.peak.ut - (g['ut'] as num)).abs() * 86400;
      if (dt > maxDt) maxDt = dt;
      expect(dt, lessThanOrEqualTo(1.0), reason: '${g['iso']} peak');
      expect(e.kind.name, g['kind'], reason: '${g['iso']} kind');
      final dd = (e.distance - (g['distance'] as num)).abs();
      if (dd > maxDist) maxDist = dd;
      if (g['latitude'] == null) {
        expect(e.latitude, isNull);
        expect(e.obscuration, isNull);
      } else {
        final dl = (e.latitude! - (g['latitude'] as num)).abs();
        var dn = (e.longitude! - (g['longitude'] as num)).abs();
        if (dn > 180) dn = 360 - dn;
        final dob = (e.obscuration! - (g['obscuration'] as num)).abs();
        if (dl > maxLat) maxLat = dl;
        if (dn > maxLon) maxLon = dn;
        if (dob > maxObs) maxObs = dob;
      }
    }
    expect(i, rows.length, reason: 'missing eclipses');
    print(
      'solar: $i eclipses; max |dt| ${maxDt.toStringAsFixed(4)} s, '
      'distance ${maxDist.toStringAsExponential(2)} km, '
      'lat ${maxLat.toStringAsExponential(2)} deg, '
      'lon ${maxLon.toStringAsExponential(2)} deg, '
      'obscuration ${maxObs.toStringAsExponential(2)}',
    );
    expect(maxLat, lessThan(1e-3));
    expect(maxLon, lessThan(1e-3));
  });

  test('lunar eclipses 1900-2100 match the oracle', () {
    final rows = (golden['lunar'] as List).cast<Map<String, dynamic>>();
    var e = searchLunarEclipse(start);
    var maxDt = 0.0, maxSd = 0.0, maxObs = 0.0;
    var i = 0;
    for (; e.peak.ut < stopUt; i++, e = nextLunarEclipse(e.peak)) {
      expect(i, lessThan(rows.length), reason: 'extra eclipse ${e.peak}');
      final g = rows[i];
      final dt = (e.peak.ut - (g['ut'] as num)).abs() * 86400;
      if (dt > maxDt) maxDt = dt;
      expect(dt, lessThanOrEqualTo(1.0), reason: '${g['iso']} peak');
      expect(e.kind.name, g['kind'], reason: '${g['iso']} kind');
      for (final (v, key) in [
        (e.sdPenum, 'sd_penum'),
        (e.sdPartial, 'sd_partial'),
        (e.sdTotal, 'sd_total'),
      ]) {
        final d = (v - (g[key] as num)).abs();
        if (d > maxSd) maxSd = d;
      }
      final dob = (e.obscuration - (g['obscuration'] as num)).abs();
      if (dob > maxObs) maxObs = dob;
    }
    expect(i, rows.length, reason: 'missing eclipses');
    print(
      'lunar: $i eclipses; max |dt| ${maxDt.toStringAsFixed(4)} s, '
      'semi-durations ${(maxSd * 60).toStringAsFixed(4)} s, '
      'obscuration ${maxObs.toStringAsExponential(2)}',
    );
    // Semi-durations come from 1-second searches: allow 2 s of slack.
    expect(maxSd * 60, lessThan(2.0));
  });
}

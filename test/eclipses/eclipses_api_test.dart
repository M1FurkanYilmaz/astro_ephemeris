// The eclipse API: search semantics, the hybrid / non-central / lunar
// refinements on top of Astronomy Engine, peak times of well-known eclipses,
// and timing (each search is synchronous).
// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:test/test.dart';
import 'package:astro_ephemeris/src/astronomy/astronomy.dart' show EclipseKind;
import 'package:astro_ephemeris/src/eclipses/eclipses.dart';

/// Same eclipse found from another start: the 1-second search converges to
/// within milliseconds, not bit-identically.
const double _sameSecond = 1 / 86400;

String _day(DateTime t) => t.toIso8601String().substring(0, 10);

void main() {
  test('famous eclipses', () {
    final a = nextSolarEclipse(DateTime.utc(2017, 8, 1));
    expect(_day(a.peakUtc), '2017-08-21');
    expect(a.kind, EclipseCategory.total);
    final b = nextSolarEclipse(DateTime.utc(2023, 10, 1));
    expect(_day(b.peakUtc), '2023-10-14');
    expect(b.kind, EclipseCategory.annular);
    final c = nextSolarEclipse(DateTime.utc(2023, 4, 1));
    expect(_day(c.peakUtc), '2023-04-20');
    expect(c.kind, EclipseCategory.hybrid);
    final d = nextLunarEclipse(DateTime.utc(2022, 11, 1));
    expect(_day(d.peakUtc), '2022-11-08');
    expect(d.kind, EclipseCategory.total);
  });

  test('peak times of well-known eclipses (published greatest-eclipse UT)', () {
    final Map<DateTime, DateTime> solar = {
      DateTime.utc(2017, 8, 1): DateTime.utc(2017, 8, 21, 18, 25, 32),
      DateTime.utc(2023, 10, 1): DateTime.utc(2023, 10, 14, 17, 59, 32),
      DateTime.utc(2024, 4, 1): DateTime.utc(2024, 4, 8, 18, 17, 16),
    };
    solar.forEach((from, published) {
      final diff = nextSolarEclipse(from).peakUtc.difference(published);
      print('solar ${_day(published)}: ours - published = ${diff.inSeconds} s');
      expect(diff.inSeconds.abs(), lessThan(20));
    });
    final lunar = nextLunarEclipse(DateTime.utc(2022, 11, 1));
    final diff =
        lunar.peakUtc.difference(DateTime.utc(2022, 11, 8, 10, 59, 11));
    print('lunar 2022-11-08: ours - published = ${diff.inSeconds} s');
    expect(diff.inSeconds.abs(), lessThan(20));
  });

  test('peak at or after fromUtc, even between peak and syzygy', () {
    final from = DateTime.utc(2000);
    final to = DateTime.utc(2030);
    final solar = solarEclipsesBetween(from, to);
    final lunar = lunarEclipsesBetween(from, to);
    // Regression pins; the counts equal those of the Astronomy Engine golden
    // (test/fixtures/astronomy_engine_golden/eclipses.json.gz).
    expect(solar.length, 68);
    expect(lunar.length, 69);
    const eps = Duration(seconds: 10);
    for (var i = 0; i + 1 < solar.length; i++) {
      final p = solar[i].peakUtc;
      expect(
        nextSolarEclipse(p.subtract(eps)).jdUt,
        closeTo(solar[i].jdUt, _sameSecond),
      );
      expect(
        nextSolarEclipse(p.add(eps)).jdUt,
        closeTo(solar[i + 1].jdUt, _sameSecond),
      );
    }
    for (var i = 0; i + 1 < lunar.length; i++) {
      final p = lunar[i].peakUtc;
      expect(
        nextLunarEclipse(p.subtract(eps)).jdUt,
        closeTo(lunar[i].jdUt, _sameSecond),
      );
      expect(
        nextLunarEclipse(p.add(eps)).jdUt,
        closeTo(lunar[i + 1].jdUt, _sameSecond),
      );
    }
  });

  test('hybrid and non-central solar eclipses 1950-2100 (regression pin)', () {
    // 2005-04-08, 2013-11-03, 2023-04-20 and 2031-11-14 are hybrid in NASA's
    // eclipse catalogue; the rest of the lists are this package's output.
    final all = solarEclipsesBetween(DateTime.utc(1950), DateTime.utc(2101));
    final hybrid = [
      for (final e in all)
        if (e.kind == EclipseCategory.hybrid) _day(e.peakUtc),
    ];
    expect(hybrid, [
      '1986-10-03',
      '1987-03-29',
      '2005-04-08',
      '2013-11-03',
      '2023-04-20',
      '2031-11-14',
      '2049-11-25',
      '2050-05-20',
      '2067-12-06',
    ]);
    final nonCentral = [
      for (final e in all)
        if (e.nonCentral) '${_day(e.peakUtc)} ${e.kind.name}',
    ];
    expect(nonCentral, [
      '1950-03-18 annular',
      '1957-04-30 annular',
      '1957-10-23 total',
      '1967-11-02 total',
      '2014-04-29 annular',
      '2043-04-09 total',
      '2043-10-03 annular',
    ]);
    // Astronomy Engine's own kind is kept in `info`: hybrids are total at
    // the peak point, non-central ones partial.
    for (final e in all) {
      if (e.kind == EclipseCategory.hybrid) {
        expect(e.info.kind, EclipseKind.total);
      }
      if (e.nonCentral) expect(e.info.kind, EclipseKind.partial);
    }
  });

  test('lunar convention offset changes only three grazing eclipses', () {
    final golden = jsonDecode(
      utf8.decode(
        gzip.decode(
          File(
            'test/fixtures/astronomy_engine_golden/eclipses.json.gz',
          ).readAsBytesSync(),
        ),
      ),
    ) as Map<String, dynamic>;
    final aeKinds = [
      for (final r in (golden['lunar'] as List).cast<Map<String, dynamic>>())
        r['kind'] as String,
    ];
    final ours = lunarEclipsesBetween(DateTime.utc(1900), DateTime.utc(2101));
    expect(ours.length, aeKinds.length);
    final changed = [
      for (var i = 0; i < ours.length; i++)
        if (ours[i].kind.name != aeKinds[i])
          '${_day(ours[i].peakUtc)} ${aeKinds[i]}->${ours[i].kind.name}',
    ];
    // All three are penumbral in NASA's Five Millennium Canon (umbral
    // magnitude -0.0040, -0.0017, -0.0031).
    expect(changed, [
      '1900-06-13 partial->penumbral',
      '1988-03-03 partial->penumbral',
      '2042-09-29 partial->penumbral',
    ]);
  });

  test('timing report', () {
    final rnd = math.Random(7);
    // Warm-up (JIT).
    nextSolarEclipse(DateTime.utc(2000));
    nextLunarEclipse(DateTime.utc(2000));
    for (final solar in [true, false]) {
      final ms = <double>[];
      for (var i = 0; i < 100; i++) {
        final from = DateTime.utc(
          1950,
        ).add(Duration(minutes: rnd.nextInt(150 * 525960)));
        final sw = Stopwatch()..start();
        solar ? nextSolarEclipse(from) : nextLunarEclipse(from);
        ms.add(sw.elapsedMicroseconds / 1000);
      }
      ms.sort();
      final mean = ms.reduce((a, b) => a + b) / ms.length;
      print(
        '${solar ? 'nextSolarEclipse' : 'nextLunarEclipse'}: mean '
        '${mean.toStringAsFixed(2)} ms, p95 ${ms[94].toStringAsFixed(2)} ms, '
        'max ${ms.last.toStringAsFixed(2)} ms (100 random starts)',
      );
    }
    final sw = Stopwatch()..start();
    solarEclipsesBetween(DateTime.utc(2026), DateTime.utc(2027));
    lunarEclipsesBetween(DateTime.utc(2026), DateTime.utc(2027));
    print('one year, both kinds: ${sw.elapsedMilliseconds} ms');
  });
}

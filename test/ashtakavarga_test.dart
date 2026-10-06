import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_astro/domain/models.dart';
import 'package:pocket_astro/engine/ashtakavarga.dart';
import 'package:pocket_astro/engine/chart_builder.dart';
import 'package:pocket_astro/engine/forecast.dart';
import 'package:pocket_astro/engine/kb.dart';
import 'package:pocket_astro/engine/tables.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;

/// Ashtakavarga has strong arithmetic invariants: the per-graha totals are
/// fixed at 48/49/39/54/56/52/39 no matter where the grahas sit, the
/// sarvashtakavarga always sums to 337, and no sign can hold more than 8
/// bindus in a bhinnashtakavarga or 56 in the sarva. A bug in the counting
/// direction or the modular arithmetic breaks at least one of them, so these
/// are tested against many random charts rather than one fixture.

const _lons = <String, double>{
  'Sun': 10.0, 'Moon': 100.0, 'Mars': 200.0, 'Mercury': 25.0,
  'Jupiter': 310.0, 'Venus': 45.0, 'Saturn': 265.0,
};

AshtakavargaChart build({Map<String, double>? lons, double lagna = 5.0}) =>
    computeAshtakavarga(
      siderealLongitudes: lons ?? _lons,
      lagnaSidereal: lagna,
    )!;

/// A deterministic pseudo-random spread, so failures are reproducible.
Map<String, double> spreadFor(int seed) {
  var x = seed * 2654435761 % 4294967296;
  double next() {
    x = (x * 1103515245 + 12345) % 2147483648;
    return (x % 360000) / 1000.0;
  }

  return {for (final p in avPlanets) p: next()};
}

void main() {
  tzdata.initializeTimeZones();

  setUpAll(() {
    PredictionKb.loadFromMap(
      jsonDecode(File('assets/kb/prediction.json').readAsStringSync())
          as Map<String, dynamic>,
    );
    PredictionKb.loadMatchingFromMap(
      jsonDecode(File('assets/kb/ashtakoota.json').readAsStringSync())
          as Map<String, dynamic>,
    );
    for (final e in PredictionKb.moduleAssets.entries) {
      PredictionKb.loadModuleFromMap(
        e.key,
        jsonDecode(File(e.value).readAsStringSync()) as Map<String, dynamic>,
      );
    }
  });

  group('invariants across 200 random charts', () {
    test('per-graha totals are the classical constants', () {
      for (var seed = 1; seed <= 200; seed++) {
        final av = build(lons: spreadFor(seed), lagna: (seed * 7.3) % 360);
        for (final p in avPlanets) {
          expect(av.bhinna[p]!.total, avExpectedTotals[p],
              reason: '$p total wrong on seed $seed');
        }
      }
    });

    test('sarvashtakavarga always sums to 337', () {
      for (var seed = 1; seed <= 200; seed++) {
        final av = build(lons: spreadFor(seed), lagna: (seed * 11.7) % 360);
        expect(av.sarvaTotal, avSarvaTotal, reason: 'seed $seed');
        expect(av.sarvaBySign, hasLength(12));
      }
    });

    test('no sign exceeds 8 bindus in a bhinna or 56 in the sarva', () {
      for (var seed = 1; seed <= 200; seed++) {
        final av = build(lons: spreadFor(seed), lagna: (seed * 3.1) % 360);
        for (final p in avPlanets) {
          for (final n in av.bhinna[p]!.bySign) {
            expect(n, inInclusiveRange(0, 8), reason: '$p on seed $seed');
          }
        }
        for (final n in av.sarvaBySign) {
          expect(n, inInclusiveRange(0, 56), reason: 'seed $seed');
        }
      }
    });

    test('each contributor appears at most once per sign', () {
      final av = build();
      for (final p in avPlanets) {
        for (final set in av.bhinna[p]!.contributors) {
          expect(set.length, lessThanOrEqualTo(8));
          expect(set.difference(avContributors.toSet()), isEmpty);
        }
      }
    });
  });

  group('counting direction', () {
    test('a contributor places a bindu in its own sign when house 1 is listed',
        () {
      // The Sun's table lists house 1 from the Sun itself, so the Sun's own
      // sign must carry a bindu contributed by the Sun.
      final av = build(lons: {..._lons, 'Sun': 100.0}); // Cancer
      final sunSign = signIndex(100.0);
      expect(av.bhinna['Sun']!.contributors[sunSign], contains('Sun'));
    });

    test('house 11 from a contributor lands ten signs later, not earlier', () {
      // Saturn's table gives the Moon a bindu in the 3rd, 6th and 11th from
      // the Moon. Put the Moon at 0° Aries and check the 11th is Aquarius.
      final av = build(lons: {..._lons, 'Moon': 5.0});
      final aquarius = signIndex(305.0);
      final gemini = signIndex(65.0); // the 3rd from Aries
      expect(av.bhinna['Saturn']!.contributors[aquarius], contains('Moon'));
      expect(av.bhinna['Saturn']!.contributors[gemini], contains('Moon'));
      // And nothing at the 2nd, which is not in Saturn's list from the Moon.
      final taurus = signIndex(35.0);
      expect(av.bhinna['Saturn']!.contributors[taurus], isNot(contains('Moon')));
    });

    test('the lagna contributes like any other reference point', () {
      final av = build(lagna: 185.0); // Libra
      // The Sun's table gives the lagna houses 3, 4, 6, 10, 11, 12.
      final libra = signIndex(185.0);
      for (final h in const [3, 4, 6, 10, 11, 12]) {
        expect(av.bhinna['Sun']!.contributors[(libra + h - 1) % 12],
            contains('Lagna'),
            reason: 'house $h from the lagna');
      }
      for (final h in const [1, 2, 5, 7, 8, 9]) {
        expect(av.bhinna['Sun']!.contributors[(libra + h - 1) % 12],
            isNot(contains('Lagna')),
            reason: 'house $h from the lagna should be empty');
      }
    });

    test('moving the lagna moves only the lagna contributions', () {
      final a = build(lagna: 5.0);
      final b = build(lagna: 185.0);
      for (final p in avPlanets) {
        for (var s = 0; s < 12; s++) {
          final fa = a.bhinna[p]!.contributors[s].difference({'Lagna'});
          final fb = b.bhinna[p]!.contributors[s].difference({'Lagna'});
          expect(fa, fb, reason: '$p sign $s changed when only the lagna moved');
        }
      }
    });
  });

  group('house and sign lookups', () {
    test('sarva by house agrees with sarva by sign', () {
      final av = build(lagna: 215.0); // Scorpio rising
      for (var h = 1; h <= 12; h++) {
        expect(av.sarvaInHouse(h), av.sarvaInSign((av.lagnaSign + h - 1) % 12));
      }
      expect(av.sarvaInHouse(1), av.sarvaInSign(av.lagnaSign));
    });

    test('strong and weak houses partition around the average', () {
      final av = build();
      final avg = PredictionKb.current.sarvaAverage;
      for (final h in av.strongHouses) {
        expect(av.sarvaInHouse(h), greaterThan(avg));
      }
      for (final h in av.weakHouses) {
        expect(av.sarvaInHouse(h), lessThan(avg));
      }
      expect(av.strongHouses.toSet().intersection(av.weakHouses.toSet()),
          isEmpty);
    });
  });

  group('kakshya', () {
    test('eight kakshyas of 3°45 fill a sign, Saturn first', () {
      expect(kakshyaArcDeg, 3.75);
      expect(kakshyaIndex(0.0), 0);
      expect(kakshyaIndex(3.74), 0);
      expect(kakshyaIndex(3.76), 1);
      expect(kakshyaIndex(29.99), 7);
      expect(kakshyaIndex(30.0), 0); // first kakshya of the next sign
      expect(kakshyaOwner(0.0), 'Saturn');
      expect(kakshyaOwner(4.0), 'Jupiter');
      expect(kakshyaOwner(29.0), 'Lagna');
      expect(kakshyaOwner(150.0 + 8.0), 'Mars');
    });

    test('kakshya ownership repeats identically in every sign', () {
      for (var s = 0; s < 12; s++) {
        for (var k = 0; k < 8; k++) {
          expect(kakshyaOwner(s * 30.0 + k * kakshyaArcDeg + 1.0),
              kakshyaOwner(k * kakshyaArcDeg + 1.0));
        }
      }
    });

    test('a day is graded 0 to 7 with the classical wording', () {
      final av = build();
      final day = kakshyaDay(av, {for (final p in avPlanets) p: 12.0});
      expect(day.score, inInclusiveRange(0, 7));
      expect(day.withBindu.length + day.withoutBindu.length, 7);
      expect(day.quality, isNotEmpty);
      expect(day.line, contains('of 7 grahas'));
    });

    test('the grade matches whether the kakshya owner gave a bindu', () {
      final av = build();
      // Put every graha at 1° of Aries: the Saturn kakshya of Aries.
      final day = kakshyaDay(av, {for (final p in avPlanets) p: 1.0});
      for (final p in avPlanets) {
        final hasBindu = av.bhinna[p]!.contributors[0].contains('Saturn');
        final listed = hasBindu ? day.withBindu : day.withoutBindu;
        expect(listed.any((e) => e.startsWith(p)), isTrue,
            reason: '$p graded on the wrong side');
      }
    });
  });

  group('transit judgment', () {
    test('verdict follows the 5 / 4 / 0-3 rule', () {
      final av = build();
      for (var s = 0; s < 12; s++) {
        final t = judgeTransit(av, 'Jupiter', s * 30.0 + 10.0)!;
        expect(t.sign, s);
        expect(t.bindus, av.bhinna['Jupiter']!.inSign(s));
        final expected = t.bindus >= 5
            ? 'delivers'
            : t.bindus == 4
                ? 'mixed'
                : 'withholds';
        expect(t.verdict, expected, reason: 'sign $s with ${t.bindus} bindus');
        expect(t.reading, isNotEmpty);
      }
    });

    test('houses are reported from both the lagna and the Moon', () {
      final av = build(lagna: 5.0); // Aries rising, Moon in Cancer
      final t = judgeTransit(av, 'Saturn', 95.0)!; // Cancer
      expect(t.houseFromLagna, 4);
      expect(t.houseFromMoon, 1);
    });

    test('confidence delta rewards 5+ and penalises 0-3', () {
      expect(avConfidenceDelta(8), greaterThan(0));
      expect(avConfidenceDelta(5), greaterThan(0));
      expect(avConfidenceDelta(4), 0);
      expect(avConfidenceDelta(3), lessThan(0));
      expect(avConfidenceDelta(0), lessThan(0));
    });
  });

  group('dignity override (Charak XXX points 7 and 8)', () {
    test('a strong graha on few bindus is flagged', () {
      // Find a chart where an exalted graha sits on fewer than four bindus.
      String? note;
      for (var seed = 1; seed <= 400 && note == null; seed++) {
        final lons = spreadFor(seed);
        lons['Saturn'] = 185.0; // exalted in Libra
        final av = build(lons: lons, lagna: (seed * 5.0) % 360);
        note = av.dignityOverride('Saturn', 'exalted');
      }
      expect(note, isNotNull,
          reason: 'no chart in 400 put an exalted Saturn on under 4 bindus');
      expect(note, contains('exalted'));
      expect(note, contains('bindu'));
    });

    test('nothing is flagged when dignity and bindus agree', () {
      final av = build();
      // A graha with no dignity string never produces an override.
      expect(av.dignityOverride('Mars', ''), isNull);
    });
  });

  group('house comparisons', () {
    test('every rule in the KB is evaluated, none silently unknown', () {
      final av = build();
      final ids = PredictionKb.current.avComparisons
          .map((c) => c['rule'] as String)
          .toList();
      expect(ids, isNotEmpty);
      expect(av.comparisons.map((c) => c.rule).toList(), ids);
      for (final c in av.comparisons) {
        expect(c.means, isNotEmpty);
      }
    });

    test('the 11-above-10 rule reads the right two houses', () {
      final av = build();
      final c = av.comparisons.firstWhere((c) => c.rule == '11_above_10');
      expect(c.holds, av.sarvaInHouse(11) > av.sarvaInHouse(10));
    });
  });

  group('birth time', () {
    test('a chart without a birth time yields no ashtakavarga', () {
      final input = BirthInput(
        id: 'n',
        name: 'No time',
        localDateTime: DateTime(1992, 4, 14),
        place: const Place(
          name: 'Kathmandu',
          region: 'Nepal',
          latitude: 27.7172,
          longitude: 85.3240,
          timezone: 'Asia/Kathmandu',
        ),
        timeSource: TimeSource.unknown,
      );
      final chart = buildChart(input, DateTime.utc(1992, 4, 13, 22, 12));
      expect(ashtakavargaFor(chart), isNull);
    });

    test('a timed chart yields a complete ashtakavarga', () {
      final input = BirthInput(
        id: 't',
        name: 'Timed',
        localDateTime: DateTime(1992, 4, 14, 3, 57),
        place: const Place(
          name: 'Kathmandu',
          region: 'Nepal',
          latitude: 27.7172,
          longitude: 85.3240,
          timezone: 'Asia/Kathmandu',
        ),
        timeSource: TimeSource.memory,
      );
      final chart = buildChart(input, DateTime.utc(1992, 4, 13, 22, 12));
      final av = ashtakavargaFor(chart)!;
      expect(av.sarvaTotal, 337);
      expect(av.lagnaSign, signIndex(chart.lagnaSidereal));
      expect(av.moonSign, signIndex(chart.graha('Moon').siderealLon));
      for (final p in avPlanets) {
        expect(av.natalSigns[p], signIndex(chart.graha(p).siderealLon));
      }
    });

    test('an incomplete set of longitudes yields null rather than a wrong sum',
        () {
      final partial = Map<String, double>.from(_lons)..remove('Saturn');
      expect(
        computeAshtakavarga(siderealLongitudes: partial, lagnaSidereal: 5.0),
        isNull,
      );
    });
  });

  group('forecast integration', () {
    late NatalChart chart;

    setUp(() {
      final input = BirthInput(
        id: 'f',
        name: 'Forecast',
        localDateTime: DateTime(1992, 4, 14, 3, 57),
        place: const Place(
          name: 'Kathmandu',
          region: 'Nepal',
          latitude: 27.7172,
          longitude: 85.3240,
          timezone: 'Asia/Kathmandu',
        ),
        timeSource: TimeSource.memory,
      );
      chart = buildChart(input, DateTime.utc(1992, 4, 13, 22, 12));
    });

    test('the snapshot carries a complete ashtakavarga and seven transits', () {
      final f = forecastChart(chart, now: DateTime.utc(2026, 9, 15));
      expect(f.now.av, isNotNull);
      expect(f.now.av!.sarvaTotal, 337);
      expect(f.now.avTransits.keys.toSet(), avPlanets.toSet());
      for (final p in avPlanets) {
        expect(f.now.bindusFor(p), inInclusiveRange(0, 8));
      }
    });

    test('the gochara hit reports bindus for the slow grahas', () {
      final f = forecastChart(chart, now: DateTime.utc(2026, 9, 15));
      final g = f.hits.firstWhere((h) => h.title == 'Gochara now');
      expect(g.body, contains('bindu'));
      expect(g.body, contains('Sarvashtakavarga'));
    });

    test('a bindu veto never coexists with a likely verdict', () {
      // Scan four years so the veto path is actually exercised.
      var vetoes = 0;
      var confirmations = 0;
      for (var m = 0; m < 48; m++) {
        final when = DateTime.utc(2026, 9 + m, 15);
        final f = forecastChart(chart, now: when);
        for (final h in f.hits) {
          final techniques = h.techniques.join(' ');
          if (techniques.contains('ashtakavarga veto')) {
            vetoes++;
            expect(h.verdict, isNot('likely'),
                reason: 'vetoed hit called likely at $when: ${h.title}');
            expect(h.body, contains('withholds its result'));
          }
          if (techniques.contains('ashtakavarga: Jupiter holds')) {
            confirmations++;
          }
        }
      }
      expect(vetoes + confirmations, greaterThan(0),
          reason: 'ashtakavarga never engaged across four years of windows');
    });

    test('a chart without a birth time still forecasts, minus ashtakavarga',
        () {
      final input = BirthInput(
        id: 'n',
        name: 'No time',
        localDateTime: DateTime(1992, 4, 14),
        place: chart.input.place,
        timeSource: TimeSource.unknown,
      );
      final noTime = buildChart(input, DateTime.utc(1992, 4, 13, 22, 12));
      final f = forecastChart(noTime, now: DateTime.utc(2026, 9, 15));
      expect(f.now.av, isNull);
      expect(f.now.avTransits, isEmpty);
      expect(f.hits, isNotEmpty);
      final g = f.hits.firstWhere((h) => h.title == 'Gochara now');
      expect(g.body, contains('Ashtakavarga is withheld'));
    });
  });

  test('an empty catalogue yields null rather than throwing', () {
    final saved = Map<String, dynamic>.from(
      PredictionKb.modules['ashtakavarga'] ?? const {},
    );
    PredictionKb.loadModuleFromMap('ashtakavarga', const {});
    expect(
      computeAshtakavarga(siderealLongitudes: _lons, lagnaSidereal: 5.0),
      isNull,
    );
    PredictionKb.loadModuleFromMap('ashtakavarga', saved);
  });
}

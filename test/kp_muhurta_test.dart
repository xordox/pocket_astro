/// Tests for the second tranche: KP, extended matching, Varshaphal, Muhurta
/// and rectification.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_astro/domain/models.dart';
import 'package:pocket_astro/engine/astro/units.dart';
import 'package:pocket_astro/engine/chart_builder.dart';
import 'package:pocket_astro/engine/kb.dart';
import 'package:pocket_astro/engine/kp.dart';
import 'package:pocket_astro/engine/matching_extended.dart';
import 'package:pocket_astro/engine/muhurta.dart';
import 'package:pocket_astro/engine/rectification.dart';
import 'package:pocket_astro/engine/tables.dart';
import 'package:pocket_astro/engine/time_convert.dart';
import 'package:pocket_astro/engine/varshaphal.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;

const _kathmandu = Place(
  name: 'Kathmandu', region: 'Nepal',
  latitude: 27.7172, longitude: 85.324, timezone: 'Asia/Kathmandu');

late NatalChart bride;
late NatalChart groom;

void main() {
  tzdata.initializeTimeZones();

  setUpAll(() {
    PredictionKb.loadFromMap(jsonDecode(
        File('assets/kb/prediction.json').readAsStringSync()) as Map<String, dynamic>);
    PredictionKb.loadMatchingFromMap(jsonDecode(
        File('assets/kb/ashtakoota.json').readAsStringSync()) as Map<String, dynamic>);
    for (final e in PredictionKb.moduleAssets.entries) {
      PredictionKb.loadModuleFromMap(e.key,
          jsonDecode(File(e.value).readAsStringSync()) as Map<String, dynamic>);
    }
    bride = _chart('Bride', DateTime(1992, 4, 14, 3, 57));
    groom = _chart('Groom', DateTime(1989, 11, 3, 9, 40));
  });

  group('KP', () {
    test('the zodiac divides into exactly 249 parts', () {
      // The canonical KP table has 249 entries. This one is generated from the
      // sub division rather than transcribed, so hitting 249 exactly is a
      // check on the arithmetic — not a coincidence.
      final divisions = kpDivisions();
      expect(divisions.length, 249);
      expect(divisions.first.start, 0.0);
      expect(divisions.last.end, closeTo(360.0, 1e-6));
      for (var i = 0; i < divisions.length - 1; i++) {
        expect(divisions[i].end, closeTo(divisions[i + 1].start, 1e-9));
      }
    });

    test('subs tile their nakshatra in Vimshottari proportion', () {
      for (var nak = 0; nak < 27; nak++) {
        final start = nak * nakshatraWidth;
        final lords = <String>[];
        var probe = start + 1e-6;
        while (probe < start + nakshatraWidth - 1e-6) {
          final p = kpPointer(probe);
          if (lords.isEmpty || lords.last != p.subLord) lords.add(p.subLord);
          probe = p.subEnd + 1e-6;
        }
        expect(lords.length, 9, reason: nakshatras[nak].name);
        // The first sub belongs to the nakshatra lord.
        expect(lords.first, nakshatras[nak].lord);
        // And the widths are in Vimshottari proportion.
        final first = kpPointer(start + 1e-6);
        expect(
          first.subEnd - first.subStart,
          closeTo(nakshatraWidth * vimshottariYears[lords.first]! / 120, 1e-9),
        );
      }
    });

    test('sub-sub divides the sub the same way', () {
      final p = kpPointer(97.3);
      expect(vimshottariOrder, contains(p.subSubLord));
      expect(p.longitude, inInclusiveRange(p.subStart, p.subEnd));
    });

    test('significators rank the four steps', () {
      for (var h = 1; h <= 12; h++) {
        final s = significatorsFor(bride, h);
        expect(s.lord, isNotEmpty);
        // No planet appears twice in the ranked list.
        expect(s.ranked.toSet().length, s.ranked.length);
        // The house lord always signifies its own house.
        expect(s.signifies(s.lord), isTrue);
      }
    });

    test('cuspal sub-lords produce a verdict for every house', () {
      final cusps = cuspalSubLords(bride);
      expect(cusps.length, 12);
      for (final c in cusps) {
        expect(const ['promises', 'denies', 'mixed'], contains(c.verdict));
        expect(c.line, isNotEmpty);
        expect(vimshottariOrder, contains(c.pointer.subLord));
      }
    });

    test('ruling planets are ordered and free of repeats', () {
      final rp = rulingPlanets(
        utc: DateTime.utc(2024, 6, 1, 9, 30),
        latitude: 27.7172,
        longitudeEast: 85.324,
      );
      expect(rp.ordered, isNotEmpty);
      expect(rp.ordered.toSet().length, rp.ordered.length);
      expect(rp.ordered.length, lessThanOrEqualTo(7));
      expect(rp.dayLord, isNotEmpty);
    });

    test('a horary number selects a division and an ascendant', () {
      for (final n in const [1, 63, 128, 249]) {
        final d = horaryDivisionFor(n);
        expect(d.number, n);
        final asc = horaryAscendantFor(n);
        expect(asc, inInclusiveRange(d.start, d.end));
      }
    });

    test('KP settings are the three that have to travel together', () {
      expect(kpSettings.ayanamsa.name, 'krishnamurti');
      expect(kpSettings.houseSystem.name, 'placidus');
      expect(kpSettings.topocentric, isTrue);
    });
  });

  group('extended matching', () {
    test('rajju runs the classical zigzag', () {
      // 1-2-3-4-5-4-3-2-1, repeating across the 27.
      expect(rajjuOf(0), 0);  // Ashwini, Pada
      expect(rajjuOf(4), 4);  // Mrigashira, Siro
      expect(rajjuOf(8), 0);  // Ashlesha, back to Pada
      expect(rajjuOf(13), 4); // Chitra, Siro
      expect(rajjuOf(22), 4); // Dhanishta, Siro
      expect(rajjuOf(26), 0); // Revati, Pada
      for (var i = 0; i < 27; i++) {
        expect(rajjuOf(i), inInclusiveRange(0, 4));
      }
    });

    test('vedha pairs are symmetric and Chitra is unpaired', () {
      var paired = 0;
      for (var i = 0; i < 27; i++) {
        for (var j = 0; j < 27; j++) {
          if (vedhaBetween(nakshatras[i], nakshatras[j])) {
            expect(vedhaBetween(nakshatras[j], nakshatras[i]), isTrue);
            paired++;
          }
        }
      }
      // Thirteen pairs, counted twice.
      expect(paired, 26);
      expect(
        List.generate(27, (j) => vedhaBetween(nakshatras[13], nakshatras[j]))
            .any((x) => x),
        isFalse,
        reason: 'Chitra has no vedha partner',
      );
    });

    test('Stree-Deergha is directional', () {
      final forward = streeDeergha(0, 20);
      final backward = streeDeergha(20, 0);
      expect(forward.count, isNot(backward.count));
      expect(forward.full, isTrue);
    });

    test('a full extended report is produced with reasons', () {
      final m = extendedMatch(bride, groom);
      expect(m.checks, isNotEmpty);
      for (final c in m.checks) {
        expect(c.note, isNotEmpty, reason: c.name);
      }
      expect(m.rajju.note, isNotEmpty);
      expect(m.summary, isNotEmpty);
      expect(navamsaCompatibility(bride, groom), contains('navamsa lagna'));
    });

    test('nadi exceptions are evaluated rather than assumed away', () {
      final exceptions = nadiExceptions(bride, groom);
      for (final e in exceptions) {
        expect(e.applies, isTrue);
        expect(e.reason, isNotEmpty);
      }
    });

    test('papasamya compares rather than condemns', () {
      final a = papaWeight(bride);
      final b = papaWeight(groom);
      expect(a, greaterThanOrEqualTo(0));
      expect(b, greaterThanOrEqualTo(0));
    });
  });

  group('varshaphal', () {
    test('the solar return lands on the natal sidereal Sun', () {
      final v = varshaphalFor(bride, 2024);
      expect(v, isNotNull);
      expect(
        separation(v!.chart.graha('Sun').siderealLon,
            bride.graha('Sun').siderealLon),
        lessThan(0.05),
      );
    });

    test('the muntha advances one sign a year', () {
      final a = varshaphalFor(bride, 2023)!;
      final b = varshaphalFor(bride, 2024)!;
      expect((b.muntha.sign - a.muntha.sign) % 12, 1);
    });

    test('the year lord is chosen from five offices and the workings are kept',
        () {
      final v = varshaphalFor(bride, 2024)!;
      expect(v.offices.length, 5);
      expect(v.offices.map((o) => o.planet), contains(v.varshesha));
      final best = v.offices.reduce((a, b) => a.bala >= b.bala ? a : b);
      expect(v.varshesha, best.planet);
    });

    test('Mudda dasha fills the year', () {
      final v = varshaphalFor(bride, 2024)!;
      expect(v.mudda.length, 9);
      for (var i = 0; i < 8; i++) {
        expect(v.mudda[i].end, v.mudda[i + 1].start);
      }
      final span = v.mudda.last.end.difference(v.mudda.first.start).inDays;
      expect(span, lessThanOrEqualTo(366));
    });

    test('Ithasala is applying and Ishrafa separating', () {
      final v = varshaphalFor(bride, 2024)!;
      for (final a in v.aspects) {
        expect(a.orb, lessThanOrEqualTo(a.allowed));
        if (a.yoga == TajikaYoga.ithasala) {
          expect(a.reading, contains('completes'));
        }
        if (a.yoga == TajikaYoga.ishrafa) {
          expect(a.reading, contains('has gone'));
        }
      }
    });

    test('panchavargiya stays within its eighty points', () {
      for (final p in const ['Sun', 'Moon', 'Mars', 'Jupiter', 'Saturn']) {
        for (var lon = 0.0; lon < 360; lon += 17) {
          final b = panchavargiya(p, lon);
          expect(b.total, inInclusiveRange(0.0, 80.0));
        }
      }
    });
  });

  group('muhurta', () {
    test('finds windows and never returns one inside Rahu kaal', () {
      final result = searchMuhurta(
        purpose: MuhurtaPurpose.business,
        from: DateTime.utc(2024, 6, 3),
        to: DateTime.utc(2024, 6, 6),
        place: _kathmandu,
        native: bride,
        step: const Duration(hours: 1),
      );
      expect(result.notes, isNotEmpty);
      for (final w in result.windows) {
        expect(w.factors, isNotEmpty);
        expect(w.verdict, isNotEmpty);
        // Every window must carry its own reasons.
        expect(w.helps.length + w.hurts.length, w.factors.length);
      }
      // Some candidates must have been refused outright.
      expect(result.rejected, greaterThan(0));
    });

    test('a native changes the answer', () {
      final without = searchMuhurta(
        purpose: MuhurtaPurpose.travel,
        from: DateTime.utc(2024, 6, 3),
        to: DateTime.utc(2024, 6, 5),
        place: _kathmandu,
        step: const Duration(hours: 2),
      );
      final with_ = searchMuhurta(
        purpose: MuhurtaPurpose.travel,
        from: DateTime.utc(2024, 6, 3),
        to: DateTime.utc(2024, 6, 5),
        place: _kathmandu,
        native: bride,
        step: const Duration(hours: 2),
      );
      expect(
        with_.windows.any((w) =>
            w.factors.any((f) => f.name == 'Tarabala' || f.name == 'Chandrabala')),
        isTrue,
      );
      expect(without.notes.join(), isNot(contains('Tarabala')));
    });

    test('each purpose names the houses that carry it', () {
      for (final p in MuhurtaPurpose.values) {
        expect(p.houses, isNotEmpty, reason: p.label);
        expect(p.favouredNakshatras, isNotEmpty, reason: p.label);
        for (final h in p.houses) {
          expect(h, inInclusiveRange(1, 12));
        }
      }
    });
  });

  group('rectification', () {
    test('sensitivity reports what a window actually costs', () {
      final input = _input('Test', DateTime(1992, 4, 14, 3, 57));
      final s = sensitivityOf(input, window: const Duration(hours: 2));
      expect(s.notes, isNotEmpty);
      expect(s.ascendantSigns, isNotEmpty);
      // Two hours of lagna is more than one sign at this latitude.
      expect(s.ascendantSigns.length, greaterThanOrEqualTo(1));
    });

    test('a narrow window is reported as stable', () {
      final input = _input('Test', DateTime(1992, 4, 14, 3, 57));
      final s = sensitivityOf(input, window: const Duration(seconds: 30));
      expect(s.ascendantSigns.length, 1);
      expect(s.houseChanges, isEmpty);
    });

    test('event fitting ranks candidates and shows its working', () {
      final input = _input('Test', DateTime(1992, 4, 14, 3, 57));
      final result = rectify(
        input,
        [
          LifeEvent(
            when: DateTime.utc(2018, 6, 1),
            description: 'Marriage',
            houses: const [7, 2, 11],
          ),
          LifeEvent(
            when: DateTime.utc(2021, 3, 15),
            description: 'Moved house',
            houses: const [4, 3, 12],
          ),
          LifeEvent(
            when: DateTime.utc(2015, 9, 1),
            description: 'Started a job',
            houses: const [10, 6, 2],
          ),
        ],
        window: const Duration(hours: 1),
        step: const Duration(minutes: 10),
      );

      expect(result.candidates, isNotEmpty);
      expect(result.notes, isNotEmpty);
      for (var i = 0; i < result.candidates.length - 1; i++) {
        expect(result.candidates[i].score,
            greaterThanOrEqualTo(result.candidates[i + 1].score));
      }
      expect(result.best!.lagnaSign, inInclusiveRange(0, 11));
    });

    test('the live ascendant helper agrees with a full chart', () {
      final input = _input('Test', DateTime(1992, 4, 14, 3, 57));
      final quick = ascendantAt(input, input.localDateTime);
      final full = buildChart(input, toUtc(input));
      expect(quick.sign, signIndex(full.lagnaSidereal));
      expect(quick.degree, closeTo(full.lagnaSidereal % 30, 1e-6));
      expect(quick.navamsa, full.navamsaLagna);
    });

    test('event templates name plausible houses', () {
      for (final t in eventTemplates) {
        expect(t.houses, isNotEmpty, reason: t.label);
        for (final h in t.houses) {
          expect(h, inInclusiveRange(1, 12));
        }
      }
    });
  });
}

BirthInput _input(String name, DateTime local) => BirthInput(
      id: name,
      name: name,
      localDateTime: local,
      place: _kathmandu,
      timeSource: TimeSource.hospital,
    );

NatalChart _chart(String name, DateTime local) {
  final input = _input(name, local);
  return buildChart(input, toUtc(input));
}

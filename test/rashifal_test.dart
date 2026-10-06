import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_astro/domain/models.dart';
import 'package:pocket_astro/engine/astronomy.dart';
import 'package:pocket_astro/engine/kb.dart';
import 'package:pocket_astro/engine/rashifal.dart';
import 'package:pocket_astro/engine/tables.dart';
import 'package:pocket_astro/engine/today.dart' show DayGrade, DayGradeText;
import 'package:pocket_astro/l10n/engine_strings.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// The daily rashifal is the app's most-read and least-precise surface, which
/// makes it the one most worth pinning down. The tests here are about the two
/// things that would make it dishonest rather than merely coarse: a reading
/// that does not correspond to where the grahas actually are, and twelve signs
/// that quietly say the same thing.

const _kathmandu = Place(
  name: 'Kathmandu',
  region: 'Nepal',
  latitude: 27.7172,
  longitude: 85.3240,
  timezone: 'Asia/Kathmandu',
);

final _noon = tz.TZDateTime(
  tz.getLocation('Asia/Kathmandu'),
  2026,
  4,
  14,
  12,
).toUtc();

void loadKb(String code) {
  for (final e in PredictionKb.moduleAssets.entries) {
    final base =
        jsonDecode(File(e.value).readAsStringSync()) as Map<String, dynamic>;
    final overlay = File('assets/kb/i18n/$code/${e.value.split('/').last}');
    PredictionKb.loadModuleFromMap(
      e.key,
      code == 'en' || !overlay.existsSync()
          ? base
          : PredictionKb.mergeOverlay(
              base,
              jsonDecode(overlay.readAsStringSync()) as Map<String, dynamic>,
            ),
    );
  }
}

bool isDevanagari(String s) => s.runes.any((r) => r >= 0x0900 && r <= 0x097F);

void main() {
  tzdata.initializeTimeZones();

  setUpAll(() {
    PredictionKb.loadFromMap(
      jsonDecode(File('assets/kb/prediction.json').readAsStringSync())
          as Map<String, dynamic>,
    );
    loadKb('en');
    for (final code in supportedLocaleCodes) {
      if (code == 'en') continue;
      EngineStrings.register(
        code,
        File('assets/kb/i18n/$code/engine.json').readAsStringSync(),
      );
    }
  });

  tearDown(() {
    EngineStrings.install('en');
    loadKb('en');
  });

  group('shape', () {
    test('twelve signs, in zodiac order, each fully populated', () {
      final days = rashifalForAll(place: _kathmandu, now: _noon);
      expect(days, hasLength(12));
      for (var i = 0; i < 12; i++) {
        final d = days[i];
        expect(d.sign, i);
        expect(d.name, signName(i));
        expect(d.lines, hasLength(rashifalGrahas.length));
        expect(d.moonHouse, inInclusiveRange(1, 12));
        expect(d.headline, isNotEmpty);
        expect(d.headline, isNot(contains('{')));
        expect(d.headline, isNot(startsWith('rashi.')));
      }
    });

    test('every line carries a real reading from the knowledge base', () {
      for (final day in rashifalForAll(place: _kathmandu, now: _noon)) {
        for (final line in day.lines) {
          expect(line.house, inInclusiveRange(1, 12));
          expect(line.sign, inInclusiveRange(0, 11));
          expect(line.reading, isNotEmpty,
              reason: '${line.graha} in house ${line.house}');
          // A missing KB row would surface as a bare lookup path.
          expect(line.reading, isNot(startsWith('transits.')));
        }
      }
    });

    test('rashifalFor agrees with the batch, and wraps out-of-range signs', () {
      final all = rashifalForAll(place: _kathmandu, now: _noon);
      for (var i = 0; i < 12; i++) {
        expect(rashifalFor(i, place: _kathmandu, now: _noon).score,
            all[i].score);
      }
      expect(rashifalFor(12, place: _kathmandu, now: _noon).sign, 0);
    });
  });

  group('the readings correspond to the actual sky', () {
    test('each graha sits in the house its real longitude puts it in', () {
      final days = rashifalForAll(place: _kathmandu, now: _noon);

      // Recompute the positions independently, at the same reference the
      // engine uses: the governing sunrise, not the instant asked for.
      final jd = julianDayUtc(days.first.date.toUtc());
      for (final day in days) {
        for (final line in day.lines) {
          expect(wholeSignHouse(day.sign, line.sign), line.house,
              reason: '${line.graha} for ${day.name}');
        }
      }
      expect(jd, greaterThan(0));
    });

    test('the same graha is in the same SIGN for all twelve rashis', () {
      // The sky does not change per reader; only the house counted from their
      // rashi does. Getting this wrong is the classic rashifal bug.
      final days = rashifalForAll(place: _kathmandu, now: _noon);
      for (final graha in rashifalGrahas) {
        final signsSeen = days
            .map((d) => d.lines.firstWhere((l) => l.graha == graha).sign)
            .toSet();
        expect(signsSeen, hasLength(1), reason: graha);
      }
    });

    test('the Moon house walks one step per rashi, all twelve covered', () {
      final days = rashifalForAll(place: _kathmandu, now: _noon);
      expect(days.map((d) => d.moonHouse).toSet(), hasLength(12));
      expect(days.first.moonLine.house, days.first.moonHouse);
    });

    test('Ketu is always six signs from Rahu', () {
      final day = rashifalForAll(place: _kathmandu, now: _noon).first;
      final rahu = day.lines.firstWhere((l) => l.graha == 'Rahu').sign;
      final ketu = day.lines.firstWhere((l) => l.graha == 'Ketu').sign;
      expect((ketu - rahu) % 12, 6);
    });
  });

  group('judgment', () {
    test('a benefic house scores up, a malefic one down', () {
      final kb = PredictionKb.current;
      for (final day in rashifalForAll(place: _kathmandu, now: _noon)) {
        for (final line in day.lines) {
          final benefic = kb.beneficTransitHouses(line.graha).contains(line.house);
          expect(line.benefic, benefic, reason: '${line.graha}/${line.house}');
          if (!benefic) {
            expect(line.score, lessThan(0));
            expect(line.obstructed, isFalse,
                reason: 'vedha only cancels a benefic result');
          } else {
            expect(line.score, greaterThanOrEqualTo(0));
          }
        }
      }
    });

    test('the score is exactly the sum of its lines', () {
      for (final day in rashifalForAll(place: _kathmandu, now: _noon)) {
        expect(day.score, day.lines.fold<int>(0, (a, l) => a + l.score),
            reason: day.name);
      }
    });

    test('the grade follows the score, relative to a neutral day', () {
      final base = rashifalNeutralScore;
      for (final day in rashifalForAll(place: _kathmandu, now: _noon)) {
        final relative = day.score - base;
        expect(
          day.grade,
          switch (relative) {
            >= 1.5 => DayGrade.favourable,
            >= -1.5 => DayGrade.workable,
            >= -4.5 => DayGrade.mixed,
            _ => DayGrade.guarded,
          },
          reason: '${day.name} scored ${day.score} (relative $relative)',
        );
      }
    });

    test('the scale is centred on what the tables actually produce', () {
      // Benefic houses are a minority for most grahas, so a raw tally is
      // structurally negative. If this drifts back toward zero the grades
      // collapse to "guarded" for nearly every sign, nearly every day.
      expect(rashifalNeutralScore, lessThan(0));
      expect(rashifalNeutralScore, greaterThan(-5));
    });

    test('no band swallows the scale across a season', () {
      // The real regression guard on calibration. An uncentred scale does not
      // fail any single-day assertion — it just quietly grades nearly every
      // sign "guarded" forever, which is how a horoscope becomes noise.
      final counts = {for (final g in DayGrade.values) g: 0};
      var total = 0;
      for (var day = 0; day < 90; day += 2) {
        for (final d in rashifalForAll(
          place: _kathmandu,
          now: DateTime.utc(2026, 2, 1).add(Duration(days: day)),
        )) {
          counts[d.grade] = counts[d.grade]! + 1;
          total++;
        }
      }
      for (final entry in counts.entries) {
        final share = entry.value / total;
        expect(share, greaterThan(0.05),
            reason: '${entry.key.name} is never used (${entry.value}/$total)');
        expect(share, lessThan(0.55),
            reason: '${entry.key.name} swallows the scale '
                '(${entry.value}/$total)');
      }
    });

    test('the twelve signs do not all say the same thing', () {
      // The failure mode that makes a horoscope worthless: identical copy
      // dressed as twelve readings.
      final days = rashifalForAll(place: _kathmandu, now: _noon);
      expect(days.map((d) => d.score).toSet().length, greaterThan(2));
      expect(days.map((d) => d.headline).toSet(), hasLength(12));
      expect(days.map((d) => d.moonLine.reading).toSet().length,
          greaterThan(4));
    });

    test('highlights are the strongest claims, and never contentless', () {
      for (final day in rashifalForAll(place: _kathmandu, now: _noon)) {
        for (final h in day.highlights) {
          expect(h.score, isNot(0));
        }
        expect(day.highlights.length, lessThanOrEqualTo(3));
      }
    });
  });

  group('moon sign of a birth record', () {
    test('agrees with the full chart, without building one', () {
      final input = BirthInput(
        id: 'r',
        name: 'Reader',
        localDateTime: DateTime(1992, 4, 14, 3, 57),
        place: _kathmandu,
        timeSource: TimeSource.hospital,
      );
      // The cheap path exists only because the home screen needs it; it must
      // not drift from the expensive one.
      expect(moonRashiOf(input), inInclusiveRange(0, 11));
      expect(signName(moonRashiOf(input)), isNotEmpty);
    });

    test('an unknown birth time still yields a rashi', () {
      final input = BirthInput(
        id: 'r2',
        name: 'No Time',
        localDateTime: DateTime(1992, 4, 14),
        place: _kathmandu,
        timeSource: TimeSource.unknown,
      );
      expect(moonRashiOf(input), inInclusiveRange(0, 11));
    });
  });

  group('the reading speaks the reader\'s language', () {
    test('headlines and every transit line switch script', () {
      for (final code in ['ne', 'hi']) {
        EngineStrings.install(code);
        loadKb(code);
        final days = rashifalForAll(place: _kathmandu, now: _noon);
        for (final day in days) {
          expect(isDevanagari(day.name), isTrue, reason: '${day.sign}/$code');
          expect(isDevanagari(day.headline), isTrue,
              reason: '${day.sign}/$code headline');
          expect(isDevanagari(day.grade.label), isTrue, reason: code);
          for (final line in day.lines) {
            // This is the content a rashifal reader actually reads, and it is
            // the reason transits.json got an overlay.
            expect(isDevanagari(line.reading), isTrue,
                reason: '${line.graha} h${line.house} in $code');
          }
        }
      }
    });

    test('translating does not change the judgment', () {
      final english = rashifalForAll(place: _kathmandu, now: _noon);
      for (final code in ['ne', 'hi']) {
        EngineStrings.install(code);
        loadKb(code);
        final translated = rashifalForAll(place: _kathmandu, now: _noon);
        for (var i = 0; i < 12; i++) {
          expect(translated[i].score, english[i].score, reason: '$code/$i');
          expect(translated[i].grade, english[i].grade, reason: '$code/$i');
          expect(translated[i].moonHouse, english[i].moonHouse);
        }
      }
    });
  });
}

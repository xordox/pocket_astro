import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_astro/domain/models.dart';
import 'package:pocket_astro/engine/astronomy.dart';
import 'package:pocket_astro/state/library_bloc.dart';
import 'package:pocket_astro/engine/kb.dart';
import 'package:pocket_astro/engine/panchanga.dart';
import 'package:pocket_astro/engine/tables.dart';
import 'package:pocket_astro/engine/today.dart';
import 'package:pocket_astro/l10n/engine_strings.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// The Today tab is the one surface a reader may open every morning, so its
/// engine is checked against things that are independently knowable: the Sun
/// really does rise in Kathmandu around a quarter to six in mid-April, a tithi
/// really is a twelfth of the Moon's elongation, and Rahu kaal really is one
/// eighth of the daylight.

const _kathmandu = Place(
  name: 'Kathmandu',
  region: 'Nepal',
  latitude: 27.7172,
  longitude: 85.3240,
  timezone: 'Asia/Kathmandu',
);

const _reykjavik = Place(
  name: 'Reykjavik',
  region: 'Iceland',
  latitude: 64.1466,
  longitude: -21.9426,
  timezone: 'Atlantic/Reykjavik',
);

BirthInput _timed({Place place = _kathmandu}) => BirthInput(
      id: 'today',
      name: 'Today Chart',
      localDateTime: DateTime(1992, 4, 14, 3, 57),
      place: place,
      timeSource: TimeSource.hospital,
    );

BirthInput _untimed() => BirthInput(
      id: 'today-untimed',
      name: 'No Time',
      localDateTime: DateTime(1992, 4, 14),
      place: _kathmandu,
      timeSource: TimeSource.unknown,
    );

/// A fixed instant, so the day the tests read is always the same day.
final _noon = tz.TZDateTime(
  tz.getLocation('Asia/Kathmandu'),
  2026,
  4,
  14,
  12,
).toUtc();

void main() {
  tzdata.initializeTimeZones();

  setUpAll(() {
    PredictionKb.loadFromMap(
      jsonDecode(File('assets/kb/prediction.json').readAsStringSync())
          as Map<String, dynamic>,
    );
    for (final e in PredictionKb.moduleAssets.entries) {
      PredictionKb.loadModuleFromMap(
        e.key,
        jsonDecode(File(e.value).readAsStringSync()) as Map<String, dynamic>,
      );
    }
    for (final code in supportedLocaleCodes) {
      if (code == 'en') continue;
      EngineStrings.register(
        code,
        File('assets/kb/i18n/$code/engine.json').readAsStringSync(),
      );
    }
  });

  tearDown(() => EngineStrings.install('en'));

  group('sunrise and sunset', () {
    test('Kathmandu in mid-April rises about 05:45 and sets about 18:35', () {
      final light = daylightFor(
        date: DateTime(2026, 4, 14),
        latitude: _kathmandu.latitude,
        longitudeEast: _kathmandu.longitude,
        timezone: _kathmandu.timezone,
      );
      expect(light.estimated, isFalse);
      final rise = light.sunrise.hour + light.sunrise.minute / 60;
      final set = light.sunset.hour + light.sunset.minute / 60;
      expect(rise, closeTo(5.75, 0.25));
      expect(set, closeTo(18.58, 0.25));
      expect(light.length.inMinutes, greaterThan(700));
    });

    test('the Sun is below the horizon before sunrise and above after', () {
      final light = daylightFor(
        date: DateTime(2026, 4, 14),
        latitude: _kathmandu.latitude,
        longitudeEast: _kathmandu.longitude,
        timezone: _kathmandu.timezone,
      );
      double altitudeAt(DateTime t) => sunAltitude(
            julianDayUtc(t.toUtc()),
            _kathmandu.latitude,
            _kathmandu.longitude,
          );
      expect(
        altitudeAt(light.sunrise.subtract(const Duration(minutes: 20))),
        lessThan(-0.833),
      );
      expect(
        altitudeAt(light.sunrise.add(const Duration(minutes: 20))),
        greaterThan(-0.833),
      );
      expect(
        altitudeAt(light.sunset.add(const Duration(minutes: 20))),
        lessThan(-0.833),
      );
    });

    test('a polar midsummer day falls back to a stated convention', () {
      final light = daylightFor(
        date: DateTime(2026, 6, 21),
        latitude: 78.2,
        longitudeEast: 15.6,
        timezone: 'Europe/Oslo',
      );
      expect(light.estimated, isTrue);
      expect(light.length, const Duration(hours: 12));
    });
  });

  group('the five limbs', () {
    late PanchangaDay pan;

    setUp(() {
      pan = panchangaFor(
        at: _noon,
        latitude: _kathmandu.latitude,
        longitudeEast: _kathmandu.longitude,
        timezone: _kathmandu.timezone,
      );
    });

    test('every limb is named, numbered and in range', () {
      expect(pan.limbs, hasLength(5));
      expect(pan.tithi.number, inInclusiveRange(1, 30));
      expect(pan.nakshatra.number, inInclusiveRange(1, 27));
      expect(pan.yoga.number, inInclusiveRange(1, 27));
      expect(pan.karana.number, inInclusiveRange(1, 60));
      expect(pan.vara.number, inInclusiveRange(1, 7));
      for (final limb in pan.limbs) {
        expect(limb.name, isNotEmpty);
        expect(limb.name, isNot(startsWith('panchanga.')));
        expect(limb.label, isNot(startsWith('panchanga.')));
      }
    });

    test('the tithi is the twelfth of the elongation it claims to be', () {
      final jd = julianDayUtc(pan.daylight.sunrise.toUtc());
      final elongation = norm360(moonLongitude(jd) - sunLongitude(jd));
      expect((elongation / 12).floor() + 1, pan.tithi.number);
      expect(pan.paksha, elongation < 180 ? 'shukla' : 'krishna');
    });

    test('the karana is the half-tithi of the same elongation', () {
      final jd = julianDayUtc(pan.daylight.sunrise.toUtc());
      final elongation = norm360(moonLongitude(jd) - sunLongitude(jd));
      expect((elongation / 6).floor() + 1, pan.karana.number);
      // Two karanas per tithi, always.
      expect(pan.karana.number, inInclusiveRange(
        pan.tithi.number * 2 - 1,
        pan.tithi.number * 2,
      ));
    });

    test('the nakshatra matches the Moon the tables would report', () {
      expect(
        nakshatraOf(pan.moonSidereal).index + 1,
        pan.nakshatra.number,
      );
    });

    test('a limb that ends does so within its own arc of time', () {
      // A tithi runs a little under or over a day; never more than 30 hours.
      final ends = pan.tithi.endsAt;
      expect(ends, isNotNull);
      final hours = ends!.difference(pan.daylight.sunrise).inMinutes / 60;
      expect(hours, greaterThan(0));
      expect(hours, lessThan(30));

      final nakEnds = pan.nakshatra.endsAt;
      expect(nakEnds, isNotNull);
      expect(
        nakEnds!.difference(pan.daylight.sunrise).inMinutes / 60,
        inExclusiveRange(0, 30),
      );
    });

    test('the vara runs to the next sunrise rather than ending mid-day', () {
      expect(pan.vara.endsAt, isNull);
    });

    test('before sunrise the previous Vedic day is still running', () {
      final loc = tz.getLocation('Asia/Kathmandu');
      final beforeDawn = tz.TZDateTime(loc, 2026, 4, 14, 3).toUtc();
      final early = panchangaFor(
        at: beforeDawn,
        latitude: _kathmandu.latitude,
        longitudeEast: _kathmandu.longitude,
        timezone: _kathmandu.timezone,
      );
      expect(early.date, DateTime(2026, 4, 13));
      expect(early.daylight.sunrise.day, 13);
    });
  });

  group('windows in the day', () {
    late PanchangaDay pan;

    setUp(() {
      pan = panchangaFor(
        at: _noon,
        latitude: _kathmandu.latitude,
        longitudeEast: _kathmandu.longitude,
        timezone: _kathmandu.timezone,
      );
    });

    test('three inauspicious eighths and Abhijit, all inside daylight', () {
      expect(pan.windows.map((w) => w.id).toSet(),
          {'rahu', 'yamaganda', 'gulika', 'abhijit'});
      for (final w in pan.windows) {
        expect(w.start.isBefore(w.end), isTrue, reason: w.id);
        expect(w.start.isBefore(pan.daylight.sunrise), isFalse, reason: w.id);
        expect(w.end.isAfter(pan.daylight.sunset), isFalse, reason: w.id);
        expect(w.title, isNot(startsWith('panchanga.')));
      }
    });

    test('each inauspicious window is exactly one eighth of the daylight', () {
      final eighth = pan.daylight.length.inSeconds / 8;
      for (final id in const ['rahu', 'yamaganda', 'gulika']) {
        final w = pan.window(id)!;
        expect(w.end.difference(w.start).inSeconds, closeTo(eighth, 2));
        expect(w.favourable, isFalse);
      }
    });

    test('Abhijit is the eighth of fifteen muhurtas and straddles midday', () {
      final abhijit = pan.window('abhijit')!;
      final fifteenth = pan.daylight.length.inSeconds / 15;
      expect(
        abhijit.end.difference(abhijit.start).inSeconds,
        closeTo(fifteenth, 2),
      );
      final midday = pan.daylight.sunrise.add(pan.daylight.length ~/ 2);
      expect(abhijit.start.isAfter(midday), isFalse);
      expect(abhijit.end.isBefore(midday), isFalse);
    });

    test('Rahu kaal lands on the eighth the weekday table names', () {
      final table = (PredictionKb.module('panchanga')['inauspicious_periods']
          as Map)['rahu_kaal'] as Map;
      final segment =
          (table['segments'] as Map)[varaNames[pan.date.weekday - 1]] as int;
      final expected = pan.daylight.sunrise.add(
        Duration(
          microseconds:
              (pan.daylight.length.inMicroseconds * (segment - 1) / 8).round(),
        ),
      );
      expect(
        pan.window('rahu')!.start.difference(expected).inSeconds.abs(),
        lessThan(2),
      );
    });

    test('Abhijit is flagged weak on Wednesday', () {
      final loc = tz.getLocation('Asia/Kathmandu');
      // 2026-04-15 is a Wednesday.
      final wednesday = panchangaFor(
        at: tz.TZDateTime(loc, 2026, 4, 15, 12).toUtc(),
        latitude: _kathmandu.latitude,
        longitudeEast: _kathmandu.longitude,
        timezone: _kathmandu.timezone,
      );
      expect(wednesday.date.weekday, DateTime.wednesday);
      expect(wednesday.window('abhijit')!.favourable, isFalse);
    });
  });

  group('the day read against a chart', () {
    late TodayReport report;

    setUp(() {
      report = todayFor(chartFor(_timed()), now: _noon);
    });

    test('tarabala counts inclusively from the birth Moon', () {
      final natal = nakshatraOf(
        chartFor(_timed()).graha('Moon').siderealLon,
      ).index;
      final today = report.panchanga.nakshatra.number - 1;
      expect(report.tarabala.count, ((today - natal) % 27) + 1);
      expect(report.tarabala.tara, inInclusiveRange(1, 9));
      expect(report.tarabala.name, isNotEmpty);
      expect(report.tarabala.reading, isNotEmpty);
    });

    test('chandrabala is the Moon whole-sign house from the janma rashi', () {
      final natalSign =
          signIndex(chartFor(_timed()).graha('Moon').siderealLon);
      expect(
        report.chandrabala.house,
        wholeSignHouse(natalSign, signIndex(report.panchanga.moonSidereal)),
      );
      expect(report.chandrabala.good && report.chandrabala.bad, isFalse);
    });

    test('a known birth time unlocks the kakshya count', () {
      expect(report.kakshya, isNotNull);
      expect(report.kakshya!.score, inInclusiveRange(0, 7));
    });

    test('an unknown birth time withholds it instead of guessing', () {
      final untimed = todayFor(chartFor(_untimed()), now: _noon);
      expect(untimed.kakshya, isNull);
      // Everything that does not need a lagna still reads.
      expect(untimed.tarabala.name, isNotEmpty);
      expect(untimed.guidance, isNotEmpty);
      expect(untimed.cues, isNotEmpty);
    });

    test('the grade follows the tally, and the tally is shown', () {
      expect(
        report.grade,
        switch (report.score) {
          >= 5 => DayGrade.favourable,
          >= 2 => DayGrade.workable,
          >= -1 => DayGrade.mixed,
          _ => DayGrade.guarded,
        },
      );
      expect(report.grade.label, isNot(startsWith('today.')));
      expect(report.grade.summary, isNot(startsWith('today.')));
    });

    test('suggestions carry both sides and each states its reason', () {
      expect(report.favour, isNotEmpty);
      for (final cue in report.cues) {
        expect(cue.text, isNotEmpty);
        expect(cue.because, isNotEmpty);
        expect(cue.text, isNot(startsWith('today.')));
        expect(cue.because, isNot(startsWith('today.')));
      }
    });

    test('guidance ends on the order of judgment, never on a promise', () {
      expect(report.guidance.length, greaterThanOrEqualTo(3));
      for (final line in report.guidance) {
        expect(line, isNot(contains('{')));
      }
      expect(report.guidance.last, contains('cannot'));
    });

    test('the remedy leads with behaviour, not with a stone', () {
      expect(report.remedy, isNotEmpty);
      expect(report.remedy.toLowerCase(), isNot(contains('carat')));
    });

    test('the day is reckoned at the birth place, and says so', () {
      expect(report.place, _kathmandu);
      expect(report.panchanga.daylight.estimated, isFalse);
    });

    test('a high-latitude chart still produces a readable day', () {
      final arctic = todayFor(chartFor(_timed(place: _reykjavik)), now: _noon);
      expect(arctic.panchanga.limbs, hasLength(5));
      expect(arctic.panchanga.windows, hasLength(4));
      expect(arctic.guidance, isNotEmpty);
    });
  });

  group('the panchanga overlays stay in step with the base', () {
    // A flag list names its entries rather than indexing them, so a locale
    // that translates the names but not the flags would silently grade the
    // day differently from English. These checks are the guard on that.
    Map<String, dynamic> overlayed(String code) {
      final english = jsonDecode(File('assets/kb/panchanga.json').readAsStringSync())
          as Map<String, dynamic>;
      final overlay = jsonDecode(
        File('assets/kb/i18n/$code/panchanga.json').readAsStringSync(),
      ) as Map<String, dynamic>;
      return PredictionKb.mergeOverlay(english, overlay);
    }

    test('every flagged name still exists in the list it flags', () {
      for (final code in ['ne', 'hi']) {
        final p = overlayed(code);

        final yoga = p['yoga'] as Map<String, dynamic>;
        final names = (yoga['names'] as List).cast<String>();
        expect(names, hasLength(27), reason: code);
        for (final bad in (yoga['inauspicious'] as List).cast<String>()) {
          expect(names, contains(bad),
              reason: '$code flags a yoga it does not name: $bad');
        }

        final karana = p['karana'] as Map<String, dynamic>;
        final all = [
          ...(karana['movable'] as List).cast<String>(),
          ...(karana['fixed'] as List).cast<String>(),
        ];
        for (final bad in (karana['inauspicious'] as List).cast<String>()) {
          expect(all, contains(bad.split(' ').first),
              reason: '$code flags a karana it does not name: $bad');
        }

        final tarabala = p['tarabala'] as Map<String, dynamic>;
        final taras = (tarabala['taras'] as List)
            .map((e) => (e as Map)['name'] as String)
            .toList();
        expect(taras, hasLength(9), reason: code);
        for (final bad in (tarabala['malefic_taras'] as List).cast<String>()) {
          expect(taras, contains(bad),
              reason: '$code flags a tara it does not name: $bad');
        }
      }
    });

    test('an overlay never translates a key the engine looks up by', () {
      for (final code in ['ne', 'hi']) {
        final p = overlayed(code);
        // Tithi groups key into the groups map, and vara lords key into the
        // graha tables; translating either would break the lookup.
        final groups = (p['tithi'] as Map)['groups'] as Map<String, dynamic>;
        for (final row in ((p['tithi'] as Map)['list'] as List)) {
          expect(groups.keys, contains((row as Map)['group']), reason: code);
        }
        for (final day in varaNames) {
          final lord = ((p['vara'] as Map)[day] as Map)['lord'] as String;
          expect(isDevanagari(lord), isFalse,
              reason: '$code translated the $day lord, which is a lookup key');
        }
      }
    });

    test('the translated day grades the same as the English one', () {
      final english = todayFor(chartFor(_timed()), now: _noon);
      for (final code in ['ne', 'hi']) {
        for (final e in PredictionKb.moduleAssets.entries) {
          final name = e.value.split('/').last;
          final base =
              jsonDecode(File(e.value).readAsStringSync()) as Map<String, dynamic>;
          final file = File('assets/kb/i18n/$code/$name');
          PredictionKb.loadModuleFromMap(
            e.key,
            file.existsSync()
                ? PredictionKb.mergeOverlay(
                    base,
                    jsonDecode(file.readAsStringSync()) as Map<String, dynamic>,
                  )
                : base,
          );
        }
        EngineStrings.install(code);
        final translated = todayFor(chartFor(_timed()), now: _noon);
        expect(translated.score, english.score, reason: code);
        expect(translated.grade, english.grade, reason: code);
        expect(translated.tarabala.tara, english.tarabala.tara, reason: code);
        expect(
          translated.panchanga.yoga.auspicious,
          english.panchanga.yoga.auspicious,
          reason: code,
        );
        expect(
          translated.panchanga.karana.auspicious,
          english.panchanga.karana.auspicious,
          reason: code,
        );
      }
      // Leave the English base loaded for whatever runs next.
      for (final e in PredictionKb.moduleAssets.entries) {
        PredictionKb.loadModuleFromMap(
          e.key,
          jsonDecode(File(e.value).readAsStringSync()) as Map<String, dynamic>,
        );
      }
    });
  });

  group('the day speaks the reader\'s language', () {
    test('limbs, grades and guidance switch script', () {
      for (final code in ['ne', 'hi']) {
        EngineStrings.install(code);
        final report = todayFor(chartFor(_timed()), now: _noon);
        expect(isDevanagari(report.grade.label), isTrue, reason: code);
        expect(isDevanagari(report.grade.summary), isTrue, reason: code);
        expect(isDevanagari(report.panchanga.vara.name), isTrue, reason: code);
        expect(isDevanagari(report.panchanga.pakshaName), isTrue, reason: code);
        for (final limb in report.panchanga.limbs) {
          expect(isDevanagari(limb.label), isTrue,
              reason: '${limb.kind} in $code');
        }
        for (final w in report.panchanga.windows) {
          expect(isDevanagari(w.title), isTrue, reason: '${w.id} in $code');
        }
        for (final line in report.guidance) {
          expect(isDevanagari(line), isTrue, reason: code);
        }
      }
    });
  });
}

/// Devanagari occupies U+0900–U+097F.
bool isDevanagari(String s) => s.runes.any((r) => r >= 0x0900 && r <= 0x097F);

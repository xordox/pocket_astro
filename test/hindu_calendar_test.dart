/// Gap G-24 — the calendar around the five limbs.
///
/// These are dated against the published 2024 panchanga. That matters more
/// than it sounds: the first version of this module was a month out on the
/// dark fortnight and a day out on every festival kept at a time other than
/// sunrise, and both bugs looked entirely plausible until checked against real
/// dates.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_astro/engine/hindu_calendar.dart';
import 'package:pocket_astro/engine/kb.dart';
import 'package:pocket_astro/engine/panchanga.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;

const _lat = 28.6139;
const _lon = 77.2090;
const _tz = 'Asia/Kolkata';

HinduDate _on(int year, int month, int day) {
  final at = DateTime.utc(year, month, day, 6);
  final panchanga = panchangaFor(
      at: at, latitude: _lat, longitudeEast: _lon, timezone: _tz);
  return hinduDateFor(day: panchanga);
}

late List<Observance> observances2024;

void main() {
  tzdata.initializeTimeZones();

  setUpAll(() {
    PredictionKb.loadFromMap(jsonDecode(
        File('assets/kb/prediction.json').readAsStringSync()) as Map<String, dynamic>);
    for (final e in PredictionKb.moduleAssets.entries) {
      PredictionKb.loadModuleFromMap(e.key,
          jsonDecode(File(e.value).readAsStringSync()) as Map<String, dynamic>);
    }
    observances2024 = observancesBetween(
      from: DateTime.utc(2024, 1, 1),
      to: DateTime.utc(2025, 1, 1),
      latitude: _lat,
      longitudeEast: _lon,
      timezone: _tz,
    );
  });

  group('months', () {
    test('the full moon of 25 March 2024 is Phalguna Purnima', () {
      // The anchor the whole month-naming rests on. Holi is universally
      // Phalguna Purnima, and that full moon falls inside amanta Chaitra —
      // which is what fixes purnimanta as one behind amanta in a bright
      // fortnight.
      final d = _on(2024, 3, 25);
      expect(d.purnimantaMonth, 'Phalguna');
      expect(d.amantaMonth, 'Chaitra');
      expect(d.paksha, 'shukla');
      expect(d.tithiNumber, 15);
    });

    test('the two reckonings agree through the dark fortnight', () {
      final d = _on(2024, 11, 1);
      expect(d.paksha, 'krishna');
      expect(d.amantaMonth, d.purnimantaMonth);
      expect(d.monthNamesAgree, isTrue);
      expect(d.amantaMonth, 'Kartika');
    });

    test('and differ through the bright one', () {
      final d = _on(2024, 4, 17);
      expect(d.paksha, 'shukla');
      expect(d.monthNamesAgree, isFalse);
      expect(d.purnimantaMonth, 'Chaitra');
      expect(d.amantaMonth, 'Vaishakha');
      expect(d.monthLine, contains('amanta'));
    });

    test('the month does not turn over before the tithi does', () {
      // A new moon in the evening must not start the next month while the
      // day's own tithi is still Amavasya. Everything is referred to the
      // governing sunrise for exactly this reason.
      final amavasya = _on(2024, 11, 1);
      expect(amavasya.tithiNumber, 30);
      expect(amavasya.amantaMonth, 'Kartika');
      final nextDay = _on(2024, 11, 2);
      expect(nextDay.paksha, 'shukla');
      expect(nextDay.amantaMonth, 'Margashirsha');
    });
  });

  group('years and seasons', () {
    test('Shaka 1946 is Krodhi', () {
      final d = _on(2024, 6, 1);
      expect(d.shakaYear, 1946);
      expect(d.samvatsara, 'Krodhi');
      expect(d.vikramYear, 2081);
    });

    test('the year turns at Chaitra, not in January', () {
      final january = _on(2024, 1, 20);
      final may = _on(2024, 5, 20);
      expect(january.shakaYear, 1945);
      expect(may.shakaYear, 1946);
    });

    test('the sixty-year cycle is complete and unique', () {
      expect(samvatsaras.length, 60);
      expect(samvatsaras.toSet().length, 60);
      expect(samvatsaras[37], 'Krodhi');
    });

    test('ayana follows the sidereal Sun', () {
      expect(_on(2024, 2, 1).ayana, 'Uttarayana');
      expect(_on(2024, 8, 1).ayana, 'Dakshinayana');
    });

    test('ritu tracks the lunar month', () {
      expect(_on(2024, 4, 20).ritu, 'Vasanta');
      expect(_on(2024, 8, 20).ritu, 'Varsha');
      expect(ritus.length, 6);
    });
  });

  group('sankranti', () {
    test('Mesha Sankranti 2024 falls on 13 April', () {
      final list = sankrantisIn(2024);
      final mesha = list.firstWhere((s) => s.sign == 'Mesha');
      expect(mesha.at.toUtc().month, 4);
      expect(mesha.at.toUtc().day, anyOf(12, 13));
    });

    test('there are twelve in a year, about a month apart', () {
      final list = sankrantisIn(2024);
      expect(list.length, 12);
      for (var i = 0; i < list.length - 1; i++) {
        final gap = list[i + 1].at.difference(list[i].at).inDays;
        expect(gap, inInclusiveRange(28, 33));
      }
    });

    test('the next one is reported from any date', () {
      final d = _on(2024, 1, 5);
      expect(d.nextSankrantiSign, 'Makara');
      expect(d.nextSankranti.month, 1);
    });
  });

  group('observances, against the published 2024 calendar', () {
    DateTime dateOf(String name) =>
        observances2024.firstWhere((o) => o.name == name).date;

    test('festivals kept at sunrise land on the right day', () {
      expect(dateOf('Holi'), DateTime(2024, 3, 25));
      expect(dateOf('Ram Navami'), DateTime(2024, 4, 17));
      expect(dateOf('Akshaya Tritiya'), DateTime(2024, 5, 10));
      expect(dateOf('Guru Purnima'), DateTime(2024, 7, 21));
      expect(dateOf('Raksha Bandhan'), DateTime(2024, 8, 19));
      expect(dateOf('Navaratri begins'), DateTime(2024, 10, 3));
      expect(dateOf('Chhath'), DateTime(2024, 11, 7));
    });

    test('festivals kept at another hour land on that hour’s day', () {
      // Each of these is a day away from the sunrise reckoning, which is the
      // whole reason observance windows exist.
      expect(dateOf('Maha Shivaratri'), DateTime(2024, 3, 8)); // nishita
      expect(dateOf('Vijayadashami'), DateTime(2024, 10, 12)); // aparahna
      expect(dateOf('Karva Chauth'), DateTime(2024, 10, 20)); // pradosha
      expect(dateOf('Krishna Janmashtami'), DateTime(2024, 8, 26)); // nishita
      expect(dateOf('Ganesh Chaturthi'), DateTime(2024, 9, 7)); // midday
    });

    test('Diwali resolves the year it was contested', () {
      // 2024 split panchangas between 31 October and 1 November. The rule is
      // that Amavasya must prevail at pradosha, which gives 31 October — the
      // date most published calendars carried.
      expect(dateOf('Diwali'), DateTime(2024, 10, 31));
      final note = observances2024.firstWhere((o) => o.name == 'Diwali').note;
      expect(note, contains('pradosha'));
    });

    test('Ekadashi appears twice a lunar month, sometimes on two days', () {
      final ekadashis =
          observances2024.where((o) => o.name.contains('Ekadashi')).toList();
      // Twice per lunar month over roughly 12.4 lunar months is about 25. It
      // runs a little higher because a tithi can span two sunrises and then
      // governs both days — which is not an artefact but the mechanism behind
      // the smarta and vaishnava Ekadashi falling on consecutive dates.
      expect(ekadashis.length, inInclusiveRange(23, 28));
      for (final e in ekadashis) {
        expect(e.isFast, isTrue);
      }

      // At least one such pair should appear in a year.
      var consecutive = 0;
      for (var i = 0; i < ekadashis.length - 1; i++) {
        if (ekadashis[i + 1].date.difference(ekadashis[i].date).inDays == 1) {
          consecutive++;
        }
      }
      expect(consecutive, greaterThanOrEqualTo(1));
    });

    test('Purnima and Amavasya each appear about twelve times', () {
      expect(observances2024.where((o) => o.name == 'Purnima').length,
          inInclusiveRange(11, 13));
      expect(observances2024.where((o) => o.name == 'Amavasya').length,
          inInclusiveRange(11, 13));
    });

    test('everything is dated in order and inside the range', () {
      for (var i = 0; i < observances2024.length - 1; i++) {
        expect(observances2024[i].date.isAfter(observances2024[i + 1].date),
            isFalse);
      }
      for (final o in observances2024) {
        expect(o.date.year, 2024);
        expect(o.note, isNotEmpty);
      }
    });
  });

  group('tithi arithmetic', () {
    test('tithis are numbered 1..30 across the month, not 1..15 per paksha', () {
      // The bug this guards: Amavasya is tithi 30, so a rule written as
      // "krishna 15" silently never matches.
      expect(tithiInPaksha(1), 1);
      expect(tithiInPaksha(15), 15);
      expect(tithiInPaksha(16), 1);
      expect(tithiInPaksha(30), 15);
    });

    test('tithiAt agrees with the panchanga at sunrise', () {
      final at = DateTime.utc(2024, 3, 25, 6);
      final day = panchangaFor(
          at: at, latitude: _lat, longitudeEast: _lon, timezone: _tz);
      expect(tithiAt(day.daylight.sunrise.toUtc()), day.tithi.number);
    });

    test('observance windows fall in the right part of the day', () {
      final day = panchangaFor(
          at: DateTime.utc(2024, 6, 1, 6),
          latitude: _lat, longitudeEast: _lon, timezone: _tz);
      final light = day.daylight;
      final sunrise = windowInstant(ObservanceWindow.sunrise, light);
      final midday = windowInstant(ObservanceWindow.madhyahna, light);
      final aparahna = windowInstant(ObservanceWindow.aparahna, light);
      final pradosha = windowInstant(ObservanceWindow.pradosha, light);
      final nishita = windowInstant(ObservanceWindow.nishita, light);

      expect(sunrise, light.sunrise);
      expect(midday.isAfter(sunrise), isTrue);
      expect(aparahna.isAfter(midday), isTrue);
      expect(aparahna.isBefore(light.sunset), isTrue);
      expect(pradosha.isAfter(light.sunset), isTrue);
      expect(nishita.isAfter(pradosha), isTrue);
    });
  });
}

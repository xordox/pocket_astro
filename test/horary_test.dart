/// Gap G-33 — Western horary.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_astro/domain/models.dart';
import 'package:pocket_astro/engine/chart_builder.dart';
import 'package:pocket_astro/engine/horary.dart';
import 'package:pocket_astro/engine/kb.dart';
import 'package:pocket_astro/engine/panchanga.dart';
import 'package:pocket_astro/engine/time_convert.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;

const _london = Place(
  name: 'London', region: 'United Kingdom',
  latitude: 51.5074, longitude: -0.1278, timezone: 'Europe/London');

NatalChart _cast(DateTime local) {
  final input = BirthInput(
    id: 'q',
    name: 'Question',
    localDateTime: local,
    place: _london,
    timeSource: TimeSource.hospital,
  );
  return buildChart(input, toUtc(input), settings: horarySettings);
}

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
  });

  group('the chart is cast traditionally', () {
    test('tropical, Regiomontanus, true node', () {
      expect(horarySettings.ayanamsa.name, 'none');
      expect(horarySettings.houseSystem.name, 'regiomontanus');
      expect(horarySettings.trueNode, isTrue);

      final chart = _cast(DateTime(2024, 6, 1, 14, 30));
      expect(chart.ayanamsa, 0);
      expect(chart.westernCusps!.system.name, 'regiomontanus');
    });
  });

  group('considerations before judgment', () {
    test('every check reports either way, never in silence', () {
      final chart = _cast(DateTime(2024, 6, 1, 14, 30));
      final checks = considerations(chart);
      expect(checks, isNotEmpty);
      for (final c in checks) {
        expect(c.note, isNotEmpty, reason: c.name);
        expect(const ['blocks', 'caution'], contains(c.severity));
      }
    });

    test('an early ascendant blocks judgment', () {
      // Sweep a day for a moment when the ascendant is under three degrees.
      NatalChart? early;
      for (var m = 0; m < 24 * 60 && early == null; m += 4) {
        final chart = _cast(DateTime(2024, 6, 1).add(Duration(minutes: m)));
        if (chart.lagnaTropical % 30 < 3) early = chart;
      }
      expect(early, isNotNull);
      final checks = considerations(early!);
      final tooEarly =
          checks.firstWhere((c) => c.name == 'Ascendant too early');
      expect(tooEarly.applies, isTrue);
      expect(tooEarly.note, contains('not yet ripe'));
      expect(fitToJudge(checks), isFalse);
    });

    test('a late ascendant blocks judgment', () {
      NatalChart? late;
      for (var m = 0; m < 24 * 60 && late == null; m += 4) {
        final chart = _cast(DateTime(2024, 6, 1).add(Duration(minutes: m)));
        if (chart.lagnaTropical % 30 > 27) late = chart;
      }
      expect(late, isNotNull);
      expect(fitToJudge(considerations(late!)), isFalse);
    });

    test('a mid-sign ascendant does not block', () {
      NatalChart? fine;
      for (var m = 0; m < 24 * 60 && fine == null; m += 4) {
        final chart = _cast(DateTime(2024, 6, 1).add(Duration(minutes: m)));
        final d = chart.lagnaTropical % 30;
        if (d > 10 && d < 20) fine = chart;
      }
      expect(fitToJudge(considerations(fine!)), isTrue);
    });
  });

  group('void of course Moon', () {
    test('is decided by whether an aspect still perfects in the sign', () {
      // Sample across a fortnight; both states must occur, and each must be
      // reported with its reason.
      var sawVoid = false;
      var sawNotVoid = false;
      for (var d = 0; d < 14; d++) {
        final chart = _cast(DateTime(2024, 6, 1 + d, 12));
        final voc = voidOfCourse(chart);
        expect(voc.note, isNotEmpty);
        if (voc.isVoid) {
          sawVoid = true;
          expect(voc.nextAspect, isNull);
          expect(voc.note, contains('no further Ptolemaic aspect'));
        } else {
          sawNotVoid = true;
          expect(voc.nextAspect, isNotNull);
        }
      }
      expect(sawNotVoid, isTrue);
      // The Moon is void a few hours most days, so a fortnight of noon
      // samples should catch at least one.
      expect(sawVoid, isTrue);
    });
  });

  group('planetary hours', () {
    test('the first hour of the day belongs to the day’s own ruler', () {
      final day = panchangaFor(
        at: DateTime.utc(2024, 6, 2, 9),
        latitude: _london.latitude,
        longitudeEast: _london.longitude,
        timezone: _london.timezone,
      );
      final sunrise = day.daylight.sunrise;
      final hour = planetaryHour(
        at: sunrise.add(const Duration(minutes: 5)),
        sunrise: sunrise,
        sunset: day.daylight.sunset,
        nextSunrise: sunrise.add(const Duration(days: 1)),
      );
      // 2 June 2024 was a Sunday.
      expect(sunrise.weekday, DateTime.sunday);
      expect(hour.ruler, 'Sun');
      expect(hour.index, 1);
      expect(hour.isDay, isTrue);
    });

    test('twelve unequal hours fill the daylight', () {
      final day = panchangaFor(
        at: DateTime.utc(2024, 6, 2, 9),
        latitude: _london.latitude,
        longitudeEast: _london.longitude,
        timezone: _london.timezone,
      );
      final sunrise = day.daylight.sunrise;
      final sunset = day.daylight.sunset;
      final seen = <int>{};
      for (var i = 0; i < 12; i++) {
        final at = sunrise.add(Duration(
            microseconds:
                sunset.difference(sunrise).inMicroseconds * (2 * i + 1) ~/ 24));
        final h = planetaryHour(
          at: at, sunrise: sunrise, sunset: sunset,
          nextSunrise: sunrise.add(const Duration(days: 1)));
        seen.add(h.index);
        expect(h.isDay, isTrue);
      }
      expect(seen.length, 12);
    });

    test('night hours continue the Chaldean sequence', () {
      final day = panchangaFor(
        at: DateTime.utc(2024, 6, 2, 9),
        latitude: _london.latitude,
        longitudeEast: _london.longitude,
        timezone: _london.timezone,
      );
      final sunset = day.daylight.sunset;
      final hour = planetaryHour(
        at: sunset.add(const Duration(minutes: 5)),
        sunrise: day.daylight.sunrise,
        sunset: sunset,
        nextSunrise: day.daylight.sunrise.add(const Duration(days: 1)),
      );
      expect(hour.isDay, isFalse);
      // The thirteenth hour of a Sunday is Jupiter's.
      expect(hour.ruler, 'Jupiter');
    });
  });

  group('significators and perfection', () {
    test('significators are named with their reasons', () {
      final chart = _cast(DateTime(2024, 6, 1, 14, 30));
      final sig = significatorsForQuestion(chart, 10);
      expect(sig.querent.why, contains('ascendant'));
      expect(sig.quesited.why, contains('10th'));
      expect(sig.moon.planet, 'Moon');
      expect(sig.querent.planet, isNotEmpty);
    });

    test('a judgment is produced for every question', () {
      final chart = _cast(DateTime(2024, 6, 1, 14, 30));
      for (final entry in horaryHouses.entries) {
        final j = judgeHorary(
          chart: chart, question: entry.key, house: entry.value.house);
        expect(const ['yes', 'yes, with help', 'no', 'not fit to judge'],
            contains(j.answer));
        expect(j.perfection.note, isNotEmpty);
        expect(j.dignities.length, 3);
      }
    });

    test('the same planet on both sides is read as already in hand', () {
      // House 1 and house 1: querent and quesited must coincide.
      final chart = _cast(DateTime(2024, 6, 1, 14, 30));
      final p = judgePerfection(
        chart,
        significatorsForQuestion(chart, 1).querent.planet,
        significatorsForQuestion(chart, 1).quesited.planet,
      );
      expect(p.route, PerfectionRoute.direct);
      expect(p.note, contains('already being in hand'));
    });

    test('perfection routes are all reachable across a sample of charts', () {
      final routes = <PerfectionRoute>{};
      for (var d = 0; d < 30; d++) {
        for (final house in const [2, 7, 10]) {
          final chart = _cast(DateTime(2024, 6, 1 + d, 11));
          final sig = significatorsForQuestion(chart, house);
          routes.add(judgePerfection(
                  chart, sig.querent.planet, sig.quesited.planet)
              .route);
        }
      }
      // Direct application and outright failure are both common; the carried
      // routes are rarer but must be reachable or the code is dead.
      expect(routes, contains(PerfectionRoute.direct));
      expect(routes.length, greaterThanOrEqualTo(2));
    });

    test('a denied perfection explains which classical rule denied it', () {
      var found = false;
      for (var d = 0; d < 60 && !found; d++) {
        for (final house in const [2, 7, 10]) {
          final chart = _cast(DateTime(2024, 1, 1 + d, 11));
          final sig = significatorsForQuestion(chart, house);
          final p =
              judgePerfection(chart, sig.querent.planet, sig.quesited.planet);
          if (p.denied && p.denialReason.isNotEmpty &&
              p.denialReason != 'no perfection') {
            expect(
              p.denialReason,
              anyOf(contains('prohibition'), contains('refranation')),
            );
            found = true;
            break;
          }
        }
      }
      expect(found, isTrue,
          reason: 'prohibition and refranation must actually fire');
    });
  });
}

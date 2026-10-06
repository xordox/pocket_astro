import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_astro/domain/models.dart';
import 'package:pocket_astro/engine/kb.dart';
import 'package:pocket_astro/engine/learn.dart';
import 'package:pocket_astro/engine/tables.dart';
import 'package:pocket_astro/l10n/engine_strings.dart';
import 'package:pocket_astro/state/library_bloc.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;

/// The syllabus is content, so the tests here are mostly integrity checks: the
/// course is complete, every lesson is whole, every worked example resolves
/// against a real chart, and nothing leaks a raw lookup key to a reader who is
/// trying to learn from it.

const _kathmandu = Place(
  name: 'Kathmandu',
  region: 'Nepal',
  latitude: 27.7172,
  longitude: 85.3240,
  timezone: 'Asia/Kathmandu',
);

BirthInput _timed() => BirthInput(
      id: 'learn',
      name: 'Learner',
      localDateTime: DateTime(1992, 4, 14, 3, 57),
      place: _kathmandu,
      timeSource: TimeSource.hospital,
    );

BirthInput _untimed() => BirthInput(
      id: 'learn-untimed',
      name: 'No Time',
      localDateTime: DateTime(1992, 4, 14),
      place: _kathmandu,
      timeSource: TimeSource.unknown,
    );

/// Devanagari occupies U+0900–U+097F.
bool isDevanagari(String s) => s.runes.any((r) => r >= 0x0900 && r <= 0x097F);

/// Loads every module, applying [code]'s overlay where one exists — the same
/// merge `PredictionKb.loadFromAssets` performs at runtime.
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

  group('the syllabus', () {
    test('runs basic, intermediate, advanced, in that order', () {
      final s = syllabusFor(null);
      expect(s.levels.map((l) => l.id).toList(),
          ['basic', 'intermediate', 'advanced']);
      for (final level in s.levels) {
        expect(level.title, isNotEmpty);
        expect(level.blurb, isNotEmpty);
        expect(level.lessons, isNotEmpty, reason: level.id);
      }
    });

    test('lesson numbers run 1..n across the whole course, without gaps', () {
      final s = syllabusFor(null);
      expect(s.lessonCount, greaterThanOrEqualTo(12));
      expect(
        s.lessons.map((e) => e.number).toList(),
        [for (var i = 1; i <= s.lessonCount; i++) i],
      );
    });

    test('lesson ids are unique — progress is keyed on them', () {
      final ids = syllabusFor(null).lessons.map((e) => e.id).toList();
      expect(ids.toSet(), hasLength(ids.length));
      for (final id in ids) {
        expect(id, isNotEmpty);
      }
    });

    test('every lesson is whole: hook, points and a check', () {
      for (final lesson in syllabusFor(null).lessons) {
        expect(lesson.title, isNotEmpty, reason: lesson.id);
        expect(lesson.hook, isNotEmpty, reason: lesson.id);
        expect(lesson.minutes, inInclusiveRange(1, 30), reason: lesson.id);
        expect(lesson.points.length, greaterThanOrEqualTo(3),
            reason: lesson.id);
        for (final p in lesson.points) {
          expect(p.heading, isNotEmpty, reason: lesson.id);
          expect(p.body.length, greaterThan(60), reason: '${lesson.id}: thin');
        }
        expect(lesson.check.question, isNotEmpty, reason: lesson.id);
        expect(lesson.check.answer, isNotEmpty, reason: lesson.id);
      }
    });

    test('the course ends on the limits of the method, not on a promise', () {
      final last = syllabusFor(null).lessons.last;
      expect(last.id, 'order-of-judgment');
      final prose = [
        last.hook,
        for (final p in last.points) p.body,
      ].join(' ').toLowerCase();
      expect(prose, contains('death'));
      expect(prose, contains('confidence'));
    });

    test('a missing module degrades to an empty syllabus, not a crash', () {
      PredictionKb.loadModuleFromMap('learn', const {});
      expect(syllabusFor(null).lessonCount, 0);
      expect(syllabusFor(null).nextAfter(const {}), isNull);
    });
  });

  group('progress', () {
    test('nextAfter walks the course in order and then returns null', () {
      final s = syllabusFor(null);
      final done = <String>{};
      for (var i = 0; i < s.lessonCount; i++) {
        final next = s.nextAfter(done);
        expect(next, isNotNull);
        expect(next!.number, i + 1);
        done.add(next.id);
      }
      expect(s.nextAfter(done), isNull);
    });

    test('a level counts only its own finished lessons', () {
      final s = syllabusFor(null);
      final basic = s.levels.first;
      final done = {basic.lessons.first.id, s.levels.last.lessons.first.id};
      expect(s.doneIn(basic, done), 1);
      expect(s.doneIn(s.levels.last, done), 1);
      expect(s.doneIn(s.levels[1], done), 0);
    });
  });

  group('the worked examples', () {
    test('a timed chart resolves an example for every lesson', () {
      final s = syllabusFor(chartFor(_timed()));
      for (final lesson in s.lessons) {
        expect(lesson.inYourChart, isNotEmpty,
            reason: '${lesson.id} has no worked example');
        // A missing template would surface as a bare lookup key, and an
        // unfilled slot as a literal brace.
        expect(lesson.inYourChart, isNot(startsWith('learn.')),
            reason: lesson.id);
        expect(lesson.inYourChart, isNot(contains('{')), reason: lesson.id);
        expect(lesson.inYourChart, isNot(contains('null')), reason: lesson.id);
      }
    });

    test('examples name things actually found in that chart', () {
      final chart = chartFor(_timed());
      final s = syllabusFor(chart);
      expect(s.byId('what-a-chart-is')!.inYourChart, contains('Kathmandu'));
      expect(
        s.byId('your-three-signs')!.inYourChart,
        contains(signNameFor(chart.lagnaSidereal)),
      );
      expect(s.byId('nakshatras')!.inYourChart, contains('pada'));
    });

    test('an unknown birth time withholds the examples that need a lagna', () {
      final s = syllabusFor(chartFor(_untimed()));
      for (final id in const [
        'the-twelve-houses',
        'house-lords',
        'aspects',
        'divisional-charts',
        'ashtakavarga',
      ]) {
        expect(s.byId(id)!.inYourChart, contains('birth time'), reason: id);
      }
      // And the ones that read from the Moon still work.
      expect(s.byId('nakshatras')!.inYourChart, isNotEmpty);
      expect(s.byId('your-three-signs')!.inYourChart, isNotEmpty);
      expect(s.byId('gochara')!.inYourChart, isNotEmpty);
    });

    test('browsing without a chart drops the examples and keeps the text', () {
      for (final lesson in syllabusFor(null).lessons) {
        expect(lesson.inYourChart, isEmpty);
        expect(lesson.points, isNotEmpty);
      }
    });
  });

  group('the syllabus in the reader\'s language', () {
    test('every lesson is translated, not left in English', () {
      for (final code in ['ne', 'hi']) {
        EngineStrings.install(code);
        loadKb(code);
        final s = syllabusFor(chartFor(_timed()));
        expect(s.lessonCount, syllabusFor(null).lessonCount, reason: code);
        for (final level in s.levels) {
          expect(isDevanagari(level.title), isTrue, reason: '${level.id}/$code');
          expect(isDevanagari(level.blurb), isTrue, reason: '${level.id}/$code');
        }
        for (final lesson in s.lessons) {
          expect(isDevanagari(lesson.title), isTrue,
              reason: '${lesson.id}/$code title');
          expect(isDevanagari(lesson.hook), isTrue,
              reason: '${lesson.id}/$code hook');
          for (final p in lesson.points) {
            expect(isDevanagari(p.heading), isTrue,
                reason: '${lesson.id}/$code heading');
            expect(isDevanagari(p.body), isTrue,
                reason: '${lesson.id}/$code body');
          }
          expect(isDevanagari(lesson.check.question), isTrue,
              reason: '${lesson.id}/$code question');
          expect(isDevanagari(lesson.check.answer), isTrue,
              reason: '${lesson.id}/$code answer');
          expect(isDevanagari(lesson.inYourChart), isTrue,
              reason: '${lesson.id}/$code example');
        }
      }
    });

    test('a lesson id is never translated — progress is keyed on it', () {
      final english = syllabusFor(null).lessons.map((e) => e.id).toList();
      for (final code in ['ne', 'hi']) {
        loadKb(code);
        expect(syllabusFor(null).lessons.map((e) => e.id).toList(), english,
            reason: '$code changed a lesson id');
      }
    });
  });
}

/// The sign name the engine would print for a longitude, for the example test.
String signNameFor(double siderealLon) =>
    signName(signIndex(siderealLon));

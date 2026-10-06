/// Gap G-41 — getting charts in and out.
///
/// The behaviour that matters most here is not the happy path but the refusal:
/// an import that silently drops rows is worse than one that fails loudly,
/// because the reader believes they have everything.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_astro/data/bundled_atlas.dart';
import 'package:pocket_astro/data/interchange.dart';
import 'package:pocket_astro/domain/models.dart';
import 'package:pocket_astro/engine/zone_offset.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;

const _kathmandu = Place(
  name: 'Kathmandu', region: 'Nepal',
  latitude: 27.7172, longitude: 85.324, timezone: 'Asia/Kathmandu');

BirthInput _input(String name, {List<String> tags = const []}) => BirthInput(
      id: name,
      name: name,
      localDateTime: DateTime(1992, 4, 14, 3, 57),
      place: _kathmandu,
      timeSource: TimeSource.hospital,
      timeStandard: TimeStandard.zone,
      tags: tags,
      notes: 'Discussed the house move, spring.',
    );

void main() {
  tzdata.initializeTimeZones();

  setUpAll(() {
    BundledAtlas.instance.loadFromString(
        File('assets/atlas/cities.txt').readAsStringSync());
  });

  group('JSON backup', () {
    test('round-trips a library exactly', () {
      final profiles = [
        _input('Ada', tags: const ['client', 'career']),
        _input('Grace').copyWith(
          timeSource: TimeSource.unknown,
          timeStandard: TimeStandard.localMean,
        ),
      ];
      final outcome = importJson(exportJson(profiles));

      expect(outcome.problems, isEmpty);
      expect(outcome.skipped, 0);
      expect(outcome.imported.length, 2);

      final ada = outcome.imported.first;
      expect(ada.name, 'Ada');
      expect(ada.tags, ['client', 'career']);
      expect(ada.notes, contains('house move'));
      expect(ada.place.timezone, 'Asia/Kathmandu');

      final grace = outcome.imported.last;
      expect(grace.timeUnknown, isTrue);
      expect(grace.timeStandard, TimeStandard.localMean);
    });

    test('carries the calculation settings alongside the charts', () {
      final text = exportJson([_input('Ada')], settings: {'chart': {'ayanamsa': 'raman'}});
      expect(text, contains('raman'));
      expect(text, contains('"version": $interchangeVersion'));
    });

    test('a corrupt file fails loudly rather than silently', () {
      final outcome = importJson('{not json');
      expect(outcome.isEmpty, isTrue);
      expect(outcome.problems.single, contains('not valid JSON'));
    });

    test('valid JSON that is not a backup says so', () {
      final outcome = importJson('{"hello": "world"}');
      expect(outcome.isEmpty, isTrue);
      expect(outcome.problems.single, contains('no "profiles" list'));
    });

    test('one bad record costs that record, not the file', () {
      final good = _input('Ada').toJson();
      final text = '{"format":"pocketastro","version":1,"profiles":['
          '${_json(good)},{"id":"x"}]}';
      final outcome = importJson(text);
      expect(outcome.imported.length, 1);
      expect(outcome.skipped, 1);
      expect(outcome.problems, isNotEmpty);
    });

    test('a newer format is read as far as it can be, with a warning', () {
      final text = '{"format":"pocketastro","version":99,"profiles":'
          '[${_json(_input('Ada').toJson())}]}';
      final outcome = importJson(text);
      expect(outcome.imported.length, 1);
      expect(outcome.problems.first, contains('newer version'));
    });

    test('an unresolvable timezone is rejected with a reason', () {
      final bad = _input('Ada').toJson();
      (bad['place'] as Map)['timezone'] = 'Mars/Olympus_Mons';
      final outcome =
          importJson('{"format":"pocketastro","version":1,"profiles":[${_json(bad)}]}');
      expect(outcome.imported, isEmpty);
      expect(outcome.problems.single, contains('not in the database'));
    });
  });

  group('CSV', () {
    test('round-trips through our own export', () {
      final profiles = [_input('Ada', tags: const ['client'])];
      final outcome = importCsv(exportCsv(profiles));
      expect(outcome.imported.length, 1);
      final ada = outcome.imported.single;
      expect(ada.name, 'Ada');
      expect(ada.localDateTime.year, 1992);
      expect(ada.localDateTime.hour, 3);
      expect(ada.tags, ['client']);
      expect(ada.place.latitude, closeTo(27.7172, 1e-4));
    });

    test('a two-column file imports, with the atlas resolving the place', () {
      // The realistic case for someone arriving from another program.
      final outcome = importCsv('name,date,place\n'
          'Ada Lovelace,1815-12-10,London\n'
          'Alan Turing,1912-06-23,London\n');
      expect(outcome.imported.length, 2);
      expect(outcome.imported.first.place.region, contains('United Kingdom'));
      expect(outcome.imported.first.place.timezone, 'Europe/London');
      // No time column means the time is genuinely unknown, not midnight.
      expect(outcome.imported.first.timeUnknown, isTrue);
    });

    test('coordinates without a timezone get one from the nearest place', () {
      final outcome = importCsv('name,date,time,latitude,longitude\n'
          'Test,1990-01-01,09:30,27.7172,85.3240\n');
      expect(outcome.imported.single.place.timezone, 'Asia/Kathmandu');
    });

    test('quoted fields with commas survive', () {
      final outcome = importCsv('name,date,place,notes\n'
          '"Smith, John",1980-05-05,Paris,"Said ""hello"", then left"\n');
      final row = outcome.imported.single;
      expect(row.name, 'Smith, John');
      expect(row.notes, 'Said "hello", then left');
    });

    test('an ambiguous slash date is rejected rather than guessed', () {
      // 03/04/1990 could be March or April. Guessing silently moves a
      // birthday, which is the one thing an importer must never do.
      final outcome = importCsv('name,date,place\nAmbiguous,03/04/1990,Paris\n');
      expect(outcome.imported, isEmpty);
      expect(outcome.skipped, 1);
      expect(outcome.problems.single, contains('could not read the date'));
    });

    test('an unambiguous slash date is accepted', () {
      final outcome = importCsv('name,date,place\nClear,25/12/1990,Paris\n');
      expect(outcome.imported.single.localDateTime.month, 12);
      expect(outcome.imported.single.localDateTime.day, 25);
    });

    test('12-hour times are understood', () {
      final outcome = importCsv('name,date,time,place\n'
          'PM,1990-01-01,09:30 pm,London\n'
          'Midnight,1990-01-01,12:15 am,London\n');
      expect(outcome.imported[0].localDateTime.hour, 21);
      expect(outcome.imported[1].localDateTime.hour, 0);
    });

    test('an unresolvable place is reported, not dropped in silence', () {
      final outcome = importCsv('name,date,place\n'
          'Good,1990-01-01,Paris\n'
          'Bad,1990-01-01,Qqqzzzxnowhere\n');
      expect(outcome.imported.length, 1);
      expect(outcome.skipped, 1);
      expect(outcome.problems.single, contains('could not be resolved'));
    });

    test('column order and naming are tolerated', () {
      final outcome = importCsv('dob,city,chart\n'
          '1990-01-01,Paris,Reordered\n');
      expect(outcome.imported.single.name, 'Reordered');
      expect(outcome.imported.single.place.region, contains('France'));
    });

    test('a file missing name, date or location is refused with an explanation',
        () {
      // No name column.
      expect(importCsv('place,latitude\nParis,48.85\n').problems.single,
          contains('name column'));
      // No location of any kind. A chart cannot exist without one, and saying
      // so beats importing a row that can never be opened.
      final noPlace = importCsv('name,date\nAda,1815-12-10\n');
      expect(noPlace.imported, isEmpty);
      expect(noPlace.problems.single, contains('location'));
    });

    test('an empty file is refused', () {
      expect(importCsv('').problems.single, contains('empty'));
    });
  });

  group('consultations', () {
    test('round-trip through JSON', () {
      final c = Consultation(
        id: 'c1',
        chartId: 'Ada',
        when: DateTime.utc(2024, 3, 2),
        summary: 'House move',
        notes: 'Discussed the fourth house and the Saturn transit.',
        topics: const ['relocation'],
      );
      final back = Consultation.fromJson(c.toJson());
      expect(back.summary, 'House move');
      expect(back.topics, ['relocation']);
      expect(back.when, c.when);
    });

    test('are carried in a backup', () {
      final text = exportJson(
        [_input('Ada')],
        consultations: {
          'Ada': [
            Consultation(
              id: 'c1', chartId: 'Ada', when: DateTime.utc(2024, 3, 2),
              summary: 'House move'),
          ],
        },
      );
      expect(text, contains('House move'));
    });
  });
}

String _json(Map<String, dynamic> m) {
  // Small local encoder so the fixtures read as literals in the test.
  final buffer = StringBuffer('{');
  var first = true;
  m.forEach((k, v) {
    if (!first) buffer.write(',');
    first = false;
    buffer.write('"$k":');
    if (v is String) {
      buffer.write('"${v.replaceAll('"', r'\"')}"');
    } else if (v is Map) {
      buffer.write(_json(v.cast<String, dynamic>()));
    } else if (v is List) {
      buffer.write('[${v.map((e) => '"$e"').join(',')}]');
    } else {
      buffer.write('$v');
    }
  });
  buffer.write('}');
  return buffer.toString();
}

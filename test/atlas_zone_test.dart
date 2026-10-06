/// Gap G-40 — the bundled atlas and the offset a chart is actually built with.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_astro/data/bundled_atlas.dart';
import 'package:pocket_astro/domain/models.dart';
import 'package:pocket_astro/engine/time_convert.dart';
import 'package:pocket_astro/engine/zone_offset.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

void main() {
  tzdata.initializeTimeZones();

  setUpAll(() {
    BundledAtlas.instance.loadFromString(
        File('assets/atlas/cities.txt').readAsStringSync());
  });

  group('the bundled atlas', () {
    test('carries tens of thousands of places, not a shortlist', () {
      expect(BundledAtlas.instance.size, greaterThan(30000));
    });

    test('every timezone id in it resolves', () {
      // A place whose zone the database cannot resolve would throw deep inside
      // chart building, which is the failure this guards.
      final seen = <String>{};
      for (final q in const ['a', 'e', 'i', 'o', 'u', 'y', 'z']) {
        for (final hit in BundledAtlas.instance.search(q, limit: 400)) {
          seen.add(hit.timezone);
        }
      }
      expect(seen.length, greaterThan(40));
      for (final id in seen) {
        expect(tz.timeZoneDatabase.locations.containsKey(id), isTrue,
            reason: id);
      }
    });

    test('ranks the place the reader almost certainly meant first', () {
      expect(BundledAtlas.instance.search('london').first.region,
          contains('United Kingdom'));
      expect(BundledAtlas.instance.search('paris').first.region,
          contains('France'));
      // Population ordering is what makes this work without a relevance model.
      final lagos = BundledAtlas.instance.search('lagos');
      expect(lagos.first.region, contains('Nigeria'));
    });

    test('folds diacritics so an ASCII keyboard can find anything', () {
      expect(BundledAtlas.instance.search('zurich').first.name, contains('Z'));
      expect(BundledAtlas.instance.search('sao paulo').first.region,
          contains('Brazil'));
      expect(BundledAtlas.instance.search('malaga'), isNotEmpty);
      expect(foldForSearch('Zürich'), 'zurich');
      expect(foldForSearch('São Paulo'), 'sao paulo');
      expect(foldForSearch("Val-d'Or"), 'val d or');
    });

    test('searching by region works, not only by name', () {
      final hits = BundledAtlas.instance.search('maharashtra');
      expect(hits, isNotEmpty);
      for (final h in hits) {
        expect(h.region.toLowerCase(), contains('maharashtra'));
      }
    });

    test('an empty query returns the largest places rather than nothing', () {
      final hits = BundledAtlas.instance.search('');
      expect(hits, isNotEmpty);
      expect(hits.first.population, greaterThan(1000000));
    });

    test('nearest resolves a coordinate to a place and a zone', () {
      final n = BundledAtlas.instance.nearest(27.7172, 85.324);
      expect(n, isNotNull);
      expect(n!.name, 'Kathmandu');
      expect(n.timezone, 'Asia/Kathmandu');
    });

    test('search is fast enough to run on every keystroke', () {
      final sw = Stopwatch()..start();
      for (final q in const ['k', 'ka', 'kat', 'kath', 'kathm', 'kathmandu']) {
        BundledAtlas.instance.search(q);
      }
      sw.stop();
      // Six keystrokes across 34,000 places. Generous bound — the point is to
      // catch an accidental O(n²), not to pin a number.
      expect(sw.elapsedMilliseconds, lessThan(250));
    });
  });

  group('historical offsets', () {
    // The assessment assumed these were missing. They were not — the IANA
    // database carries them — and these cases record that, so nobody
    // "fixes" it again.
    Place at(String tz) => Place(
        name: 'x', region: '', latitude: 0, longitude: 0, timezone: tz);

    test('Kolkata reports Madras Mean Time before standardisation', () {
      final r = readZone(
        localDateTime: DateTime(1900, 6, 1, 12),
        place: const Place(
          name: 'Kolkata', region: 'India',
          latitude: 22.5726, longitude: 88.3639, timezone: 'Asia/Kolkata'),
      );
      expect(r.formatted, '+05:21');
      expect(r.abbreviation, 'MMT');
      expect(r.isPreStandard, isTrue);
      expect(r.notes.any((n) => n.contains('not a whole or half hour')), isTrue);
    });

    test('New York reports Eastern War Time in 1943', () {
      final r = readZone(
        localDateTime: DateTime(1943, 6, 1, 12),
        place: at('America/New_York'),
      );
      expect(r.abbreviation, 'EWT');
      expect(r.isWarTime, isTrue);
      expect(r.worthConfirming, isTrue);
      expect(r.notes.any((n) => n.contains('wartime')), isTrue);
    });

    test('London reports British Double Summer Time in 1947', () {
      final r = readZone(
        localDateTime: DateTime(1947, 6, 1, 12),
        place: at('Europe/London'),
      );
      expect(r.formatted, '+02:00');
      expect(r.abbreviation, 'BDST');
      expect(r.isWarTime, isTrue);
    });

    test('Kathmandu shifts from +05:30 to +05:45 in 1986', () {
      final before = readZone(
        localDateTime: DateTime(1980, 1, 1, 12), place: at('Asia/Kathmandu'));
      final after = readZone(
        localDateTime: DateTime(1990, 1, 1, 12), place: at('Asia/Kathmandu'));
      expect(before.formatted, '+05:30');
      expect(after.formatted, '+05:45');
    });

    test('an ordinary modern chart says nothing alarming', () {
      final r = readZone(
        localDateTime: DateTime(1992, 4, 14, 3, 57),
        place: const Place(
          name: 'Kathmandu', region: 'Nepal',
          latitude: 27.7172, longitude: 85.324, timezone: 'Asia/Kathmandu'),
      );
      expect(r.isWarTime, isFalse);
      expect(r.isPreStandard, isFalse);
      // Kathmandu's zone is close to its own meridian, so there is nothing to
      // confirm.
      expect(r.worthConfirming, isFalse);
    });
  });

  group('local mean time', () {
    const place = Place(
      name: 'Kolkata', region: 'India',
      latitude: 22.5726, longitude: 88.3639, timezone: 'Asia/Kolkata');

    test('is longitude arithmetic and nothing else', () {
      final r = readZone(
        localDateTime: DateTime(1900, 6, 1, 12),
        place: place,
        standard: TimeStandard.localMean,
      );
      // 88.3639 / 15 = 5.8909 h = 5h53m
      expect(r.formatted, '+05:53');
      expect(r.abbreviation, 'LMT');
    });

    test('changes the UTC instant a chart is built for', () {
      final zoneInput = BirthInput(
        id: 'z', name: 'z',
        localDateTime: DateTime(1900, 6, 1, 12),
        place: place, timeSource: TimeSource.hospital);
      final lmtInput = zoneInput.copyWith(timeStandard: TimeStandard.localMean);

      final zoneUtc = toUtc(zoneInput);
      final lmtUtc = toUtc(lmtInput);
      expect(zoneUtc, isNot(lmtUtc));
      // MMT was +05:21, local mean time here is +05:53 — 32 minutes apart.
      expect(zoneUtc.difference(lmtUtc).inMinutes.abs(), closeTo(32, 1));
    });

    test('survives a round trip through storage', () {
      final input = BirthInput(
        id: 'z', name: 'z',
        localDateTime: DateTime(1900, 6, 1, 12),
        place: place, timeSource: TimeSource.hospital,
        timeStandard: TimeStandard.localMean,
        tags: const ['client', 'rectify']);
      final back = BirthInput.fromJson(input.toJson());
      expect(back.timeStandard, TimeStandard.localMean);
      expect(back.tags, ['client', 'rectify']);
    });

    test('records written before the setting existed still read as zone time', () {
      final legacy = {
        'id': 'old',
        'name': 'Old record',
        'localDateTime': DateTime(1980, 1, 1, 9).toIso8601String(),
        'place': place.toJson(),
        'timeSource': 'hospital',
        'notes': '',
      };
      final back = BirthInput.fromJson(legacy);
      expect(back.timeStandard, TimeStandard.zone);
      expect(back.tags, isEmpty);
    });
  });
}

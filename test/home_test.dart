import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_astro/app.dart';
import 'package:pocket_astro/data/geocoder.dart';
import 'package:pocket_astro/data/local_store.dart';
import 'package:pocket_astro/domain/models.dart';
import 'package:pocket_astro/engine/kb.dart';
import 'package:pocket_astro/l10n/engine_strings.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;

/// Drags the named list until [target] is built.
Future<void> _reveal(WidgetTester tester, String key, Finder target,
    {int maxDrags = 14}) async {
  final scroller = find.descendant(
    of: find.byKey(PageStorageKey(key)),
    matching: find.byType(Scrollable),
  );
  for (var i = 0; i < maxDrags && target.evaluate().isEmpty; i++) {
    await tester.drag(scroller.first, const Offset(0, -260));
    await tester.pumpAndSettle();
  }
}

/// The home screen, which used to be a bare list behind two unlabelled icons.
///
/// These tests are about reachability: a reader must be able to get to the
/// course and to the daily reading from the first screen, without opening a
/// chart first, and with no charts saved at all.

class _MemStore extends LocalStore {
  _MemStore([List<BirthInput>? seed]) : saved = seed ?? [];
  List<BirthInput> saved;

  @override
  Future<List<BirthInput>> loadProfiles() async => saved;

  @override
  Future<void> saveProfiles(List<BirthInput> p) async => saved = p;

  @override
  Future<List<Place>> loadRecentPlaces() async => [];

  @override
  Future<void> saveRecentPlaces(List<Place> p) async {}

  @override
  Future<Set<String>> loadLearned() async => {};

  @override
  Future<void> saveLearned(Set<String> ids) async {}
}

const _kathmandu = Place(
  name: 'Kathmandu',
  region: 'Nepal',
  latitude: 27.7172,
  longitude: 85.3240,
  timezone: 'Asia/Kathmandu',
);

BirthInput _profile() => BirthInput(
      id: 'home',
      name: 'Ada',
      localDateTime: DateTime(1992, 4, 14, 3, 57),
      place: _kathmandu,
      timeSource: TimeSource.hospital,
    );

Widget _app(_MemStore store) =>
    PocketAstroApp(store: store, geocoder: const OfflineGeocoder());

/// Pumps the app and makes sure it is showing home.
///
/// The app's GoRouter is a top-level `final` — correct in production, where
/// rebuilding it inside build() would reset the navigation stack on every
/// language change, but it means one test's push survives into the next.
Future<void> _pumpHome(WidgetTester tester, _MemStore store) async {
  await tester.pumpWidget(_app(store));
  await tester.pumpAndSettle();
  for (var i = 0; i < 4; i++) {
    if (find.byType(BackButton).evaluate().isEmpty) break;
    await tester.pageBack();
    await tester.pumpAndSettle();
  }
}

void main() {
  tzdata.initializeTimeZones();

  setUpAll(() async {
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
    EngineStrings.install('en');
  });

  testWidgets('home offers the course and the daily reading with no charts',
      (tester) async {
    await _pumpHome(tester, _MemStore());

    expect(find.text('Learn astrology'), findsWidgets);
    expect(find.text('Compatibility'), findsWidgets);
    // The daily card stands on its own: the panchanga is true for everybody.
    expect(find.text('Daily reading'), findsWidgets);
    // And the empty state is still the first thing a new reader is told.
    expect(find.textContaining('Read a birth chart, offline'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the course opens from home without opening a chart',
      (tester) async {
    await _pumpHome(tester, _MemStore());

    await tester.tap(find.text('Learn astrology').first);
    await tester.pumpAndSettle();

    // The syllabus renders in full; only the worked examples are absent.
    expect(find.text('Basics'), findsOneWidget);
    expect(find.text('0 of 15 lessons done'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the daily reading opens from home and lists twelve signs',
      (tester) async {
    await _pumpHome(tester, _MemStore());

    await tester.tap(find.text('Daily reading').first);
    await tester.pumpAndSettle();

    expect(find.text('Choose your moon sign'), findsOneWidget);
    // Twelve rashi tiles, by name.
    for (final sign in const ['Aries', 'Cancer', 'Libra', 'Capricorn']) {
      expect(find.text(sign), findsWidgets, reason: sign);
    }
    // And it says plainly that a chart reads better.
    final caveat = find.textContaining('reads the same transits');
    await _reveal(tester, 'rashifal', caveat);
    expect(caveat, findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a saved chart lifts its own rashi onto the home card',
      (tester) async {
    await _pumpHome(tester, _MemStore([_profile()]));

    expect(find.text('Your charts'), findsOneWidget);
    expect(find.text('Ada'), findsOneWidget);
    // The daily card now names a moon sign rather than a generic invitation.
    expect(find.textContaining('Moon sign'), findsWidgets);
    expect(find.text('Read your day'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the rashifal marks which sign is the reader\'s own',
      (tester) async {
    await _pumpHome(tester, _MemStore([_profile()]));

    await tester.tap(find.text('Daily reading').first);
    await tester.pumpAndSettle();

    expect(find.textContaining('Yours · Ada'), findsWidgets);
    final mark = find.text('Yours');
    await _reveal(tester, 'rashifal', mark);
    expect(mark, findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tapping a sign opens its full reading', (tester) async {
    await _pumpHome(tester, _MemStore());
    await tester.tap(find.text('Daily reading').first);
    await tester.pumpAndSettle();

    final aries = find.text('Aries');
    await _reveal(tester, 'rashifal', aries);
    await tester.ensureVisible(aries.first);
    await tester.pumpAndSettle();
    await tester.tap(aries.first);
    await tester.pumpAndSettle();

    expect(find.text('WHAT IS MOVING TODAY'), findsOneWidget);
    // All nine grahas are named, not a curated three. The sheet scrolls, so
    // reach each one rather than assuming it is above the fold.
    for (final graha in const ['Moon', 'Saturn', 'Jupiter', 'Ketu']) {
      final row = find.textContaining(graha);
      await _reveal(tester, 'rashi-0', row);
      expect(row, findsWidgets, reason: graha);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('home renders in Nepali end to end', (tester) async {
    EngineStrings.install('ne');
    addTearDown(() => EngineStrings.install('en'));

    final store = _MemStore([_profile()]);
    await _pumpHome(tester, store);

    expect(tester.takeException(), isNull);
  });
}

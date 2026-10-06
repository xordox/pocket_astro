import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_astro/data/geocoder.dart';
import 'package:pocket_astro/data/local_store.dart';
import 'package:pocket_astro/data/place_lookup.dart';
import 'package:pocket_astro/domain/models.dart';
import 'package:pocket_astro/engine/kb.dart';
import 'package:pocket_astro/l10n/engine_strings.dart';
import 'package:pocket_astro/l10n/generated/app_localizations.dart';
import 'package:pocket_astro/state/library_bloc.dart';
import 'package:pocket_astro/state/match_cubit.dart';
import 'package:pocket_astro/state/place_lookup_cubit.dart';
import 'package:pocket_astro/ui/match_screen.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;

/// Compatibility used to be a dead end: with fewer than two saved charts it
/// drew an icon, a heading and a sentence telling the reader to go and save a
/// chart somewhere else. There was no button.
///
/// These tests are about that specific failure — that a reader can now arrive
/// with nothing saved and leave with a score, without going anywhere else.

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

BirthInput _profile(String id, String name) => BirthInput(
      id: id,
      name: name,
      localDateTime: DateTime(1992, 4, 14, 3, 57),
      place: _kathmandu,
      timeSource: TimeSource.hospital,
    );

class _Harness {
  _Harness(this.store, this.widget);
  final _MemStore store;
  final Widget widget;
}

_Harness _screen({List<BirthInput>? seed, String locale = 'en'}) {
  final store = _MemStore(seed);
  return _Harness(
    store,
    MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) => LibraryBloc(store)..add(const LibraryStarted()),
        ),
        BlocProvider(create: (_) => MatchCubit()),
        BlocProvider(
          create: (_) =>
              PlaceLookupCubit(PlaceLookup(store, const OfflineGeocoder())),
        ),
      ],
      child: MaterialApp(
        locale: Locale(locale),
        supportedLocales: L.supportedLocales,
        localizationsDelegates: const [
          L.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: const MatchScreen(),
      ),
    ),
  );
}

/// Fills the open birth form with a name and a bundled place, then saves.
Future<void> _fillForm(WidgetTester tester, String name) async {
  await tester.enterText(find.byType(TextField).first, name);
  await tester.pumpAndSettle();

  final placeField = find.widgetWithText(TextField, 'Birth place').first;
  await tester.enterText(placeField, 'Kathmandu');
  await tester.pumpAndSettle();
  await tester.tap(find.text('Kathmandu, Nepal').first);
  await tester.pumpAndSettle();

  final save = find.text('Save and compare');
  final scroller = find.descendant(
    of: find.byKey(const PageStorageKey('birth-form')),
    matching: find.byType(Scrollable),
  );
  for (var i = 0; i < 14 && save.evaluate().isEmpty; i++) {
    await tester.drag(scroller.first, const Offset(0, -260));
    await tester.pumpAndSettle();
  }
  await tester.ensureVisible(save.first);
  await tester.pumpAndSettle();
  await tester.tap(save.first);
  await tester.pumpAndSettle();
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
    for (final code in supportedLocaleCodes) {
      if (code == 'en') continue;
      EngineStrings.register(
        code,
        File('assets/kb/i18n/$code/engine.json').readAsStringSync(),
      );
    }
    EngineStrings.install('en');
  });

  tearDown(() => EngineStrings.install('en'));

  group('no longer a dead end', () {
    testWidgets('with nothing saved, both slots are present and live',
        (tester) async {
      await tester.pumpWidget(_screen().widget);
      await tester.pumpAndSettle();

      // The heading still explains the situation...
      expect(find.text('Two charts needed'), findsOneWidget);
      // ...but it no longer sends the reader elsewhere.
      expect(find.textContaining('right here'), findsOneWidget);
      // And both slots are on screen and tappable.
      expect(find.text('First person'), findsOneWidget);
      expect(find.text('Second person'), findsOneWidget);
    });

    testWidgets('an empty slot offers to create a chart', (tester) async {
      await tester.pumpWidget(_screen().widget);
      await tester.pumpAndSettle();

      await tester.tap(find.text('First person'));
      await tester.pumpAndSettle();

      expect(find.text('Add a new chart'), findsOneWidget);
      expect(find.text('No charts saved yet.'), findsOneWidget);
    });

    testWidgets('adding a chart fills the slot and saves it to the library',
        (tester) async {
      final h = _screen();
      await tester.pumpWidget(h.widget);
      await tester.pumpAndSettle();

      await tester.tap(find.text('First person'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add a new chart'));
      await tester.pumpAndSettle();

      // The form names the slot being filled.
      expect(find.widgetWithText(AppBar, 'First person'), findsOneWidget);
      await _fillForm(tester, 'Ada');

      // Back on the comparison, with the slot filled — not on a chart screen.
      expect(find.text('Second person'), findsOneWidget);
      expect(find.text('Ada'), findsWidgets);
      // And the chart exists in the library like any other.
      expect(h.store.saved.single.name, 'Ada');
    });

    testWidgets('two charts added inline produce a score, start to finish',
        (tester) async {
      final h = _screen();
      await tester.pumpWidget(h.widget);
      await tester.pumpAndSettle();

      for (final person in const ['First person', 'Second person']) {
        await tester.tap(find.text(person));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Add a new chart'));
        await tester.pumpAndSettle();
        await _fillForm(tester, person == 'First person' ? 'Ada' : 'Ben');
      }

      expect(h.store.saved, hasLength(2));
      // The heading is gone and the reading has appeared.
      expect(find.text('Two charts needed'), findsNothing);
      expect(find.text('of 36'), findsOneWidget);
      expect(find.text('The eight parameters'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('the slot sheet', () {
    testWidgets('lists saved charts alongside the add action', (tester) async {
      await tester.pumpWidget(
        _screen(seed: [_profile('a', 'Ada'), _profile('b', 'Ben')]).widget,
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('First person'));
      await tester.pumpAndSettle();

      expect(find.text('Add a new chart'), findsOneWidget);
      expect(find.text('CHOOSE A SAVED CHART'), findsOneWidget);
      expect(find.text('Ada'), findsOneWidget);
      expect(find.text('Ben'), findsOneWidget);
      expect(find.text('No charts saved yet.'), findsNothing);
    });

    testWidgets('a filled slot can be emptied again', (tester) async {
      await tester.pumpWidget(
        _screen(seed: [_profile('a', 'Ada'), _profile('b', 'Ben')]).widget,
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('First person'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ada'));
      await tester.pumpAndSettle();
      expect(find.text('Ada'), findsWidgets);

      // Clearing is on the slot itself, so it is reachable without scrolling
      // a sheet that may not have built its last child.
      await tester.tap(find.byTooltip('Remove'));
      await tester.pumpAndSettle();

      // The slot is back to its prompt.
      expect(find.text('Choose'), findsWidgets);
    });

    testWidgets('an empty slot offers nothing to clear', (tester) async {
      await tester.pumpWidget(_screen(seed: [_profile('a', 'Ada')]).widget);
      await tester.pumpAndSettle();
      expect(find.byTooltip('Remove'), findsNothing);

      await tester.tap(find.text('First person'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ada'));
      await tester.pumpAndSettle();
      // One slot filled, one clear button.
      expect(find.byTooltip('Remove'), findsOneWidget);
    });
  });

  group('selection integrity', () {
    testWidgets('picking the same person twice does not score', (tester) async {
      await tester.pumpWidget(
        _screen(seed: [_profile('a', 'Ada'), _profile('b', 'Ben')]).widget,
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('First person'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ada'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Second person'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ada').last);
      await tester.pumpAndSettle();

      expect(find.text('of 36'), findsNothing);
      expect(find.textContaining('Pick two different people'), findsOneWidget);
    });

    testWidgets('a deleted profile does not leave a stale score',
        (tester) async {
      final h = _screen(seed: [_profile('a', 'Ada'), _profile('b', 'Ben')]);
      await tester.pumpWidget(h.widget);
      await tester.pumpAndSettle();

      await tester.tap(find.text('First person'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ada'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Second person'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ben'));
      await tester.pumpAndSettle();
      expect(find.text('of 36'), findsOneWidget);

      // Ben is deleted from somewhere else in the app while this screen lives.
      final context = tester.element(find.byType(MatchScreen));
      BlocProvider.of<LibraryBloc>(context).add(const LibraryRemove('b'));
      await tester.pumpAndSettle();

      // The score must not survive its own input.
      expect(find.text('of 36'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('the whole flow works in Nepali', (tester) async {
    EngineStrings.install('ne');
    addTearDown(() => EngineStrings.install('en'));

    await tester.pumpWidget(_screen(locale: 'ne').widget);
    await tester.pumpAndSettle();

    expect(find.text('पहिलो व्यक्ति'), findsOneWidget);
    await tester.tap(find.text('पहिलो व्यक्ति'));
    await tester.pumpAndSettle();
    expect(find.text('नयाँ कुण्डली थप्नुहोस्'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

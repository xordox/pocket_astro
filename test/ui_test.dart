import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_astro/domain/models.dart';
import 'package:pocket_astro/engine/house_quality.dart';
import 'package:pocket_astro/engine/kb.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:pocket_astro/engine/tables.dart';
import 'package:pocket_astro/engine/today.dart';
import 'package:pocket_astro/l10n/engine_strings.dart';
import 'package:pocket_astro/l10n/generated/app_localizations.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pocket_astro/data/local_store.dart';
import 'package:pocket_astro/state/learn_cubit.dart';
import 'package:pocket_astro/state/settings_cubit.dart';
import 'package:pocket_astro/state/library_bloc.dart';
import 'package:pocket_astro/engine/matching.dart';
import 'package:pocket_astro/state/match_cubit.dart';
import 'package:pocket_astro/ui/chart_screen.dart';
import 'package:pocket_astro/ui/match_screen.dart';
import 'package:pocket_astro/ui/widgets/ask_panel.dart';
import 'package:pocket_astro/ui/widgets/atoms.dart';
import 'package:pocket_astro/ui/widgets/kundali.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;

/// Widget-level checks on the reading surfaces. The point is not pixels; it is
/// that a general reader can reach the information — that the chart draws in
/// both traditions, that tapping a graha reveals what it influences, that a
/// house explains itself, and that asking a question shows the real reasoning.

const _place = Place(
  name: 'Kathmandu',
  region: 'Nepal',
  latitude: 27.7172,
  longitude: 85.3240,
  timezone: 'Asia/Kathmandu',
);

BirthInput _timed() => BirthInput(
      id: 'timed',
      name: 'Timed Chart',
      localDateTime: DateTime(1992, 4, 14, 3, 57),
      place: _place,
      timeSource: TimeSource.hospital,
    );

BirthInput _untimed() => BirthInput(
      id: 'untimed',
      name: 'No Time',
      localDateTime: DateTime(1992, 4, 14),
      place: _place,
      timeSource: TimeSource.unknown,
    );

const _delegates = <LocalizationsDelegate<dynamic>>[
  L.delegate,
  GlobalMaterialLocalizations.delegate,
  GlobalWidgetsLocalizations.delegate,
  GlobalCupertinoLocalizations.delegate,
];

Widget _host(Widget child, {String locale = 'en'}) => MaterialApp(
      locale: Locale(locale),
      supportedLocales: L.supportedLocales,
      localizationsDelegates: _delegates,
      home: Scaffold(body: child),
    );

class _MemStore extends LocalStore {
  _MemStore(this.saved);
  List<BirthInput> saved;
  Set<String> learned = {};

  @override
  Future<List<BirthInput>> loadProfiles() async => saved;

  @override
  Future<void> saveProfiles(List<BirthInput> profiles) async => saved = profiles;

  @override
  Future<Set<String>> loadLearned() async => learned;

  @override
  Future<void> saveLearned(Set<String> ids) async => learned = ids;
}

/// The scrollable belonging to a keyed tab list, so a test scrolls the panel
/// it means to and not the tab bar.
Finder _scrollerOf(String key) => find.descendant(
      of: find.byKey(PageStorageKey(key)),
      matching: find.byType(Scrollable),
    );

/// Drags a keyed tab list until [target] is built, then returns.
Future<void> _scrollTo(
  WidgetTester tester,
  String key,
  Finder target, {
  int maxDrags = 8,
}) async {
  final scroller = _scrollerOf(key);
  for (var i = 0; i < maxDrags; i++) {
    if (target.evaluate().isNotEmpty) return;
    await tester.drag(scroller, const Offset(0, -320));
    await tester.pumpAndSettle();
  }
}

BirthInput _partner() => BirthInput(
      id: 'partner',
      name: 'Partner Chart',
      localDateTime: DateTime(1990, 8, 2, 14, 20),
      place: _place,
      timeSource: TimeSource.hospital,
    );

/// The match screen with both blocs, as the app runs it.
Widget _matchScreen(List<BirthInput> profiles, {String locale = 'en'}) =>
    MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) =>
              LibraryBloc(_MemStore(profiles))..add(const LibraryStarted()),
        ),
        BlocProvider(create: (_) => MatchCubit()),
      ],
      child: MaterialApp(
        locale: Locale(locale),
        supportedLocales: L.supportedLocales,
        localizationsDelegates: _delegates,
        home: const MatchScreen(),
      ),
    );

/// The chart screen inside its blocs, as the app runs it.
Widget _screen(BirthInput input, {String locale = 'en'}) {
  final store = _MemStore([input]);
  return MultiBlocProvider(
    providers: [
      BlocProvider(create: (_) => LibraryBloc(store)..add(const LibraryStarted())),
      BlocProvider(create: (_) => LearnCubit(store)..start()),
      // The chart is now built under the reader's calculation settings, so
      // the screen needs them in scope (G-46).
      BlocProvider(create: (_) => SettingsCubit(store)..start()),
    ],
    child: MaterialApp(
      locale: Locale(locale),
      supportedLocales: L.supportedLocales,
      localizationsDelegates: _delegates,
      home: ChartScreen(id: input.id),
    ),
  );
}

/// Taps a tab, scrolling the tab strip first.
///
/// The bar became scrollable when the Techniques tab landed, so a bare
/// `tap(find.text('Learn'))` now derives an offset outside the 800px test
/// viewport and silently misses.
Future<void> _tapTab(WidgetTester tester, String label) async {
  final tabBar = find.byType(TabBar);
  if (tabBar.evaluate().isNotEmpty) {
    await tester.dragUntilVisible(
      find.text(label),
      find.descendant(of: tabBar, matching: find.byType(Scrollable)).first,
      const Offset(-120, 0),
      maxIteration: 12,
    );
    await tester.pumpAndSettle();
  }
  await tester.tap(find.text(label));
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

  group('house quality', () {
    test('a timed chart reads all twelve houses with reasons', () {
      final readings = readHouses(chartFor(_timed()));
      expect(readings, hasLength(12));
      for (var i = 0; i < 12; i++) {
        final r = readings[i];
        expect(r.house, i + 1);
        expect(r.plainTitle, isNotEmpty);
        expect(r.summary, isNotEmpty);
        expect(r.lord, isNotEmpty);
        expect(r.reasons, isNotEmpty,
            reason: 'house ${r.house} scored with no stated reason');
        // The score must equal the reasons that produced it, or the colour on
        // the chart would not match the explanation in the sheet.
        expect(r.score, r.reasons.fold<int>(0, (a, x) => a + x.weight));
      }
    });

    test('bands follow the score, and supporting/pressure split cleanly', () {
      for (final r in readHouses(chartFor(_timed()))) {
        if (r.band == HouseBand.prosperous) expect(r.score, greaterThanOrEqualTo(3));
        if (r.band == HouseBand.strained) expect(r.score, lessThanOrEqualTo(-3));
        for (final s in r.supporting) {
          expect(s.weight, greaterThan(0));
        }
        for (final p in r.pressures) {
          expect(p.weight, lessThan(0));
        }
      }
    });

    test('no birth time yields no houses rather than invented ones', () {
      expect(readHouses(chartFor(_untimed())), isEmpty);
    });

    test('aspect targets follow the classical special aspects', () {
      final chart = chartFor(_timed());
      for (final planet in const ['Sun', 'Moon', 'Mercury', 'Venus']) {
        final row = chart.graha(planet);
        final reached = aspectedHouses(chart, planet);
        // Every graha looks at the 7th from itself, and these four look only
        // there.
        expect(reached, [((row.house + 5) % 12) + 1]);
      }
      for (final e in const {
        'Mars': [4, 7, 8],
        'Jupiter': [5, 7, 9],
        'Saturn': [3, 7, 10],
      }.entries) {
        final row = chart.graha(e.key);
        final expected = e.value.map((o) => ((row.house + o - 2) % 12) + 1).toList()
          ..sort();
        expect(aspectedHouses(chart, e.key), expected, reason: e.key);
      }
      expect(aspectedHouses(chartFor(_untimed()), 'Mars'), isEmpty);
    });
  });

  group('kundali geometry', () {
    test('north layout gives twelve houses, house 1 at the top', () {
      const size = Size.square(300);
      final cells = kundaliCells(size, KundaliStyle.north, 0);
      expect(cells, hasLength(12));
      expect(cells.map((c) => c.house).toSet(), {for (var i = 1; i <= 12; i++) i});
      final one = cells.firstWhere((c) => c.house == 1);
      final seven = cells.firstWhere((c) => c.house == 7);
      expect(one.center.dy, lessThan(seven.center.dy),
          reason: 'house 1 must sit above house 7');
      // North Indian numbering runs anticlockwise: house 4 is on the left.
      final four = cells.firstWhere((c) => c.house == 4);
      final ten = cells.firstWhere((c) => c.house == 10);
      expect(four.center.dx, lessThan(ten.center.dx));
    });

    test('north cells contain their own centre and nothing else', () {
      const size = Size.square(300);
      final cells = kundaliCells(size, KundaliStyle.north, 0);
      for (final cell in cells) {
        expect(cell.path.contains(cell.center), isTrue,
            reason: 'house ${cell.house} does not contain its own centre');
        final others =
            cells.where((c) => c.house != cell.house && c.path.contains(cell.center));
        expect(others, isEmpty,
            reason: 'house ${cell.house} centre also falls inside '
                '${others.map((c) => c.house).toList()}');
      }
    });

    test('signs rotate with the lagna in north, stay fixed in south', () {
      const size = Size.square(300);
      final northA = kundaliCells(size, KundaliStyle.north, 0);
      final northB = kundaliCells(size, KundaliStyle.north, 6);
      expect(northA.firstWhere((c) => c.house == 1).sign, 0);
      expect(northB.firstWhere((c) => c.house == 1).sign, 6);

      final southA = kundaliCells(size, KundaliStyle.south, 0);
      final southB = kundaliCells(size, KundaliStyle.south, 6);
      expect(southA.map((c) => c.sign).toSet(), southB.map((c) => c.sign).toSet());
      expect(southA, hasLength(12));
      // The house number is what moves in a South chart.
      expect(southA.firstWhere((c) => c.sign == 0).house, 1);
      expect(southB.firstWhere((c) => c.sign == 0).house, 7);
    });
  });

  group('kundali widget', () {
    testWidgets('draws in both traditions and survives a style change',
        (tester) async {
      final chart = chartFor(_timed());
      final readings = readHouses(chart);
      var style = KundaliStyle.north;

      await tester.pumpWidget(_host(
        StatefulBuilder(
          builder: (context, setState) => Column(
            children: [
              KundaliChart(
                chart: chart,
                style: style,
                readings: readings,
              ),
              TextButton(
                onPressed: () => setState(() => style = KundaliStyle.south),
                child: const Text('switch'),
              ),
            ],
          ),
        ),
      ));
      expect(find.byType(KundaliChart), findsOneWidget);

      await tester.tap(find.text('switch'));
      await tester.pumpAndSettle();
      expect(find.byType(KundaliChart), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('tapping a cell reports either a graha or a house',
        (tester) async {
      final chart = chartFor(_timed());
      String? tappedPlanet;
      int? tappedHouse;

      await tester.pumpWidget(_host(
        KundaliChart(
          chart: chart,
          style: KundaliStyle.north,
          readings: readHouses(chart),
          onPlanetTap: (p) => tappedPlanet = p,
          onHouseTap: (h) => tappedHouse = h,
        ),
      ));

      // The centre of the widget falls inside one of the middle diamonds.
      await tester.tapAt(tester.getCenter(find.byType(KundaliChart)));
      await tester.pump();
      expect(tappedPlanet != null || tappedHouse != null, isTrue,
          reason: 'a tap inside the chart must resolve to something');
    });

    testWidgets('a chart with no birth time still draws from the Moon',
        (tester) async {
      final chart = chartFor(_untimed());
      await tester.pumpWidget(_host(
        KundaliChart(
          chart: chart,
          style: KundaliStyle.south,
          readings: readHouses(chart),
        ),
      ));
      expect(find.byType(KundaliChart), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('atoms', () {
    testWidgets('every band and verdict renders a word, not only a colour',
        (tester) async {
      await tester.pumpWidget(_host(
        const Column(
          children: [
            BandPill(HouseBand.prosperous),
            BandPill(HouseBand.steady),
            BandPill(HouseBand.strained),
            VerdictBadge('likely'),
            VerdictBadge('possible'),
            VerdictBadge('caution'),
            VerdictBadge('do_not_claim'),
            ConfidenceMeter(62),
            ChartLegend(),
          ],
        ),
      ));
      for (final band in HouseBand.values) {
        expect(find.text(band.label), findsOneWidget);
      }
      for (final v in const ['likely', 'possible', 'caution', 'do_not_claim']) {
        expect(find.text(VerdictBadge.labelFor(v)), findsOneWidget);
      }
      expect(find.text('Helpful graha'), findsOneWidget);
      expect(find.text('Demanding graha'), findsOneWidget);
    });

    testWidgets('ExplainCard hides its detail until asked', (tester) async {
      await tester.pumpWidget(_host(
        const SingleChildScrollView(
          child: ExplainCard(
            title: 'Marriage',
            lead: 'The short answer.',
            detail: 'The long technical reasoning.',
          ),
        ),
      ));
      expect(find.text('The short answer.'), findsOneWidget);
      expect(find.text('Why this?'), findsOneWidget);

      await tester.tap(find.text('Why this?'));
      await tester.pumpAndSettle();
      expect(find.text('The long technical reasoning.'), findsOneWidget);
      expect(find.text('Hide detail'), findsOneWidget);
    });
  });

  group('ask panel', () {
    testWidgets('shows the real reasoning trace, then the answer',
        (tester) async {
      await tester.pumpWidget(_host(AskPanel(chart: chartFor(_timed()))));
      expect(find.textContaining('Ask in your own words'), findsOneWidget);

      await tester.enterText(
        find.byType(TextField),
        'When is a good time to marry?',
      );
      await tester.testTextInput.receiveAction(TextInputAction.send);
      await tester.pump();

      // The trace panel appears immediately and names the chart being read.
      expect(find.text('Reading your chart'), findsOneWidget);

      // Steps reveal one at a time; let them all through.
      await tester.pumpAndSettle(const Duration(milliseconds: 400));

      expect(find.text('Reading your chart'), findsNothing);
      expect(find.textContaining('When is a good time to marry?'),
          findsOneWidget);
      expect(find.textContaining('How this was worked out'), findsOneWidget);
    });

    testWidgets('a death question is refused without reading the chart',
        (tester) async {
      await tester.pumpWidget(_host(AskPanel(chart: chartFor(_timed()))));
      await tester.enterText(find.byType(TextField), 'when will i die');
      await tester.testTextInput.receiveAction(TextInputAction.send);
      await tester.pumpAndSettle(const Duration(milliseconds: 400));

      expect(find.textContaining('does not predict death'), findsWidgets);
      // The refusal trace must be short: it never opens the chart.
      expect(find.textContaining('How this was worked out (2 steps)'),
          findsOneWidget);
    });
  });

  group('chart screen', () {
    testWidgets('opens on a plain-language overview, not a table',
        (tester) async {
      await tester.pumpWidget(_screen(_timed()));
      await tester.pumpAndSettle();

      for (final tab in const [
        'Overview', 'Today', 'Kundali', 'Life areas', 'Timing', 'Techniques',
        'Ask', 'Learn',
      ]) {
        expect(find.text(tab), findsOneWidget, reason: 'missing tab \$tab');
      }
      // The first thing a reader meets is a sentence about themselves.
      expect(find.textContaining('rising'), findsWidgets);
      expect(find.textContaining('period'), findsWidgets);
      // and not a grid of numbers.
      expect(find.byType(DataTable), findsNothing);
    });

    testWidgets('the kundali tab offers both traditions and reacts to a graha',
        (tester) async {
      await tester.pumpWidget(_screen(_timed()));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Kundali'));
      await tester.pumpAndSettle();

      expect(find.text('North Indian'), findsWidgets);
      expect(find.text('South Indian'), findsWidgets);
      expect(find.byType(KundaliChart), findsOneWidget);

      // Selecting a graha names the houses it influences. The chips sit below
      // the chart, so scroll them into view first.
      final jupiter = find.widgetWithText(InkWell, 'Jupiter');
      await _scrollTo(tester, 'kundali', jupiter);
      expect(jupiter, findsWidgets, reason: 'graha chips must be reachable');
      await tester.tap(jupiter.first);
      await tester.pumpAndSettle();
      expect(find.textContaining('It influences'), findsOneWidget);
      expect(find.textContaining('Why this colour?'), findsOneWidget);
    });

    testWidgets('switching to South Indian keeps the chart on screen',
        (tester) async {
      await tester.pumpWidget(_screen(_timed()));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Kundali'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('South Indian').last);
      await tester.pumpAndSettle();
      expect(find.byType(KundaliChart), findsOneWidget);
      expect(find.textContaining('Signs stay in place'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the exact-positions panel opens without throwing',
        (tester) async {
      // Regression: ExpansionTile stores its expanded bool in PageStorage at
      // the same key path an unkeyed scrollable inside it computes, so the
      // horizontal table scroller read that bool as a scroll offset and threw.
      await tester.pumpWidget(_screen(_timed()));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Kundali'));
      await tester.pumpAndSettle();

      final expander = find.text('Exact positions and the Western wheel');
      await _scrollTo(tester, 'kundali', expander);
      expect(expander, findsOneWidget);

      await tester.tap(expander);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull,
          reason: 'expanding the advanced panel must not throw');
      expect(find.byType(DataTable), findsOneWidget);
      expect(find.text('Western wheel (tropical)'), findsOneWidget);

      // And it closes again.
      await tester.tap(expander);
      await tester.pumpAndSettle();
      expect(find.byType(DataTable), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a life area opens a sheet that explains its own colour',
        (tester) async {
      await tester.pumpWidget(_screen(_timed()));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Life areas'));
      await tester.pumpAndSettle();

      expect(find.text('The twelve areas of your life'), findsOneWidget);
      final firstHouse = find.text(housePlainTitle(1));
      await _scrollTo(tester, 'life', firstHouse);
      await tester.tap(firstHouse.first);
      await tester.pumpAndSettle();

      expect(find.text('House 1'), findsOneWidget);
      expect(find.textContaining('Ruled by'), findsOneWidget);

      // The justification sits lower in the sheet; scroll it up.
      final justification = find.textContaining('What helps here');
      final pressure = find.textContaining('What presses on it');
      for (var i = 0; i < 6; i++) {
        if (justification.evaluate().isNotEmpty ||
            pressure.evaluate().isNotEmpty) {
          break;
        }
        await tester.drag(_scrollerOf('house-sheet'), const Offset(0, -260));
        await tester.pumpAndSettle();
      }
      expect(
        justification.evaluate().isNotEmpty || pressure.evaluate().isNotEmpty,
        isTrue,
        reason: 'a house sheet must justify its band',
      );
    });

    testWidgets('the today tab grades the day and shows its working',
        (tester) async {
      await tester.pumpWidget(_screen(_timed()));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Today'));
      await tester.pumpAndSettle();

      // The grade is a word before it is a colour, and it explains itself.
      final grades = DayGrade.values.map((g) => g.label).toList();
      expect(
        grades.where((g) => find.text(g).evaluate().isNotEmpty),
        hasLength(1),
        reason: 'exactly one day grade must be shown',
      );
      expect(find.text('Guidance'), findsOneWidget);

      // The classical windows are named and timed, not merely hinted at.
      await _scrollTo(tester, 'today', find.text('Windows in the day'),
          maxDrags: 12);
      for (final window in const ['Rahu kaal', 'Abhijit muhurta']) {
        await _scrollTo(tester, 'today', find.text(window), maxDrags: 4);
        expect(find.text(window), findsOneWidget);
      }

      // And the last word is that a day cannot overrule a chart.
      final footnote = find.textContaining('Muhurta is the last filter');
      await _scrollTo(tester, 'today', footnote, maxDrags: 16);
      expect(footnote, findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the today tab withholds the kakshya count with no birth time',
        (tester) async {
      await tester.pumpWidget(_screen(_untimed()));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Today'));
      await tester.pumpAndSettle();

      final note = find.textContaining('kakshya count needs a birth time');
      await _scrollTo(tester, 'today', note, maxDrags: 16);
      expect(note, findsOneWidget);
      // The rest of the day still reads.
      expect(find.text('Your Moon today'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the timing tab draws a period timeline', (tester) async {
      await tester.pumpWidget(_screen(_timed()));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Timing'));
      await tester.pumpAndSettle();

      expect(find.text('Your life in periods'), findsOneWidget);
      expect(find.textContaining('through'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the learn tab lists three levels and opens a lesson',
        (tester) async {
      await tester.pumpWidget(_screen(_timed()));
      await tester.pumpAndSettle();
      await _tapTab(tester, 'Learn');

      expect(find.text('Learn astrology'), findsOneWidget);
      expect(find.text('Start the course'), findsOneWidget);

      // Three levels, in order, each named. Scrolling down reaches each in turn.
      for (final level in const ['Basics', 'Intermediate', 'Advanced']) {
        await _scrollTo(tester, 'learn', find.text(level), maxDrags: 24);
        expect(find.text(level), findsOneWidget, reason: level);
      }

      // Tapping a lesson row opens the sheet, and the sheet carries the
      // worked example from this chart. Advanced is the level on screen.
      final lesson = find.text('Ashtakavarga');
      await _scrollTo(tester, 'learn', lesson, maxDrags: 8);
      await tester.ensureVisible(lesson.first);
      await tester.pumpAndSettle();
      await tester.tap(lesson.first);
      await tester.pumpAndSettle();

      // The label is set in small caps, so match what is actually rendered.
      final banner = find.text('IN YOUR CHART');
      await _scrollTo(tester, 'lesson-ashtakavarga', banner, maxDrags: 12);
      expect(banner, findsOneWidget);
      expect(find.textContaining('sarvashtakavarga bindus'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a lesson hides its answer until the reader asks',
        (tester) async {
      await tester.pumpWidget(_screen(_timed()));
      await tester.pumpAndSettle();
      await _tapTab(tester, 'Learn');
      await tester.tap(find.text('Start the course'));
      await tester.pumpAndSettle();

      final answer = find.textContaining('degrees a minute');
      await _scrollTo(tester, 'lesson-what-a-chart-is',
          find.text('CHECK YOURSELF'), maxDrags: 12);
      expect(find.text('Show the answer'), findsOneWidget);
      expect(answer, findsNothing);

      await tester.ensureVisible(find.text('Show the answer'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Show the answer'));
      await tester.pumpAndSettle();
      expect(answer, findsOneWidget);
      expect(find.text('Hide the answer'), findsOneWidget);
    });

    testWidgets('marking a lesson read moves the course on', (tester) async {
      await tester.pumpWidget(_screen(_timed()));
      await tester.pumpAndSettle();
      await _tapTab(tester, 'Learn');
      expect(find.text('0 of 15 lessons done'), findsOneWidget);

      await tester.tap(find.text('Start the course'));
      await tester.pumpAndSettle();
      await _scrollTo(tester, 'lesson-what-a-chart-is',
          find.text('Mark as read'), maxDrags: 14);
      await tester.ensureVisible(find.text('Mark as read'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mark as read'));
      await tester.pumpAndSettle();
      expect(find.text('Read'), findsOneWidget);

      // Back on the list the count has moved and so has "next up".
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      expect(find.text('1 of 15 lessons done'), findsOneWidget);
      expect(find.text('Signs, and the gap between the two zodiacs'),
          findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('every tab scrolls to the bottom without throwing',
        (tester) async {
      // A general guard on the PageStorage hazard: two scrollables that share
      // a key path share one bucket entry, and a scrollable that shares one
      // with a widget storing a bool throws when it restores its offset.
      await tester.pumpWidget(_screen(_timed()));
      await tester.pumpAndSettle();

      for (final tab in const [
        'Overview', 'Today', 'Kundali', 'Life areas', 'Timing', 'Techniques',
        'Learn',
      ]) {
        await _tapTab(tester, tab);
        for (var i = 0; i < 12; i++) {
          await tester.drag(
            find.byType(Scrollable).last,
            const Offset(0, -400),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull,
              reason: 'scrolling \$tab threw on drag \$i');
        }
        // And back to the top.
        for (var i = 0; i < 12; i++) {
          await tester.drag(
            find.byType(Scrollable).last,
            const Offset(0, 400),
          );
          await tester.pumpAndSettle();
        }
        expect(tester.takeException(), isNull, reason: 'scrolling \$tab back');
      }
    });

    testWidgets('revisiting a tab keeps its scroll position and does not throw',
        (tester) async {
      await tester.pumpWidget(_screen(_timed()));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Kundali'));
      await tester.pumpAndSettle();
      await tester.drag(_scrollerOf('kundali'), const Offset(0, -400));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Timing'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Kundali'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('a chart with no birth time explains what is withheld',
        (tester) async {
      await tester.pumpWidget(_screen(_untimed()));
      await tester.pumpAndSettle();

      expect(find.textContaining('No birth time on file'), findsOneWidget);
      await tester.tap(find.text('Life areas'));
      await tester.pumpAndSettle();
      expect(find.textContaining('need a birth time'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('match screen', () {
    test('every koota the engine emits has a plain-language gloss', () {
      final m = matchCharts(chartFor(_timed()), chartFor(_partner()));
      expect(m.kootas, hasLength(8));
      expect(m.kootas.map((k) => k.name).toList(), kootaNames);
      for (final k in m.kootas) {
        final plain = kootaPlain(k.name);
        // A missing translation would surface as the raw lookup key.
        expect(plain.title, isNot(startsWith('koota.')),
            reason: 'no plain title for the \${k.name} koota');
        expect(plain.means, isNot(startsWith('koota.')));
      }
    });

    test('the verdict never tells anyone to leave', () {
      for (final total in const [0.0, 8.0, 18.0, 27.0, 36.0]) {
        final v = matchVerdict(total, 36).toLowerCase();
        expect(v, isNotEmpty);
        for (final forbidden in const [
          'do not marry', 'should not marry', 'avoid this', 'incompatible',
          'will fail',
        ]) {
          expect(v, isNot(contains(forbidden)), reason: 'total \$total');
        }
      }
    });

    testWidgets('asks for a second chart when only one is saved',
        (tester) async {
      await tester.pumpWidget(_matchScreen([_timed()]));
      await tester.pumpAndSettle();
      expect(find.text('Two charts needed'), findsOneWidget);
    });

    testWidgets('picking two people scores them in plain language',
        (tester) async {
      await tester.pumpWidget(_matchScreen([_timed(), _partner()]));
      await tester.pumpAndSettle();

      expect(find.textContaining('Pick two different people'), findsOneWidget);

      await tester.tap(find.text('First person'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Timed Chart').last);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Second person'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Partner Chart').last);
      await tester.pumpAndSettle();

      // The score reads as a sentence before it reads as a number.
      expect(find.text('of 36'), findsOneWidget);
      expect(find.textContaining('traditional'), findsWidgets);
      expect(find.text('The eight parameters'), findsOneWidget);
      expect(find.textContaining('Manglik'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('kootas are titled in English before their Sanskrit',
        (tester) async {
      await tester.pumpWidget(_matchScreen([_timed(), _partner()]));
      await tester.pumpAndSettle();
      await tester.tap(find.text('First person'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Timed Chart').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Second person'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Partner Chart').last);
      await tester.pumpAndSettle();

      // 'Mental friendship' is the gloss for Graha-maitri.
      final gloss = find.text(kootaPlain('Graha-maitri').title);
      for (var i = 0; i < 8 && gloss.evaluate().isEmpty; i++) {
        await tester.drag(find.byType(Scrollable).first, const Offset(0, -320));
        await tester.pumpAndSettle();
      }
      expect(gloss, findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the Manglik card leads with cancellation, not alarm',
        (tester) async {
      await tester.pumpWidget(_matchScreen([_timed(), _partner()]));
      await tester.pumpAndSettle();
      await tester.tap(find.text('First person'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Timed Chart').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Second person'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Partner Chart').last);
      await tester.pumpAndSettle();

      final card = find.text('Manglik (Kuja dosha)');
      for (var i = 0; i < 12 && card.evaluate().isEmpty; i++) {
        await tester.drag(find.byType(Scrollable).first, const Offset(0, -320));
        await tester.pumpAndSettle();
      }
      expect(card, findsOneWidget);
      expect(
        find.textContaining('never use Manglik to predict harm'),
        findsOneWidget,
      );
    });
  });

  group('language', () {
    testWidgets('the whole chart screen renders in Nepali', (tester) async {
      EngineStrings.install('ne');
      addTearDown(() => EngineStrings.install('en'));

      await tester.pumpWidget(_screen(_timed(), locale: 'ne'));
      await tester.pumpAndSettle();

      // Tab labels come from the ARB, the reading from the engine table.
      expect(find.text('सारांश'), findsOneWidget);
      expect(find.text('आज'), findsOneWidget);
      expect(find.text('सिक्नुहोस्'), findsOneWidget);
      expect(find.text('कुण्डली'), findsOneWidget);
      expect(find.textContaining('लग्न'), findsWidgets);
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('जीवनका क्षेत्र'));
      await tester.pumpAndSettle();
      expect(find.text(housePlainTitle(1)), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the whole chart screen renders in Hindi', (tester) async {
      EngineStrings.install('hi');
      addTearDown(() => EngineStrings.install('en'));

      await tester.pumpWidget(_screen(_timed(), locale: 'hi'));
      await tester.pumpAndSettle();
      expect(find.text('सारांश'), findsOneWidget);
      expect(find.text('कुंडली'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the Ask trace is narrated in the reader\'s language',
        (tester) async {
      EngineStrings.install('ne');
      addTearDown(() => EngineStrings.install('en'));

      await tester.pumpWidget(
        _host(AskPanel(chart: chartFor(_timed())), locale: 'ne'),
      );
      await tester.enterText(find.byType(TextField), 'career');
      await tester.testTextInput.receiveAction(TextInputAction.send);
      await tester.pump();
      expect(find.text('तपाईंको कुण्डली पढ्दै'), findsOneWidget);

      await tester.pumpAndSettle(const Duration(milliseconds: 400));
      expect(find.textContaining('यो कसरी निकालियो'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the match screen renders in Hindi', (tester) async {
      EngineStrings.install('hi');
      addTearDown(() => EngineStrings.install('en'));

      await tester.pumpWidget(
        _matchScreen([_timed(), _partner()], locale: 'hi'),
      );
      await tester.pumpAndSettle();
      expect(find.text('अनुकूलता'), findsOneWidget);
      expect(find.text('पहला व्यक्ति'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('plain-language titles', () {
    test('every house has a title a first-time reader understands', () {
      for (var h = 1; h <= 12; h++) {
        final title = housePlainTitle(h);
        expect(title, isNotEmpty);
        // No Sanskrit, no house numbers, and never a bare lookup key.
        expect(title.toLowerCase(), isNot(contains('bhava')));
        expect(title, isNot(contains('$h')));
        expect(title, isNot(startsWith('house.')));
      }
    });

    test('house topics stay available alongside the plain titles', () {
      for (var h = 1; h <= 12; h++) {
        expect(houseTopics[h], isNotNull);
        expect(houseTopic(h), isNotEmpty);
      }
    });
  });
}

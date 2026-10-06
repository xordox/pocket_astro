/// Widget tests for the KP, Varshaphal, Muhurta and rectification screens.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_astro/data/interchange.dart';
import 'package:pocket_astro/domain/models.dart';
import 'package:pocket_astro/engine/chart_builder.dart';
import 'package:pocket_astro/engine/kb.dart';
import 'package:pocket_astro/engine/time_convert.dart';
import 'package:pocket_astro/l10n/engine_strings.dart';
import 'package:pocket_astro/l10n/generated/app_localizations.dart';
import 'package:pocket_astro/state/settings_cubit.dart';
import 'package:pocket_astro/theme/theme.dart';
import 'package:pocket_astro/ui/calendar_screen.dart';
import 'package:pocket_astro/ui/consultations_screen.dart';
import 'package:pocket_astro/ui/horary_screen.dart';
import 'package:pocket_astro/ui/kp_screen.dart';
import 'package:pocket_astro/ui/muhurta_screen.dart';
import 'package:pocket_astro/ui/rectification_screen.dart';
import 'package:pocket_astro/ui/varshaphal_screen.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;

import 'support/memory_store.dart';

const _place = Place(
  name: 'Kathmandu', region: 'Nepal',
  latitude: 27.7172, longitude: 85.324, timezone: 'Asia/Kathmandu');

late BirthInput input;
late NatalChart chart;

Future<void> _pump(WidgetTester tester, Widget screen) async {
  tester.view.physicalSize = const Size(1000, 3200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => SettingsCubit(MemoryStore())..start()),
      ],
      child: MaterialApp(
        theme: pocketTheme(),
        localizationsDelegates: const [
          L.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: L.supportedLocales,
        home: screen,
      ),
    ),
  );
  await tester.pumpAndSettle();
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
    for (final code in supportedLocaleCodes) {
      if (code == 'en') continue;
      EngineStrings.register(
        code, File('assets/kb/i18n/$code/engine.json').readAsStringSync());
    }
    EngineStrings.install('en');

    input = BirthInput(
      id: 'demo',
      name: 'Demo',
      localDateTime: DateTime(1992, 4, 14, 3, 57),
      place: _place,
      timeSource: TimeSource.hospital,
    );
    chart = buildChart(input, toUtc(input));
  });

  group('KP screen', () {
    testWidgets('recasts under KP settings and says so', (tester) async {
      await _pump(tester, KpScreen(input: input));
      expect(find.textContaining('Krishnamurti ayanamsa'), findsWidgets);
      expect(find.textContaining('cuspal sub-lord decides'), findsOneWidget);
    });

    testWidgets('every cusp carries a verdict', (tester) async {
      await _pump(tester, KpScreen(input: input));
      final verdicts = find.textContaining(RegExp('promises|denies|mixed'));
      expect(verdicts, findsWidgets);
    });

    testWidgets('the planet tab shows star, sub and sub-sub', (tester) async {
      await _pump(tester, KpScreen(input: input));
      await tester.tap(find.text('Planets'));
      await tester.pumpAndSettle();
      expect(find.text('Star lord'), findsOneWidget);
      expect(find.text('Sub'), findsOneWidget);
      expect(find.text('Sub-sub'), findsOneWidget);
    });

    testWidgets('horary accepts a number and names its division',
        (tester) async {
      await _pump(tester, KpScreen(input: input));
      await tester.tap(find.text('Horary'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Ruling planets'), findsOneWidget);

      await tester.enterText(find.byType(TextField), '128');
      await tester.pumpAndSettle();
      expect(find.text('Number 128'), findsOneWidget);
      expect(find.textContaining('horary ascendant falls at'), findsOneWidget);
    });

    testWidgets('a bad number is ignored rather than crashing',
        (tester) async {
      await _pump(tester, KpScreen(input: input));
      await tester.tap(find.text('Horary'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '999');
      await tester.pumpAndSettle();
      expect(find.textContaining('Number 999'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('Varshaphal screen', () {
    testWidgets('shows the pravesh, the muntha and the year lord',
        (tester) async {
      await _pump(tester, VarshaphalScreen(chart: chart));
      expect(find.text('Varsha Pravesh'), findsOneWidget);
      expect(find.textContaining('Muntha in'), findsWidgets);
      expect(find.textContaining('Varshesha'), findsWidgets);
      expect(find.textContaining('Mudda dasha'), findsOneWidget);
    });

    testWidgets('switching year recomputes', (tester) async {
      await _pump(tester, VarshaphalScreen(chart: chart));
      final target = DateTime.now().year - 1;
      await tester.tap(find.text('$target'));
      await tester.pumpAndSettle(const Duration(seconds: 10));
      expect(tester.takeException(), isNull);
      expect(find.text('Varsha Pravesh'), findsOneWidget);
    });
  });

  group('Muhurta screen', () {
    testWidgets('searches and shows reasons for each window', (tester) async {
      await _pump(tester, MuhurtaScreen(place: _place, native: chart));
      expect(find.text('Business or a contract'), findsOneWidget);

      await tester.tap(find.text('7 days'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Find windows'));
      await tester.pumpAndSettle(const Duration(seconds: 60));

      // The refusals are stated, so a thin result is explained rather than bare.
      expect(find.textContaining('refused outright'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a purpose with a caution shows it', (tester) async {
      await _pump(tester, const MuhurtaScreen(place: _place));
      await tester.tap(find.text('Surgery or treatment'));
      await tester.pumpAndSettle();
      expect(find.textContaining('not medical advice'), findsOneWidget);
    });
  });

  group('rectification screen', () {
    testWidgets('the live readout moves with the slider', (tester) async {
      await _pump(tester, RectificationScreen(input: input));
      expect(find.text('Lagna'), findsOneWidget);
      expect(find.text('Navamsa lagna'), findsOneWidget);

      await tester.drag(find.byType(Slider), const Offset(120, 0));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('a wide window reports what changes', (tester) async {
      await _pump(tester, RectificationScreen(input: input));
      await tester.tap(find.text('±2h'));
      await tester.pumpAndSettle();
      expect(find.textContaining(RegExp('lagna (stays|crosses)')), findsWidgets);
    });

    testWidgets('event fitting refuses to run with no events', (tester) async {
      await _pump(tester, RectificationScreen(input: input));
      await tester.tap(find.text('Fit to events'));
      await tester.pumpAndSettle();
      final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Score candidate times'));
      expect(button.onPressed, isNull);
    });

    testWidgets('the ranking is framed as a ranking', (tester) async {
      await _pump(tester, RectificationScreen(input: input));
      await tester.tap(find.text('Fit to events'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Three events is the practical minimum'),
          findsOneWidget);
    });
  });

  group('calendar screen', () {
    testWidgets('names the month in both reckonings when they differ',
        (tester) async {
      await _pump(tester, const CalendarScreen(place: _place));
      await tester.pumpAndSettle(const Duration(seconds: 30));
      expect(find.text('Today'), findsOneWidget);
      expect(find.textContaining('Samvatsara'), findsWidgets);
      expect(find.textContaining('Vikram Samvat'), findsWidgets);
      expect(find.textContaining('Next sankranti'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('lists moons and fasts for the month', (tester) async {
      await _pump(tester, const CalendarScreen(place: _place));
      await tester.pumpAndSettle(const Duration(seconds: 30));
      expect(find.text('Moons and fasts'), findsOneWidget);
      expect(find.textContaining('Ekadashi'), findsWidgets);
    });
  });

  group('horary screen', () {
    testWidgets('offers questions with the house each belongs to',
        (tester) async {
      await _pump(tester, const HoraryScreen(place: _place));
      expect(find.text('Will we marry?'), findsOneWidget);
      expect(find.textContaining('7th house'), findsWidgets);
    });

    testWidgets('casting produces considerations and either an answer or a '
        'refusal', (tester) async {
      await _pump(tester, const HoraryScreen(place: _place));
      await tester.tap(find.text('Cast and judge'));
      await tester.pumpAndSettle(const Duration(seconds: 20));

      expect(find.text('Considerations before judgment'), findsOneWidget);
      // Either the chart was judged, or it was refused — never both, never
      // neither.
      final judged = find.text('Significators').evaluate().isNotEmpty;
      final refused = find.text('Not fit to judge').evaluate().isNotEmpty;
      expect(judged ^ refused, isTrue);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a refused chart shows no answer at all', (tester) async {
      await _pump(tester, const HoraryScreen(place: _place));
      await tester.tap(find.text('Cast and judge'));
      await tester.pumpAndSettle(const Duration(seconds: 20));
      if (find.text('Not fit to judge').evaluate().isNotEmpty) {
        expect(find.text('yes'), findsNothing);
        expect(find.text('no'), findsNothing);
        expect(find.textContaining('you would believe it'), findsOneWidget);
      }
    });
  });

  group('session log', () {
    testWidgets('records a dated session and reads it back', (tester) async {
      final store = MemoryStore();
      await _pump(tester, ConsultationsScreen(input: input, store: store));
      expect(find.text('No sessions recorded yet.'), findsOneWidget);

      await tester.tap(find.text('New session'));
      await tester.pumpAndSettle();
      await tester.enterText(
          find.widgetWithText(TextField, 'What was it about?'), 'House move');
      await tester.enterText(
          find.widgetWithText(TextField, 'Notes'), 'Fourth house, Saturn.');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.text('House move'), findsOneWidget);
      expect(find.text('Fourth house, Saturn.'), findsOneWidget);

      final saved = await store.loadConsultations();
      expect(saved[input.id]!.single.summary, 'House move');
    });

    testWidgets('sessions are listed most recent first', (tester) async {
      final store = MemoryStore();
      await store.saveConsultations({
        input.id: [
          Consultation(
            id: 'a', chartId: input.id,
            when: DateTime(2023, 1, 1), summary: 'Older'),
          Consultation(
            id: 'b', chartId: input.id,
            when: DateTime(2024, 6, 1), summary: 'Newer'),
        ],
      });
      await _pump(tester, ConsultationsScreen(input: input, store: store));

      final newer = tester.getTopLeft(find.text('Newer'));
      final older = tester.getTopLeft(find.text('Older'));
      expect(newer.dy, lessThan(older.dy));
    });

    testWidgets('a session can be deleted', (tester) async {
      final store = MemoryStore();
      await store.saveConsultations({
        input.id: [
          Consultation(
            id: 'a', chartId: input.id,
            when: DateTime(2023, 1, 1), summary: 'Remove me'),
        ],
      });
      await _pump(tester, ConsultationsScreen(input: input, store: store));
      await tester.tap(find.byTooltip('Delete this session'));
      await tester.pumpAndSettle();

      expect(find.text('Remove me'), findsNothing);
      expect((await store.loadConsultations())[input.id], isEmpty);
    });
  });
}
/// Widget tests for the screens added with the Tier 2–4 gaps.
///
/// These are deliberately shallow but broad: every new screen is pumped,
/// scrolled and interacted with at least once. A screen that throws on first
/// paint is the failure mode that matters here, and it is the one an engine
/// test can never catch.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_astro/domain/models.dart';
import 'package:pocket_astro/engine/astronomy.dart';
import 'package:pocket_astro/engine/chart_builder.dart';
import 'package:pocket_astro/engine/kb.dart';
import 'package:pocket_astro/engine/time_convert.dart';
import 'package:pocket_astro/l10n/engine_strings.dart';
import 'package:pocket_astro/l10n/generated/app_localizations.dart';
import 'package:pocket_astro/state/settings_cubit.dart';
import 'package:pocket_astro/theme/theme.dart';
import 'package:pocket_astro/ui/schools_screen.dart';
import 'package:pocket_astro/ui/settings_screen.dart';
import 'package:pocket_astro/ui/strength_screen.dart';
import 'package:pocket_astro/ui/timeline_screen.dart';
import 'package:pocket_astro/ui/vargas_screen.dart';
import 'package:pocket_astro/ui/wheel_screen.dart';
import 'package:pocket_astro/ui/widgets/provenance.dart';
import 'package:pocket_astro/ui/widgets/wheel.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;

import 'support/memory_store.dart';

const _delegates = [
  L.delegate,
  GlobalMaterialLocalizations.delegate,
  GlobalWidgetsLocalizations.delegate,
  GlobalCupertinoLocalizations.delegate,
];

late NatalChart timed;
late NatalChart untimed;

/// A birth inside the Arctic circle, where Placidus has no answer.
final _polarBirth = DateTime(1992, 4, 14, 0, 12);

/// Pumps a screen on a tall viewport.
///
/// These screens are long by design — a professional tool has a lot to say per
/// view. The default 800x600 test surface puts most of it below the fold and
/// turns every assertion into a scroll dance, so the viewport is made tall
/// enough to hold a page instead.
Future<void> _pump(WidgetTester tester, Widget screen,
    {MemoryStore? store}) async {
  tester.view.physicalSize = const Size(1000, 3200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(_host(screen, store: store));
  await tester.pumpAndSettle();
}

Widget _host(Widget child, {MemoryStore? store}) => MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) => SettingsCubit(store ?? MemoryStore())..start(),
        ),
      ],
      child: MaterialApp(
        theme: pocketTheme(),
        localizationsDelegates: _delegates,
        supportedLocales: L.supportedLocales,
        home: child,
      ),
    );

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
        code,
        File('assets/kb/i18n/$code/engine.json').readAsStringSync(),
      );
    }
    EngineStrings.install('en');
    timed = _chart(TimeSource.hospital);
    untimed = _chart(TimeSource.unknown);
  });

  group('divisional charts screen', () {
    testWidgets('opens on the navamsa and can switch varga', (tester) async {
      await _pump(tester, VargasScreen(chart: timed));

      expect(find.text('Divisional charts'), findsOneWidget);
      expect(find.textContaining('D9'), findsWidgets);

      // Every varga is listed by what it is for, not only by number.
      expect(find.textContaining('marriage'), findsWidgets);
      expect(find.textContaining('career'), findsWidgets);

      await tester.tap(find.text('Dashamsa').first);
      await tester.pumpAndSettle();
      expect(find.textContaining('D10'), findsWidgets);
    });

    testWidgets('vimshopaka groups are switchable', (tester) async {
      await _pump(tester, VargasScreen(chart: timed));
      expect(find.textContaining('Vimshopaka'), findsWidgets);
      expect(find.textContaining('Shodashavarga (16)'), findsWidgets);
      await tester.tap(find.textContaining('Dashavarga (10)').first);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });

  group('strength screen', () {
    testWidgets('names the strongest graha and shows the six strengths',
        (tester) async {
      await _pump(tester, StrengthScreen(chart: timed));

      expect(find.text('Strength'), findsOneWidget);
      expect(find.textContaining('strongest graha here'), findsOneWidget);
      expect(find.textContaining('rupas'), findsWidgets);

      await tester.tap(find.text('The six strengths').first);
      await tester.pumpAndSettle();
      expect(find.textContaining('Cheshta'), findsWidgets);
    });

    testWidgets('every tab renders', (tester) async {
      await _pump(tester, StrengthScreen(chart: timed));
      for (final tab in const ['Avastha', 'Bhava bala', 'Ashtakavarga']) {
        await tester.tap(find.text(tab));
        await tester.pumpAndSettle();
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('withholds ashtakavarga without a birth time', (tester) async {
      await _pump(tester, StrengthScreen(chart: untimed));
      await tester.tap(find.text('Ashtakavarga'));
      await tester.pumpAndSettle();
      // The engine refuses a seven-eighths ashtakavarga; the screen says why.
      expect(find.textContaining('eight contributors'), findsOneWidget);
    });
  });

  group('schools screen', () {
    testWidgets('Jaimini names the Atmakaraka and the Darakaraka',
        (tester) async {
      await _pump(tester, SchoolsScreen(chart: timed));
      expect(find.text('Atmakaraka'), findsWidgets);
      expect(find.text('Darakaraka'), findsWidgets);
      expect(find.text('AL'), findsWidgets);
      expect(find.text('UL'), findsWidgets);
    });

    testWidgets('the traditional tab states the sect', (tester) async {
      await _pump(tester, SchoolsScreen(chart: timed));
      await tester.tap(find.text('Traditional'));
      await tester.pumpAndSettle();
      expect(find.textContaining(RegExp('diurnal|nocturnal')), findsWidgets);
      expect(find.textContaining('Almuten figuris'), findsOneWidget);
    });

    testWidgets('time lords show a profection and a releasing period',
        (tester) async {
      await _pump(tester, SchoolsScreen(chart: timed));
      await tester.tap(find.text('Time lords'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Profected year'), findsOneWidget);
      expect(find.textContaining('Firdaria'), findsWidgets);
    });

    testWidgets('derived charts switch harmonic', (tester) async {
      await _pump(tester, SchoolsScreen(chart: timed));
      await tester.tap(find.text('Derived charts'));
      await tester.pumpAndSettle();
      expect(find.text('H5'), findsWidgets);
      await tester.tap(find.text('H9').first);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('Jaimini stands down without a birth time', (tester) async {
      await _pump(tester, SchoolsScreen(chart: untimed));
      expect(find.textContaining('need a birth time'), findsOneWidget);
    });
  });

  group('wheel', () {
    testWidgets('draws and switches to a bi-wheel', (tester) async {
      await _pump(tester, WheelScreen(chart: timed));
      expect(find.byType(ChartWheel), findsOneWidget);
      await tester.tap(find.text('Transits'));
      await tester.pumpAndSettle();
      expect(find.textContaining('outer ring'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('names the house system it actually used', (tester) async {
      await _pump(tester, WheelScreen(chart: timed));
      expect(find.textContaining('Placidus houses'), findsOneWidget);
    });

    testWidgets('declines a wheel without a birth time', (tester) async {
      await _pump(tester, WheelScreen(chart: untimed));
      expect(find.textContaining('houses need a birth time'), findsOneWidget);
    });
  });

  group('timeline', () {
    testWidgets('searches and then lists dated events', (tester) async {
      tester.view.physicalSize = const Size(1000, 3200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_host(TimelineScreen(chart: timed)));
      await tester.pump();
      // The search is real work, so the screen says what it is doing first.
      expect(find.textContaining('Solving exact contacts'), findsOneWidget);
      await tester.pumpAndSettle(const Duration(seconds: 60));
      expect(find.text('Timeline'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('settings', () {
    testWidgets('changing the ayanamsa persists', (tester) async {
      final store = MemoryStore();
      await _pump(tester, const SettingsScreen(), store: store);

      expect(find.text('Calculation'), findsOneWidget);
      await tester.tap(find.text('Raman'));
      await tester.pumpAndSettle();

      final saved = await store.loadChartSettings();
      expect(saved, isNotNull);
      expect((saved!['chart'] as Map)['ayanamsa'], 'raman');
    });

    testWidgets('a preset sets several things at once', (tester) async {
      final store = MemoryStore();
      await _pump(tester, const SettingsScreen(), store: store);

      await tester.tap(find.text('KP (Krishnamurti)'));
      await tester.pumpAndSettle();

      final saved = (await store.loadChartSettings())!['chart'] as Map;
      // KP needs all three together or it is not KP.
      expect(saved['ayanamsa'], 'krishnamurti');
      expect(saved['houseSystem'], 'placidus');
      expect(saved['topocentric'], isTrue);
    });

    testWidgets('shows the consequence of the ayanamsa on a real chart',
        (tester) async {
      await _pump(tester, SettingsScreen(sampleChart: timed));
      expect(
        find.textContaining(RegExp('moves the dasha|under every school')),
        findsWidgets,
      );
    });

    testWidgets('the accuracy note is honest about the planets',
        (tester) async {
      await _pump(tester, const SettingsScreen());
      // The settings page is genuinely long, so this one still needs a scroll
      // even on the tall test viewport.
      await tester.scrollUntilVisible(
        find.text('How accurate is this?'),
        600,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('How accurate is this?'));
      await tester.pumpAndSettle();
      expect(find.textContaining('not Swiss Ephemeris grade'), findsOneWidget);
    });
  });

  group('provenance', () {
    testWidgets('records what the chart was computed under', (tester) async {
      await _pump(tester,
          Scaffold(body: ListView(children: [ProvenancePanel(chart: timed)])));
      await tester.tap(find.text('How this chart was computed'));
      await tester.pumpAndSettle();

      expect(find.text('Lahiri (Chitrapaksha)'), findsWidgets);
      expect(find.text('Mean node'), findsOneWidget);
      expect(find.text('Geocentric'), findsOneWidget);
      expect(find.textContaining('ΔT applied'), findsOneWidget);
    });

    testWidgets('reports a polar fallback rather than hiding it',
        (tester) async {
      final polar = buildChart(
        BirthInput(
          id: 'polar',
          name: 'Tromsø',
          localDateTime: _polarBirth,
          place: Place(
            name: 'Tromsø', region: 'Norway',
            latitude: 69.65, longitude: 18.96, timezone: 'Europe/Oslo',
          ),
          timeSource: TimeSource.hospital,
        ),
        DateTime.utc(1992, 4, 13, 22, 12),
      );
      await _pump(tester,
          Scaffold(body: ListView(children: [ProvenancePanel(chart: polar)])));
      await tester.tap(find.text('How this chart was computed'));
      await tester.pumpAndSettle();
      expect(find.text('House fallback'), findsOneWidget);
      expect(find.textContaining('never rises'), findsOneWidget);
    });
  });
}

NatalChart _chart(TimeSource source) {
  final input = BirthInput(
    id: 'demo-$source',
    name: 'Demo',
    localDateTime: DateTime(1992, 4, 14, 3, 57),
    place: const Place(
      name: 'Kathmandu',
      region: 'Nepal',
      latitude: 27.7172,
      longitude: 85.324,
      timezone: 'Asia/Kathmandu',
    ),
    timeSource: source,
  );
  return buildChart(input, toUtc(input), settings: const ChartSettings());
}

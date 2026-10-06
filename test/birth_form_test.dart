import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pocket_astro/data/geocoder.dart';
import 'package:pocket_astro/data/local_store.dart';
import 'package:pocket_astro/data/place_lookup.dart';
import 'package:pocket_astro/domain/models.dart';
import 'package:pocket_astro/l10n/generated/app_localizations.dart';
import 'package:pocket_astro/state/library_bloc.dart';
import 'package:pocket_astro/state/place_lookup_cubit.dart';
import 'package:pocket_astro/ui/library_screen.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;

/// The birth form, which had no test coverage before birthplace entry became
/// free text and started involving a network.
///
/// The load-bearing assertion in this file is the first one: typing must not
/// open a socket. Everything else is ordinary UI behaviour; that one is the
/// product promise. It is asserted twice over — once by inspecting what the
/// fake geocoder was asked, and once by an `HttpOverrides` that makes any real
/// socket a test failure rather than a slow test.

/// Any attempt to open a real connection blows up the test.
class _NoNetwork extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) =>
      throw StateError('a test tried to open a real network connection');
}

class _MemStore extends LocalStore {
  _MemStore([List<BirthInput>? seed]) : saved = seed ?? [];
  List<BirthInput> saved;
  List<Place> places = [];

  @override
  Future<List<BirthInput>> loadProfiles() async => saved;

  @override
  Future<void> saveProfiles(List<BirthInput> profiles) async => saved = profiles;

  @override
  Future<List<Place>> loadRecentPlaces() async => places;

  @override
  Future<void> saveRecentPlaces(List<Place> p) async => places = p;

  @override
  Future<Set<String>> loadLearned() async => {};

  @override
  Future<void> saveLearned(Set<String> ids) async {}
}

/// Records what it was asked, and lets a test hold a search open.
class _FakeGeocoder implements Geocoder {
  _FakeGeocoder(this.result);

  GeocodeResult result;
  final List<String> queries = [];
  Completer<void>? gate;

  @override
  Future<GeocodeResult> search(String query, {String language = 'en'}) async {
    queries.add(query);
    if (gate != null) await gate!.future;
    return result;
  }
}

/// Deliberately NOT in the bundled atlas: searching online is only worth doing
/// for a place the device does not already know.
const _lagos = Place(
  name: 'Lagos',
  region: 'Nigeria',
  latitude: 6.5244,
  longitude: 3.3792,
  timezone: 'Africa/Lagos',
);

class _Harness {
  _Harness(this.store, this.geocoder, this.widget);
  final _MemStore store;
  final _FakeGeocoder geocoder;
  final Widget widget;
}

_Harness _form({GeocodeResult? result, String locale = 'en'}) {
  final store = _MemStore();
  final geocoder = _FakeGeocoder(result ?? const GeocodeEmpty());
  final lookup = PlaceLookup(store, geocoder);
  return _Harness(
    store,
    geocoder,
    MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => LibraryBloc(store)..add(const LibraryStarted())),
        BlocProvider(create: (_) => PlaceLookupCubit(lookup)),
      ],
      child: MaterialApp.router(
        locale: Locale(locale),
        supportedLocales: L.supportedLocales,
        localizationsDelegates: const [
          L.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        // A real router: saving navigates to the chart, and a plain
        // MaterialApp would make that a crash rather than a test.
        routerConfig: GoRouter(
          routes: [
            GoRoute(path: '/', builder: (c, s) => const BirthFormScreen()),
            GoRoute(
              path: '/chart/:id',
              builder: (c, s) => Scaffold(
                body: Center(child: Text('chart ${s.pathParameters['id']}')),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

Finder get _placeField => find.widgetWithText(TextField, 'Birth place').first;

/// The form's own scrollable, so a test scrolls the list and not some inner
/// one. The form is long enough now that the save button starts off-screen and
/// outside the cache extent, so `ensureVisible` alone cannot reach it.
Finder get _formScroller => find.descendant(
      of: find.byKey(const PageStorageKey('birth-form')),
      matching: find.byType(Scrollable),
    );

Future<void> _reveal(WidgetTester tester, Finder target,
    {int maxDrags = 12}) async {
  for (var i = 0; i < maxDrags && target.evaluate().isEmpty; i++) {
    await tester.drag(_formScroller.first, const Offset(0, -260));
    await tester.pumpAndSettle();
  }
  if (target.evaluate().isNotEmpty) {
    await tester.ensureVisible(target.first);
    await tester.pumpAndSettle();
  }
}

/// Devanagari occupies U+0900–U+097F.
bool isDevanagari(String s) => s.runes.any((r) => r >= 0x0900 && r <= 0x097F);

void main() {
  tzdata.initializeTimeZones();

  setUpAll(() => HttpOverrides.global = _NoNetwork());
  tearDownAll(() => HttpOverrides.global = null);

  group('typing', () {
    testWidgets('matches on-device places and opens no socket', (tester) async {
      final h = _form();
      await tester.pumpWidget(h.widget);
      await tester.pumpAndSettle();

      await tester.enterText(_placeField, 'Kath');
      await tester.pumpAndSettle();

      // The bundled atlas answered.
      expect(find.text('Kathmandu, Nepal'), findsOneWidget);
      // And nothing was asked of the network. This is the promise.
      expect(h.geocoder.queries, isEmpty,
          reason: 'a keystroke must never reach the geocoder');
    });

    testWidgets('tapping a local match selects it', (tester) async {
      final h = _form();
      await tester.pumpWidget(h.widget);
      await tester.pumpAndSettle();

      await tester.enterText(_placeField, 'Pokhara');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Pokhara, Nepal'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Asia/Kathmandu'), findsWidgets);
      expect(h.geocoder.queries, isEmpty);
    });

    testWidgets('online search is refused below three letters', (tester) async {
      final h = _form();
      await tester.pumpWidget(h.widget);
      await tester.pumpAndSettle();

      await tester.enterText(_placeField, 'Lo');
      await tester.pumpAndSettle();

      final button = tester.widget<TextButton>(
        find.ancestor(
          of: find.text('Search online'),
          matching: find.byType(TextButton),
        ),
      );
      expect(button.onPressed, isNull, reason: 'must be disabled');
      expect(find.text('Type at least three letters, then search.'),
          findsOneWidget);
    });
  });

  group('online search', () {
    testWidgets('shows a loading state while the lookup is in flight',
        (tester) async {
      final h = _form(result: const GeocodeHits([_lagos]));
      h.geocoder.gate = Completer<void>();
      await tester.pumpWidget(h.widget);
      await tester.pumpAndSettle();

      await tester.enterText(_placeField, 'Lagos');
      await tester.pumpAndSettle();
      await _reveal(tester, find.text('Search online'));
      await tester.tap(find.text('Search online'));
      // pump, not pumpAndSettle — the progress indicator animates forever.
      await tester.pump();

      expect(find.byKey(const Key('place-search-progress')), findsOneWidget);
      expect(find.text('Searching…'), findsOneWidget);

      h.geocoder.gate!.complete();
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('place-search-progress')), findsNothing);
      expect(find.text('Lagos, Nigeria'), findsOneWidget);
    });

    testWidgets('a hit can be chosen and is remembered for offline use',
        (tester) async {
      final h = _form(result: const GeocodeHits([_lagos]));
      await tester.pumpWidget(h.widget);
      await tester.pumpAndSettle();

      await tester.enterText(_placeField, 'Lagos');
      await tester.pumpAndSettle();
      await _reveal(tester, find.text('Search online'));
      await tester.tap(find.text('Search online'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Lagos, Nigeria'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Africa/Lagos'), findsWidgets);
      expect(h.store.places.single.name, 'Lagos',
          reason: 'a place found online must survive offline');
    });

    testWidgets('nothing found raises the required snackbar', (tester) async {
      final h = _form(result: const GeocodeEmpty());
      await tester.pumpWidget(h.widget);
      await tester.pumpAndSettle();

      await tester.enterText(_placeField, 'Nowherecity');
      await tester.pumpAndSettle();
      await _reveal(tester, find.text('Search online'));
      await tester.tap(find.text('Search online'));
      await tester.pumpAndSettle();

      expect(
        find.text('Invalid location data. Please enter a valid place name.'),
        findsWidgets,
      );
    });

    testWidgets('the snackbar is localised for a Nepali reader',
        (tester) async {
      final h = _form(result: const GeocodeEmpty(), locale: 'ne');
      await tester.pumpWidget(h.widget);
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).at(1), 'Nowherecity');
      await tester.pumpAndSettle();
      await _reveal(tester, find.text('अनलाइन खोज्नुहोस्'));
      await tester.tap(find.text('अनलाइन खोज्नुहोस्'));
      await tester.pumpAndSettle();

      final snack = tester.widget<SnackBar>(find.byType(SnackBar));
      final text = ((snack.content as Text).data)!;
      expect(isDevanagari(text), isTrue, reason: text);
    });

    testWidgets('an unreachable service offers retry, and does not blame '
        'the reader', (tester) async {
      final h = _form(result: const GeocodeUnreachable('down'));
      await tester.pumpWidget(h.widget);
      await tester.pumpAndSettle();

      await tester.enterText(_placeField, 'Lagos');
      await tester.pumpAndSettle();
      await _reveal(tester, find.text('Search online'));
      await tester.tap(find.text('Search online'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Could not reach the place search'),
          findsOneWidget);
      // "Your spelling is wrong" is the wrong message when the wifi is off.
      expect(
        find.text('Invalid location data. Please enter a valid place name.'),
        findsNothing,
      );

      await _reveal(tester, find.text('Try again'));
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(h.geocoder.queries, hasLength(2));
    });

    testWidgets('the search button is disabled while a search is in flight',
        (tester) async {
      // Confirmed by review: the button did not see PlaceSearching, so every
      // impatient tap fired another request at a free service.
      final h = _form(result: const GeocodeHits([_lagos]));
      h.geocoder.gate = Completer<void>();
      await tester.pumpWidget(h.widget);
      await tester.pumpAndSettle();

      await tester.enterText(_placeField, 'Lagos');
      await tester.pumpAndSettle();
      await _reveal(tester, find.text('Search online'));
      await tester.tap(find.text('Search online'));
      await tester.pump();

      final button = tester.widget<TextButton>(
        find.ancestor(
          of: find.text('Search online'),
          matching: find.byType(TextButton),
        ),
      );
      expect(button.onPressed, isNull, reason: 'disabled while in flight');

      // And a second tap cannot get through anyway.
      await tester.tap(find.text('Search online'), warnIfMissed: false);
      await tester.pump();
      expect(h.geocoder.queries, hasLength(1));

      h.geocoder.gate!.complete();
      await tester.pumpAndSettle();
    });

    testWidgets('a response landing after the form is gone is a no-op',
        (tester) async {
      final h = _form(result: const GeocodeHits([_lagos]));
      h.geocoder.gate = Completer<void>();
      await tester.pumpWidget(h.widget);
      await tester.pumpAndSettle();

      await tester.enterText(_placeField, 'Lagos');
      await tester.pumpAndSettle();
      await _reveal(tester, find.text('Search online'));
      await tester.tap(find.text('Search online'));
      await tester.pump();

      // Tear the screen down mid-flight, then let the answer arrive.
      await tester.pumpWidget(const SizedBox());
      h.geocoder.gate!.complete();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(tester.takeException(), isNull);
    });
  });

  group('saving', () {
    testWidgets('saving with no place chosen raises the snackbar and writes '
        'nothing', (tester) async {
      final h = _form();
      await tester.pumpWidget(h.widget);
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, 'Ada');
      await tester.pumpAndSettle();
      await _reveal(tester, find.text('Save and read the chart'));
      await tester.tap(find.text('Save and read the chart'));
      await tester.pumpAndSettle();

      expect(
        find.text('Invalid location data. Please enter a valid place name.'),
        findsOneWidget,
      );
      expect(h.store.saved, isEmpty);
    });

    testWidgets('a geocoded place survives into the saved profile',
        (tester) async {
      final h = _form(result: const GeocodeHits([_lagos]));
      await tester.pumpWidget(h.widget);
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, 'Ada');
      await tester.enterText(_placeField, 'Lagos');
      await tester.pumpAndSettle();
      await _reveal(tester, find.text('Search online'));
      await tester.tap(find.text('Search online'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Lagos, Nigeria'));
      await tester.pumpAndSettle();
      await _reveal(tester, find.text('Save and read the chart'));
      await tester.tap(find.text('Save and read the chart'));
      await tester.pumpAndSettle();

      final saved = h.store.saved.single;
      expect(saved.name, 'Ada');
      expect(saved.place.timezone, 'Africa/Lagos');
      expect(saved.place.latitude, closeTo(6.5244, 0.001));
    });
  });

  group('manual coordinates', () {
    testWidgets('a valid triple can be used with no network at all',
        (tester) async {
      final h = _form();
      await tester.pumpWidget(h.widget);
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, 'Ada');
      await tester.enterText(_placeField, 'Lagos');
      await _reveal(tester, find.text('Enter coordinates instead'));
      await tester.tap(find.text('Enter coordinates instead'));
      await tester.pumpAndSettle();

      await tester.enterText(find.widgetWithText(TextField, 'Latitude'), '6.5244');
      await tester.enterText(find.widgetWithText(TextField, 'Longitude'), '3.3792');
      await tester.enterText(find.widgetWithText(TextField, 'Time zone'), 'Africa/Lagos');
      await tester.pumpAndSettle();
      await _reveal(tester, find.text('Use this place'));
      await tester.tap(find.text('Use this place'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Africa/Lagos'), findsWidgets);
      expect(h.geocoder.queries, isEmpty,
          reason: 'the offline path must never call out');
    });

    testWidgets('an unresolvable zone is refused inline', (tester) async {
      final h = _form();
      await tester.pumpWidget(h.widget);
      await tester.pumpAndSettle();

      await _reveal(tester, find.text('Enter coordinates instead'));
      await tester.tap(find.text('Enter coordinates instead'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, 'Latitude'), '1');
      await tester.enterText(find.widgetWithText(TextField, 'Longitude'), '1');
      await tester.enterText(find.widgetWithText(TextField, 'Time zone'), 'Mars/Olympus');
      await tester.pumpAndSettle();
      await _reveal(tester, find.text('Use this place'));
      await tester.tap(find.text('Use this place'));
      await tester.pumpAndSettle();

      expect(find.textContaining('must be a real IANA id'), findsOneWidget);
    });
  });
}

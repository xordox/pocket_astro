import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_astro/data/atlas.dart';
import 'package:pocket_astro/data/geocoder.dart';
import 'package:pocket_astro/data/local_store.dart';
import 'package:pocket_astro/data/place_lookup.dart';
import 'package:pocket_astro/domain/models.dart';
import 'package:pocket_astro/engine/tz_lookup.dart';
import 'package:pocket_astro/state/place_lookup_cubit.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;

/// The tiering, and the serialisation it now depends on.
///
/// `PlaceLookup` is where the offline guarantee is enforced: tiers 1 and 2 are
/// synchronous and cannot reach a socket, and tier 3 is refused for queries too
/// short to be worth a request.

class _MemStore extends LocalStore {
  List<Place> places = [];

  /// Mirrors the real store's on-load gate, which the file-backed
  /// implementation applies and this fake would otherwise skip.
  @override
  Future<List<Place>> loadRecentPlaces() async => places
      .where((p) => p.isWellFormed && isKnownZone(p.timezone))
      .toList();

  @override
  Future<void> saveRecentPlaces(List<Place> p) async => places = p;
}

class _SpyGeocoder implements Geocoder {
  _SpyGeocoder([this.result = const GeocodeEmpty()]);
  final GeocodeResult result;
  final List<String> queries = [];

  @override
  Future<GeocodeResult> search(String query, {String language = 'en'}) async {
    queries.add(query);
    return result;
  }
}

const _lagos = Place(
  name: 'Lagos',
  region: 'Nigeria',
  latitude: 6.5244,
  longitude: 3.3792,
  timezone: 'Africa/Lagos',
);

void main() {
  tzdata.initializeTimeZones();

  group('local matching', () {
    test('finds bundled cities without any geocoder involvement', () async {
      final spy = _SpyGeocoder();
      final lookup = PlaceLookup(_MemStore(), spy);
      await lookup.start();

      expect(lookup.localMatches('Kath').single.name, 'Kathmandu');
      expect(lookup.localMatches('Nepal').length, greaterThan(1));
      expect(spy.queries, isEmpty);
    });

    test('an empty query still offers somewhere to start', () async {
      final lookup = PlaceLookup(_MemStore(), _SpyGeocoder());
      await lookup.start();
      expect(lookup.localMatches(''), isNotEmpty);
    });

    test('a remembered place outranks and shadows its bundled twin', () async {
      final store = _MemStore()
        ..places = [
          const Place(
            name: 'Kathmandu',
            region: 'Nepal',
            latitude: 27.7,
            longitude: 85.3,
            timezone: 'Asia/Kathmandu',
          ),
        ];
      final lookup = PlaceLookup(store, _SpyGeocoder());
      await lookup.start();

      final hits = lookup.localMatches('Kathmandu');
      expect(hits, hasLength(1), reason: 'deduped by label');
      expect(hits.first.latitude, 27.7, reason: 'the remembered one wins');
    });

    test('never returns more than it promises', () async {
      final lookup = PlaceLookup(_MemStore(), _SpyGeocoder());
      await lookup.start();
      expect(lookup.localMatches('a').length, lessThanOrEqualTo(8));
    });
  });

  group('online tier', () {
    test('a query shorter than three characters never goes out', () async {
      final spy = _SpyGeocoder();
      final lookup = PlaceLookup(_MemStore(), spy);
      for (final q in const ['', ' ', 'a', 'ab', '  ab  ']) {
        expect(await lookup.online(q), isA<GeocodeEmpty>(), reason: '"$q"');
      }
      expect(spy.queries, isEmpty);
    });

    test('a long enough query is passed through, trimmed', () async {
      final spy = _SpyGeocoder(const GeocodeHits([_lagos]));
      final lookup = PlaceLookup(_MemStore(), spy);
      expect(await lookup.online('  Lagos '), isA<GeocodeHits>());
      expect(spy.queries, ['Lagos']);
    });
  });

  group('remembering', () {
    test('persists, most recent first, deduped and capped', () async {
      final store = _MemStore();
      final lookup = PlaceLookup(store, _SpyGeocoder());
      await lookup.remember(_lagos);
      await lookup.remember(kathmandu);
      await lookup.remember(_lagos);

      expect(store.places.first.name, 'Lagos');
      expect(store.places.where((p) => p.name == 'Lagos'), hasLength(1));

      for (var i = 0; i < 60; i++) {
        await lookup.remember(Place(
          name: 'City$i',
          region: 'Nowhere',
          latitude: 0,
          longitude: 0,
          timezone: 'UTC',
        ));
      }
      expect(store.places.length, lessThanOrEqualTo(50));
    });

    test('a remembered place is available on the next cold start', () async {
      final store = _MemStore();
      await PlaceLookup(store, _SpyGeocoder()).remember(_lagos);

      // A fresh lookup, as if the app had been restarted with no network.
      final next = PlaceLookup(store, const OfflineGeocoder());
      await next.start();
      expect(next.localMatches('Lagos').single.timezone, 'Africa/Lagos');
    });
  });

  group('PlaceLookupCubit', () {
    test('walks idle -> searching -> found', () async {
      final cubit = PlaceLookupCubit(
        PlaceLookup(_MemStore(), _SpyGeocoder(const GeocodeHits([_lagos]))),
      );
      final seen = <PlaceLookupState>[];
      final sub = cubit.stream.listen(seen.add);
      await cubit.search('Lagos');
      // Cubit emits synchronously; stream delivery is a microtask behind.
      await Future<void>.delayed(Duration.zero);
      await sub.cancel();

      expect(seen.map((e) => e.runtimeType).toList(),
          [PlaceSearching, PlaceFound]);
      expect((seen.last as PlaceFound).hits.single.name, 'Lagos');
    });

    test('an empty answer is NotFound, an unreachable one is Unreachable',
        () async {
      final notFound = PlaceLookupCubit(
        PlaceLookup(_MemStore(), _SpyGeocoder(const GeocodeEmpty())),
      );
      await notFound.search('Nowherecity');
      expect(notFound.state, isA<PlaceNotFound>());

      final down = PlaceLookupCubit(
        PlaceLookup(_MemStore(), const OfflineGeocoder()),
      );
      await down.search('Lagos');
      expect(down.state, isA<PlaceUnreachable>());
    });

    test('a stale response cannot overwrite a newer one', () async {
      final lookup = PlaceLookup(_MemStore(), _SpyGeocoder(const GeocodeEmpty()));
      final cubit = PlaceLookupCubit(lookup);
      final slow = cubit.search('first');
      cubit.reset(); // the reader left the screen
      await slow;
      expect(cubit.state, isA<PlaceIdle>(),
          reason: 'the abandoned search must not emit');
    });

    test('emitting after close is a no-op, not a crash', () async {
      final cubit = PlaceLookupCubit(
        PlaceLookup(_MemStore(), _SpyGeocoder(const GeocodeHits([_lagos]))),
      );
      final pending = cubit.search('Lagos');
      await cubit.close();
      await expectLater(pending, completes);
    });

    test('retry re-issues the query the panel is showing', () async {
      final spy = _SpyGeocoder(const GeocodeEmpty());
      final cubit = PlaceLookupCubit(PlaceLookup(_MemStore(), spy));
      await cubit.search('Nowherecity');
      await cubit.retry();
      expect(spy.queries, ['Nowherecity', 'Nowherecity']);

      // Nothing to retry from idle.
      cubit.reset();
      await cubit.retry();
      expect(spy.queries, hasLength(2));
    });
  });

  group('the stored-data gate', () {
    // Regression: making Place.fromJson tolerant meant a malformed stored row
    // survived decode, rendered in the library, and threw UnknownTimezone the
    // moment it was tapped. The gate that guards remote data guards stored
    // data too.
    test('a remembered place with an unusable zone is never offered back',
        () async {
      final store = _MemStore()
        ..places = [
          const Place(
            name: 'Ghost',
            region: 'Nowhere',
            latitude: 1,
            longitude: 1,
            timezone: 'Mars/Olympus',
          ),
          const Place(
            name: 'Zoneless',
            region: 'Nowhere',
            latitude: 1,
            longitude: 1,
            timezone: '',
          ),
          _lagos,
        ];
      final lookup = PlaceLookup(store, const OfflineGeocoder());
      await lookup.start();
      expect(lookup.recent.map((p) => p.name), ['Lagos'],
          reason: 'only the usable place survives the load');
    });
  });

  group('serialisation', () {
    // There was no round-trip test anywhere in the repo before this, and a
    // Place now arrives from outside the app.
    test('a Place survives toJson/fromJson unchanged', () {
      final back = Place.fromJson(
        jsonDecode(jsonEncode(_lagos.toJson())) as Map<String, dynamic>,
      );
      expect(back.name, _lagos.name);
      expect(back.region, _lagos.region);
      expect(back.latitude, _lagos.latitude);
      expect(back.longitude, _lagos.longitude);
      expect(back.timezone, _lagos.timezone);
    });

    test('a malformed record loses a field, not the library', () {
      // Previously an unchecked cast here threw inside LocalStore, whose
      // catch-all returned [] — so one bad row emptied every saved chart.
      expect(() => Place.fromJson(const {}), returnsNormally);
      expect(Place.fromJson(const {'name': 'X'}).isWellFormed, isTrue);
      expect(Place.fromJson(const {}).isWellFormed, isFalse);
    });

    test('isWellFormed rejects what a chart cannot use', () {
      Place at(double lat, double lon) => Place(
            name: 'X',
            region: 'Y',
            latitude: lat,
            longitude: lon,
            timezone: 'UTC',
          );
      expect(at(0, 0).isWellFormed, isTrue);
      expect(at(90, 180).isWellFormed, isTrue);
      expect(at(91, 0).isWellFormed, isFalse);
      expect(at(0, 181).isWellFormed, isFalse);
      expect(at(double.nan, 0).isWellFormed, isFalse);
    });
  });
}

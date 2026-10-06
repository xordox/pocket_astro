/// Where a birthplace comes from, in order of preference.
///
/// Three tiers, and only the third involves a network:
///
/// 1. **Places this reader has used before**, persisted by [LocalStore].
/// 2. **The bundled atlas** — about 34,000 places, always present (G-40).
/// 3. **An online geocoder**, reached only when the reader asks.
///
/// Tiers 1 and 2 are synchronous and are what `onChanged` calls, so typing
/// cannot open a socket. That is a structural property rather than a debounce
/// interval that could be tuned wrong, and it is what keeps the app usable
/// with no connectivity: a chart can always be built from a remembered place,
/// a bundled city, or coordinates entered by hand.
///
/// The bundled tier used to be twenty-five hand-picked cities, which meant a
/// reader born anywhere else had to be online once. It is now the GeoNames
/// cities-above-15,000 set, so the offline promise covers most of the world's
/// birthplaces rather than a shortlist.
library;

import 'dart:async';

import '../domain/models.dart';
import 'atlas.dart';
import 'bundled_atlas.dart';
import 'geocoder.dart';
import 'local_store.dart';

class PlaceLookup {
  PlaceLookup(this._store, this._geocoder);

  final LocalStore _store;
  final Geocoder _geocoder;

  /// Shortest query the online tier will accept. Two letters match half the
  /// world and waste a request on a free service.
  static const minOnlineChars = 3;

  static const _recentLimit = 50;
  static const _localLimit = 8;

  List<Place> _recent = const [];
  bool _loaded = false;

  /// Loads the reader's remembered places, and starts the atlas loading.
  ///
  /// The atlas is deliberately *not* awaited here. [remember] calls [start]
  /// before writing, and making a two-megabyte parse sit in front of "save
  /// this place" turned a fast operation into a slow one for no benefit — the
  /// atlas is only needed for searching, and app bootstrap awaits it properly.
  /// Until it arrives the picker degrades to the compiled-in cities, which is
  /// the behaviour it had before the atlas existed.
  Future<void> start() async {
    if (_loaded) return;
    _recent = await _store.loadRecentPlaces();
    _loaded = true;
    unawaited(warmAtlas());
  }

  /// Awaits the bundled atlas. Called from app bootstrap, where waiting is
  /// free because there is nothing on screen yet.
  Future<void> warmAtlas() async {
    try {
      await BundledAtlas.instance.load();
    } catch (_) {
      // A missing or unreadable asset costs the offline tier, not the app.
    }
  }

  /// Matches from this device only. Synchronous, and opens nothing.
  ///
  /// An empty query returns a starting set rather than nothing, preserving the
  /// behaviour the static picker had.
  List<Place> localMatches(String query) {
    final q = query.trim().toLowerCase();
    final out = <Place>[];
    final seen = <String>{};

    void add(Place p) {
      if (seen.add(p.label.toLowerCase())) out.add(p);
    }

    for (final p in _recent) {
      if (q.isEmpty || p.label.toLowerCase().contains(q)) add(p);
    }
    for (final e in BundledAtlas.instance.search(query, limit: _localLimit * 2)) {
      add(e.toPlace());
    }
    // The compiled-in list is a floor, not a duplicate: it keeps the picker
    // working in tests and in any build where the asset failed to load.
    for (final p in searchPlaces(query)) {
      add(p);
    }
    return out.take(_localLimit).toList();
  }

  /// Asks the geocoder. Short queries are refused without a request.
  Future<GeocodeResult> online(String query, {String language = 'en'}) async {
    final q = query.trim();
    if (q.length < minOnlineChars) return const GeocodeEmpty();
    return _geocoder.search(q, language: language);
  }

  /// Files a place into the reader's own atlas, most recent first.
  Future<void> remember(Place place) async {
    await start();
    final next = <Place>[place];
    for (final p in _recent) {
      if (p.label.toLowerCase() != place.label.toLowerCase()) next.add(p);
    }
    _recent = next.take(_recentLimit).toList();
    await _store.saveRecentPlaces(_recent);
  }

  /// Visible for tests and for the picker's "places on this device" section.
  List<Place> get recent => List.unmodifiable(_recent);
}

/// The bundled offline atlas.
///
/// Gap G-40, first half. The app shipped with twenty-five hardcoded cities and
/// an opt-in online lookup, which meant a chart could only be cast offline for
/// somewhere the author had happened to think of. This carries every populated
/// place above fifteen thousand people — about thirty-four thousand of them —
/// as a single asset, searched without a network.
///
/// The asset is built by `tool/build_atlas.py` from the GeoNames dump
/// (CC BY 4.0). Records are sorted by population descending, so a search that
/// stops early still returns the place the reader almost certainly meant:
/// someone typing "london" wants the one in England before the one in Ontario,
/// and both before London, Kentucky.
///
/// Two design notes worth keeping:
///
/// * **Loading is asynchronous, searching is not.** `PlaceLookup.localMatches`
///   is synchronous by design — that is what makes it structurally impossible
///   for typing to open a socket — so the atlas has to be resident before the
///   first keystroke, not fetched on demand.
/// * **Names are folded once, at load.** Diacritics and case are stripped into
///   a parallel search key so that "zurich" finds Zürich and "sao paulo" finds
///   São Paulo. Folding on every keystroke instead would be thirty-four
///   thousand string allocations per letter typed.
library;

import 'package:flutter/services.dart' show rootBundle;

import '../domain/models.dart';

class AtlasEntry {
  const AtlasEntry({
    required this.name,
    required this.region,
    required this.latitude,
    required this.longitude,
    required this.timezone,
    required this.population,
    required this.searchKey,
    required this.foldedName,
  });

  final String name;
  final String region;
  final double latitude;
  final double longitude;
  final String timezone;
  final int population;

  /// Lowercase, diacritic-free "name region", precomputed at load.
  final String searchKey;

  /// The name alone, folded. Kept separately so ranking a prefix match does
  /// not refold thirty-four thousand names on every keystroke.
  final String foldedName;

  Place toPlace() => Place(
        name: name,
        region: region,
        latitude: latitude,
        longitude: longitude,
        timezone: timezone,
      );
}

const _accentedFrom =
    'àáâãäåāăąèéêëēĕėęěìíîïĩīĭįıòóôõöøōŏőùúûüũūŭůűųçćĉċčñńņňłśŝşšžźżýÿŷđğþðæœß';
const _accentedTo =
    'aaaaaaaaaeeeeeeeeeiiiiiiiiiooooooooouuuuuuuuuucccccnnnnlsssszzzyyydgtdaos';

/// Code point to replacement, built once.
///
/// The obvious implementation — `indexOf` into a string of accented
/// characters, per character — is O(n) per letter and was measurably too slow
/// across thirty-four thousand rows at startup. A map makes it constant.
final Map<int, int> _foldMap = () {
  final m = <int, int>{};
  for (var i = 0; i < _accentedFrom.length; i++) {
    m[_accentedFrom.codeUnitAt(i)] = _accentedTo.codeUnitAt(i);
  }
  return m;
}();

const _codeA = 97; // 'a'
const _codeZ = 122;
const _code0 = 48;
const _code9 = 57;
const _codeSpace = 32;
const _codeUpperA = 65;
const _codeUpperZ = 90;

/// Folds a string for searching: lowercase, accents removed, punctuation
/// flattened to single spaces.
///
/// Deliberately small rather than pulling in a full Unicode normaliser — the
/// Latin-1 and Latin Extended-A range covers essentially every place name in
/// the dump, and a birth-place search does not need to fold Devanagari into
/// Latin.
String foldForSearch(String input) {
  final out = <int>[];
  var lastWasSpace = true;

  for (var i = 0; i < input.length; i++) {
    var c = input.codeUnitAt(i);
    if (c >= _codeUpperA && c <= _codeUpperZ) c += 32;

    final folded = _foldMap[c];
    if (folded != null) c = folded;

    final keep = (c >= _codeA && c <= _codeZ) || (c >= _code0 && c <= _code9);
    if (keep) {
      out.add(c);
      lastWasSpace = false;
    } else if (!lastWasSpace) {
      out.add(_codeSpace);
      lastWasSpace = true;
    }
  }
  while (out.isNotEmpty && out.last == _codeSpace) {
    out.removeLast();
  }
  return String.fromCharCodes(out);
}

class BundledAtlas {
  BundledAtlas._();

  static final BundledAtlas instance = BundledAtlas._();

  static const assetPath = 'assets/atlas/cities.txt';

  final List<AtlasEntry> _entries = [];

  /// First two folded characters of a name, to the rows that start with them.
  ///
  /// Turns a thirty-four-thousand-row scan into a few hundred for the common
  /// case of typing a place's actual name.
  final Map<String, List<int>> _prefixIndex = {};

  bool _loaded = false;
  Future<void>? _loading;

  bool get isLoaded => _loaded;
  int get size => _entries.length;

  /// Loads the asset. Safe to call more than once and from several places at
  /// once; concurrent callers share one load rather than parsing twice.
  Future<void> load() {
    if (_loaded) return Future<void>.value();
    return _loading ??= _doLoad();
  }

  Future<void> _doLoad() async {
    try {
      final raw = await rootBundle.loadString(assetPath);
      _parse(raw);
      _loaded = true;
    } finally {
      _loading = null;
    }
  }

  /// For tests and tooling, which read the file directly rather than through
  /// the asset bundle.
  void loadFromString(String raw) {
    if (_loaded) return;
    _parse(raw);
    _loaded = true;
  }

  void _parse(String raw) {
    final lines = raw.split('\n');
    if (lines.isEmpty) return;

    // The head of the file is the timezone table; every row then refers to it
    // by index, because three hundred ids repeat across thirty-four thousand
    // rows and storing them inline would nearly double the asset.
    final timezones = lines.first.split('\t');

    for (var i = 1; i < lines.length; i++) {
      final line = lines[i];
      if (line.isEmpty) continue;
      final f = line.split('\t');
      if (f.length < 6) continue;

      final tzIndex = int.tryParse(f[4]);
      if (tzIndex == null || tzIndex < 0 || tzIndex >= timezones.length) continue;

      final name = f[0];
      final region = f[1];
      final folded = foldForSearch(name);
      final entry = AtlasEntry(
        name: name,
        region: region,
        latitude: double.tryParse(f[2]) ?? 0,
        longitude: double.tryParse(f[3]) ?? 0,
        timezone: timezones[tzIndex],
        population: int.tryParse(f[5]) ?? 0,
        searchKey: foldForSearch('$name $region'),
        foldedName: folded,
      );

      final row = _entries.length;
      _entries.add(entry);

      if (folded.length >= 2) {
        _prefixIndex.putIfAbsent(folded.substring(0, 2), () => []).add(row);
      }
    }
  }

  /// Searches the atlas.
  ///
  /// Ranked: an exact name match first, then names that start with the query,
  /// then anything containing it. Within each band the more populous place
  /// wins, which the file's own ordering gives for free.
  List<AtlasEntry> search(String query, {int limit = 12}) {
    if (!_loaded) return const [];
    final q = foldForSearch(query);
    if (q.isEmpty) return _entries.take(limit).toList();

    final exact = <AtlasEntry>[];
    final prefix = <AtlasEntry>[];
    final contains = <AtlasEntry>[];

    void consider(AtlasEntry e) {
      final foldedName = e.foldedName;
      if (foldedName == q) {
        exact.add(e);
      } else if (foldedName.startsWith(q)) {
        prefix.add(e);
      } else if (e.searchKey.contains(q)) {
        contains.add(e);
      }
    }

    // The index only helps when the query is a name prefix; a query like
    // "maharashtra" has to fall back to the full scan, which is still only a
    // few milliseconds.
    final bucket = q.length >= 2 ? _prefixIndex[q.substring(0, 2)] : null;
    if (bucket != null) {
      for (final row in bucket) {
        consider(_entries[row]);
        if (exact.length + prefix.length >= limit) break;
      }
    }
    if (exact.length + prefix.length < limit) {
      for (final e in _entries) {
        consider(e);
        if (exact.length + prefix.length + contains.length >= limit * 3) break;
      }
    }

    final seen = <String>{};
    final out = <AtlasEntry>[];
    for (final band in [exact, prefix, contains]) {
      for (final e in band) {
        if (seen.add('${e.name}|${e.region}')) out.add(e);
        if (out.length >= limit) return out;
      }
    }
    return out;
  }

  /// The nearest bundled place to a coordinate.
  ///
  /// Used to name a chart cast from raw coordinates, and to suggest a timezone
  /// for one — a reader who types a latitude and longitude should not also
  /// have to know their IANA zone id.
  AtlasEntry? nearest(double latitude, double longitude) {
    if (!_loaded || _entries.isEmpty) return null;
    AtlasEntry? best;
    var bestDistance = double.infinity;
    for (final e in _entries) {
      // Equirectangular is ample for "which city is this" and avoids a
      // trigonometric call per row.
      final dLat = e.latitude - latitude;
      final dLon = (e.longitude - longitude) * 0.7;
      final d = dLat * dLat + dLon * dLon;
      if (d < bestDistance) {
        bestDistance = d;
        best = e;
      }
    }
    return best;
  }
}

import 'dart:convert';

import 'package:flutter/services.dart';

/// Runtime prediction knowledge compiled from the 56-PDF library.
///
/// `prediction.json` is the entry point: it carries the shortcuts the forecast
/// engine reads directly and indexes the modules below. The modules hold the
/// bulk tables — grahas, bhavas, nakshatras, yogas, doshas, dashas, gochara,
/// ashtakavarga, strength, vargas, panchanga, remedies, the judgment protocol
/// and the 360 degree symbols.
///
/// Raw ebook extracts stay in `knowledge/extract/` and are not bundled;
/// the builders that produce these assets live in `knowledge/build/`.
class PredictionKb {
  PredictionKb(this.data);

  final Map<String, dynamic> data;

  static PredictionKb current = PredictionKb(const {});

  static Map<String, dynamic> matching = {};

  static const assetPath = 'assets/kb/prediction.json';
  static const matchingAssetPath = 'assets/kb/ashtakoota.json';

  /// Module name -> asset path. Loaded lazily at startup alongside the core.
  static const moduleAssets = <String, String>{
    'planets': 'assets/kb/planets.json',
    'houses': 'assets/kb/houses.json',
    'nakshatras': 'assets/kb/nakshatras.json',
    'yogas': 'assets/kb/yogas.json',
    'doshas': 'assets/kb/doshas.json',
    'dashas': 'assets/kb/dashas.json',
    'transits': 'assets/kb/transits.json',
    'ashtakavarga': 'assets/kb/ashtakavarga.json',
    'strength': 'assets/kb/strength.json',
    'divisionals': 'assets/kb/divisionals.json',
    'panchanga': 'assets/kb/panchanga.json',
    'remedies': 'assets/kb/remedies.json',
    'interpretation': 'assets/kb/interpretation.json',
    'degrees': 'assets/kb/degrees.json',
    'learn': 'assets/kb/learn.json',
  };

  /// Decoded modules, keyed as in [moduleAssets]. Empty until loaded.
  static final Map<String, Map<String, dynamic>> modules = {};

  static Map<String, dynamic> module(String name) =>
      modules[name] ?? const <String, dynamic>{};

  int get sourceCount {
    final s = data['sources'];
    if (s is List) return s.length;
    return 0;
  }

  String get disclaimer =>
      data['disclaimer'] as String? ??
      'Interpretive astrology. Not medical, legal, or financial advice. '
          'Two techniques must agree before an event is called likely.';

  List<int> get sadeSatiHouses =>
      ((data['sade_sati_houses_from_moon'] as List?) ?? const [12, 1, 2])
          .map((e) => (e as num).toInt())
          .toList();

  int get ashtamaHouse =>
      (data['ashtama_shani_house_from_moon'] as num?)?.toInt() ?? 8;

  List<int> get saturnUpachaya =>
      ((data['saturn_upachaya_from_moon'] as List?) ?? const [3, 6, 11])
          .map((e) => (e as num).toInt())
          .toList();

  Map<String, dynamic> dashaOf(String lord) {
    final all = data['dasha'];
    if (all is Map && all[lord] is Map) {
      return Map<String, dynamic>.from(all[lord] as Map);
    }
    return const {};
  }

  String dashaFlavour(String lord) =>
      dashaOf(lord)['flavour'] as String? ?? '';

  String dashaPush(String lord) => dashaOf(lord)['push'] as String? ?? '';

  String dashaWait(String lord) => dashaOf(lord)['wait'] as String? ?? '';

  String saturnFromMoon(int house) =>
      _mapAt('gochara_saturn_from_moon', house);

  String jupiterFromMoon(int house) =>
      _mapAt('gochara_jupiter_from_moon', house);

  String marsFromLagna(int house) => _mapAt('gochara_mars_from_lagna', house);

  String rahuFromMoon(int house) => _mapAt('gochara_rahu_from_moon', house);

  String ketuFromMoon(int house) => _mapAt('gochara_ketu_from_moon', house);

  String nakshatraTone(String name) {
    final m = data['nakshatra_tone'];
    if (m is Map && m[name] is String) return m[name] as String;
    return '';
  }

  Map<String, dynamic>? eventKey(String name) {
    final m = data['event_keys'];
    if (m is Map && m[name] is Map) {
      return Map<String, dynamic>.from(m[name] as Map);
    }
    return null;
  }

  List<String> ketuForbidden() {
    final v = data['ketu_ad_forbidden'];
    if (v is List) return v.map((e) => e.toString()).toList();
    return const [
      'marriage stamp',
      'company incorporation',
      'pregnancy-as-plan',
      'leveraged speculation',
    ];
  }

  // ---- module accessors -------------------------------------------------

  /// Bhinnashtakavarga benefic-point table: subject graha -> contributor ->
  /// houses (counted from the contributor) that earn a bindu.
  Map<String, dynamic> get bhinnashtakavarga =>
      _sub('ashtakavarga', 'bhinnashtakavarga');

  /// Charak XXX house-comparison rules, each with an id and its meaning.
  List<Map<String, dynamic>> get avComparisons =>
      _list('ashtakavarga', 'house_comparisons');

  /// Bindus a transiting graha needs in a sign before it delivers (5).
  int get avTransitThreshold =>
      (module('ashtakavarga')['bhinna_transit_threshold'] as num?)?.toInt() ?? 5;

  /// The bindu count at which a transit is mixed rather than good or bad (4).
  int get avMixedAt =>
      (module('ashtakavarga')['bhinna_mixed_at'] as num?)?.toInt() ?? 4;

  /// How the classics grade a day by kakshya count, 0 to 7.
  String kakshyaDayQuality(int score) =>
      _str(_row(_sub('ashtakavarga', 'kakshya'), 'day_quality'), '$score');

  /// The two notes reconciling dignity with bindu count.
  Map<String, dynamic> get avDignityOverride =>
      _sub('ashtakavarga', 'dignity_override');

  /// Reading for a bhinnashtakavarga bindu count of 0..8.
  String bhinnaReading(int bindus) =>
      _str(_sub('ashtakavarga', 'bhinna_reading'), '$bindus');

  /// Average sarvashtakavarga bindus per sign (28 in the classical scheme).
  int get sarvaAverage =>
      (_sub('ashtakavarga', 'sarva')['average_per_sign'] as num?)?.toInt() ?? 28;

  /// Kakshya owners in order, starting at 0°00' of each sign.
  List<String> get kakshyaOrder =>
      ((_sub('ashtakavarga', 'kakshya')['order'] as List?) ?? const [])
          .map((e) => e.toString())
          .toList();

  /// Thresholds that decide whether the Moon and Mercury count as natural
  /// benefics. Read by the yoga evaluator.
  Map<String, dynamic> get beneficRules =>
      _sub('planets', 'natural_benefic_rules');

  /// Moolatrikona sign and degree range for a graha.
  Map<String, dynamic> moolatrikona(String name) =>
      _row(planet(name), 'moolatrikona');

  /// Core record for a graha: dignity, karaka, body, professions, gems,
  /// plus `in_sign` and `in_house` interpretation maps.
  Map<String, dynamic> planet(String name) =>
      _row(_sub('planets', 'planets'), name);

  String planetInSign(String planet, String sign) =>
      _str(_row(this.planet(planet), 'in_sign'), sign);

  String planetInHouse(String planet, int house) =>
      _str(_row(this.planet(planet), 'in_house'), '$house');

  /// Functional benefics, malefics, yogakaraka, marakas and badhaka for a
  /// rising sign.
  Map<String, dynamic> functionalFor(String lagnaSign) =>
      _row(_sub('planets', 'functional_by_lagna'), lagnaSign);

  /// Full signification record for a bhava.
  Map<String, dynamic> house(int n) => _row(_sub('houses', 'houses'), '$n');

  /// What it means for the lord of [owner] to sit in [field].
  String lordInHouse(int owner, int field) =>
      _str(_sub('houses', 'lord_in_house'), '$owner-$field');

  /// Full nakshatra record by zero-based index (0 = Ashwini).
  Map<String, dynamic> nakshatraAt(int index) {
    final rows = modules['nakshatras']?['nakshatras'];
    if (rows is List && index >= 0 && index < rows.length) {
      return Map<String, dynamic>.from(rows[index] as Map);
    }
    return const {};
  }

  /// Full nakshatra record by name.
  Map<String, dynamic> nakshatraNamed(String name) {
    final rows = modules['nakshatras']?['nakshatras'];
    if (rows is List) {
      for (final r in rows) {
        if (r is Map && r['name'] == name) {
          return Map<String, dynamic>.from(r);
        }
      }
    }
    return const {};
  }

  /// Every yoga definition, each with machine-checkable `conditions`.
  List<Map<String, dynamic>> get yogas => _list('yogas', 'yogas');

  /// Every dosha, each with its `cancellations` list.
  List<Map<String, dynamic>> get doshas => _list('doshas', 'doshas');

  Map<String, dynamic> dosha(String id) {
    for (final d in doshas) {
      if (d['id'] == id) return d;
    }
    return const {};
  }

  /// Mahadasha record for a graha: favourable, adverse, push, wait, body.
  Map<String, dynamic> mahadasha(String lord) =>
      _row(_sub('dashas', 'mahadasha'), lord);

  /// Reading for an antardasha lord sitting [house] houses from the MD lord.
  String antardashaByHouse(int house) =>
      _str(_sub('dashas', 'antardasha_by_house_from_md_lord'), '$house');

  /// Named note for a specific mahadasha/antardasha pair, if the classics
  /// single it out. Empty string when they do not.
  String mdAdNote(String md, String ad) =>
      _str(_row(_sub('dashas', 'md_ad_matrix'), '$md-$ad'), 'note');

  /// Gochara reading for [planet] transiting [house] from the natal Moon.
  String gocharaFromMoon(String planet, int house) =>
      _str(_row(_sub('transits', 'results_from_moon'), planet), '$house');

  /// Houses (from the Moon) in which [planet] gives its benefic transit.
  List<int> beneficTransitHouses(String planet) =>
      ((_sub('transits', 'benefic_houses_from_moon')[planet] as List?) ??
              const [])
          .map((e) => (e as num).toInt())
          .toList();

  /// Vedha pair table: benefic house -> the house that obstructs it.
  Map<int, int> vedhaPairs(String planet) {
    final all = _sub('transits', 'vedha')['pairs'];
    final out = <int, int>{};
    if (all is Map && all[planet] is Map) {
      (all[planet] as Map).forEach((k, v) {
        final a = int.tryParse(k.toString());
        final b = (v as num?)?.toInt();
        if (a != null && b != null) out[a] = b;
      });
    }
    return out;
  }

  /// Divisional chart definition (`D1`, `D9`, `D10`, ...).
  Map<String, dynamic> varga(String id) {
    final rows = modules['divisionals']?['vargas'];
    if (rows is List) {
      for (final r in rows) {
        if (r is Map && r['id'] == id) return Map<String, dynamic>.from(r);
      }
    }
    return const {};
  }

  /// Required minimum shadbala, in rupas, for a graha to deliver.
  double requiredRupas(String planet) {
    final mins = _sub('strength', 'shadbala')['required_minimum_rupas'];
    if (mins is Map && mins[planet] is num) {
      return (mins[planet] as num).toDouble();
    }
    return 6.0;
  }

  /// Combustion orb in degrees for a graha, 0 when it does not combust.
  double combustionOrb(String planet) =>
      ((_sub('strength', 'combustion')['orbs_deg'] as Map?)?[planet] as num?)
          ?.toDouble() ??
      0.0;

  /// Panchanga tithi group meaning (`nanda`, `bhadra`, `jaya`, `rikta`,
  /// `purna`).
  String tithiGroupMeaning(String group) =>
      _str(_row(_sub('panchanga', 'tithi'), 'groups'), group);

  /// Muhurta rules for a named activity (`marriage`, `travel`, ...).
  Map<String, dynamic> muhurtaFor(String activity) =>
      _row(_sub('panchanga', 'activities'), activity);

  /// Remedial record for a graha, including the practical counterpart that
  /// PocketAstro leads with.
  Map<String, dynamic> remedyFor(String planet) =>
      _row(_sub('remedies', 'grahas'), planet);

  /// PocketAstro's house-quality synthesis: weights, thresholds and bands.
  Map<String, dynamic> get houseQuality =>
      _sub('interpretation', 'house_quality');

  /// Prediction recipe for a life area (`marriage`, `career`, ...).
  Map<String, dynamic> topic(String key) {
    final rows = modules['interpretation']?['topics'];
    if (rows is List) {
      for (final r in rows) {
        if (r is Map && r['key'] == key) return Map<String, dynamic>.from(r);
      }
    }
    return const {};
  }

  List<String> get orderOfJudgment =>
      ((modules['interpretation']?['order_of_judgment'] as List?) ?? const [])
          .map((e) => e.toString())
          .toList();

  Map<String, dynamic> get confidenceModel =>
      _sub('interpretation', 'confidence_model');

  /// Tropical degree symbol for a longitude, or an empty map if unavailable.
  Map<String, dynamic> degreeSymbol(double tropicalLon) {
    final rows = modules['degrees']?['degrees'];
    final i = tropicalLon.floor() % 360;
    if (rows is List && i >= 0 && i < rows.length) {
      return Map<String, dynamic>.from(rows[i] as Map);
    }
    return const {};
  }

  // ---- module helpers ---------------------------------------------------

  Map<String, dynamic> _sub(String module, String key) {
    final m = modules[module];
    if (m != null && m[key] is Map) {
      return Map<String, dynamic>.from(m[key] as Map);
    }
    return const {};
  }

  Map<String, dynamic> _row(Map<String, dynamic> map, String key) =>
      map[key] is Map ? Map<String, dynamic>.from(map[key] as Map) : const {};

  String _str(Map<String, dynamic> map, String key) =>
      map[key] is String ? map[key] as String : '';

  List<Map<String, dynamic>> _list(String module, String key) {
    final v = modules[module]?[key];
    if (v is List) {
      return v.whereType<Map>().map(Map<String, dynamic>.from).toList();
    }
    return const [];
  }

  String _mapAt(String key, int house) {
    final m = data[key];
    if (m is Map) {
      final v = m['$house'] ?? m[house];
      if (v is String) return v;
    }
    return '';
  }

  /// The locale the loaded tables are in.
  static String locale = 'en';

  /// Loads the English knowledge base and, for any other locale, merges the
  /// overlay at `assets/kb/i18n/<locale>/<module>.json` on top of it.
  ///
  /// The overlay carries the same key paths as the base and only replaces
  /// leaf strings, so a partial translation is not a broken app: every key the
  /// overlay omits keeps its English text. That is deliberate — a visible
  /// English sentence is more useful to a reader than a blank one, and the
  /// coverage report says exactly what is outstanding.
  static Future<void> loadFromAssets({
    AssetBundle? bundle,
    String locale = 'en',
  }) async {
    final b = bundle ?? rootBundle;
    PredictionKb.locale = locale;

    Future<Map<String, dynamic>?> read(String path) async {
      try {
        final decoded = jsonDecode(await b.loadString(path));
        return decoded is Map<String, dynamic> ? decoded : null;
      } catch (_) {
        return null;
      }
    }

    Future<Map<String, dynamic>?> localized(String base, String name) async {
      final english = await read(base);
      if (english == null || locale == 'en') return english;
      final overlay = await read('assets/kb/i18n/$locale/$name');
      return overlay == null ? english : mergeOverlay(english, overlay);
    }

    final core = await localized(assetPath, 'prediction.json');
    if (core != null) current = PredictionKb(core);

    final match = await localized(matchingAssetPath, 'ashtakoota.json');
    if (match != null) matching = match;

    for (final e in moduleAssets.entries) {
      final name = e.value.split('/').last;
      final module = await localized(e.value, name);
      if (module != null) {
        modules[e.key] = module;
      }
      // A missing module degrades that feature only; the core still runs.
    }
  }

  /// Deep-merges a translation [overlay] onto [base].
  ///
  /// Only leaves present in the overlay are replaced, and only where the
  /// shapes agree. An overlay can never add a key, change a number, or alter
  /// the structure the engine reads — it translates text and nothing else.
  static Map<String, dynamic> mergeOverlay(
    Map<String, dynamic> base,
    Map<String, dynamic> overlay,
  ) {
    final out = Map<String, dynamic>.from(base);
    for (final e in overlay.entries) {
      final existing = out[e.key];
      if (existing == null) continue; // never introduce a new key
      final value = e.value;
      if (existing is Map<String, dynamic> && value is Map) {
        out[e.key] = mergeOverlay(existing, Map<String, dynamic>.from(value));
      } else if (existing is List && value is List) {
        out[e.key] = _mergeList(existing, value);
      } else if (existing is String && value is String) {
        out[e.key] = value;
      }
      // Anything else — a number, a bool, a shape mismatch — keeps the base.
    }
    return out;
  }

  static List<dynamic> _mergeList(List<dynamic> base, List<dynamic> overlay) {
    // Lists are positional. A shorter overlay translates a prefix; a longer
    // one is truncated to the base, since it cannot add entries.
    final out = List<dynamic>.from(base);
    for (var i = 0; i < base.length && i < overlay.length; i++) {
      final b = base[i], o = overlay[i];
      if (b is Map<String, dynamic> && o is Map) {
        out[i] = mergeOverlay(b, Map<String, dynamic>.from(o));
      } else if (b is String && o is String) {
        out[i] = o;
      }
    }
    return out;
  }

  static void loadModuleFromMap(String name, Map<String, dynamic> map) {
    modules[name] = map;
  }

  static void loadFromMap(Map<String, dynamic> map) {
    current = PredictionKb(map);
  }

  static void loadMatchingFromMap(Map<String, dynamic> map) {
    matching = map;
  }
}

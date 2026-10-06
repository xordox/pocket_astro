/// Evaluator for the yoga catalogue in `assets/kb/yogas.json`.
///
/// Each yoga there carries a `conditions` list written in a small declarative
/// vocabulary (documented at the top of `knowledge/build/build_yogas.py`).
/// This file interprets that vocabulary against a chart, applies the
/// cancellations the classics attach to the fragile yogas, and resolves the
/// Nabhasa precedence rules from Charak XX.
///
/// Nothing here invents a rule. Where a classical source is ambiguous the
/// choice is spelled out in a comment so it can be argued with.
library;

import 'dart:math' as math;

import '../domain/models.dart';
import 'kb.dart';
import 'nature.dart';
import 'tables.dart';

// ---------------------------------------------------------------------------
// Result types
// ---------------------------------------------------------------------------

/// One yoga found on a chart.
class YogaHit {
  const YogaHit({
    required this.id,
    required this.name,
    required this.category,
    required this.effect,
    required this.source,
    required this.weight,
    required this.detail,
    this.strength,
    this.cancellation,
    this.caution,
    this.cancelled = false,
    this.cancelledBy = const [],
    this.supersededBy,
  });

  final String id;
  final String name;
  final String category;
  final String effect;
  final String source;
  final int weight;

  /// What actually formed it on this chart — grahas, houses, degrees.
  final String detail;

  final String? strength;
  final String? cancellation;
  final String? caution;

  /// True when a classical cancellation fired. The hit is still returned so
  /// the reading can say "this looked like X, and here is why it does not
  /// stand" rather than silently dropping it.
  final bool cancelled;
  final List<String> cancelledBy;

  /// Set when a higher-precedence Nabhasa yoga displaces this one.
  final String? supersededBy;

  /// Yogas that stand are the only ones a forecast may lean on.
  bool get stands => !cancelled && supersededBy == null;

  /// One line suitable for a report.
  String get line {
    final buf = StringBuffer('$name — $detail');
    if (supersededBy != null) {
      buf.write(' Superseded by $supersededBy (Charak XX precedence).');
    } else if (cancelled) {
      buf.write(' Cancelled: ${cancelledBy.join(' ')}');
    } else {
      buf.write(' $effect');
      if (strength != null && strength!.isNotEmpty) buf.write(' $strength');
      if (caution != null && caution!.isNotEmpty) buf.write(' $caution');
    }
    return buf.toString();
  }

  @override
  String toString() => line;
}

/// Everything the evaluator found, in report order.
class YogaReport {
  const YogaReport({
    required this.hits,
    required this.skippedForNoBirthTime,
  });

  final List<YogaHit> hits;

  /// Yogas that could not be judged because the lagna is withheld.
  final int skippedForNoBirthTime;

  List<YogaHit> get standing => hits.where((h) => h.stands).toList();
  List<YogaHit> get cancelled => hits.where((h) => !h.stands).toList();
}

// ---------------------------------------------------------------------------
// Entry points
// ---------------------------------------------------------------------------

/// Evaluate every yoga in the KB against a built chart.
YogaReport yogaReport(NatalChart chart) => detectYogas(
      grahas: chart.grahas,
      lagnaSidereal: chart.lagnaSidereal,
      noLagna: chart.input.timeUnknown,
    );

/// Evaluate every yoga against raw chart parts, so this can also run inside
/// `buildChart` before a [NatalChart] exists.
YogaReport detectYogas({
  required List<GrahaRow> grahas,
  required double lagnaSidereal,
  required bool noLagna,
}) {
  final defs = PredictionKb.current.yogas;
  if (defs.isEmpty) {
    return const YogaReport(hits: [], skippedForNoBirthTime: 0);
  }
  final ctx = _Chart(grahas: grahas, lagnaSidereal: lagnaSidereal, noLagna: noLagna);

  final hits = <YogaHit>[];
  var skipped = 0;
  for (final def in defs) {
    if (noLagna && def['requires_lagna'] == true) {
      skipped++;
      continue;
    }
    final m = _match(ctx, def);
    if (m == null) continue;
    final cancels = _cancellations(ctx, def, m);
    hits.add(
      YogaHit(
        id: def['id'] as String,
        name: def['name'] as String,
        category: def['category'] as String,
        effect: def['effect'] as String? ?? '',
        source: def['source'] as String? ?? '',
        weight: (def['weight'] as num?)?.toInt() ?? 1,
        detail: m.detail,
        strength: def['strength'] as String?,
        cancellation: def['cancellation'] as String?,
        caution: def['caution'] as String?,
        cancelled: cancels.isNotEmpty,
        cancelledBy: cancels,
      ),
    );
  }

  final resolved = _applyNabhasaPrecedence(hits);
  resolved.sort((a, b) {
    if (a.stands != b.stands) return a.stands ? -1 : 1;
    return b.weight.compareTo(a.weight);
  });
  return YogaReport(hits: resolved, skippedForNoBirthTime: skipped);
}

// ---------------------------------------------------------------------------
// Chart facts the conditions are evaluated against
// ---------------------------------------------------------------------------

/// The seven classical grahas. Charak's Nabhasa, Sankhya and Aakriti yogas are
/// all defined on these; Rahu and Ketu take no part in them.
const _seven = ['Sun', 'Moon', 'Mars', 'Mercury', 'Jupiter', 'Venus', 'Saturn'];

/// The nine grahas. Uranus, Neptune and Pluto are carried for the Western
/// layer and never take part in a yoga.
const _nine = [
  'Sun', 'Moon', 'Mars', 'Mercury', 'Jupiter', 'Venus', 'Saturn', 'Rahu', 'Ketu',
];

const _kendras = [1, 4, 7, 10];

class _Chart {
  _Chart({
    required List<GrahaRow> grahas,
    required this.lagnaSidereal,
    required this.noLagna,
  }) {
    for (final g in grahas) {
      if (_nine.contains(g.name)) _rows[g.name] = g;
    }
    lagnaSign = signIndex(lagnaSidereal);
  }

  final double lagnaSidereal;
  final bool noLagna;
  late final int lagnaSign;
  final Map<String, GrahaRow> _rows = {};

  GrahaRow? row(String name) => _rows[name];

  Iterable<String> get present => _nine.where(_rows.containsKey);

  Iterable<String> get sevenPresent => _seven.where(_rows.containsKey);

  double lon(String name) => _rows[name]?.siderealLon ?? double.nan;

  int sign(String name) => signIndex(lon(name));

  /// Whole-sign house from the lagna, or 0 when the lagna is withheld.
  int house(String name) {
    if (noLagna) return 0;
    final r = _rows[name];
    return r == null ? 0 : wholeSignHouse(lagnaSign, signIndex(r.siderealLon));
  }

  /// Whole-sign house of [name] counted from [from] (`'lagna'` or a graha).
  int houseFrom(String from, String name) {
    final r = _rows[name];
    if (r == null) return 0;
    final base = from == 'lagna' ? lagnaSign : sign(from);
    if (from == 'lagna' && noLagna) return 0;
    if (from != 'lagna' && _rows[from] == null) return 0;
    return wholeSignHouse(base, signIndex(r.siderealLon));
  }

  String lordOf(int house) => signs[(lagnaSign + house - 1) % 12].ruler;

  /// Sign index owned by [house] for this lagna.
  int signOfHouse(int house) => (lagnaSign + house - 1) % 12;

  /// Natural benefic and malefic come from the shared classifier in
  /// `nature.dart`, so the yoga evaluator and the house-quality model can
  /// never disagree about what a graha is.
  late final GrahaNature _nature = GrahaNature({
    for (final e in _rows.entries) e.key: e.value.siderealLon,
  });

  bool get moonIsBenefic => _nature.moonHasPakshaBala;

  bool isBenefic(String name) => _nature.isBenefic(name);

  bool isMalefic(String name) => _nine.contains(name) && !isBenefic(name);

  List<String> get benefics => present.where(isBenefic).toList();

  List<String> get malefics => present.where(isMalefic).toList();

  /// Own sign, moolatrikona or exaltation.
  bool isDignified(String name) {
    final r = _rows[name];
    if (r == null) return false;
    if (r.dignity == 'exalted' || r.dignity == 'own sign') return true;
    return isMoolatrikona(name);
  }

  bool isMoolatrikona(String name) {
    final mt = PredictionKb.current.moolatrikona(name);
    if (mt.isEmpty) return false;
    final want = mt['sign'] as String?;
    if (want == null || signs[sign(name)].name != want) return false;
    final from = (mt['from_deg'] as num?)?.toDouble() ?? 0;
    final to = (mt['to_deg'] as num?)?.toDouble() ?? 30;
    final deg = lon(name) % 30.0;
    return deg >= from && deg < to;
  }

  bool isExalted(String name) => _rows[name]?.dignity == 'exalted';

  bool isDebilitated(String name) => _rows[name]?.dignity == 'debilitated';

  /// Combustion by the orbs in `strength.json`. The Sun is never combust and
  /// the nodes, having no body, do not combust at all.
  bool isCombust(String name) {
    if (name == 'Sun' || name == 'Rahu' || name == 'Ketu') return false;
    final sun = _rows['Sun'];
    if (sun == null || _rows[name] == null) return false;
    var orb = PredictionKb.current.combustionOrb(name);
    if (orb == 0) return false;
    // Venus and Mercury combust closer to the Sun when retrograde; the chart
    // does not carry a retrograde flag, so the direct orb is used and the
    // difference is noted rather than guessed at.
    final d = _sep(lon(name), sun.siderealLon);
    return d <= orb;
  }

  /// Graha [a] casts a Vedic aspect onto graha [b] by whole sign.
  bool aspects(String a, String b) {
    if (_rows[a] == null || _rows[b] == null) return false;
    if (a == b) return false;
    final h = wholeSignHouse(sign(a), sign(b));
    return aspectsFrom(a).contains(h);
  }

  bool mutualAspect(String a, String b) => aspects(a, b) && aspects(b, a);

  bool conjunct(String a, String b) =>
      _rows[a] != null && _rows[b] != null && sign(a) == sign(b);

  /// Charak XXI's four modes of relationship between two grahas.
  ///
  /// (i) conjunction, (ii) mutual aspect, (iii) exchange of signs,
  /// (iv) one placed in the other's sign and aspected by it.
  String? relationBetween(String a, String b) {
    if (a == b || _rows[a] == null || _rows[b] == null) return null;
    if (conjunct(a, b)) return 'conjunct in ${signs[sign(a)].name}';
    if (mutualAspect(a, b)) return 'in mutual aspect';
    if (_ownsSign(b, sign(a)) && _ownsSign(a, sign(b))) {
      return 'in exchange of signs';
    }
    if (_ownsSign(b, sign(a)) && aspects(b, a)) {
      return '$a in $b’s sign under its aspect';
    }
    if (_ownsSign(a, sign(b)) && aspects(a, b)) {
      return '$b in $a’s sign under its aspect';
    }
    return null;
  }

  bool _ownsSign(String planet, int signIdx) => signs[signIdx].ruler == planet;

  /// Grahas occupying a house counted from [from].
  List<String> occupantsFrom(String from, int house, {Set<String> skip = const {}}) {
    final out = <String>[];
    for (final name in present) {
      if (name == from || skip.contains(name)) continue;
      if (houseFrom(from, name) == house) out.add(name);
    }
    return out;
  }

  List<String> occupants(int house) => occupantsFrom('lagna', house);

  /// Distinct signs occupied by the seven classical grahas.
  Set<int> get sevenSigns => {for (final g in sevenPresent) sign(g)};

  /// Whole-sign houses occupied by the seven classical grahas.
  Set<int> get sevenHouses => {for (final g in sevenPresent) house(g)};
}

double _sep(double a, double b) {
  var d = (a - b).abs() % 360;
  if (d > 180) d = 360 - d;
  return d;
}

// ---------------------------------------------------------------------------
// Matching
// ---------------------------------------------------------------------------

class _Match {
  _Match(this.detail);
  final String detail;
}

_Match? _match(_Chart c, Map<String, dynamic> def) {
  final conditions = (def['conditions'] as List).cast<Map<String, dynamic>>();
  final any = def['match'] == 'any';
  final details = <String>[];
  for (final cond in conditions) {
    final d = _evaluate(c, cond);
    if (d == null) {
      if (!any) return null;
      continue;
    }
    details.add(d);
    if (any) return _Match(d);
  }
  if (any) return null;
  return _Match(details.where((s) => s.isNotEmpty).join(' '));
}

/// Returns a human description of how the condition was satisfied, or null.
String? _evaluate(_Chart c, Map<String, dynamic> cond) {
  final type = cond['type'] as String;
  switch (type) {
    case 'kendra_from':
      return _kendraFrom(c, cond);
    case 'house_from':
      return _houseFrom(c, cond);
    case 'dignified_in_kendra':
      return _dignifiedInKendra(c, cond);
    case 'occupied_from':
      return _occupiedFrom(c, cond);
    case 'empty_from':
      return _emptyFrom(c, cond);
    case 'lords_related':
      return _lordsRelated(c, cond);
    case 'lords_related_planets':
      return _lordsRelatedPlanets(c, cond);
    case 'lord_in_houses':
      return _lordInHouses(c, cond);
    case 'lord_dignified_in_kendra':
      return _lordDignifiedInKendra(c, cond);
    case 'lord_exalted_in_kendra_aspected_by':
      return _lordExaltedInKendraAspected(c, cond);
    case 'planet_in_houses':
    case 'planet_in_house_from_lagna':
      return _planetInHouses(c, cond);
    case 'planet_in_sign':
      return _planetInSign(c, cond);
    case 'conjunct':
      return _conjunct(c, cond);
    case 'all_in_houses':
      return _allInHouses(c, cond);
    case 'all_in_modes':
      return _allInModes(c, cond);
    case 'contiguous_houses':
      return _contiguousHouses(c, cond);
    case 'distinct_sign_count':
      return _distinctSignCount(c, cond);
    case 'benefics_in_houses':
      return _naturalsInHouses(c, cond, benefic: true);
    case 'malefics_in_houses':
      return _naturalsInHouses(c, cond, benefic: false);
    case 'benefic_in_house':
      return _beneficInHouse(c, cond);
    case 'benefics_in_kendras':
      return _naturalsInKendras(c, cond, benefic: true);
    case 'malefics_in_kendras':
      return _naturalsInKendras(c, cond, benefic: false);
    case 'benefics_not_in_kendras':
      return _naturalsNotInKendras(c, benefic: true);
    case 'malefics_not_in_kendras':
      return _naturalsNotInKendras(c, benefic: false);
    case 'benefics_malefics_split':
      return _beneficMaleficSplit(c, cond);
    case 'houses_empty_or_benefic':
      return _housesEmptyOrBenefic(c, cond);
    case 'exchange':
      return _exchange(c, cond);
    case 'exchange_between_sets':
      return _exchangeBetweenSets(c, cond);
    case 'exchange_with_trik':
      return _exchangeWithTrik(c);
    case 'neecha_bhanga':
      return _neechaBhanga(c);
    case 'node_axis_hemmed':
      return _nodeAxisHemmed(c);
    case 'maha_bhagya':
      return _mahaBhagya(c);
    case 'vargottama':
      return _vargottama(c);
    case 'stellium_with_lord':
      return _stelliumWithLord(c, cond);
    default:
      // An unknown condition never fires. Adding a new type to the KB without
      // an evaluator arm should mean "not detected", never "always true".
      return null;
  }
}

List<int> _ints(dynamic v) =>
    ((v as List?) ?? const []).map((e) => (e as num).toInt()).toList();

String _ord(int n) => switch (n) {
      1 => '1st',
      2 => '2nd',
      3 => '3rd',
      _ => '${n}th',
    };

// --- individual conditions -------------------------------------------------

String? _kendraFrom(_Chart c, Map<String, dynamic> cond) {
  final a = cond['a'] as String, b = cond['b'] as String;
  if (c.row(a) == null || c.row(b) == null) return null;
  final h = c.houseFrom(b, a);
  if (!_kendras.contains(h)) return null;
  return '$a is ${_ord(h)} from $b.';
}

String? _houseFrom(_Chart c, Map<String, dynamic> cond) {
  final a = cond['a'] as String, b = cond['b'] as String;
  if (c.row(a) == null || c.row(b) == null) return null;
  final h = c.houseFrom(b, a);
  if (!_ints(cond['houses']).contains(h)) return null;
  return '$a is ${_ord(h)} from $b.';
}

String? _dignifiedInKendra(_Chart c, Map<String, dynamic> cond) {
  final p = cond['planet'] as String;
  if (c.row(p) == null || c.noLagna) return null;
  final h = c.house(p);
  if (!_kendras.contains(h)) return null;
  if (!c.isDignified(p)) return null;
  final how = c.isExalted(p)
      ? 'exalted'
      : c.isMoolatrikona(p)
          ? 'in moolatrikona'
          : 'in its own sign';
  return '$p is $how in ${signs[c.sign(p)].name}, house $h (a kendra).';
}

String? _occupiedFrom(_Chart c, Map<String, dynamic> cond) {
  final from = cond['from'] as String;
  if (c.row(from) == null) return null;
  final skip = ((cond['exclude'] as List?) ?? const [])
      .map((e) => e.toString())
      .toSet();
  final min = (cond['min'] as num?)?.toInt() ?? 1;
  final found = <String>[];
  for (final h in _ints(cond['houses'])) {
    found.addAll(c.occupantsFrom(from, h, skip: skip));
  }
  if (found.length < min) return null;
  final houses = _ints(cond['houses']).map(_ord).join(' and ');
  return '${found.join(', ')} in the $houses from $from.';
}

String? _emptyFrom(_Chart c, Map<String, dynamic> cond) {
  final from = cond['from'] as String;
  if (c.row(from) == null) return null;
  final skip = ((cond['exclude'] as List?) ?? const [])
      .map((e) => e.toString())
      .toSet();
  for (final h in _ints(cond['houses'])) {
    if (c.occupantsFrom(from, h, skip: skip).isNotEmpty) return null;
  }
  final houses = _ints(cond['houses']).map(_ord).join(' and ');
  return 'The $houses from $from are both empty.';
}

String? _lordsRelated(_Chart c, Map<String, dynamic> cond) {
  if (c.noLagna) return null;
  final a = _ints(cond['a_houses']), b = _ints(cond['b_houses']);
  for (final ha in a) {
    for (final hb in b) {
      if (ha == hb) continue;
      final pa = c.lordOf(ha), pb = c.lordOf(hb);
      if (pa == pb) continue;
      final rel = c.relationBetween(pa, pb);
      if (rel == null) continue;
      return '${_ord(ha)} lord $pa and ${_ord(hb)} lord $pb are $rel.';
    }
  }
  return null;
}

String? _lordsRelatedPlanets(_Chart c, Map<String, dynamic> cond) {
  final a = cond['a'] as String, b = cond['b'] as String;
  final rel = c.relationBetween(a, b);
  return rel == null ? null : '$a and $b are $rel.';
}

String? _lordInHouses(_Chart c, Map<String, dynamic> cond) {
  if (c.noLagna) return null;
  final of = (cond['lord_of'] as num).toInt();
  final lord = c.lordOf(of);
  final h = c.house(lord);
  if (h == 0 || !_ints(cond['houses']).contains(h)) return null;
  return '${_ord(of)} lord $lord sits in the ${_ord(h)}.';
}

String? _lordDignifiedInKendra(_Chart c, Map<String, dynamic> cond) {
  if (c.noLagna) return null;
  final of = (cond['lord_of'] as num).toInt();
  final lord = c.lordOf(of);
  final h = c.house(lord);
  if (!_kendras.contains(h) || !c.isDignified(lord)) return null;
  return '${_ord(of)} lord $lord is dignified in ${signs[c.sign(lord)].name}, '
      'house $h (a kendra).';
}

String? _lordExaltedInKendraAspected(_Chart c, Map<String, dynamic> cond) {
  if (c.noLagna) return null;
  final of = (cond['lord_of'] as num).toInt();
  final by = cond['by'] as String;
  final lord = c.lordOf(of);
  if (!c.isExalted(lord)) return null;
  final h = c.house(lord);
  if (!_kendras.contains(h)) return null;
  if (!c.aspects(by, lord)) return null;
  return '${_ord(of)} lord $lord is exalted in house $h and aspected by $by.';
}

String? _planetInHouses(_Chart c, Map<String, dynamic> cond) {
  if (c.noLagna) return null;
  final p = cond['planet'] as String;
  final h = c.house(p);
  if (h == 0 || !_ints(cond['houses']).contains(h)) return null;
  return '$p is in the ${_ord(h)}.';
}

String? _planetInSign(_Chart c, Map<String, dynamic> cond) {
  final p = cond['planet'] as String;
  if (c.row(p) == null) return null;
  if (signs[c.sign(p)].name != cond['sign']) return null;
  return '$p is in ${cond['sign']}.';
}

String? _conjunct(_Chart c, Map<String, dynamic> cond) {
  final a = cond['a'] as String, b = cond['b'] as String;
  if (!c.conjunct(a, b)) return null;
  return '$a and $b are together in ${signs[c.sign(a)].name}.';
}

String? _allInHouses(_Chart c, Map<String, dynamic> cond) {
  if (c.noLagna) return null;
  final raw = cond['houses'];
  final occupied = c.sevenHouses;
  if (occupied.isEmpty) return null;

  if (raw is String) {
    switch (raw) {
      case 'two_adjacent_kendras':
        // Charak XX Gada: all seven in two adjacent kendras.
        const pairs = [[1, 4], [4, 7], [7, 10], [10, 1]];
        for (final p in pairs) {
          if (occupied.every(p.contains)) {
            return 'All seven grahas fall in houses ${p[0]} and ${p[1]}.';
          }
        }
        return null;
      case 'one_trinal_set_non_kendra':
        // Charak XX Hala: all seven in 2/6/10, 3/7/11 or 4/8/12.
        const sets = [[2, 6, 10], [3, 7, 11], [4, 8, 12]];
        for (final s in sets) {
          if (occupied.every(s.contains)) {
            return 'All seven grahas fall in houses ${s.join(', ')}.';
          }
        }
        return null;
      default:
        return null;
    }
  }

  final houses = _ints(raw);
  if (!occupied.every(houses.contains)) return null;
  return 'All seven grahas fall in houses ${houses.join(', ')}.';
}

const _modeNames = {'movable': 'Cardinal', 'fixed': 'Fixed', 'dual': 'Mutable'};

String? _allInModes(_Chart c, Map<String, dynamic> cond) {
  final want = ((cond['modes'] as List?) ?? const [])
      .map((e) => _modeNames[e.toString()] ?? e.toString())
      .toSet();
  final present = c.sevenPresent.toList();
  if (present.length < _seven.length) return null;
  for (final g in present) {
    if (!want.contains(signs[c.sign(g)].mode)) return null;
  }
  final label = (cond['modes'] as List).join('/');
  return 'All seven grahas occupy $label signs.';
}

String? _contiguousHouses(_Chart c, Map<String, dynamic> cond) {
  if (c.noLagna) return null;
  final span = (cond['span'] as num).toInt();
  final occupied = c.sevenHouses;
  if (occupied.isEmpty) return null;

  final starts = cond['start_any_of'] != null
      ? _ints(cond['start_any_of'])
      : [(cond['start'] as num).toInt()];

  for (final start in starts) {
    final arc = [for (var i = 0; i < span; i++) ((start - 1 + i) % 12) + 1];
    if (!occupied.every(arc.contains)) continue;
    // Charak describes the seven-house forms as planets "continuously
    // occupying" the arc, so every house in it must be tenanted. The
    // four-house forms are stated as containment only.
    if (span == 7 && !arc.every(occupied.contains)) continue;
    return 'The seven grahas fill houses ${arc.first} to ${arc.last}.';
  }
  return null;
}

String? _distinctSignCount(_Chart c, Map<String, dynamic> cond) {
  if (c.sevenPresent.length < _seven.length) return null;
  final n = (cond['n'] as num).toInt();
  final occupied = c.sevenSigns;
  if (occupied.length != n) return null;
  final names = occupied.map((s) => signs[s].name).join(', ');
  return 'The seven grahas occupy $n sign${n == 1 ? '' : 's'} ($names).';
}

String? _naturalsInHouses(_Chart c, Map<String, dynamic> cond,
    {required bool benefic}) {
  final from = cond['from'] as String? ?? 'lagna';
  if (from == 'lagna' && c.noLagna) return null;
  if (from != 'lagna' && c.row(from) == null) return null;
  final houses = _ints(cond['houses']);
  final mode = cond['mode'] as String? ?? 'all_benefics_within';
  final named = (cond['planets'] as List?)?.map((e) => e.toString()).toList();
  // The reference graha is never "in the nth house from itself".
  final pool = (named ?? (benefic ? c.benefics : c.malefics))
      .where((p) => p != from && c.row(p) != null)
      .toList();
  final label = benefic ? 'benefic' : 'malefic';

  if (mode == 'each_house_occupied') {
    final placed = <String>[];
    for (final h in houses) {
      final here =
          c.occupantsFrom(from, h).where(pool.contains).toList();
      if (here.isEmpty) return null;
      placed.add('${here.join('/')} in the ${_ord(h)}');
    }
    return 'Natural ${label}s hem the $from: ${placed.join(', ')}.';
  }

  // all_benefics_within: every natural benefic must sit inside the arc.
  if (pool.isEmpty) return null;
  final where = <String>[];
  for (final p in pool) {
    final h = c.houseFrom(from, p);
    if (!houses.contains(h)) return null;
    where.add('$p in the ${_ord(h)}');
  }
  if (cond['no_malefics'] == true) {
    for (final h in houses) {
      if (c.occupantsFrom(from, h).any(c.isMalefic)) return null;
    }
  }
  return 'All natural ${label}s sit in the ${houses.map(_ord).join(', ')} '
      'from $from (${where.join(', ')}).';
}

String? _beneficInHouse(_Chart c, Map<String, dynamic> cond) {
  final from = cond['from'] as String? ?? 'lagna';
  if (from == 'lagna' && c.noLagna) return null;
  if (from != 'lagna' && c.row(from) == null) return null;
  final h = (cond['house'] as num).toInt();
  final here = c.occupantsFrom(from, h).where(c.isBenefic).toList();
  if (here.isEmpty) return null;
  return '${here.join(', ')} in the ${_ord(h)} from $from.';
}

String? _naturalsInKendras(_Chart c, Map<String, dynamic> cond,
    {required bool benefic}) {
  if (c.noLagna) return null;
  final want = (cond['count'] as num?)?.toInt();
  final pool = benefic ? c.benefics : c.malefics;
  // Charak XX: the Moon is left out of the Dala yogas.
  final counted = pool.where((p) => p != 'Moon').toList();
  final held = <int>{};
  for (final p in counted) {
    final h = c.house(p);
    if (_kendras.contains(h)) held.add(h);
  }
  if (want == null ? held.isEmpty : held.length < want) return null;
  final label = benefic ? 'Benefics' : 'Malefics';
  final list = held.toList()..sort();
  return '$label occupy ${list.length} kendra${list.length == 1 ? '' : 's'} '
      '(houses ${list.join(', ')}).';
}

String? _naturalsNotInKendras(_Chart c, {required bool benefic}) {
  if (c.noLagna) return null;
  final pool = (benefic ? c.benefics : c.malefics).where((p) => p != 'Moon');
  for (final p in pool) {
    if (_kendras.contains(c.house(p))) return null;
  }
  return benefic
      ? 'No natural benefic occupies a kendra.'
      : 'No natural malefic occupies a kendra.';
}

String? _beneficMaleficSplit(_Chart c, Map<String, dynamic> cond) {
  if (c.noLagna) return null;
  if (cond['all_in_kendras'] == true &&
      !c.sevenHouses.every(_kendras.contains)) {
    return null;
  }
  final bHouses = _ints(cond['benefics']), mHouses = _ints(cond['malefics']);
  for (final h in bHouses) {
    final occ = c.occupants(h).where((p) => p != 'Moon');
    if (occ.isEmpty || !occ.every(c.isBenefic)) return null;
  }
  for (final h in mHouses) {
    final occ = c.occupants(h).where((p) => p != 'Moon');
    if (occ.isEmpty || !occ.every(c.isMalefic)) return null;
  }
  return 'Benefics hold houses ${bHouses.join(' and ')}; malefics hold '
      '${mHouses.join(' and ')}.';
}

String? _housesEmptyOrBenefic(_Chart c, Map<String, dynamic> cond) {
  if (c.noLagna) return null;
  for (final h in _ints(cond['houses'])) {
    if (c.occupants(h).any(c.isMalefic)) return null;
  }
  return 'Houses ${_ints(cond['houses']).join(' and ')} carry no malefic.';
}

String? _exchange(_Chart c, Map<String, dynamic> cond) {
  if (c.noLagna) return null;
  final a = (cond['a_house'] as num).toInt(), b = (cond['b_house'] as num).toInt();
  return _exchangeBetween(c, a, b);
}

String? _exchangeBetween(_Chart c, int a, int b) {
  final pa = c.lordOf(a), pb = c.lordOf(b);
  if (pa == pb) return null;
  if (c.row(pa) == null || c.row(pb) == null) return null;
  if (c.sign(pa) != c.signOfHouse(b)) return null;
  if (c.sign(pb) != c.signOfHouse(a)) return null;
  return '${_ord(a)} lord $pa and ${_ord(b)} lord $pb exchange signs.';
}

String? _exchangeBetweenSets(_Chart c, Map<String, dynamic> cond) {
  if (c.noLagna) return null;
  final houses = _ints(cond['houses']);
  for (var i = 0; i < houses.length; i++) {
    for (var j = i + 1; j < houses.length; j++) {
      final d = _exchangeBetween(c, houses[i], houses[j]);
      if (d != null) return d;
    }
  }
  return null;
}

String? _exchangeWithTrik(_Chart c) {
  if (c.noLagna) return null;
  const trik = [6, 8, 12];
  for (final t in trik) {
    for (var other = 1; other <= 12; other++) {
      if (trik.contains(other)) continue;
      final d = _exchangeBetween(c, t, other);
      if (d != null) return d;
    }
  }
  return null;
}

/// Charak XXII: six independent routes to neecha bhanga.
String? _neechaBhanga(_Chart c) {
  for (final p in c.present) {
    if (!c.isDebilitated(p)) continue;
    final debilSign = c.sign(p);
    final debilLord = signs[debilSign].ruler;
    final dg = dignity[p];
    if (dg == null) continue;
    final exaltLord = signs[dg.exaltSign].ruler;

    final reasons = <String>[];
    // Mercury is exalted in its own sign, so it can be its own exaltation
    // lord. A graha cannot cancel its own debilitation by joining itself.
    for (final lord in {debilLord, exaltLord}..remove(p)) {
      if (c.row(lord) == null) continue;
      final fromLagna = c.noLagna ? 0 : c.house(lord);
      final fromMoon = c.houseFrom('Moon', lord);
      if (_kendras.contains(fromLagna)) {
        reasons.add('$lord sits in a kendra from the lagna');
      } else if (_kendras.contains(fromMoon)) {
        reasons.add('$lord sits in a kendra from the Moon');
      }
      if (c.conjunct(lord, p)) reasons.add('$lord joins $p');
      if (c.aspects(lord, p)) reasons.add('$lord aspects $p');
    }
    // Exchange with the debilitation lord.
    if (c.row(debilLord) != null &&
        c.sign(debilLord) != debilSign &&
        signs[c.sign(debilLord)].ruler == p) {
      reasons.add('$p exchanges signs with $debilLord');
    }
    // Two debilitated grahas aspecting each other.
    for (final q in c.present) {
      if (q == p || !c.isDebilitated(q)) continue;
      if (c.mutualAspect(p, q)) {
        reasons.add('$p and the equally debilitated $q aspect each other');
      }
    }
    if (reasons.isNotEmpty) {
      return '$p is debilitated in ${signs[debilSign].name}, and the '
          'debilitation is cancelled — ${reasons.toSet().join('; ')}.';
    }
  }
  return null;
}

/// All seven classical grahas inside the arc running one way from Rahu to Ketu.
String? _nodeAxisHemmed(_Chart c) {
  final rahu = c.row('Rahu');
  if (rahu == null || c.row('Ketu') == null) return null;
  if (c.sevenPresent.length < _seven.length) return null;
  final start = c.lon('Rahu');
  var allWithin = true;
  for (final g in c.sevenPresent) {
    final d = (c.lon(g) - start) % 360;
    if (d > 180) {
      allWithin = false;
      break;
    }
  }
  if (!allWithin) {
    // Try the other half of the axis.
    allWithin = true;
    for (final g in c.sevenPresent) {
      final d = (c.lon(g) - start) % 360;
      if (d < 180) {
        allWithin = false;
        break;
      }
    }
  }
  if (!allWithin) return null;
  return 'All seven grahas lie on one side of the Rahu–Ketu axis '
      '(Rahu ${formatDms(c.lon('Rahu'))} ${signs[c.sign('Rahu')].name}).';
}

/// Charak XXII: odd lagna, Sun and Moon for a day birth; even for a night one.
String? _mahaBhagya(_Chart c) {
  if (c.noLagna) return null;
  final sun = c.row('Sun'), moon = c.row('Moon');
  if (sun == null || moon == null) return null;
  // Equal-from-ascendant houses 7 to 12 are above the horizon.
  final day = sun.westernHouse >= 7;
  bool odd(int signIdx) => signIdx % 2 == 0; // Aries is sign 1, an odd sign.
  final want = day;
  if (odd(c.lagnaSign) != want) return null;
  if (odd(c.sign('Sun')) != want) return null;
  if (odd(c.sign('Moon')) != want) return null;
  return '${day ? 'Day' : 'Night'} birth with lagna, Sun and Moon all in '
      '${want ? 'odd' : 'even'} signs.';
}

String? _vargottama(_Chart c) {
  final found = <String>[];
  if (!c.noLagna && navamsaSign(c.lagnaSidereal) == c.lagnaSign) {
    found.add('the lagna');
  }
  for (final p in c.present) {
    if (navamsaSign(c.lon(p)) == c.sign(p)) found.add(p);
  }
  if (found.isEmpty) return null;
  return '${found.join(', ')} ${found.length == 1 ? 'is' : 'are'} vargottama '
      '(same sign in D1 and D9).';
}

String? _stelliumWithLord(_Chart c, Map<String, dynamic> cond) {
  if (c.noLagna) return null;
  final min = (cond['min'] as num?)?.toInt() ?? 4;
  final of = (cond['lord_of'] as num).toInt();
  final lord = c.lordOf(of);
  final allowed = _ints(cond['houses']);
  for (final h in allowed) {
    final occ = c.occupants(h);
    if (occ.length >= min && occ.contains(lord)) {
      return '${occ.length} grahas (${occ.join(', ')}) gather in the ${_ord(h)} '
          'with the ${_ord(of)} lord $lord.';
    }
  }
  return null;
}

// ---------------------------------------------------------------------------
// Cancellations
// ---------------------------------------------------------------------------

/// Runs the checks named in a yoga's `cancellation_checks`. Returns the
/// reasons that fired; empty means the yoga stands.
List<String> _cancellations(_Chart c, Map<String, dynamic> def, _Match m) {
  final checks = ((def['cancellation_checks'] as List?) ?? const [])
      .map((e) => e.toString())
      .toList();
  if (checks.isEmpty) return const [];
  final id = def['id'] as String;
  final out = <String>[];

  for (final check in checks) {
    switch (check) {
      // --- Kemadruma: any one of these four undoes it -----------------
      case 'grahas_in_kendra_from_lagna':
        if (c.noLagna) break;
        final k = c.present
            .where((p) => p != 'Moon' && _kendras.contains(c.house(p)))
            .toList();
        if (k.isNotEmpty) {
          out.add('${k.join(', ')} occupy kendras from the lagna.');
        }
      case 'grahas_in_kendra_from_moon':
        final k = c.present
            .where((p) => p != 'Moon' && _kendras.contains(c.houseFrom('Moon', p)))
            .toList();
        if (k.isNotEmpty) {
          out.add('${k.join(', ')} occupy kendras from the Moon.');
        }
      case 'all_grahas_aspect_moon':
        final others = c.present.where((p) => p != 'Moon').toList();
        if (others.isNotEmpty && others.every((p) => c.aspects(p, 'Moon'))) {
          out.add('Every other graha aspects the Moon.');
        }
      case 'strong_moon_in_kendra_with_benefic':
        if (c.noLagna) break;
        if (!_kendras.contains(c.house('Moon'))) break;
        if (!c.isDignified('Moon') && !c.moonIsBenefic) break;
        final helpers = ['Mercury', 'Jupiter', 'Venus']
            .where((p) => c.conjunct(p, 'Moon') || c.aspects(p, 'Moon'))
            .toList();
        if (helpers.isNotEmpty) {
          out.add('A strong Moon sits in a kendra with ${helpers.join('/')}.');
        }

      // --- Gaja Kesari ------------------------------------------------
      case 'jupiter_combust':
        if (c.isCombust('Jupiter')) out.add('Jupiter is combust.');
      case 'moon_combust':
        if (c.isCombust('Moon')) out.add('The Moon is combust.');
      case 'moon_debilitated':
        if (c.isDebilitated('Moon')) out.add('The Moon is debilitated.');
      case 'jupiter_without_benefic_support':
        final support = ['Mercury', 'Venus', 'Moon']
            .where((p) =>
                c.isBenefic(p) &&
                (c.conjunct(p, 'Jupiter') || c.aspects(p, 'Jupiter')))
            .toList();
        if (support.isEmpty && !c.isDignified('Jupiter')) {
          out.add('Jupiter is neither dignified nor supported by a benefic, '
              'so the yoga gives an ordinary rather than a lasting result.');
        }

      // --- Shakata ----------------------------------------------------
      case 'jupiter_and_moon_both_strong':
        if (c.isDignified('Jupiter') && c.isDignified('Moon')) {
          out.add('Both Jupiter and the Moon are strong, which makes this '
              'yoga largely inoperative (Charak XXII, on Nehru’s chart).');
        }

      // --- Kala Sarpa -------------------------------------------------
      case 'graha_conjunct_node':
        final touching = c.sevenPresent
            .where((p) => c.conjunct(p, 'Rahu') || c.conjunct(p, 'Ketu'))
            .toList();
        if (touching.isNotEmpty) {
          out.add('${touching.join(', ')} shares a sign with a node, which '
              'breaks the enclosure.');
        }
      case 'graha_outside_axis':
        break; // handled by the match itself; a partial axis never matches.

      // --- Pancha Mahapurusha ----------------------------------------
      case 'planet_combust':
        final p = (def['conditions'] as List)
            .cast<Map<String, dynamic>>()
            .firstWhere((x) => x['type'] == 'dignified_in_kendra',
                orElse: () => const {})['planet'] as String?;
        if (p != null && c.isCombust(p)) out.add('$p is combust.');
      case 'only_malefic_aspects':
        final p = (def['conditions'] as List)
            .cast<Map<String, dynamic>>()
            .firstWhere((x) => x['type'] == 'dignified_in_kendra',
                orElse: () => const {})['planet'] as String?;
        if (p == null) break;
        final onto = c.present
            .where((q) => q != p && (c.aspects(q, p) || c.conjunct(q, p)))
            .toList();
        if (onto.isNotEmpty && onto.every(c.isMalefic)) {
          out.add('Only malefics (${onto.join(', ')}) reach $p.');
        }

      // --- Adhi / Dala ------------------------------------------------
      case 'malefic_in_adhi_houses':
        for (final h in const [6, 7, 8]) {
          final bad = c.occupantsFrom('Moon', h).where(c.isMalefic).toList();
          if (bad.isNotEmpty) {
            out.add('${bad.join(', ')} spoil the ${_ord(h)} from the Moon.');
          }
        }
      case 'malefic_in_kendra':
        if (c.noLagna) break;
        final bad = c.malefics
            .where((p) => p != 'Moon' && _kendras.contains(c.house(p)))
            .toList();
        if (bad.isNotEmpty) {
          out.add('${bad.join(', ')} occupy kendras.');
        }
      case 'benefic_in_kendra':
        if (c.noLagna) break;
        final good = c.benefics
            .where((p) => p != 'Moon' && _kendras.contains(c.house(p)))
            .toList();
        if (good.isNotEmpty) {
          out.add('${good.join(', ')} occupy kendras.');
        }

      // --- Daridra ----------------------------------------------------
      case 'no_maraka_influence':
        if (c.noLagna) break;
        final marakas = {c.lordOf(2), c.lordOf(7)};
        final lagnaLord = c.lordOf(1);
        final twelfth = c.lordOf(12);
        final touched = marakas.any((mk) =>
            c.conjunct(mk, lagnaLord) ||
            c.aspects(mk, lagnaLord) ||
            c.conjunct(mk, twelfth) ||
            c.aspects(mk, twelfth));
        if (!touched) {
          out.add('No maraka influences the lagna or 12th lord, which the '
              'classics require before this combination bites.');
        }
    }
  }

  // Kemadruma and the mahapurusha yogas are fragile by design; everything
  // else only reports the reasons without necessarily falling over.
  if (id == 'kemadruma' && out.isEmpty) {
    return const [];
  }
  return out;
}

// ---------------------------------------------------------------------------
// Nabhasa precedence (Charak XX)
// ---------------------------------------------------------------------------

/// An Aakriti or Dala yoga displaces an Aashraya yoga, and both displace a
/// Sankhya yoga. Gola is the stated exception: it survives and cancels the
/// Aashraya yoga instead.
List<YogaHit> _applyNabhasaPrecedence(List<YogaHit> hits) {
  const nabhasa = {
    'nabhasa_aakriti': 3,
    'nabhasa_dala': 3,
    'nabhasa_aashraya': 2,
    'nabhasa_sankhya': 1,
  };
  final present = hits.where((h) => nabhasa.containsKey(h.category)).toList();
  if (present.length < 2) return hits;

  final gola = present.where((h) => h.id == 'gola' && h.stands).toList();
  final best = present
      .where((h) => h.stands)
      .fold<int>(0, (a, h) => math.max(a, nabhasa[h.category]!));

  return hits.map((h) {
    final rank = nabhasa[h.category];
    if (rank == null) return h;
    if (gola.isNotEmpty && h.category == 'nabhasa_aashraya') {
      return _supersede(h, 'Gola Yoga');
    }
    if (h.id == 'gola') return h;
    if (rank < best) {
      final winner = present.firstWhere(
        (x) => x.stands && nabhasa[x.category] == best,
      );
      return _supersede(h, winner.name);
    }
    return h;
  }).toList();
}

YogaHit _supersede(YogaHit h, String by) => YogaHit(
      id: h.id,
      name: h.name,
      category: h.category,
      effect: h.effect,
      source: h.source,
      weight: h.weight,
      detail: h.detail,
      strength: h.strength,
      cancellation: h.cancellation,
      caution: h.caution,
      cancelled: h.cancelled,
      cancelledBy: h.cancelledBy,
      supersededBy: by,
    );

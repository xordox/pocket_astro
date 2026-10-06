/// The Shodashavarga — sixteen divisional charts.
///
/// Gap G-10, the largest single omission in the Vedic half of the app. What
/// existed before: `navamsaSign()` and `dashamsaSign()`, each returning a bare
/// sign index. No varga *chart* — no houses, no planets placed, nothing to
/// draw and nothing to read.
///
/// That matters because a jyotishi does not read a marriage question from the
/// rashi chart. Marriage comes from D9, children from D7, career from D10,
/// property from D4, parents from D12, spiritual life from D20, and the final
/// word on a planet's strength from D60. Sixteen charts, each with its own
/// lagna and its own house structure.
///
/// Every division rule here follows Parashara. The awkward ones — D30, which
/// is not an equal division at all, and the odd/even and movable/fixed/dual
/// reversals — are written out explicitly rather than folded into a clever
/// formula, because that is where implementations quietly go wrong.
library;

import '../domain/models.dart';
import 'tables.dart';

/// One divisional chart in the scheme.
class VargaDef {
  const VargaDef({
    required this.division,
    required this.name,
    required this.sanskrit,
    required this.signifies,
  });

  /// The D-number: 1, 2, 3, 4, 7, 9 ...
  final int division;
  final String name;
  final String sanskrit;

  /// What this varga is consulted for. Shown in the UI, because a divisional
  /// chart with no stated purpose is just a second chart.
  final String signifies;

  String get label => 'D$division';
}

const shodashavarga = <VargaDef>[
  VargaDef(division: 1, name: 'Rashi', sanskrit: 'Rashi', signifies: 'the body and the life as a whole'),
  VargaDef(division: 2, name: 'Hora', sanskrit: 'Hora', signifies: 'wealth and what sustains it'),
  VargaDef(division: 3, name: 'Drekkana', sanskrit: 'Drekkana', signifies: 'siblings, courage, initiative'),
  VargaDef(division: 4, name: 'Chaturthamsa', sanskrit: 'Chaturthamsa', signifies: 'home, property, inner fortune'),
  VargaDef(division: 7, name: 'Saptamsa', sanskrit: 'Saptamsa', signifies: 'children and lineage'),
  VargaDef(division: 9, name: 'Navamsa', sanskrit: 'Navamsa', signifies: 'marriage, dharma, the real strength of a graha'),
  VargaDef(division: 10, name: 'Dashamsa', sanskrit: 'Dashamsa', signifies: 'career and public action'),
  VargaDef(division: 12, name: 'Dwadashamsa', sanskrit: 'Dwadashamsa', signifies: 'parents and ancestry'),
  VargaDef(division: 16, name: 'Shodashamsa', sanskrit: 'Kalamsa', signifies: 'vehicles, comforts, and their loss'),
  VargaDef(division: 20, name: 'Vimshamsa', sanskrit: 'Vimshamsa', signifies: 'spiritual practice and its fruit'),
  VargaDef(division: 24, name: 'Chaturvimshamsa', sanskrit: 'Siddhamsa', signifies: 'learning and skill'),
  VargaDef(division: 27, name: 'Bhamsa', sanskrit: 'Nakshatramsa', signifies: 'strengths and weaknesses of the body'),
  VargaDef(division: 30, name: 'Trimshamsa', sanskrit: 'Trimshamsa', signifies: 'misfortune, and the character under strain'),
  VargaDef(division: 40, name: 'Khavedamsa', sanskrit: 'Khavedamsa', signifies: 'auspicious and inauspicious matrilineal legacy'),
  VargaDef(division: 45, name: 'Akshavedamsa', sanskrit: 'Akshavedamsa', signifies: 'character, patrilineal legacy'),
  VargaDef(division: 60, name: 'Shashtiamsa', sanskrit: 'Shashtiamsa', signifies: 'the final word — past-life credit and debt'),
];

VargaDef vargaDef(int division) =>
    shodashavarga.firstWhere((v) => v.division == division);

// ---------------------------------------------------------------------------
// The division rules
// ---------------------------------------------------------------------------

bool _isOddSign(int sign) => sign % 2 == 0; // Aries is the first sign
bool _isMovable(int sign) => sign % 3 == 0;
bool _isFixed(int sign) => sign % 3 == 1;

/// Which sign a longitude falls in for a given varga.
///
/// Returns 0..11. The rules are Parashara's; the comments name the trap in
/// each one.
int vargaSign(int division, double siderealLon) {
  final sign = signIndex(siderealLon);
  final within = siderealLon % 30.0;
  final odd = _isOddSign(sign);

  switch (division) {
    case 1:
      return sign;

    case 2:
      // Hora. Only two destinations exist in the whole chart: Leo and Cancer.
      // Odd signs give the Sun's hora first, even signs the Moon's.
      final firstHalf = within < 15.0;
      if (odd) return firstHalf ? 4 : 3;
      return firstHalf ? 3 : 4;

    case 3:
      // Drekkana: same sign, then the 5th, then the 9th.
      final part = (within / 10.0).floor().clamp(0, 2);
      return (sign + part * 4) % 12;

    case 4:
      // Chaturthamsa runs through the kendras.
      final part = (within / 7.5).floor().clamp(0, 3);
      return (sign + part * 3) % 12;

    case 7:
      // Saptamsa starts from the sign in odd signs and from the seventh in
      // even ones.
      final part = (within / (30.0 / 7)).floor().clamp(0, 6);
      final start = odd ? sign : (sign + 6) % 12;
      return (start + part) % 12;

    case 9:
      // Navamsa: movable from itself, fixed from the ninth, dual from the
      // fifth. Equivalently, every element starts from its own cardinal sign.
      final part = (within / (30.0 / 9)).floor().clamp(0, 8);
      final start = _isMovable(sign)
          ? sign
          : _isFixed(sign)
              ? (sign + 8) % 12
              : (sign + 4) % 12;
      return (start + part) % 12;

    case 10:
      final part = (within / 3.0).floor().clamp(0, 9);
      final start = odd ? sign : (sign + 8) % 12;
      return (start + part) % 12;

    case 12:
      final part = (within / 2.5).floor().clamp(0, 11);
      return (sign + part) % 12;

    case 16:
      final part = (within / (30.0 / 16)).floor().clamp(0, 15);
      final start = _isMovable(sign) ? 0 : (_isFixed(sign) ? 4 : 8);
      return (start + part) % 12;

    case 20:
      final part = (within / 1.5).floor().clamp(0, 19);
      final start = _isMovable(sign) ? 0 : (_isFixed(sign) ? 8 : 4);
      return (start + part) % 12;

    case 24:
      final part = (within / 1.25).floor().clamp(0, 23);
      final start = odd ? 4 : 3;
      return (start + part) % 12;

    case 27:
      // Bhamsa starts from the cardinal sign of the element.
      final part = (within / (30.0 / 27)).floor().clamp(0, 26);
      final element = signs[sign].element;
      final start = switch (element) {
        'Fire' => 0,
        'Earth' => 3,
        'Air' => 6,
        _ => 9,
      };
      return (start + part) % 12;

    case 30:
      // Trimshamsa is the exception: five unequal bands ruled by the five
      // star-planets, and the order reverses between odd and even signs. No
      // formula covers it, so the bands are written out.
      if (odd) {
        if (within < 5) return 0;    // Mars — Aries
        if (within < 10) return 10;  // Saturn — Aquarius
        if (within < 18) return 8;   // Jupiter — Sagittarius
        if (within < 25) return 2;   // Mercury — Gemini
        return 6;                    // Venus — Libra
      }
      if (within < 5) return 1;      // Venus — Taurus
      if (within < 12) return 5;     // Mercury — Virgo
      if (within < 20) return 11;    // Jupiter — Pisces
      if (within < 25) return 9;     // Saturn — Capricorn
      return 7;                      // Mars — Scorpio

    case 40:
      final part = (within / 0.75).floor().clamp(0, 39);
      return ((odd ? 0 : 6) + part) % 12;

    case 45:
      final part = (within / (30.0 / 45)).floor().clamp(0, 44);
      final start = _isMovable(sign) ? 0 : (_isFixed(sign) ? 4 : 8);
      return (start + part) % 12;

    case 60:
      final part = (within * 2).floor().clamp(0, 59);
      return (sign + part) % 12;

    default:
      throw ArgumentError('D$division is not part of the shodashavarga');
  }
}

// ---------------------------------------------------------------------------
// A varga as an actual chart
// ---------------------------------------------------------------------------

class VargaPlacement {
  const VargaPlacement({
    required this.name,
    required this.sign,
    required this.house,
    required this.dignity,
    required this.retrograde,
  });
  final String name;
  final int sign;

  /// Whole-sign house from the varga lagna.
  final int house;

  /// Dignity judged in the varga sign — which is the whole point of the
  /// exercise. A planet strong in D1 and collapsing across the vargas promises
  /// more than it pays.
  final String dignity;

  final bool retrograde;
}

class VargaChart {
  const VargaChart({
    required this.def,
    required this.lagnaSign,
    required this.placements,
  });

  final VargaDef def;
  final int lagnaSign;
  final List<VargaPlacement> placements;

  List<VargaPlacement> inHouse(int house) =>
      placements.where((p) => p.house == house).toList();

  List<VargaPlacement> inSign(int sign) =>
      placements.where((p) => p.sign == sign).toList();

  VargaPlacement? of(String name) =>
      placements.where((p) => p.name == name).firstOrNull;

  /// True when the graha holds the same sign here as in the rashi chart —
  /// vargottama, and a real strength wherever it appears.
  bool isVargottama(String name, int rashiSign) => of(name)?.sign == rashiSign;
}

const _vargaBodies = [
  'Sun', 'Moon', 'Mars', 'Mercury', 'Jupiter', 'Venus', 'Saturn', 'Rahu', 'Ketu',
];

/// Builds one divisional chart.
VargaChart buildVarga(int division, NatalChart chart) {
  final lagnaSign = chart.input.timeUnknown
      ? vargaSign(division, chart.graha('Moon').siderealLon)
      : vargaSign(division, chart.lagnaSidereal);

  final placements = <VargaPlacement>[];
  for (final name in _vargaBodies) {
    final g = chart.grahas.where((x) => x.name == name).firstOrNull;
    if (g == null) continue;
    final sign = vargaSign(division, g.siderealLon);
    placements.add(VargaPlacement(
      name: name,
      sign: sign,
      house: ((sign - lagnaSign) % 12 + 12) % 12 + 1,
      // Dignity is judged from the varga sign's midpoint, since a varga
      // placement is a sign, not a degree.
      dignity: dignityLabel(name, sign * 30.0 + 15.0),
      retrograde: g.isRetrograde,
    ));
  }

  return VargaChart(
    def: vargaDef(division),
    lagnaSign: lagnaSign,
    placements: placements,
  );
}

/// All sixteen, built once.
Map<int, VargaChart> buildAllVargas(NatalChart chart) => {
      for (final v in shodashavarga) v.division: buildVarga(v.division, chart),
    };

// ---------------------------------------------------------------------------
// Vimshopaka bala (G-11)
// ---------------------------------------------------------------------------

/// The classical varga groups and their twenty-point weightings.
class VargaGroup {
  const VargaGroup(this.name, this.weights);
  final String name;

  /// Division number to weight. Every group sums to 20.
  final Map<int, double> weights;

  List<int> get divisions => weights.keys.toList();
}

const shadvarga = VargaGroup('Shadvarga', {
  1: 6, 2: 2, 3: 4, 9: 5, 12: 2, 30: 1,
});

const saptavarga = VargaGroup('Saptavarga', {
  1: 5, 2: 2, 3: 3, 7: 2.5, 9: 4.5, 12: 2, 30: 1,
});

const dashavarga = VargaGroup('Dashavarga', {
  1: 3, 2: 1.5, 3: 1.5, 7: 1.5, 9: 1.5, 10: 1.5, 12: 1.5, 16: 1.5, 30: 1.5, 60: 5,
});

const shodashavargaGroup = VargaGroup('Shodashavarga', {
  1: 3.5, 2: 1, 3: 1, 4: 0.5, 7: 0.5, 9: 3, 10: 0.5, 12: 0.5,
  16: 2, 20: 0.5, 24: 0.5, 27: 0.5, 30: 1, 40: 0.5, 45: 0.5, 60: 4,
});

const vargaGroups = [shadvarga, saptavarga, dashavarga, shodashavargaGroup];

/// How much of its weight a placement earns, by dignity.
double _dignityFactor(String dignity) => switch (dignity) {
      'exalted' => 1.0,
      'own sign' => 0.85,
      'debilitated' => 0.0,
      _ => 0.5,
    };

class Vimshopaka {
  const Vimshopaka({
    required this.planet,
    required this.group,
    required this.score,
    required this.dignifiedIn,
    required this.positionName,
  });

  final String planet;
  final VargaGroup group;

  /// Out of twenty.
  final double score;

  /// How many of the group's vargas the planet holds dignity in.
  final int dignifiedIn;

  /// The classical name for that count — Parijatamsa through Vaiseshikamsa.
  final String positionName;

  /// A reader-facing verdict rather than a bare number.
  String get verdict {
    if (score >= 15) return 'very strong across the divisions';
    if (score >= 10) return 'holds up across the divisions';
    if (score >= 5) return 'thins out in the divisions';
    return 'promises in D1 and does not deliver below it';
  }
}

/// Names for the number of vargas a planet is dignified in.
const _dashavargaNames = [
  '', '', 'Parijatamsa', 'Uttamamsa', 'Gopuramsa', 'Simhasanamsa',
  'Parvatamsa', 'Devalokamsa', 'Brahmalokamsa', 'Shakravahanamsa', 'Shridhamamsa',
];

const _shodashavargaNames = [
  '', '', 'Bhedaka', 'Kusuma', 'Nagapushpa', 'Kanduka', 'Kerala',
  'Kalpavriksha', 'Chandanavana', 'Purnachandra', 'Uchchaisrava',
  'Dhanvantari', 'Suryakanta', 'Vidruma', 'Chakra', 'Airavata', 'Shridhama',
];

String _positionName(VargaGroup group, int count) {
  final table = group.weights.length >= 16 ? _shodashavargaNames : _dashavargaNames;
  if (count < 2 || count >= table.length) return '';
  return table[count];
}

/// Vimshopaka bala for one planet under one group.
///
/// This is how a jyotishi decides between two well-placed planets. The one
/// that keeps its dignity down through the vargas is the one whose dasha
/// actually pays.
Vimshopaka vimshopakaFor(
  String planet,
  Map<int, VargaChart> vargas,
  VargaGroup group,
) {
  var score = 0.0;
  var dignified = 0;
  for (final e in group.weights.entries) {
    final chart = vargas[e.key];
    final placement = chart?.of(planet);
    if (placement == null) continue;
    final factor = _dignityFactor(placement.dignity);
    score += e.value * factor;
    if (placement.dignity == 'exalted' || placement.dignity == 'own sign') {
      dignified++;
    }
  }
  return Vimshopaka(
    planet: planet,
    group: group,
    score: score,
    dignifiedIn: dignified,
    positionName: _positionName(group, dignified),
  );
}

List<Vimshopaka> vimshopakaTable(
  Map<int, VargaChart> vargas, {
  VargaGroup group = shodashavargaGroup,
}) =>
    [
      for (final p in const ['Sun', 'Moon', 'Mars', 'Mercury', 'Jupiter', 'Venus', 'Saturn'])
        vimshopakaFor(p, vargas, group),
    ];

/// Which grahas repeat their rashi sign in the navamsa.
///
/// Vargottama is the cheapest strong signal in the whole system, and the app
/// could not report it before the vargas existed as charts.
List<String> vargottamaIn(NatalChart chart, Map<int, VargaChart> vargas) {
  final d9 = vargas[9];
  if (d9 == null) return const [];
  final out = <String>[];
  for (final g in chart.grahas) {
    if (g.name == 'Lagna') {
      if (d9.lagnaSign == signIndex(chart.lagnaSidereal)) out.add('Lagna');
      continue;
    }
    if (d9.isVargottama(g.name, signIndex(g.siderealLon))) out.add(g.name);
  }
  return out;
}

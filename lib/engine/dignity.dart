/// Dignity, avastha, combustion and cancellation.
///
/// Three gaps land here.
///
/// **G-17 — the cancellation engine.** The old build printed "check neecha
/// bhanga before calling it weak" and then never checked it. That is the
/// difference between frightening a client and informing one: a debilitated
/// planet with neecha bhanga raja yoga is a strength, and flagging the
/// debility without the cancellation does harm.
///
/// **G-15 — the qualifiers.** Combustion, graha yuddha, and the avastha
/// systems. A combust Mercury does not deliver what an uncombust one does, and
/// a planet in mrita avastha gives nothing however well it is placed. These
/// are what stop a reading being a list of placements.
///
/// **G-32 (in part) — traditional essential dignity.** `dignityLabel` returned
/// one of three strings. Western traditional practice needs the full scored
/// table — rulership, exaltation, triplicity by sect, Egyptian bounds and
/// Chaldean faces — and the almuten that falls out of it.
library;

import '../domain/models.dart';
import 'astro/units.dart';
import 'tables.dart';

// ---------------------------------------------------------------------------
// Combustion (asta)
// ---------------------------------------------------------------------------

/// Classical combustion orbs, in degrees from the Sun.
///
/// Mercury and Venus are given tighter orbs when retrograde, which is the
/// traditional refinement and one the engine could not previously express
/// because retrogradation did not exist in it (G-01).
const Map<String, double> combustionOrb = {
  'Moon': 12,
  'Mars': 17,
  'Mercury': 14,
  'Jupiter': 11,
  'Venus': 10,
  'Saturn': 15,
};

const Map<String, double> combustionOrbRetrograde = {
  'Mercury': 12,
  'Venus': 8,
};

class Combustion {
  const Combustion({
    required this.planet,
    required this.distance,
    required this.orb,
    required this.deeplyCombust,
  });
  final String planet;
  final double distance;
  final double orb;

  /// Within one degree — cazimi in Western terms, where the tradition reverses
  /// the judgment entirely and calls the planet strengthened.
  final bool deeplyCombust;

  double get severity => (1.0 - distance / orb).clamp(0.0, 1.0);
}

/// Which grahas are burnt by the Sun.
List<Combustion> combustionsIn(List<GrahaRow> grahas) {
  final sun = grahas.where((g) => g.name == 'Sun').firstOrNull;
  if (sun == null) return const [];
  final out = <Combustion>[];
  for (final g in grahas) {
    final base = combustionOrb[g.name];
    if (base == null) continue;
    final orb = (g.isRetrograde ? combustionOrbRetrograde[g.name] : null) ?? base;
    final d = separation(g.siderealLon, sun.siderealLon);
    if (d <= orb) {
      out.add(Combustion(
        planet: g.name,
        distance: d,
        orb: orb,
        deeplyCombust: d <= 1.0,
      ));
    }
  }
  return out;
}

// ---------------------------------------------------------------------------
// Graha yuddha
// ---------------------------------------------------------------------------

class PlanetaryWar {
  const PlanetaryWar({
    required this.winner,
    required this.loser,
    required this.separationDegrees,
  });
  final String winner;
  final String loser;
  final double separationDegrees;
}

/// Planetary war: two of the five star-planets within one degree.
///
/// The winner is the one further north in ecliptic latitude — which is why
/// this could not be computed until latitude stopped being discarded (G-08).
/// The loser gives up most of its promised results for the life.
List<PlanetaryWar> planetaryWars(List<GrahaRow> grahas) {
  const combatants = ['Mars', 'Mercury', 'Jupiter', 'Venus', 'Saturn'];
  final present = grahas.where((g) => combatants.contains(g.name)).toList();
  final out = <PlanetaryWar>[];
  for (var i = 0; i < present.length; i++) {
    for (var j = i + 1; j < present.length; j++) {
      final a = present[i];
      final b = present[j];
      final d = separation(a.siderealLon, b.siderealLon);
      if (d > 1.0) continue;
      final aWins = a.latitude >= b.latitude;
      out.add(PlanetaryWar(
        winner: aWins ? a.name : b.name,
        loser: aWins ? b.name : a.name,
        separationDegrees: d,
      ));
    }
  }
  return out;
}

// ---------------------------------------------------------------------------
// Avasthas
// ---------------------------------------------------------------------------

/// Baladi avastha — the five ages, read from the degree within the sign.
///
/// The order reverses in even signs, which is the detail that makes this worth
/// computing rather than eyeballing.
({String name, double potency}) baladiAvastha(double siderealLon) {
  final sign = signIndex(siderealLon);
  final within = siderealLon % 30.0;
  final band = (within / 6.0).floor().clamp(0, 4);
  final odd = sign % 2 == 0; // Aries is the first sign and counts as odd
  final index = odd ? band : 4 - band;
  const names = ['bala', 'kumara', 'yuva', 'vriddha', 'mrita'];
  const potency = [0.25, 0.5, 1.0, 0.25, 0.0];
  return (name: names[index], potency: potency[index]);
}

const Map<String, String> baladiMeaning = {
  'bala': 'infant — a quarter of its results',
  'kumara': 'child — half its results',
  'yuva': 'youth — full strength, the best of the five',
  'vriddha': 'old — little left to give',
  'mrita': 'dead — the placement promises but does not deliver',
};

/// Jagradadi avastha — awake, dreaming, or asleep, from dignity alone.
String jagradadiAvastha(String planet, double siderealLon) {
  final label = dignityLabel(planet, siderealLon);
  if (label == 'exalted' || label == 'own sign') return 'jagrat';
  final sign = signIndex(siderealLon);
  final lord = signs[sign].ruler;
  final rel = relation(planet, lord);
  if (rel == 'friend' || rel == 'same') return 'swapna';
  return 'sushupti';
}

/// Deeptadi — the nine states, which fold dignity, combustion and war into one
/// verdict a jyotishi can act on.
String deeptadiAvastha(
  String planet,
  double siderealLon, {
  bool combust = false,
  bool lostWar = false,
  bool retrograde = false,
}) {
  final label = dignityLabel(planet, siderealLon);
  if (label == 'exalted') return 'deepta';
  if (lostWar) return 'peedita';
  if (combust) return 'vikala';
  if (label == 'debilitated') return 'khala';
  if (label == 'own sign') return 'swastha';
  if (retrograde) return 'shakta';
  final lord = signs[signIndex(siderealLon)].ruler;
  final rel = relation(planet, lord);
  if (rel == 'friend') return 'mudita';
  if (rel == 'enemy') return 'deena';
  return 'shanta';
}

const Map<String, String> deeptadiMeaning = {
  'deepta': 'blazing — exalted, gives fully',
  'swastha': 'at home — own sign, comfortable and reliable',
  'mudita': 'delighted — in a friend’s sign',
  'shanta': 'calm — neutral ground',
  'shakta': 'capable — retrograde, turned inward but strong',
  'peedita': 'afflicted — beaten in planetary war',
  'deena': 'wretched — in an enemy’s sign',
  'vikala': 'crippled — combust, burnt by the Sun',
  'khala': 'wicked — debilitated',
};

class AvasthaReport {
  const AvasthaReport({
    required this.planet,
    required this.baladi,
    required this.baladiPotency,
    required this.jagradadi,
    required this.deeptadi,
    required this.combust,
    required this.lostWar,
    required this.retrograde,
  });
  final String planet;
  final String baladi;
  final double baladiPotency;
  final String jagradadi;
  final String deeptadi;
  final bool combust;
  final bool lostWar;
  final bool retrograde;

  String get line {
    final parts = <String>[
      '$baladi (${baladiMeaning[baladi]})',
      deeptadiMeaning[deeptadi] ?? deeptadi,
    ];
    if (combust) parts.add('combust');
    if (lostWar) parts.add('lost a planetary war');
    if (retrograde) parts.add('retrograde');
    return '$planet: ${parts.join('; ')}.';
  }
}

List<AvasthaReport> avasthasFor(List<GrahaRow> grahas) {
  final combust = {for (final c in combustionsIn(grahas)) c.planet};
  final lost = {for (final w in planetaryWars(grahas)) w.loser};
  const seven = ['Sun', 'Moon', 'Mars', 'Mercury', 'Jupiter', 'Venus', 'Saturn'];
  return [
    for (final g in grahas)
      if (seven.contains(g.name))
        AvasthaReport(
          planet: g.name,
          baladi: baladiAvastha(g.siderealLon).name,
          baladiPotency: baladiAvastha(g.siderealLon).potency,
          jagradadi: jagradadiAvastha(g.name, g.siderealLon),
          deeptadi: deeptadiAvastha(
            g.name,
            g.siderealLon,
            combust: combust.contains(g.name),
            lostWar: lost.contains(g.name),
            retrograde: g.isRetrograde,
          ),
          combust: combust.contains(g.name),
          lostWar: lost.contains(g.name),
          retrograde: g.isRetrograde,
        ),
  ];
}

// ---------------------------------------------------------------------------
// Cancellation (G-17)
// ---------------------------------------------------------------------------

class Cancellation {
  const Cancellation(this.rule, this.reason);
  final String rule;
  final String reason;
}

/// Neecha bhanga — the classical cancellations of debilitation.
///
/// Any one of these is enough for most schools; several together make the
/// case strong. The rules implemented are the ones that recur across
/// Parashara, Mantreswara and Charak:
///
///   1. the lord of the sign of debilitation is in a kendra from the lagna or
///      the Moon;
///   2. the planet that would be exalted in that sign is in a kendra from the
///      lagna or the Moon;
///   3. the debilitated planet is aspected by its dispositor;
///   4. the dispositor and the debilitated planet are in mutual kendra;
///   5. the debilitated planet is exalted in the navamsa.
Cancellation? neechaBhangaFor(
  String planet,
  List<GrahaRow> grahas,
  int lagnaSign,
) {
  final row = grahas.where((g) => g.name == planet).firstOrNull;
  if (row == null) return null;
  if (dignityLabel(planet, row.siderealLon) != 'debilitated') return null;

  final moon = grahas.where((g) => g.name == 'Moon').firstOrNull;
  final debilSign = signIndex(row.siderealLon);
  final dispositorName = signs[debilSign].ruler;
  final dispositor = grahas.where((g) => g.name == dispositorName).firstOrNull;

  bool inKendraFrom(int referenceSign, GrahaRow of) {
    final d = ((signIndex(of.siderealLon) - referenceSign) % 12 + 12) % 12;
    return const {0, 3, 6, 9}.contains(d);
  }

  final reasons = <String>[];

  if (dispositor != null) {
    if (inKendraFrom(lagnaSign, dispositor)) {
      reasons.add('its dispositor $dispositorName sits in a kendra from the lagna');
    } else if (moon != null &&
        inKendraFrom(signIndex(moon.siderealLon), dispositor)) {
      reasons.add('its dispositor $dispositorName sits in a kendra from the Moon');
    }
    final d = ((signIndex(dispositor.siderealLon) - debilSign) % 12 + 12) % 12;
    if (const {0, 3, 6, 9}.contains(d)) {
      reasons.add('it and $dispositorName stand in mutual kendra');
    }
    // Aspect from the dispositor, by the Vedic rule set.
    final from = signIndex(dispositor.siderealLon);
    final to = debilSign;
    final houses = aspectsFrom(dispositorName);
    final distance = ((to - from) % 12 + 12) % 12 + 1;
    if (houses.contains(distance)) {
      reasons.add('$dispositorName aspects it from ${signs[from].name}');
    }
  }

  // The planet exalted in this sign, placed in a kendra.
  for (final e in dignityTable.entries) {
    if (e.value.exaltSign != debilSign) continue;
    final exaltedOne = grahas.where((g) => g.name == e.key).firstOrNull;
    if (exaltedOne == null) continue;
    if (inKendraFrom(lagnaSign, exaltedOne)) {
      reasons.add('${e.key}, exalted in ${signs[debilSign].name}, is in a kendra');
    }
  }

  // Exalted in the navamsa.
  final navamsa = navamsaSign(row.siderealLon);
  if (dignityTable[planet]?.exaltSign == navamsa) {
    reasons.add('it is exalted in the navamsa');
  }

  if (reasons.isEmpty) return null;
  return Cancellation(
    'neecha bhanga',
    '${reasons.join('; ')}.',
  );
}

/// Kuja dosha cancellation. The dosha is one of the most over-applied
/// judgments in practice, and the cancellations are what keep it honest.
List<Cancellation> kujaDoshaBhanga(
  List<GrahaRow> grahas,
  int lagnaSign,
) {
  final mars = grahas.where((g) => g.name == 'Mars').firstOrNull;
  if (mars == null) return const [];
  final out = <Cancellation>[];
  final marsSign = signIndex(mars.siderealLon);

  if (dignityLabel('Mars', mars.siderealLon) == 'own sign' ||
      dignityLabel('Mars', mars.siderealLon) == 'exalted') {
    out.add(const Cancellation('kuja bhanga',
        'Mars sits in its own sign or exaltation, which cancels the dosha.'));
  }
  if (marsSign == 3 || marsSign == 4) {
    out.add(const Cancellation('kuja bhanga',
        'Mars in Cancer or Leo is held by most schools to cancel the dosha.'));
  }
  final jupiter = grahas.where((g) => g.name == 'Jupiter').firstOrNull;
  if (jupiter != null) {
    final d = ((marsSign - signIndex(jupiter.siderealLon)) % 12 + 12) % 12 + 1;
    if (aspectsFrom('Jupiter').contains(d)) {
      out.add(const Cancellation('kuja bhanga',
          'Jupiter aspects Mars, which softens the dosha considerably.'));
    }
  }
  if (const {0, 7}.contains(marsSign) && marsSign == lagnaSign) {
    out.add(const Cancellation('kuja bhanga',
        'Mars is in its own sign on the lagna — strength, not affliction.'));
  }
  return out;
}

/// Kemadruma bhanga — the cancellations of the "lonely Moon" yoga.
List<Cancellation> kemadrumaBhanga(List<GrahaRow> grahas) {
  final moon = grahas.where((g) => g.name == 'Moon').firstOrNull;
  if (moon == null) return const [];
  final moonSign = signIndex(moon.siderealLon);
  final out = <Cancellation>[];

  const others = ['Mars', 'Mercury', 'Jupiter', 'Venus', 'Saturn'];
  final occupied = <int>{
    for (final g in grahas)
      if (others.contains(g.name)) signIndex(g.siderealLon),
  };

  final second = (moonSign + 1) % 12;
  final twelfth = (moonSign + 11) % 12;
  if (occupied.contains(second) || occupied.contains(twelfth)) {
    return const [Cancellation('no kemadruma',
        'A graha flanks the Moon, so kemadruma does not arise at all.')];
  }
  if (occupied.contains(moonSign)) {
    out.add(const Cancellation('kemadruma bhanga',
        'A graha shares the Moon’s sign.'));
  }
  for (final k in const [3, 6, 9]) {
    if (occupied.contains((moonSign + k) % 12)) {
      out.add(const Cancellation('kemadruma bhanga',
          'A graha stands in a kendra from the Moon.'));
      break;
    }
  }
  return out;
}

// ---------------------------------------------------------------------------
// Traditional Western dignity (G-32, part one)
// ---------------------------------------------------------------------------

/// Western exaltation degrees. Note that these are *not* the Vedic ones — the
/// Sun exalts at 19° Aries here and 10° Aries in jyotisha — which is exactly
/// the sort of quiet difference a single shared table would have buried.
const Map<String, (int, double)> westernExaltation = {
  'Sun': (0, 19),
  'Moon': (1, 3),
  'Mercury': (5, 15),
  'Venus': (11, 27),
  'Mars': (9, 28),
  'Jupiter': (3, 15),
  'Saturn': (6, 21),
};

const Map<String, List<int>> westernRulership = {
  'Sun': [4],
  'Moon': [3],
  'Mercury': [2, 5],
  'Venus': [1, 6],
  'Mars': [0, 7],
  'Jupiter': [8, 11],
  'Saturn': [9, 10],
};

/// Dorothean triplicity rulers: (day, night, participating) by element.
const Map<String, (String, String, String)> triplicityRulers = {
  'Fire': ('Sun', 'Jupiter', 'Saturn'),
  'Earth': ('Venus', 'Moon', 'Mars'),
  'Air': ('Saturn', 'Mercury', 'Jupiter'),
  'Water': ('Venus', 'Mars', 'Moon'),
};

/// Egyptian bounds: per sign, (ruler, upper degree) in ascending order.
const List<List<(String, double)>> egyptianTerms = [
  [('Jupiter', 6), ('Venus', 12), ('Mercury', 20), ('Mars', 25), ('Saturn', 30)],
  [('Venus', 8), ('Mercury', 14), ('Jupiter', 22), ('Saturn', 27), ('Mars', 30)],
  [('Mercury', 6), ('Jupiter', 12), ('Venus', 17), ('Mars', 24), ('Saturn', 30)],
  [('Mars', 7), ('Venus', 13), ('Mercury', 19), ('Jupiter', 26), ('Saturn', 30)],
  [('Jupiter', 6), ('Venus', 11), ('Saturn', 18), ('Mercury', 24), ('Mars', 30)],
  [('Mercury', 7), ('Venus', 17), ('Jupiter', 21), ('Mars', 28), ('Saturn', 30)],
  [('Saturn', 6), ('Mercury', 14), ('Jupiter', 21), ('Venus', 28), ('Mars', 30)],
  [('Mars', 7), ('Venus', 11), ('Mercury', 19), ('Jupiter', 24), ('Saturn', 30)],
  [('Jupiter', 12), ('Venus', 17), ('Mercury', 21), ('Saturn', 26), ('Mars', 30)],
  [('Mercury', 7), ('Jupiter', 14), ('Venus', 22), ('Saturn', 26), ('Mars', 30)],
  [('Mercury', 7), ('Venus', 13), ('Jupiter', 20), ('Mars', 25), ('Saturn', 30)],
  [('Venus', 12), ('Jupiter', 16), ('Mercury', 19), ('Mars', 28), ('Saturn', 30)],
];

/// Chaldean order, which the faces (decans) run through.
const chaldeanOrder = ['Mars', 'Sun', 'Venus', 'Mercury', 'Moon', 'Saturn', 'Jupiter'];

String termRuler(double tropicalLon) {
  final sign = (tropicalLon / 30).floor() % 12;
  final within = tropicalLon % 30.0;
  for (final t in egyptianTerms[sign]) {
    if (within < t.$2) return t.$1;
  }
  return egyptianTerms[sign].last.$1;
}

String faceRuler(double tropicalLon) {
  final index = (tropicalLon / 10).floor() % 36;
  // Aries 0–10 begins with Mars and the order runs on unbroken.
  return chaldeanOrder[index % 7];
}

String triplicityRuler(double tropicalLon, {required bool night}) {
  final sign = (tropicalLon / 30).floor() % 12;
  final element = signs[sign].element;
  final r = triplicityRulers[element]!;
  return night ? r.$2 : r.$1;
}

class DignityScore {
  const DignityScore({
    required this.planet,
    required this.total,
    required this.reasons,
    required this.peregrine,
  });
  final String planet;
  final int total;
  final List<String> reasons;

  /// No essential dignity anywhere — the tradition treats this as a real
  /// weakness, not a neutral state.
  final bool peregrine;
}

/// Lilly's scoring of essential dignity at a degree.
DignityScore essentialDignity(
  String planet,
  double tropicalLon, {
  required bool night,
}) {
  final sign = (tropicalLon / 30).floor() % 12;
  final reasons = <String>[];
  var total = 0;

  if (westernRulership[planet]?.contains(sign) ?? false) {
    total += 5;
    reasons.add('rules ${signs[sign].name} (+5)');
  }
  final ex = westernExaltation[planet];
  if (ex != null && ex.$1 == sign) {
    total += 4;
    reasons.add('exalted in ${signs[sign].name} (+4)');
  }
  if (triplicityRuler(tropicalLon, night: night) == planet) {
    total += 3;
    reasons.add('triplicity ruler by ${night ? 'night' : 'day'} (+3)');
  }
  if (termRuler(tropicalLon) == planet) {
    total += 2;
    reasons.add('in its own bound (+2)');
  }
  if (faceRuler(tropicalLon) == planet) {
    total += 1;
    reasons.add('in its own face (+1)');
  }

  // Detriment and fall.
  final opposite = (sign + 6) % 12;
  if (westernRulership[planet]?.contains(opposite) ?? false) {
    total -= 5;
    reasons.add('in detriment (−5)');
  }
  if (ex != null && ex.$1 == opposite) {
    total -= 4;
    reasons.add('in fall (−4)');
  }

  final peregrine = total == 0 && reasons.isEmpty;
  if (peregrine) reasons.add('peregrine — no dignity at all (−5 in practice)');

  return DignityScore(
    planet: planet,
    total: total,
    reasons: reasons,
    peregrine: peregrine,
  );
}

/// The almuten of a degree — whichever planet holds most dignity over it.
///
/// Used for the almuten figuris, the lord of a house cusp in traditional
/// practice, and for judging which planet actually governs a matter.
String almutenOf(double tropicalLon, {required bool night}) {
  var best = '';
  var bestScore = -99;
  for (final p in const ['Sun', 'Moon', 'Mercury', 'Venus', 'Mars', 'Jupiter', 'Saturn']) {
    final s = essentialDignity(p, tropicalLon, night: night).total;
    if (s > bestScore) {
      bestScore = s;
      best = p;
    }
  }
  return best;
}

/// Sect — whether a planet is in its own half of the chart.
///
/// The diurnal team is Sun, Jupiter and Saturn; the nocturnal team is Moon,
/// Venus and Mars; Mercury takes the sect of whichever side it rises with.
/// A planet of the sect in favour behaves far better than the same planet out
/// of sect, and this is the first thing traditional practice looks at.
bool inSect(String planet, {required bool nightChart}) {
  const diurnal = {'Sun', 'Jupiter', 'Saturn'};
  const nocturnal = {'Moon', 'Venus', 'Mars'};
  if (diurnal.contains(planet)) return !nightChart;
  if (nocturnal.contains(planet)) return nightChart;
  return true; // Mercury and everything else: neutral without more work
}

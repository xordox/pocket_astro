/// The KP (Krishnamurti Paddhati) system.
///
/// Gap G-19. KP is one of the largest practising communities in Indian
/// astrology and it is a distinct product surface, not a setting. It also
/// depended on three Tier 1 items that had to close first — the KP ayanamsa
/// (G-03), real Placidus cusps (G-02) and topocentric positions (G-07) —
/// which is why it could not simply be bolted on before.
///
/// What is here:
///
///   * the **sub-lord** division, where each nakshatra is split into nine
///     unequal parts in Vimshottari proportion, and the **sub-sub** below it;
///   * the **249 divisions** of the zodiac, generated from that division
///     rather than transcribed, and checked against the canonical count;
///   * **four-step significators** for every house;
///   * **cuspal sub-lords**, which in KP decide whether a house delivers at
///     all;
///   * **ruling planets** for a moment;
///   * **KP horary**, cast from a number between 1 and 249.
///
/// The system's own claim is that the sub-lord is decisive: a house whose
/// cuspal sub-lord signifies the house is a promise, and one whose sub-lord
/// signifies its negation is a denial, however good the rest of the chart
/// looks. This module computes that judgment rather than describing it.
library;

import '../domain/models.dart';
import 'astro/ayanamsa.dart';
import 'astro/ephemeris.dart';
import 'astro/houses.dart';
import 'astro/units.dart';
import 'tables.dart';

/// The settings KP is defined under.
///
/// All three together or it is not KP: the Krishnamurti ayanamsa, Placidus
/// cusps, and topocentric positions. Setting one without the others produces a
/// chart nobody in the school would recognise.
const kpSettings = ChartSettings(
  ayanamsa: Ayanamsa.krishnamurti,
  houseSystem: HouseSystem.placidus,
  vedicHouseSystem: HouseSystem.placidus,
  topocentric: true,
);

/// A sub's share of its nakshatra, in degrees.
///
/// Each of the nine lords takes the same fraction of the 13°20′ that it takes
/// of the 120-year Vimshottari cycle.
double _subSpan(String lord) =>
    nakshatraWidth * vimshottariYears[lord]! / 120.0;

/// Where a longitude sits in the KP scheme.
class KpPointer {
  const KpPointer({
    required this.longitude,
    required this.sign,
    required this.signLord,
    required this.nakshatra,
    required this.starLord,
    required this.subLord,
    required this.subSubLord,
    required this.subStart,
    required this.subEnd,
  });

  final double longitude;
  final int sign;
  final String signLord;
  final int nakshatra;

  /// The nakshatra lord — "star lord" in KP's vocabulary.
  final String starLord;

  /// The decisive one.
  final String subLord;

  final String subSubLord;
  final double subStart;
  final double subEnd;

  String get nakshatraName => nakshatras[nakshatra].name;
  String get signName => signs[sign].name;

  /// The standard KP shorthand: sign–star–sub.
  String get notation => '${signs[sign].sanskrit} · $starLord · $subLord';
}

/// Resolves a sidereal longitude into sign, star, sub and sub-sub.
KpPointer kpPointer(double siderealLon) {
  final lon = norm360(siderealLon);
  final sign = signIndex(lon);
  final nak = (lon / nakshatraWidth).floor() % 27;
  final starLord = nakshatras[nak].lord;
  final nakStart = nak * nakshatraWidth;

  var cursor = nakStart;
  var index = vimshottariOrder.indexOf(starLord);
  var subLord = starLord;
  var subStart = nakStart;
  var subEnd = nakStart;

  for (var i = 0; i < 9; i++) {
    final lord = vimshottariOrder[(index + i) % 9];
    final span = _subSpan(lord);
    if (lon < cursor + span || i == 8) {
      subLord = lord;
      subStart = cursor;
      subEnd = cursor + span;
      break;
    }
    cursor += span;
  }

  // The sub-sub divides the sub the same way, starting from the sub lord.
  final subWidth = subEnd - subStart;
  var subCursor = subStart;
  var subIndex = vimshottariOrder.indexOf(subLord);
  var subSub = subLord;
  for (var i = 0; i < 9; i++) {
    final lord = vimshottariOrder[(subIndex + i) % 9];
    final span = subWidth * vimshottariYears[lord]! / 120.0;
    if (lon < subCursor + span || i == 8) {
      subSub = lord;
      break;
    }
    subCursor += span;
  }

  return KpPointer(
    longitude: lon,
    sign: sign,
    signLord: signs[sign].ruler,
    nakshatra: nak,
    starLord: starLord,
    subLord: subLord,
    subSubLord: subSub,
    subStart: subStart,
    subEnd: subEnd,
  );
}

// ---------------------------------------------------------------------------
// The 249
// ---------------------------------------------------------------------------

class KpDivision {
  const KpDivision({
    required this.number,
    required this.start,
    required this.end,
    required this.sign,
    required this.starLord,
    required this.subLord,
  });

  /// 1 to 249 — the number a KP horary querent is asked to pick.
  final int number;
  final double start;
  final double end;
  final int sign;
  final String starLord;
  final String subLord;

  double get midpoint => (start + end) / 2;

  String get label =>
      '${signs[sign].name} · $starLord star · $subLord sub';
}

/// The 249 divisions of the zodiac.
///
/// Generated rather than transcribed: walk the sub boundaries, and split any
/// sub that straddles a sign boundary. That the result comes to exactly 249 is
/// a check on the arithmetic, not a coincidence — `test/kp_test.dart` asserts
/// it, because a table of 249 numbers copied by hand is exactly the sort of
/// thing that is wrong in one place and never noticed.
List<KpDivision> kpDivisions() {
  // Every boundary: sub boundaries plus sign boundaries.
  final boundaries = <double>{0.0};
  for (var nak = 0; nak < 27; nak++) {
    final start = nak * nakshatraWidth;
    var cursor = start;
    final index = vimshottariOrder.indexOf(nakshatras[nak].lord);
    for (var i = 0; i < 9; i++) {
      cursor += _subSpan(vimshottariOrder[(index + i) % 9]);
      boundaries.add(_round(cursor));
    }
  }
  for (var s = 1; s <= 12; s++) {
    boundaries.add(_round(s * 30.0));
  }

  final sorted = boundaries.toList()..sort();
  final out = <KpDivision>[];
  for (var i = 0; i < sorted.length - 1; i++) {
    final start = sorted[i];
    final end = sorted[i + 1];
    if (end - start < 1e-7) continue;
    final probe = kpPointer((start + end) / 2);
    out.add(KpDivision(
      number: out.length + 1,
      start: start,
      end: end,
      sign: probe.sign,
      starLord: probe.starLord,
      subLord: probe.subLord,
    ));
  }
  return out;
}

/// Rounds to a tenth of an arcsecond, so that a sign boundary landing on a sub
/// boundary is recognised as the same point rather than two points a
/// nanodegree apart.
double _round(double v) => (v * 36000).roundToDouble() / 36000;

// ---------------------------------------------------------------------------
// Significators
// ---------------------------------------------------------------------------

class Significators {
  const Significators({
    required this.house,
    required this.starOfOccupants,
    required this.occupants,
    required this.starOfLord,
    required this.lord,
  });

  final int house;

  /// Level one — the strongest. Planets standing in the star of a planet that
  /// occupies the house.
  final List<String> starOfOccupants;

  /// Level two — planets in the house.
  final List<String> occupants;

  /// Level three — planets in the star of the house lord.
  final List<String> starOfLord;

  /// Level four — the house lord itself, the weakest signification.
  final String lord;

  /// Everything, strongest first and without repeats.
  List<String> get ranked {
    final seen = <String>{};
    final out = <String>[];
    for (final group in [starOfOccupants, occupants, starOfLord, [lord]]) {
      for (final p in group) {
        if (seen.add(p)) out.add(p);
      }
    }
    return out;
  }

  bool signifies(String planet) => ranked.contains(planet);
}

/// KP's four-step significators for a house.
///
/// The ordering is the whole technique: a planet in the star of an occupant
/// outranks the house lord itself, which inverts the Parashari instinct and is
/// the first thing that surprises a jyotishi meeting KP.
Significators significatorsFor(NatalChart chart, int house) {
  if (chart.input.timeUnknown || chart.sky == null) {
    return Significators(
      house: house,
      starOfOccupants: const [],
      occupants: const [],
      starOfLord: const [],
      lord: '',
    );
  }

  final cusps = chart.sky!.vedic;
  final ayanamsa = chart.ayanamsa;
  const planets = [
    'Sun', 'Moon', 'Mars', 'Mercury', 'Jupiter', 'Venus', 'Saturn', 'Rahu', 'Ketu',
  ];

  int houseOf(double sidereal) =>
      cusps.houseOf(norm360(sidereal + ayanamsa));

  final occupants = <String>[
    for (final p in planets)
      if (_row(chart, p) != null && houseOf(_row(chart, p)!.siderealLon) == house)
        p,
  ];

  final cuspLongitude = norm360(cusps.cusps[house - 1] - ayanamsa);
  final lord = signs[signIndex(cuspLongitude)].ruler;

  final starOfOccupants = <String>[
    for (final p in planets)
      if (_row(chart, p) != null &&
          occupants.contains(kpPointer(_row(chart, p)!.siderealLon).starLord))
        p,
  ];

  final starOfLord = <String>[
    for (final p in planets)
      if (_row(chart, p) != null &&
          kpPointer(_row(chart, p)!.siderealLon).starLord == lord)
        p,
  ];

  return Significators(
    house: house,
    starOfOccupants: starOfOccupants,
    occupants: occupants,
    starOfLord: starOfLord,
    lord: lord,
  );
}

GrahaRow? _row(NatalChart chart, String name) =>
    chart.grahas.where((g) => g.name == name).firstOrNull;

// ---------------------------------------------------------------------------
// Cuspal sub-lords
// ---------------------------------------------------------------------------

class CuspalSubLord {
  const CuspalSubLord({
    required this.house,
    required this.pointer,
    required this.signifies,
    required this.verdict,
  });

  final int house;
  final KpPointer pointer;

  /// The houses the sub-lord signifies, by KP's four steps.
  final List<int> signifies;

  /// promises | denies | mixed
  final String verdict;

  String get line {
    final houses = signifies.map(ordinal).join(', ');
    return 'Cusp ${ordinal(house)}: sub-lord ${pointer.subLord}, which '
        'signifies $houses. ${switch (verdict) {
      'promises' => 'The matter is promised.',
      'denies' => 'The matter is denied — the sub-lord signifies its negation.',
      _ => 'Mixed: the sub-lord signifies both the house and what opposes it.',
    }}';
  }
}

/// The houses a planet signifies, by the four steps, across all twelve.
List<int> housesSignifiedBy(NatalChart chart, String planet) {
  final out = <int>[];
  for (var h = 1; h <= 12; h++) {
    if (significatorsFor(chart, h).signifies(planet)) out.add(h);
  }
  return out;
}

/// Which houses negate a given house, in KP's reading.
///
/// The twelfth from a house is its loss, the sixth its obstruction, the eighth
/// its interruption. A sub-lord signifying those instead of the house itself
/// denies the matter.
const kpNegations = <int, List<int>>{
  1: [6, 8, 12],
  2: [1, 7, 12],
  3: [2, 8, 9],
  4: [3, 9, 10],
  5: [4, 10, 11],
  6: [5, 11, 12],
  7: [1, 6, 12],
  8: [2, 7, 9],
  9: [3, 8, 10],
  10: [4, 9, 11],
  11: [5, 10, 12],
  12: [6, 11, 1],
};

/// The cuspal sub-lord judgment for every house.
List<CuspalSubLord> cuspalSubLords(NatalChart chart) {
  if (chart.input.timeUnknown || chart.sky == null) return const [];
  final cusps = chart.sky!.vedic;
  final out = <CuspalSubLord>[];

  for (var h = 1; h <= 12; h++) {
    final sidereal = norm360(cusps.cusps[h - 1] - chart.ayanamsa);
    final pointer = kpPointer(sidereal);
    final signified = housesSignifiedBy(chart, pointer.subLord);
    final negations = kpNegations[h] ?? const [];

    final supports = signified.contains(h);
    final denies = signified.any(negations.contains);
    out.add(CuspalSubLord(
      house: h,
      pointer: pointer,
      signifies: signified,
      verdict: supports && !denies
          ? 'promises'
          : (!supports && denies ? 'denies' : 'mixed'),
    ));
  }
  return out;
}

// ---------------------------------------------------------------------------
// Ruling planets
// ---------------------------------------------------------------------------

class RulingPlanets {
  const RulingPlanets({
    required this.at,
    required this.dayLord,
    required this.moon,
    required this.ascendant,
    required this.ordered,
  });

  final DateTime at;
  final String dayLord;
  final KpPointer moon;
  final KpPointer ascendant;

  /// Strongest first: ascendant sub, ascendant star, ascendant sign, Moon sub,
  /// Moon star, Moon sign, then the day lord.
  final List<String> ordered;
}

/// The ruling planets for a moment and a place.
///
/// KP uses them as a shortlist: whatever is going to happen is signified by
/// something on this list, so a judgment that involves none of them is
/// probably wrong.
RulingPlanets rulingPlanets({
  required DateTime utc,
  required double latitude,
  required double longitudeEast,
  ChartSettings settings = kpSettings,
}) {
  final sky = computeSky(
    utc: utc,
    latitude: latitude,
    longitudeEast: longitudeEast,
    settings: settings,
    bodyNames: const ['Sun', 'Moon'],
  );

  final moon = kpPointer(sky.sidereal('Moon'));
  final asc = kpPointer(sky.siderealAscendant);

  const weekdayLords = [
    'Moon', 'Mars', 'Mercury', 'Jupiter', 'Venus', 'Saturn', 'Sun',
  ];
  final dayLord = weekdayLords[utc.toLocal().weekday - 1];

  final ordered = <String>[];
  for (final p in [
    asc.subLord, asc.starLord, asc.signLord,
    moon.subLord, moon.starLord, moon.signLord,
    dayLord,
  ]) {
    if (!ordered.contains(p)) ordered.add(p);
  }

  return RulingPlanets(
    at: utc,
    dayLord: dayLord,
    moon: moon,
    ascendant: asc,
    ordered: ordered,
  );
}

// ---------------------------------------------------------------------------
// Horary
// ---------------------------------------------------------------------------

class KpHorary {
  const KpHorary({
    required this.number,
    required this.division,
    required this.asked,
    required this.chart,
    required this.ruling,
    required this.cuspalSubLords,
  });

  final int number;
  final KpDivision division;
  final DateTime asked;

  /// The chart, with the ascendant placed at the division the number names
  /// rather than at the degree actually rising.
  final NatalChart chart;

  final RulingPlanets ruling;
  final List<CuspalSubLord> cuspalSubLords;

  CuspalSubLord? forHouse(int house) =>
      cuspalSubLords.where((c) => c.house == house).firstOrNull;
}

/// The ascendant a KP horary number names.
///
/// The querent picks a number between 1 and 249; that number selects one of
/// the zodiac's divisions, and the horary chart's ascendant is placed at its
/// midpoint. Everything else is cast for the moment the question was asked.
double horaryAscendantFor(int number) {
  final divisions = kpDivisions();
  final index = (number - 1).clamp(0, divisions.length - 1);
  return divisions[index].midpoint;
}

/// A description of what a number selects, for the input screen.
KpDivision horaryDivisionFor(int number) {
  final divisions = kpDivisions();
  return divisions[(number - 1).clamp(0, divisions.length - 1)];
}

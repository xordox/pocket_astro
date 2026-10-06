/// Jaimini astrology.
///
/// Gap G-14, which was not a missing feature so much as a missing school. For
/// a large part of the professional community Jaimini is the primary system,
/// and the Atmakaraka and the Arudha Lagna are where a reading starts.
///
/// Implemented here:
///
///   * **Chara karakas** in both the seven- and eight-karaka schemes, with the
///     reverse reckoning that Rahu requires;
///   * **Arudha padas** for all twelve houses, plus the Upapada, with the
///     classical exceptions that keep a pada from collapsing onto its own
///     house;
///   * **Karakamsa** and **Swamsa**;
///   * **Rashi drishti** — sign aspects, which behave nothing like graha
///     aspects and are what make a Jaimini reading look wrong to a Parashari
///     eye until the rule is stated;
///   * **Argala** and its obstruction, virodha argala;
///   * **Chara dasha**, with the odd- and even-footed direction rule and the
///     variable period lengths that follow from each sign's lord.
library;

import '../domain/models.dart';
import 'tables.dart';

// ---------------------------------------------------------------------------
// Chara karakas
// ---------------------------------------------------------------------------

/// The seven-karaka scheme, in descending order of degrees.
const charaKarakaNames7 = [
  'Atmakaraka',
  'Amatyakaraka',
  'Bhratrikaraka',
  'Matrikaraka',
  'Putrakaraka',
  'Gnatikaraka',
  'Darakaraka',
];

/// The eight-karaka scheme inserts Pitrikaraka and admits Rahu.
const charaKarakaNames8 = [
  'Atmakaraka',
  'Amatyakaraka',
  'Bhratrikaraka',
  'Matrikaraka',
  'Pitrikaraka',
  'Putrakaraka',
  'Gnatikaraka',
  'Darakaraka',
];

const Map<String, String> charaKarakaMeaning = {
  'Atmakaraka': 'the soul — what the life is actually about',
  'Amatyakaraka': 'the counsellor — career and the people who advise',
  'Bhratrikaraka': 'siblings, courage, the guru',
  'Matrikaraka': 'mother, and what nourishes',
  'Pitrikaraka': 'father',
  'Putrakaraka': 'children and creative issue',
  'Gnatikaraka': 'rivals, obstacles, and the body’s troubles',
  'Darakaraka': 'the spouse',
};

class CharaKaraka {
  const CharaKaraka({
    required this.role,
    required this.planet,
    required this.degrees,
  });
  final String role;
  final String planet;

  /// Degrees within the sign — what the ranking is done on.
  final double degrees;

  String get meaning => charaKarakaMeaning[role] ?? '';
}

/// Ranks the grahas by degrees within their sign.
///
/// Rahu is reckoned backwards — 30° minus its degrees — because it moves in
/// reverse, and a scheme that forgot this would rank it almost exactly wrong.
List<CharaKaraka> charaKarakas(NatalChart chart, {bool eightKaraka = false}) {
  const seven = ['Sun', 'Moon', 'Mars', 'Mercury', 'Jupiter', 'Venus', 'Saturn'];
  final pool = <(String, double)>[];
  for (final name in seven) {
    final g = chart.grahas.where((x) => x.name == name).firstOrNull;
    if (g == null) continue;
    pool.add((name, g.siderealLon % 30.0));
  }
  if (eightKaraka) {
    final rahu = chart.grahas.where((x) => x.name == 'Rahu').firstOrNull;
    if (rahu != null) pool.add(('Rahu', 30.0 - (rahu.siderealLon % 30.0)));
  }

  pool.sort((a, b) => b.$2.compareTo(a.$2));
  final names = eightKaraka ? charaKarakaNames8 : charaKarakaNames7;
  return [
    for (var i = 0; i < pool.length && i < names.length; i++)
      CharaKaraka(role: names[i], planet: pool[i].$1, degrees: pool[i].$2),
  ];
}

String? atmakarakaOf(NatalChart chart) =>
    charaKarakas(chart).where((k) => k.role == 'Atmakaraka').firstOrNull?.planet;

/// Karakamsa — the navamsa sign of the Atmakaraka, read as a lagna.
///
/// The classical instruction is to read the whole chart from it: what sits in
/// and aspects the karakamsa describes the soul's own agenda, which is the
/// question Jaimini is usually asked.
int? karakamsaSign(NatalChart chart) {
  final ak = atmakarakaOf(chart);
  if (ak == null) return null;
  final g = chart.grahas.where((x) => x.name == ak).firstOrNull;
  if (g == null) return null;
  return navamsaSign(g.siderealLon);
}

/// Swamsa — the navamsa of the lagna itself.
int? swamsaSign(NatalChart chart) =>
    chart.input.timeUnknown ? null : navamsaSign(chart.lagnaSidereal);

// ---------------------------------------------------------------------------
// Arudha padas
// ---------------------------------------------------------------------------

class ArudhaPada {
  const ArudhaPada({
    required this.house,
    required this.label,
    required this.sign,
    required this.lord,
    required this.signifies,
  });
  final int house;

  /// AL, A2, A3 … UL.
  final String label;
  final int sign;
  final String lord;
  final String signifies;
}

const Map<int, String> _arudhaMeaning = {
  1: 'how the person is seen, as distinct from who they are',
  2: 'the visible shape of their wealth',
  3: 'how their effort and courage appear to others',
  4: 'the home as others perceive it',
  5: 'reputation through children, students and creative work',
  6: 'visible enemies, debts and service',
  7: 'the partnership as the world sees it',
  8: 'the public face of crisis and inheritance',
  9: 'apparent fortune, teachers and belief',
  10: 'standing and title',
  11: 'the network and what it appears to bring',
  12: 'expenditure, exile and withdrawal — the Upapada, and the spouse',
};

/// The arudha of one house.
///
/// Count from the house to its lord, then the same distance again from the
/// lord. Two exceptions keep the result from being trivial: if the pada lands
/// on the house itself or on the seventh from it, take the tenth from there
/// instead — otherwise the image and the thing would be the same, which
/// defeats the purpose of the technique.
int arudhaSignFor(int houseSign, int lordSign) {
  final distance = ((lordSign - houseSign) % 12 + 12) % 12;
  var pada = (lordSign + distance) % 12;
  final fromHouse = ((pada - houseSign) % 12 + 12) % 12;
  if (fromHouse == 0 || fromHouse == 6) {
    pada = (pada + 9) % 12;
  }
  return pada;
}

/// All twelve arudha padas.
List<ArudhaPada> arudhaPadas(NatalChart chart) {
  if (chart.input.timeUnknown) return const [];
  final lagnaSign = signIndex(chart.lagnaSidereal);
  final out = <ArudhaPada>[];

  for (var house = 1; house <= 12; house++) {
    final houseSign = (lagnaSign + house - 1) % 12;
    final lordName = signs[houseSign].ruler;
    final lord = chart.grahas.where((g) => g.name == lordName).firstOrNull;
    if (lord == null) continue;
    final lordSign = signIndex(lord.siderealLon);
    final pada = arudhaSignFor(houseSign, lordSign);

    out.add(ArudhaPada(
      house: house,
      label: house == 1 ? 'AL' : (house == 12 ? 'UL' : 'A$house'),
      sign: pada,
      lord: lordName,
      signifies: _arudhaMeaning[house] ?? '',
    ));
  }
  return out;
}

// ---------------------------------------------------------------------------
// Rashi drishti
// ---------------------------------------------------------------------------

/// Which signs a sign aspects, by the Jaimini rule.
///
/// Movable signs aspect the fixed signs other than the one adjacent to them;
/// fixed signs aspect the movable signs other than the adjacent one; dual
/// signs aspect the other dual signs. Nothing here depends on what is standing
/// in the sign — which is what makes it a *rashi* aspect and why it catches
/// contacts a graha-aspect reading misses entirely.
List<int> rashiDrishtiFrom(int sign) {
  final movable = <int>[0, 3, 6, 9];
  final fixed = <int>[1, 4, 7, 10];
  final dual = <int>[2, 5, 8, 11];

  if (movable.contains(sign)) {
    // The adjacent fixed sign is the next one along.
    final adjacent = (sign + 1) % 12;
    return fixed.where((s) => s != adjacent).toList();
  }
  if (fixed.contains(sign)) {
    final adjacent = (sign + 11) % 12;
    return movable.where((s) => s != adjacent).toList();
  }
  return dual.where((s) => s != sign).toList();
}

bool rashiAspects(int from, int to) => rashiDrishtiFrom(from).contains(to);

// ---------------------------------------------------------------------------
// Argala
// ---------------------------------------------------------------------------

class Argala {
  const Argala({
    required this.onSign,
    required this.fromSign,
    required this.kind,
    required this.planets,
    required this.obstructed,
    required this.obstructors,
  });

  final int onSign;
  final int fromSign;

  /// primary | secondary
  final String kind;
  final List<String> planets;

  /// True when the counter-position is at least as strongly occupied.
  final bool obstructed;
  final List<String> obstructors;

  String get line {
    final where = signs[fromSign].name;
    final what = planets.join(', ');
    if (obstructed) {
      return '$what in $where make argala on ${signs[onSign].name}, but it is '
          'blocked by ${obstructors.join(', ')}.';
    }
    return '$what in $where make unobstructed argala on ${signs[onSign].name}.';
  }
}

/// Argala on a sign — intervention from the 2nd, 4th and 11th, with the 5th as
/// a secondary, each blocked from its own counter-position.
///
/// The obstruction rule is what makes argala worth computing rather than
/// eyeballing: an argala with more planets blocking it than making it does not
/// operate, and counting that by hand across twelve signs is exactly the sort
/// of bookkeeping software should absorb.
List<Argala> argalaOn(int sign, NatalChart chart) {
  const primary = {2: 12, 4: 10, 11: 3};
  const secondary = {5: 9};

  List<String> occupantsOf(int s) => [
        for (final g in chart.grahas)
          if (g.name != 'Lagna' && signIndex(g.siderealLon) == s) g.name,
      ];

  final out = <Argala>[];
  for (final entry in {...primary, ...secondary}.entries) {
    final fromSign = (sign + entry.key - 1) % 12;
    final blockSign = (sign + entry.value - 1) % 12;
    final makers = occupantsOf(fromSign);
    if (makers.isEmpty) continue;
    final blockers = occupantsOf(blockSign);
    out.add(Argala(
      onSign: sign,
      fromSign: fromSign,
      kind: primary.containsKey(entry.key) ? 'primary' : 'secondary',
      planets: makers,
      obstructed: blockers.length >= makers.length,
      obstructors: blockers,
    ));
  }
  return out;
}

// ---------------------------------------------------------------------------
// Chara dasha
// ---------------------------------------------------------------------------

/// Signs counted forward, and signs counted backward.
///
/// Aries, Taurus, Gemini, Libra, Scorpio and Sagittarius are odd-footed and
/// run direct; the rest are even-footed and run in reverse. This single rule
/// decides the whole shape of the dasha, and getting it wrong reverses a life.
const _oddFooted = {0, 1, 2, 6, 7, 8};

bool isOddFooted(int sign) => _oddFooted.contains(sign);

/// The lord of a sign for Jaimini purposes.
///
/// Scorpio and Aquarius have co-lords — Ketu with Mars, and Rahu with Saturn.
/// The stronger of the two is taken, judged here by which sits in the sign
/// itself, then by which has more degrees.
String charaLordOf(int sign, NatalChart chart) {
  final conventional = signs[sign].ruler;
  final coLord = switch (sign) {
    7 => 'Ketu',
    10 => 'Rahu',
    _ => null,
  };
  if (coLord == null) return conventional;

  final a = chart.grahas.where((g) => g.name == conventional).firstOrNull;
  final b = chart.grahas.where((g) => g.name == coLord).firstOrNull;
  if (a == null) return coLord;
  if (b == null) return conventional;

  final aIn = signIndex(a.siderealLon) == sign;
  final bIn = signIndex(b.siderealLon) == sign;
  if (aIn != bIn) return aIn ? conventional : coLord;
  return (a.siderealLon % 30) >= (b.siderealLon % 30) ? conventional : coLord;
}

/// How many years a sign's chara dasha runs.
///
/// Count from the sign to its lord — forward for odd-footed signs, backward
/// for even-footed — and subtract one. A count of one becomes twelve, because
/// a lord sitting in its own sign gives the longest period, not the shortest.
int charaYearsFor(int sign, NatalChart chart) {
  final lordName = charaLordOf(sign, chart);
  final lord = chart.grahas.where((g) => g.name == lordName).firstOrNull;
  if (lord == null) return 1;
  final lordSign = signIndex(lord.siderealLon);

  final count = isOddFooted(sign)
      ? ((lordSign - sign) % 12 + 12) % 12 + 1
      : ((sign - lordSign) % 12 + 12) % 12 + 1;

  final years = count - 1;
  return years == 0 ? 12 : years;
}

class CharaDashaSpan {
  const CharaDashaSpan({
    required this.sign,
    required this.start,
    required this.end,
    required this.years,
    this.level = 'MD',
  });
  final int sign;
  final DateTime start;
  final DateTime end;
  final int years;
  final String level;

  String get label => signs[sign].name;
  bool contains(DateTime t) => !t.isBefore(start) && t.isBefore(end);
}

class CharaDashaResult {
  const CharaDashaResult({
    required this.spans,
    required this.direct,
    required this.startSign,
  });
  final List<CharaDashaSpan> spans;

  /// True when the sequence runs zodiacally.
  final bool direct;
  final int startSign;

  CharaDashaSpan? at(DateTime t) =>
      spans.where((s) => s.contains(t)).firstOrNull;
}

/// Chara dasha from the lagna.
CharaDashaResult charaDasha(NatalChart chart, {int cycles = 2}) {
  if (chart.input.timeUnknown) {
    return const CharaDashaResult(spans: [], direct: true, startSign: 0);
  }
  final start = signIndex(chart.lagnaSidereal);
  final direct = isOddFooted(start);

  final spans = <CharaDashaSpan>[];
  var cursor = chart.utc;
  for (var c = 0; c < cycles; c++) {
    for (var i = 0; i < 12; i++) {
      final sign = direct ? (start + i) % 12 : ((start - i) % 12 + 12) % 12;
      final years = charaYearsFor(sign, chart);
      final end = cursor.add(
          Duration(milliseconds: (years * 365.2425 * 86400000).round()));
      spans.add(CharaDashaSpan(
        sign: sign,
        start: cursor,
        end: end,
        years: years,
      ));
      cursor = end;
    }
  }
  return CharaDashaResult(spans: spans, direct: direct, startSign: start);
}

/// Antardashas of a chara dasha period.
///
/// The sub-periods run through all twelve signs from the mahadasha sign, in
/// the same direction, each taking an equal share.
List<CharaDashaSpan> charaAntardashas(CharaDashaSpan md, bool direct) {
  final out = <CharaDashaSpan>[];
  final total = md.end.difference(md.start).inMilliseconds;
  final each = total ~/ 12;
  var cursor = md.start;
  for (var i = 0; i < 12; i++) {
    final sign = direct ? (md.sign + i) % 12 : ((md.sign - i) % 12 + 12) % 12;
    final end = i == 11 ? md.end : cursor.add(Duration(milliseconds: each));
    out.add(CharaDashaSpan(
      sign: sign,
      start: cursor,
      end: end,
      years: 0,
      level: 'AD',
    ));
    cursor = end;
  }
  return out;
}

// ---------------------------------------------------------------------------
// A whole Jaimini reading
// ---------------------------------------------------------------------------

class JaiminiReport {
  const JaiminiReport({
    required this.karakas,
    required this.padas,
    required this.karakamsa,
    required this.swamsa,
    required this.charaDasha,
    required this.notes,
  });

  final List<CharaKaraka> karakas;
  final List<ArudhaPada> padas;
  final int? karakamsa;
  final int? swamsa;
  final CharaDashaResult charaDasha;
  final List<String> notes;

  CharaKaraka? karaka(String role) =>
      karakas.where((k) => k.role == role).firstOrNull;

  ArudhaPada? pada(String label) =>
      padas.where((p) => p.label == label).firstOrNull;
}

JaiminiReport jaiminiFor(NatalChart chart, {bool eightKaraka = false}) {
  final karakas = charaKarakas(chart, eightKaraka: eightKaraka);
  final padas = arudhaPadas(chart);
  final km = karakamsaSign(chart);
  final notes = <String>[];

  final ak = karakas.where((k) => k.role == 'Atmakaraka').firstOrNull;
  if (ak != null) {
    notes.add(
      '${ak.planet} is the Atmakaraka at ${ak.degrees.toStringAsFixed(2)}° — '
      'the highest degrees in the chart. Read the life through it: its '
      'condition is the soul’s own agenda, not merely another placement.',
    );
  }
  final dk = karakas.where((k) => k.role == 'Darakaraka').firstOrNull;
  if (dk != null) {
    notes.add(
      '${dk.planet} is the Darakaraka, holding the lowest degrees. Jaimini '
      'reads the spouse from it, and it is worth weighing against the seventh '
      'house before saying anything about marriage.',
    );
  }
  if (km != null) {
    notes.add(
      'Karakamsa falls in ${signs[km].name}. What occupies and aspects that '
      'sign in the navamsa describes what the person is actually here to do.',
    );
  }
  final ul = padas.where((p) => p.label == 'UL').firstOrNull;
  if (ul != null) {
    notes.add(
      'Upapada lagna in ${signs[ul.sign].name}. The sign and its lord carry '
      'the marriage in Jaimini, and the twelfth from it is where its '
      'difficulties show.',
    );
  }
  final al = padas.where((p) => p.label == 'AL').firstOrNull;
  if (al != null) {
    notes.add(
      'Arudha lagna in ${signs[al.sign].name} — how this person is seen, which '
      'is a different question from who they are.',
    );
  }

  return JaiminiReport(
    karakas: karakas,
    padas: padas,
    karakamsa: km,
    swamsa: swamsaSign(chart),
    charaDasha: charaDasha(chart),
    notes: notes,
  );
}

/// Dasha systems.
///
/// Gap G-13. The app ran one dasha — Vimshottari — three levels deep, from the
/// Moon, with no way to ask whether that was the right system for the chart.
///
/// What is here now:
///
///   * Vimshottari to five levels (maha, antar, pratyantar, sookshma, prana),
///     which is what same-day timing actually needs;
///   * Vimshottari reckoned from the Lagna and from the Sun, not only the Moon;
///   * **Ashtottari**, the 108-year cycle, with the classical condition that
///     decides whether it applies to a given chart;
///   * **Yogini**, the 36-year cycle;
///   * a recommendation engine that says which system the chart calls for and
///     why, instead of silently assuming.
///
/// Chara dasha, being Jaimini, lives in `jaimini.dart`.
///
/// Kalachakra is deliberately absent. Its rashi groups and their year counts
/// vary enough between schools that shipping one version would be asserting a
/// position rather than computing a result; it is listed in the app's own gap
/// register rather than half-built here.
library;

import '../domain/models.dart';
import 'tables.dart';

const _yearDays = 365.2425;

DateTime _addYears(DateTime start, double years) =>
    start.add(Duration(milliseconds: (years * _yearDays * 24 * 3600 * 1000).round()));

double _yearsBetween(DateTime a, DateTime b) =>
    b.difference(a).inMilliseconds / (_yearDays * 24 * 3600 * 1000);

// ---------------------------------------------------------------------------
// The systems
// ---------------------------------------------------------------------------

enum DashaSystem { vimshottari, ashtottari, yogini }

extension DashaSystemInfo on DashaSystem {
  String get label => switch (this) {
        DashaSystem.vimshottari => 'Vimshottari',
        DashaSystem.ashtottari => 'Ashtottari',
        DashaSystem.yogini => 'Yogini',
      };

  int get cycleYears => switch (this) {
        DashaSystem.vimshottari => 120,
        DashaSystem.ashtottari => 108,
        DashaSystem.yogini => 36,
      };

  String get note => switch (this) {
        DashaSystem.vimshottari =>
          'The default for almost every chart, and the one to reach for first.',
        DashaSystem.ashtottari =>
          'Applies when Rahu stands in a kendra or trikona from the lagna lord. '
              'Worth running when Vimshottari does not fit the life in front of you.',
        DashaSystem.yogini =>
          'Short and blunt. Good for reading the texture of a few years rather '
              'than the shape of a life.',
      };
}

/// Ashtottari: 108 years across eight lords.
const ashtottariYears = <String, double>{
  'Sun': 6, 'Moon': 15, 'Mars': 8, 'Mercury': 17,
  'Saturn': 10, 'Jupiter': 19, 'Rahu': 12, 'Venus': 21,
};

const ashtottariOrder = [
  'Sun', 'Moon', 'Mars', 'Mercury', 'Saturn', 'Jupiter', 'Rahu', 'Venus',
];

/// How many nakshatras each Ashtottari lord owns, counting from Ardra.
const _ashtottariSpans = <(String, int)>[
  ('Sun', 3),      // Ardra, Punarvasu, Pushya
  ('Moon', 4),     // Ashlesha to Uttara Phalguni
  ('Mars', 3),     // Hasta, Chitra, Swati
  ('Mercury', 4),  // Vishakha to Mula
  ('Saturn', 3),   // Purva Ashadha to Shravana
  ('Jupiter', 4),  // Dhanishta to Uttara Bhadrapada
  ('Rahu', 3),     // Revati, Ashwini, Bharani
  ('Venus', 3),    // Krittika, Rohini, Mrigashira
];

/// Yogini: 36 years across eight yoginis, each carried by a graha.
const yoginiYears = <String, double>{
  'Moon': 1, 'Sun': 2, 'Jupiter': 3, 'Mars': 4,
  'Mercury': 5, 'Saturn': 6, 'Venus': 7, 'Rahu': 8,
};

const yoginiOrder = ['Moon', 'Sun', 'Jupiter', 'Mars', 'Mercury', 'Saturn', 'Venus', 'Rahu'];

/// The yogini names, which is how a practitioner refers to them.
const yoginiNames = <String, String>{
  'Moon': 'Mangala',
  'Sun': 'Pingala',
  'Jupiter': 'Dhanya',
  'Mars': 'Bhramari',
  'Mercury': 'Bhadrika',
  'Saturn': 'Ulka',
  'Venus': 'Siddha',
  'Rahu': 'Sankata',
};

// ---------------------------------------------------------------------------
// Results
// ---------------------------------------------------------------------------

class DashaResult {
  const DashaResult({
    required this.system,
    required this.mahadashas,
    required this.antardashas,
    required this.balanceYears,
    required this.startLord,
  });

  final DashaSystem system;
  final List<DashaSpan> mahadashas;
  final List<DashaSpan> antardashas;

  /// How much of the first mahadasha was already spent at birth.
  final double balanceYears;
  final String startLord;

  DashaSpan? mahadashaAt(DateTime t) {
    for (final d in mahadashas) {
      if (d.contains(t)) return d;
    }
    return null;
  }

  DashaSpan? antardashaAt(DateTime t) {
    for (final d in antardashas) {
      if (d.contains(t)) return d;
    }
    return null;
  }
}

// ---------------------------------------------------------------------------
// Vimshottari
// ---------------------------------------------------------------------------

/// Which point the dasha is reckoned from.
///
/// The Moon is standard. The classics also allow the Lagna and the Sun, and
/// running all three is a recognised way to test a timing that does not fit.
enum DashaReference { moon, lagna, sun }

extension DashaReferenceInfo on DashaReference {
  String get label => switch (this) {
        DashaReference.moon => 'from the Moon',
        DashaReference.lagna => 'from the Lagna',
        DashaReference.sun => 'from the Sun',
      };
}

DashaResult vimshottari({
  required DateTime birth,
  required double moonSidereal,
}) =>
    _cycleDasha(
      system: DashaSystem.vimshottari,
      birth: birth,
      longitude: moonSidereal,
      order: vimshottariOrder,
      years: vimshottariYears,
      lordOf: (lon) => nakshatraOf(lon).lord,
      fractionElapsed: (lon) => (lon % nakshatraWidth) / nakshatraWidth,
    );

/// Vimshottari from any of the three reference points.
DashaResult vimshottariFrom(
  NatalChart chart,
  DashaReference reference,
) {
  final lon = switch (reference) {
    DashaReference.moon => chart.graha('Moon').siderealLon,
    DashaReference.sun => chart.graha('Sun').siderealLon,
    DashaReference.lagna => chart.lagnaSidereal,
  };
  return vimshottari(birth: chart.utc, moonSidereal: lon);
}

// ---------------------------------------------------------------------------
// Ashtottari
// ---------------------------------------------------------------------------

/// The Ashtottari lord of a nakshatra, counting from Ardra.
String ashtottariLordOf(double siderealLon) {
  final nak = nakshatraOf(siderealLon).index;
  // Ardra is index 5.
  var offset = (nak - 5) % 27;
  if (offset < 0) offset += 27;
  var cursor = 0;
  for (final span in _ashtottariSpans) {
    cursor += span.$2;
    if (offset < cursor) return span.$1;
  }
  return _ashtottariSpans.last.$1;
}

/// How far through its Ashtottari span the Moon has travelled, 0..1.
double _ashtottariElapsed(double siderealLon) {
  final nak = nakshatraOf(siderealLon).index;
  var offset = (nak - 5) % 27;
  if (offset < 0) offset += 27;
  var cursor = 0;
  for (final span in _ashtottariSpans) {
    final start = cursor;
    cursor += span.$2;
    if (offset < cursor) {
      final withinGroup = offset - start;
      final withinNakshatra = (siderealLon % nakshatraWidth) / nakshatraWidth;
      return (withinGroup + withinNakshatra) / span.$2;
    }
  }
  return 0;
}

DashaResult ashtottari({
  required DateTime birth,
  required double moonSidereal,
}) =>
    _cycleDasha(
      system: DashaSystem.ashtottari,
      birth: birth,
      longitude: moonSidereal,
      order: ashtottariOrder,
      years: ashtottariYears,
      lordOf: ashtottariLordOf,
      fractionElapsed: _ashtottariElapsed,
    );

/// Whether Ashtottari applies to this chart.
///
/// Parashara's condition: Rahu stands in a kendra or a trikona from the lord
/// of the lagna. This is the sort of rule a tool should evaluate rather than
/// leaving the reader to work out by hand, and it is the reason "add more
/// dashas" is not simply a matter of adding more tables.
({bool applies, String reason}) ashtottariApplies(NatalChart chart) {
  if (chart.input.timeUnknown) {
    return (
      applies: false,
      reason: 'The condition is judged from the lagna lord, so it cannot be '
          'settled without a birth time.',
    );
  }
  final lagnaSign = signIndex(chart.lagnaSidereal);
  final lagnaLordName = signs[lagnaSign].ruler;
  final lord = chart.grahas.where((g) => g.name == lagnaLordName).firstOrNull;
  final rahu = chart.grahas.where((g) => g.name == 'Rahu').firstOrNull;
  if (lord == null || rahu == null) {
    return (applies: false, reason: 'Rahu or the lagna lord is missing.');
  }
  final distance =
      ((signIndex(rahu.siderealLon) - signIndex(lord.siderealLon)) % 12 + 12) % 12 + 1;
  final ok = const {1, 4, 7, 10, 5, 9}.contains(distance);
  return (
    applies: ok,
    reason: ok
        ? 'Rahu stands in the ${ordinal(distance)} from $lagnaLordName, the '
            'lagna lord — a kendra or trikona, so Ashtottari applies.'
        : 'Rahu stands in the ${ordinal(distance)} from $lagnaLordName, the '
            'lagna lord, which is neither a kendra nor a trikona. Ashtottari '
            'does not apply on Parashara’s condition.',
  );
}

// ---------------------------------------------------------------------------
// Yogini
// ---------------------------------------------------------------------------

String yoginiLordOf(double siderealLon) {
  final nak = nakshatraOf(siderealLon).index + 1;
  final index = (nak + 3) % 8;
  return yoginiOrder[index];
}

DashaResult yogini({
  required DateTime birth,
  required double moonSidereal,
}) =>
    _cycleDasha(
      system: DashaSystem.yogini,
      birth: birth,
      longitude: moonSidereal,
      order: yoginiOrder,
      years: yoginiYears,
      lordOf: yoginiLordOf,
      fractionElapsed: (lon) => (lon % nakshatraWidth) / nakshatraWidth,
    );

// ---------------------------------------------------------------------------
// The shared machinery
// ---------------------------------------------------------------------------

DashaResult _cycleDasha({
  required DashaSystem system,
  required DateTime birth,
  required double longitude,
  required List<String> order,
  required Map<String, double> years,
  required String Function(double) lordOf,
  required double Function(double) fractionElapsed,
}) {
  final lord = lordOf(longitude);
  final elapsed = fractionElapsed(longitude).clamp(0.0, 0.999999);
  final full = years[lord]!;
  final balance = (1 - elapsed) * full;

  final mds = <DashaSpan>[];
  var cursor = birth;
  final startIndex = order.indexOf(lord);
  for (var i = 0; i < order.length; i++) {
    final name = order[(startIndex + i) % order.length];
    final span = i == 0 ? balance : years[name]!;
    final end = _addYears(cursor, span);
    mds.add(DashaSpan(lord: name, start: cursor, end: end));
    cursor = end;
  }

  final ads = <DashaSpan>[
    for (final md in mds) ..._subPeriods(md, order, years, system.cycleYears, 'AD'),
  ];

  return DashaResult(
    system: system,
    mahadashas: mds,
    antardashas: ads,
    balanceYears: balance,
    startLord: lord,
  );
}

List<DashaSpan> _subPeriods(
  DashaSpan parent,
  List<String> order,
  Map<String, double> years,
  int cycle,
  String level,
) {
  final out = <DashaSpan>[];
  var cursor = parent.start;
  final startIndex = order.indexOf(parent.lord);
  final parentYears = _yearsBetween(parent.start, parent.end);
  for (var i = 0; i < order.length; i++) {
    final name = order[(startIndex + i) % order.length];
    final span = parentYears * years[name]! / cycle;
    final end = i == order.length - 1 ? parent.end : _addYears(cursor, span);
    out.add(DashaSpan(
      lord: name,
      start: cursor,
      end: end,
      level: level,
      parent: parent.parent == null ? parent.lord : '${parent.parent}/${parent.lord}',
    ));
    cursor = end;
  }
  return out;
}

/// Pratyantardashas of an antardasha.
List<DashaSpan> pratyantarasOf(
  DashaSpan ad, {
  DashaSystem system = DashaSystem.vimshottari,
}) =>
    _subPeriods(ad, _orderFor(system), _yearsFor(system), system.cycleYears, 'PD');

/// Sookshma — the fourth level. Five levels is standard practice for timing an
/// event to the day, and the app previously stopped at three.
List<DashaSpan> sookshmasOf(
  DashaSpan pd, {
  DashaSystem system = DashaSystem.vimshottari,
}) =>
    _subPeriods(pd, _orderFor(system), _yearsFor(system), system.cycleYears, 'SD');

/// Prana — the fifth level, which lands on hours.
List<DashaSpan> pranasOf(
  DashaSpan sd, {
  DashaSystem system = DashaSystem.vimshottari,
}) =>
    _subPeriods(sd, _orderFor(system), _yearsFor(system), system.cycleYears, 'PrD');

List<String> _orderFor(DashaSystem s) => switch (s) {
      DashaSystem.vimshottari => vimshottariOrder,
      DashaSystem.ashtottari => ashtottariOrder,
      DashaSystem.yogini => yoginiOrder,
    };

Map<String, double> _yearsFor(DashaSystem s) => switch (s) {
      DashaSystem.vimshottari => vimshottariYears,
      DashaSystem.ashtottari => ashtottariYears,
      DashaSystem.yogini => yoginiYears,
    };

DashaSpan? pratyantaraAt(DashaSpan ad, DateTime t) {
  for (final p in pratyantarasOf(ad)) {
    if (p.contains(t)) return p;
  }
  return null;
}

/// The full stack of periods running at an instant, deepest last.
///
/// This is what a five-level readout is for: the mahadasha names the decade,
/// the prana names the hour.
List<DashaSpan> dashaStackAt(
  DashaResult result,
  DateTime t, {
  int depth = 5,
}) {
  final out = <DashaSpan>[];
  final md = result.mahadashaAt(t);
  if (md == null) return out;
  out.add(md);
  if (depth < 2) return out;

  final ad = result.antardashaAt(t);
  if (ad == null) return out;
  out.add(ad);
  if (depth < 3) return out;

  DashaSpan? current = ad;
  for (var level = 3; level <= depth; level++) {
    final children = _subPeriods(
      current!,
      _orderFor(result.system),
      _yearsFor(result.system),
      result.system.cycleYears,
      switch (level) { 3 => 'PD', 4 => 'SD', _ => 'PrD' },
    );
    final next = children.where((c) => c.contains(t)).firstOrNull;
    if (next == null) break;
    out.add(next);
    current = next;
  }
  return out;
}

// ---------------------------------------------------------------------------
// Which system to use
// ---------------------------------------------------------------------------

class DashaRecommendation {
  const DashaRecommendation({
    required this.system,
    required this.reason,
    required this.alternatives,
  });
  final DashaSystem system;
  final String reason;
  final List<({DashaSystem system, String reason})> alternatives;
}

/// Says which dasha system the chart calls for.
///
/// Conditional dashas are not exotica. When Vimshottari does not fit the life
/// in front of you, the first move is to check whether the chart's own
/// conditions call for something else — and that check is a rule, so the
/// software can do it.
DashaRecommendation recommendDasha(NatalChart chart) {
  final ash = ashtottariApplies(chart);
  return DashaRecommendation(
    system: DashaSystem.vimshottari,
    reason: 'Vimshottari is the default and fits the great majority of charts.',
    alternatives: [
      (
        system: DashaSystem.ashtottari,
        reason: ash.reason,
      ),
      (
        system: DashaSystem.yogini,
        reason: 'Always available. Its 36-year cycle reads the texture of a '
            'few years rather than the arc of a life.',
      ),
    ],
  );
}

/// Builds whichever system was asked for.
DashaResult dashaFor(
  NatalChart chart,
  DashaSystem system, {
  DashaReference reference = DashaReference.moon,
}) {
  final lon = switch (reference) {
    DashaReference.moon => chart.graha('Moon').siderealLon,
    DashaReference.sun => chart.graha('Sun').siderealLon,
    DashaReference.lagna => chart.lagnaSidereal,
  };
  return switch (system) {
    DashaSystem.vimshottari => vimshottari(birth: chart.utc, moonSidereal: lon),
    DashaSystem.ashtottari => ashtottari(birth: chart.utc, moonSidereal: lon),
    DashaSystem.yogini => yogini(birth: chart.utc, moonSidereal: lon),
  };
}

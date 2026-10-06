/// Varshaphal — the annual chart, in the Tajika tradition.
///
/// Gap G-18. In Indian practice the annual chart is how a year-ahead
/// consultation is actually conducted; without it the app could describe a
/// decade but not a birthday.
///
/// What is here: the **Varsha Pravesh** (the sidereal solar return), the
/// **Muntha**, the **Varshesha** chosen through the five offices, the **Tajika
/// aspects** — Ithasala and Ishrafa above all — and the **Mudda dasha** that
/// compresses Vimshottari into the year.
///
/// Note that Ithasala is an *applying* aspect and Ishrafa a separating one.
/// Neither could be computed before planetary speed existed (G-01), which is
/// why this module sits above that gap rather than beside it.
library;

import '../domain/models.dart';
import 'astro/units.dart';
import 'chart_builder.dart';
import 'dignity.dart';
import 'predictive.dart';
import 'tables.dart';

/// Tajika orbs — deeptamsha, the "radius of light" of each graha.
const deeptamsha = <String, double>{
  'Sun': 15,
  'Moon': 12,
  'Mars': 8,
  'Mercury': 7,
  'Jupiter': 9,
  'Venus': 7,
  'Saturn': 9,
};

// ---------------------------------------------------------------------------
// Muntha
// ---------------------------------------------------------------------------

class Muntha {
  const Muntha({
    required this.sign,
    required this.house,
    required this.lord,
    required this.reading,
  });
  final int sign;
  final int house;
  final String lord;
  final String reading;
}

const _munthaByHouse = <int, String>{
  1: 'health and standing improve; the year is about the person themselves',
  2: 'money and family; speech carries further than usual',
  3: 'effort, siblings, short journeys — a year of initiative',
  4: 'home, land, vehicles, the mother; a year of settling or moving',
  5: 'children, learning, romance, speculation',
  6: 'work, service, debts and illness — a year that has to be earned',
  7: 'partnership and the public; the other person is the year’s subject',
  8: 'upheaval, inheritance, things ending; go carefully',
  9: 'fortune, teachers, long journeys, belief',
  10: 'career and reputation — the most visible year of the cycle',
  11: 'gains, friends and networks; the easiest of the twelve',
  12: 'expense, withdrawal, foreign places, and letting go',
};

/// The Muntha advances one sign for every completed year of life.
Muntha munthaFor(NatalChart natal, int age, int annualLagnaSign) {
  final natalLagna = natal.input.timeUnknown
      ? signIndex(natal.graha('Moon').siderealLon)
      : signIndex(natal.lagnaSidereal);
  final sign = (natalLagna + age) % 12;
  final house = ((sign - annualLagnaSign) % 12 + 12) % 12 + 1;
  return Muntha(
    sign: sign,
    house: house,
    lord: signs[sign].ruler,
    reading: _munthaByHouse[house] ?? '',
  );
}

// ---------------------------------------------------------------------------
// Panchavargiya bala
// ---------------------------------------------------------------------------

/// The five-fold strength Tajika uses to pick the year lord.
///
/// Not the same as shadbala — it is smaller, faster, and built entirely from
/// dignity across five divisions.
class Panchavargiya {
  const Panchavargiya({
    required this.planet,
    required this.griha,
    required this.uchcha,
    required this.hadda,
    required this.drekkana,
    required this.navamsa,
  });

  final String planet;
  final double griha;
  final double uchcha;
  final double hadda;
  final double drekkana;
  final double navamsa;

  double get total => griha + uchcha + hadda + drekkana + navamsa;
}

Panchavargiya panchavargiya(String planet, double siderealLon) {
  final sign = signIndex(siderealLon);
  final label = dignityLabel(planet, siderealLon);

  // Griha (sign), out of 30.
  final griha = switch (label) {
    'exalted' => 30.0,
    'own sign' => 30.0,
    _ => switch (relation(planet, signs[sign].ruler)) {
        'same' => 22.5,
        'friend' => 15.0,
        'enemy' => 3.75,
        _ => 7.5,
      },
  };

  // Uchcha, out of 20, falling off with distance from the exaltation degree.
  final d = dignityTable[planet];
  var uchcha = 0.0;
  if (d != null) {
    final exact = norm360(d.exaltSign * 30.0 + d.exaltDeg);
    uchcha = (180 - separation(siderealLon, exact)) / 180 * 20;
  }

  // Hadda — the Egyptian bounds, which Tajika borrows wholesale.
  final hadda = termRuler(siderealLon) == planet ? 15.0 : 0.0;

  // Drekkana, out of 10.
  final third = ((siderealLon % 30) / 10).floor().clamp(0, 2);
  final drekkanaSign = (sign + third * 4) % 12;
  final drekkana = signs[drekkanaSign].ruler == planet ? 10.0 : 0.0;

  // Navamsa, out of 5.
  final navamsa = signs[navamsaSign(siderealLon)].ruler == planet ? 5.0 : 0.0;

  return Panchavargiya(
    planet: planet,
    griha: griha,
    uchcha: uchcha,
    hadda: hadda,
    drekkana: drekkana,
    navamsa: navamsa,
  );
}

// ---------------------------------------------------------------------------
// Tajika aspects
// ---------------------------------------------------------------------------

enum TajikaYoga { ithasala, ishrafa, nakta, yamaya, kamboola, none }

class TajikaAspect {
  const TajikaAspect({
    required this.faster,
    required this.slower,
    required this.aspect,
    required this.orb,
    required this.allowed,
    required this.yoga,
    required this.reading,
  });

  final String faster;
  final String slower;

  /// conjunction, sextile, square, trine, opposition.
  final String aspect;
  final double orb;
  final double allowed;
  final TajikaYoga yoga;
  final String reading;
}

/// Tajika aspects between two grahas of the annual chart.
///
/// The whole system turns on one distinction: **Ithasala** is an applying
/// aspect and means the matter completes; **Ishrafa** is separating and means
/// it has already slipped. That is a question about motion, not position.
List<TajikaAspect> tajikaAspects(NatalChart annual) {
  const bodies = ['Sun', 'Moon', 'Mars', 'Mercury', 'Jupiter', 'Venus', 'Saturn'];
  const angles = <String, double>{
    'conjunction': 0,
    'sextile': 60,
    'square': 90,
    'trine': 120,
    'opposition': 180,
  };

  final rows = {
    for (final g in annual.grahas)
      if (bodies.contains(g.name)) g.name: g,
  };

  final out = <TajikaAspect>[];
  for (var i = 0; i < bodies.length; i++) {
    for (var j = i + 1; j < bodies.length; j++) {
      final a = rows[bodies[i]];
      final b = rows[bodies[j]];
      if (a == null || b == null) continue;

      // The faster one is the one that closes the aspect.
      final fast = a.speed.abs() >= b.speed.abs() ? a : b;
      final slow = identical(fast, a) ? b : a;

      final allowed =
          (deeptamsha[fast.name]! + deeptamsha[slow.name]!) / 2;
      final delta = separation(fast.siderealLon, slow.siderealLon);

      for (final entry in angles.entries) {
        final orb = (delta - entry.value).abs();
        if (orb > allowed) continue;

        // Applying when the faster body has yet to reach the exact angle.
        final ahead = norm180(slow.siderealLon - fast.siderealLon);
        final applying = fast.speed >= 0 ? ahead > 0 : ahead < 0;

        final yoga = orb < 0.1
            ? TajikaYoga.kamboola
            : (applying ? TajikaYoga.ithasala : TajikaYoga.ishrafa);

        out.add(TajikaAspect(
          faster: fast.name,
          slower: slow.name,
          aspect: entry.key,
          orb: orb,
          allowed: allowed,
          yoga: yoga,
          reading: switch (yoga) {
            TajikaYoga.ithasala =>
              'Ithasala — ${fast.name} is still closing on ${slow.name}. The '
                  'matter these two signify completes within the year.',
            TajikaYoga.ishrafa =>
              'Ishrafa — ${fast.name} has already passed ${slow.name}. The '
                  'moment for this has gone; do not promise it.',
            TajikaYoga.kamboola =>
              'Exact to within a tenth of a degree. Whatever these two carry '
                  'is the spine of the year.',
            _ => '',
          },
        ));
      }
    }
  }

  out.sort((x, y) => x.orb.compareTo(y.orb));
  return out;
}

// ---------------------------------------------------------------------------
// The annual chart
// ---------------------------------------------------------------------------

class VarshaphalChart {
  const VarshaphalChart({
    required this.year,
    required this.age,
    required this.pravesh,
    required this.chart,
    required this.muntha,
    required this.varshesha,
    required this.offices,
    required this.aspects,
    required this.mudda,
    required this.notes,
  });

  final int year;
  final int age;

  /// Varsha Pravesh — the moment the Sun returns to its natal sidereal degree.
  final DateTime pravesh;

  final NatalChart chart;
  final Muntha muntha;

  /// The year lord.
  final String varshesha;

  /// The five candidates and their strengths, so the choice can be checked.
  final List<({String office, String planet, double bala})> offices;

  final List<TajikaAspect> aspects;
  final List<DashaSpan> mudda;
  final List<String> notes;
}

/// The Mudda dasha — Vimshottari compressed into one year.
///
/// The same order and the same proportions, scaled so that 120 years becomes
/// 365 days. It is how Tajika times inside the year, and it starts from the
/// annual chart's Moon.
List<DashaSpan> muddaDasha(NatalChart annual, DateTime pravesh) {
  final moon = annual.graha('Moon').siderealLon;
  final startLord = nakshatraOf(moon).lord;
  final elapsed = (moon % nakshatraWidth) / nakshatraWidth;

  final out = <DashaSpan>[];
  var cursor = pravesh;
  final index = vimshottariOrder.indexOf(startLord);
  const yearMs = 365.2425 * 86400000;

  for (var i = 0; i < 9; i++) {
    final lord = vimshottariOrder[(index + i) % 9];
    final share = vimshottariYears[lord]! / 120.0;
    final full = share * yearMs;
    final span = i == 0 ? full * (1 - elapsed) : full;
    final end = cursor.add(Duration(milliseconds: span.round()));
    out.add(DashaSpan(lord: lord, start: cursor, end: end, level: 'Mudda'));
    cursor = end;
  }
  return out;
}

/// Builds the annual chart for a given year of life.
VarshaphalChart? varshaphalFor(NatalChart natal, int year) {
  // Varsha Pravesh: the *sidereal* solar return, which is what separates this
  // from a Western solar return cast on the same birthday.
  final natalSun = natal.graha('Sun').siderealLon;
  final birthday = DateTime.utc(
      year, natal.utc.month, natal.utc.day, natal.utc.hour, natal.utc.minute);

  DateTime? exact;
  var cursor = birthday.subtract(const Duration(days: 4));
  final end = birthday.add(const Duration(days: 4));

  double gap(DateTime t) {
    final probe = buildChart(
      natal.input.copyWith(localDateTime: t.toLocal()),
      t,
      settings: natal.settings,
    );
    return norm180(probe.graha('Sun').siderealLon - natalSun);
  }

  var previous = gap(cursor);
  while (cursor.isBefore(end)) {
    final next = cursor.add(const Duration(hours: 6));
    final current = gap(next);
    if (previous.sign != current.sign && (previous.abs() + current.abs()) < 90) {
      var lo = cursor;
      var hi = next;
      for (var i = 0; i < 40; i++) {
        final mid = lo.add(
            Duration(microseconds: hi.difference(lo).inMicroseconds ~/ 2));
        if (gap(lo).sign == gap(mid).sign) {
          lo = mid;
        } else {
          hi = mid;
        }
      }
      exact = lo;
      break;
    }
    previous = current;
    cursor = next;
  }
  if (exact == null) return null;

  final age = year - natal.utc.year;
  final input = BirthInput(
    id: '${natal.input.id}-varsha-$year',
    name: '${natal.input.name} — varshaphal $year',
    localDateTime: exact.toLocal(),
    place: natal.input.place,
    timeSource: TimeSource.hospital,
  );
  final annual = buildChart(input, exact, settings: natal.settings);

  final annualLagna = signIndex(annual.lagnaSidereal);
  final muntha = munthaFor(natal, age, annualLagna);

  // The five offices. Each nominates a planet; the strongest becomes the year
  // lord, and the workings are kept so the choice can be argued with.
  final natalLagnaSign = natal.input.timeUnknown
      ? signIndex(natal.graha('Moon').siderealLon)
      : signIndex(natal.lagnaSidereal);
  final night = annual.isNightChart;

  final candidates = <({String office, String planet})>[
    (office: 'Lord of the Muntha', planet: muntha.lord),
    (office: 'Lord of the birth lagna', planet: signs[natalLagnaSign].ruler),
    (office: 'Lord of the year lagna', planet: signs[annualLagna].ruler),
    (
      office: 'Lord of the triplicity',
      planet: triplicityRuler(annual.lagnaTropical, night: night)
    ),
    (office: night ? 'Lord of the night' : 'Lord of the day',
        planet: night ? 'Moon' : 'Sun'),
  ];

  final offices = <({String office, String planet, double bala})>[];
  for (final c in candidates) {
    final row = annual.grahas.where((g) => g.name == c.planet).firstOrNull;
    final bala = row == null
        ? 0.0
        : panchavargiya(c.planet, row.siderealLon).total;
    offices.add((office: c.office, planet: c.planet, bala: bala));
  }
  final ranked = [...offices]..sort((a, b) => b.bala.compareTo(a.bala));
  final varshesha = ranked.first.planet;

  final aspects = tajikaAspects(annual);

  final notes = <String>[
    'Varsha Pravesh: ${exact.toLocal()}. The Sun returns to its natal sidereal '
        'degree here, which is a different instant from the birthday.',
    'Muntha in ${signs[muntha.sign].name}, the ${ordinal(muntha.house)} house '
        'of the annual chart — ${muntha.reading}.',
    '$varshesha is Varshesha, chosen from the five offices on panchavargiya '
        'strength (${ranked.first.bala.toStringAsFixed(1)}). Read the year '
        'through it.',
  ];

  final ithasala = aspects.where((a) => a.yoga == TajikaYoga.ithasala).toList();
  if (ithasala.isNotEmpty) {
    notes.add(
      'Ithasala this year: '
      '${ithasala.take(3).map((a) => '${a.faster}–${a.slower} ${a.aspect}').join(', ')}. '
      'These complete.',
    );
  }
  final ishrafa = aspects.where((a) => a.yoga == TajikaYoga.ishrafa).toList();
  if (ishrafa.isNotEmpty) {
    notes.add(
      'Ishrafa: '
      '${ishrafa.take(3).map((a) => '${a.faster}–${a.slower} ${a.aspect}').join(', ')}. '
      'Separating — the moment for these has passed.',
    );
  }

  return VarshaphalChart(
    year: year,
    age: age,
    pravesh: exact,
    chart: annual,
    muntha: muntha,
    varshesha: varshesha,
    offices: offices,
    aspects: aspects,
    mudda: muddaDasha(annual, exact),
    notes: notes,
  );
}

/// The profection for the same year, for readers who want both.
///
/// Profections and the Muntha are the same idea arrived at twice — one house
/// per year of life — and seeing them agree or disagree is informative.
Profection profectionFor(NatalChart natal, int year) => annualProfection(
    natal, DateTime.utc(year, natal.utc.month, natal.utc.day));

/// Western horary.
///
/// Gap G-33. Horary is a paid service in its own right, and void-of-course
/// Moon is checked by plenty of astrologers who never cast a horary chart in
/// their lives — so several pieces here earn their place outside the technique
/// too.
///
/// The structure follows how a horary chart is actually judged, in order:
///
///   1. **Considerations before judgment** — is this chart fit to read at all?
///   2. **Significators** — who stands for the querent and for the thing asked
///      about.
///   3. **Perfection** — does the matter come about, and by what route:
///      direct application, translation of light, or collection. And the two
///      ways it fails: prohibition and refranation.
///
/// All of it depends on planetary speed, so none of it was possible before
/// G-01 closed.
library;

import '../domain/models.dart';
import 'astro/ayanamsa.dart';
import 'astro/ephemeris.dart';
import 'astro/houses.dart';
import 'astro/units.dart';
import 'dignity.dart';
import 'tables.dart';

/// Horary is traditional, so the chart is cast traditionally: tropical,
/// Regiomontanus cusps, and the seven visible planets doing the work.
const horarySettings = ChartSettings(
  ayanamsa: Ayanamsa.none,
  houseSystem: HouseSystem.regiomontanus,
  vedicHouseSystem: HouseSystem.regiomontanus,
  trueNode: true,
);

const _traditionalBodies = [
  'Sun', 'Moon', 'Mercury', 'Venus', 'Mars', 'Jupiter', 'Saturn',
];

/// The Ptolemaic aspects, which are the only ones horary judges on.
const _ptolemaic = <String, double>{
  'conjunction': 0,
  'sextile': 60,
  'square': 90,
  'trine': 120,
  'opposition': 180,
};

// ---------------------------------------------------------------------------
// Considerations before judgment
// ---------------------------------------------------------------------------

class Consideration {
  const Consideration({
    required this.name,
    required this.applies,
    required this.note,
    required this.severity,
  });

  final String name;
  final bool applies;
  final String note;

  /// `blocks` — do not judge. `caution` — judge carefully and say so.
  final String severity;
}

/// The classical checks that come before any judgment.
///
/// These are not superstition: each of them is a statement that the chart is
/// not yet, or no longer, a picture of the question. An astrologer who reads
/// through them is reading something else.
List<Consideration> considerations(NatalChart chart) {
  final out = <Consideration>[];
  final asc = chart.lagnaTropical;
  final ascDegree = asc % 30;

  out.add(Consideration(
    name: 'Ascendant too early',
    applies: ascDegree < 3,
    severity: 'blocks',
    note: ascDegree < 3
        ? 'The ascendant is at ${ascDegree.toStringAsFixed(1)}°, under three '
            'degrees of ${signs[signIndex(asc)].name}. The matter is not yet '
            'ripe — too early to see. Wait and ask again.'
        : 'The ascendant is past three degrees, so the matter is formed enough '
            'to judge.',
  ));

  out.add(Consideration(
    name: 'Ascendant too late',
    applies: ascDegree > 27,
    severity: 'blocks',
    note: ascDegree > 27
        ? 'The ascendant is at ${ascDegree.toStringAsFixed(1)}°, past the '
            'twenty-seventh degree. Either the matter is already settled or '
            'the question is not the real one.'
        : 'The ascendant is short of the twenty-seventh degree.',
  ));

  final moon = chart.grahas.where((g) => g.name == 'Moon').firstOrNull;
  if (moon != null) {
    final voc = voidOfCourse(chart);
    out.add(Consideration(
      name: 'Moon void of course',
      applies: voc.isVoid,
      severity: 'caution',
      note: voc.note,
    ));

    // Via combusta: 15° Libra to 15° Scorpio.
    final lon = moon.tropicalLon;
    final viaCombusta = lon >= 195 && lon <= 225;
    out.add(Consideration(
      name: 'Moon in the via combusta',
      applies: viaCombusta,
      severity: 'caution',
      note: viaCombusta
          ? 'The Moon is in the burnt way, between fifteen Libra and fifteen '
              'Scorpio. The tradition reads the matter as unstable and the '
              'querent as more upset than they are saying.'
          : 'The Moon is clear of the via combusta.',
    ));
  }

  final saturn = chart.grahas.where((g) => g.name == 'Saturn').firstOrNull;
  if (saturn != null) {
    out.add(Consideration(
      name: 'Saturn in the seventh',
      applies: saturn.westernHouse == 7,
      severity: 'caution',
      note: saturn.westernHouse == 7
          ? 'Saturn is in the seventh, which is the astrologer’s own house in '
              'a horary chart. The tradition reads it as a warning that the '
              'judgment will go wrong — take it as a reason to be careful '
              'rather than to refuse.'
          : 'Saturn is clear of the seventh.',
    ));
    out.add(Consideration(
      name: 'Saturn in the first',
      applies: saturn.westernHouse == 1,
      severity: 'caution',
      note: saturn.westernHouse == 1
          ? 'Saturn in the first afflicts the querent’s own significator. '
              'Expect the answer to be harder than the question.'
          : 'Saturn is clear of the first.',
    ));
  }

  return out;
}

/// True when nothing blocks judgment.
bool fitToJudge(List<Consideration> list) =>
    !list.any((c) => c.applies && c.severity == 'blocks');

// ---------------------------------------------------------------------------
// Void of course
// ---------------------------------------------------------------------------

class VoidOfCourse {
  const VoidOfCourse({
    required this.isVoid,
    required this.leavesSignAt,
    required this.nextAspect,
    required this.note,
  });

  final bool isVoid;
  final DateTime? leavesSignAt;

  /// The next Ptolemaic aspect the Moon perfects before leaving its sign, if
  /// there is one.
  final String? nextAspect;
  final String note;
}

/// Whether the Moon makes any further Ptolemaic aspect before leaving its sign.
///
/// The classical reading is that nothing will come of the matter — and the
/// modern reading, that the situation is already settled and will drift rather
/// than develop, is close enough to the same thing to be worth saying.
VoidOfCourse voidOfCourse(NatalChart chart) {
  final moon = chart.grahas.where((g) => g.name == 'Moon').firstOrNull;
  if (moon == null) {
    return const VoidOfCourse(
      isVoid: false, leavesSignAt: null, nextAspect: null,
      note: 'No Moon in this chart.');
  }

  final degreesLeft = 30 - (moon.tropicalLon % 30);
  final speed = moon.speed <= 0 ? 13.2 : moon.speed;
  final daysToSignChange = degreesLeft / speed;

  String? next;
  var soonest = double.infinity;

  for (final other in chart.grahas) {
    if (other.name == 'Moon' || !_traditionalBodies.contains(other.name)) {
      continue;
    }
    for (final entry in _ptolemaic.entries) {
      // How long until the separation reaches the aspect's angle, given the
      // relative motion. Both bodies move, which is why the other planet's
      // speed belongs in the denominator.
      final relative = speed - other.speed;
      if (relative.abs() < 1e-6) continue;

      for (final target in [entry.value, -entry.value]) {
        final gap = norm180(
            other.tropicalLon + target - moon.tropicalLon);
        final days = gap / relative;
        if (days <= 0 || days > daysToSignChange) continue;
        if (days < soonest) {
          soonest = days;
          next = '${entry.key} with ${other.name}';
        }
      }
    }
  }

  final isVoid = next == null;
  return VoidOfCourse(
    isVoid: isVoid,
    leavesSignAt: chart.utc.add(
        Duration(minutes: (daysToSignChange * 1440).round())),
    nextAspect: next,
    note: isVoid
        ? 'The Moon perfects no further Ptolemaic aspect before leaving '
            '${signs[signIndex(moon.tropicalLon)].name}. Nothing will come of '
            'the matter as it stands — which is an answer, not a refusal to '
            'answer.'
        : 'The Moon still has to perfect a $next before leaving '
            '${signs[signIndex(moon.tropicalLon)].name}, so it is not void.',
  );
}

// ---------------------------------------------------------------------------
// Planetary hours
// ---------------------------------------------------------------------------

/// The Chaldean order, which the hours run through.
const _chaldean = ['Saturn', 'Jupiter', 'Mars', 'Sun', 'Venus', 'Mercury', 'Moon'];

/// Weekday rulers, Sunday first.
const _dayRulers = ['Sun', 'Moon', 'Mars', 'Mercury', 'Jupiter', 'Venus', 'Saturn'];

class PlanetaryHour {
  const PlanetaryHour({
    required this.ruler,
    required this.index,
    required this.start,
    required this.end,
    required this.isDay,
  });

  final String ruler;

  /// 1..12 within the day or the night.
  final int index;
  final DateTime start;
  final DateTime end;
  final bool isDay;
}

/// The planetary hour containing an instant.
///
/// Unequal hours: daylight is divided into twelve and the night into twelve,
/// so an hour is only sixty minutes at the equinox. The first hour of the day
/// belongs to the day's own ruler, and they run on in Chaldean order.
PlanetaryHour planetaryHour({
  required DateTime at,
  required DateTime sunrise,
  required DateTime sunset,
  required DateTime nextSunrise,
}) {
  final isDay = !at.isBefore(sunrise) && at.isBefore(sunset);
  final spanStart = isDay ? sunrise : sunset;
  final spanEnd = isDay ? sunset : nextSunrise;
  final length = spanEnd.difference(spanStart).inMicroseconds ~/ 12;

  final into = at.difference(spanStart).inMicroseconds;
  final index = (into ~/ length).clamp(0, 11);

  // The day's ruler holds the first hour of daylight; the night's hours
  // continue the same sequence, so the first hour of night is the thirteenth.
  final weekday = sunrise.toLocal().weekday % 7;
  final dayRuler = _dayRulers[weekday];
  final startIndex = _chaldean.indexOf(dayRuler);
  final offset = isDay ? index : 12 + index;
  final ruler = _chaldean[(startIndex + offset) % 7];

  return PlanetaryHour(
    ruler: ruler,
    index: index + 1,
    start: spanStart.add(Duration(microseconds: length * index)),
    end: spanStart.add(Duration(microseconds: length * (index + 1))),
    isDay: isDay,
  );
}

// ---------------------------------------------------------------------------
// Significators and perfection
// ---------------------------------------------------------------------------

class Significator {
  const Significator({
    required this.role,
    required this.planet,
    required this.house,
    required this.why,
  });

  final String role;
  final String planet;
  final int house;
  final String why;
}

enum PerfectionRoute { direct, translation, collection, none }

class Perfection {
  const Perfection({
    required this.route,
    required this.aspect,
    required this.byPlanet,
    required this.daysAway,
    required this.denied,
    required this.denialReason,
    required this.note,
  });

  final PerfectionRoute route;
  final String aspect;

  /// The translating or collecting planet, when there is one.
  final String byPlanet;

  /// Roughly how far off the perfection is, in days of chart motion. Horary
  /// converts this to the querent's own units — days, weeks or months — by the
  /// mode of the signs involved, which is a judgment rather than arithmetic.
  final double daysAway;

  final bool denied;
  final String denialReason;
  final String note;

  bool get perfects => route != PerfectionRoute.none && !denied;
}

/// The houses a question belongs to.
const horaryHouses = <String, ({int house, String about})>{
  'Will I get the job?': (house: 10, about: 'career and standing'),
  'Will we marry?': (house: 7, about: 'the partner'),
  'Will I recover?': (house: 6, about: 'illness'),
  'Will I get the money?': (house: 8, about: 'money from others'),
  'Where is the lost thing?': (house: 2, about: 'movable possessions'),
  'Will I move house?': (house: 4, about: 'home and property'),
  'Will the case go my way?': (house: 7, about: 'the opponent'),
  'Will the journey go well?': (house: 9, about: 'long journeys'),
};

/// The querent's and the quesited's significators.
({Significator querent, Significator moon, Significator quesited})
    significatorsForQuestion(NatalChart chart, int questionHouse) {
  final cusps = chart.westernCusps!;
  final ascSign = signIndex(cusps.ascendant);
  final querentRuler = signs[ascSign].ruler;

  final quesitedCusp = cusps.cusps[questionHouse - 1];
  final quesitedRuler = signs[signIndex(quesitedCusp)].ruler;

  int houseOf(String planet) =>
      chart.grahas.where((g) => g.name == planet).firstOrNull?.westernHouse ?? 0;

  return (
    querent: Significator(
      role: 'Querent',
      planet: querentRuler,
      house: houseOf(querentRuler),
      why: '$querentRuler rules ${signs[ascSign].name} on the ascendant.',
    ),
    moon: Significator(
      role: 'Co-significator',
      planet: 'Moon',
      house: houseOf('Moon'),
      why: 'The Moon always co-signifies the querent and carries the flow of '
          'the matter.',
    ),
    quesited: Significator(
      role: 'Quesited',
      planet: quesitedRuler,
      house: houseOf(quesitedRuler),
      why: '$quesitedRuler rules ${signs[signIndex(quesitedCusp)].name} on the '
          '${ordinal(questionHouse)} cusp.',
    ),
  );
}

/// Whether and how the matter comes about.
Perfection judgePerfection(
  NatalChart chart,
  String querentPlanet,
  String quesitedPlanet,
) {
  GrahaRow? row(String name) =>
      chart.grahas.where((g) => g.name == name).firstOrNull;

  final a = row(querentPlanet);
  final b = row(quesitedPlanet);
  if (a == null || b == null) {
    return const Perfection(
      route: PerfectionRoute.none, aspect: '', byPlanet: '',
      daysAway: 0, denied: false, denialReason: '',
      note: 'One of the significators is missing from the chart.');
  }

  if (a.name == b.name) {
    return Perfection(
      route: PerfectionRoute.direct,
      aspect: 'same planet',
      byPlanet: '',
      daysAway: 0,
      denied: false,
      denialReason: '',
      note: '${a.name} signifies both sides. The tradition reads that as the '
          'matter already being in hand — the querent and the quesited are not '
          'really separate here.',
    );
  }

  // Direct application.
  final direct = _applicationBetween(a, b);
  if (direct != null) {
    final denial = _denial(chart, a, b, direct.days);
    return Perfection(
      route: PerfectionRoute.direct,
      aspect: direct.aspect,
      byPlanet: '',
      daysAway: direct.days,
      denied: denial != null,
      denialReason: denial ?? '',
      note: denial == null
          ? '${a.name} applies to a ${direct.aspect} of ${b.name} and perfects '
              'it. The matter comes about of itself.'
          : '${a.name} applies to a ${direct.aspect} of ${b.name}, but it does '
              'not get there: $denial',
    );
  }

  // Translation of light: a faster planet separating from one and applying to
  // the other carries the matter between them.
  for (final t in chart.grahas) {
    if (!_traditionalBodies.contains(t.name)) continue;
    if (t.name == a.name || t.name == b.name) continue;
    if (t.speed.abs() <= a.speed.abs() && t.speed.abs() <= b.speed.abs()) {
      continue;
    }
    final fromA = _separationBetween(t, a);
    final toB = _applicationBetween(t, b);
    final fromB = _separationBetween(t, b);
    final toA = _applicationBetween(t, a);

    if (fromA != null && toB != null) {
      return Perfection(
        route: PerfectionRoute.translation,
        aspect: toB.aspect,
        byPlanet: t.name,
        daysAway: toB.days,
        denied: false,
        denialReason: '',
        note: '${t.name} translates the light: it has just separated from '
            '${a.name} and now applies to ${b.name}. The matter comes about '
            'through ${t.name}’s agency — a third party, or whatever ${t.name} '
            'rules here.',
      );
    }
    if (fromB != null && toA != null) {
      return Perfection(
        route: PerfectionRoute.translation,
        aspect: toA.aspect,
        byPlanet: t.name,
        daysAway: toA.days,
        denied: false,
        denialReason: '',
        note: '${t.name} translates the light from ${b.name} to ${a.name}. '
            'The matter comes about, but the approach is made from the other '
            'side.',
      );
    }
  }

  // Collection: a slower planet that both apply to gathers the matter.
  for (final c in chart.grahas) {
    if (!_traditionalBodies.contains(c.name)) continue;
    if (c.name == a.name || c.name == b.name) continue;
    if (c.speed.abs() >= a.speed.abs() || c.speed.abs() >= b.speed.abs()) {
      continue;
    }
    final fromA = _applicationBetween(a, c);
    final fromB = _applicationBetween(b, c);
    if (fromA != null && fromB != null) {
      return Perfection(
        route: PerfectionRoute.collection,
        aspect: '${fromA.aspect} and ${fromB.aspect}',
        byPlanet: c.name,
        daysAway: fromA.days > fromB.days ? fromA.days : fromB.days,
        denied: false,
        denialReason: '',
        note: '${c.name} collects the light: both ${a.name} and ${b.name} '
            'apply to it. The matter comes about, but only through a third '
            'party heavier than either — and on that party’s terms.',
      );
    }
  }

  return const Perfection(
    route: PerfectionRoute.none,
    aspect: '',
    byPlanet: '',
    daysAway: 0,
    denied: true,
    denialReason: 'no perfection',
    note: 'The significators neither apply to each other nor have their light '
        'carried between them. On the chart as it stands, no.',
  );
}

/// An applying Ptolemaic aspect between two bodies, if there is one within
/// orb that will actually perfect.
({String aspect, double days})? _applicationBetween(GrahaRow a, GrahaRow b) {
  final relative = a.speed - b.speed;
  if (relative.abs() < 1e-6) return null;

  ({String aspect, double days})? best;
  for (final entry in _ptolemaic.entries) {
    final orb = (deeptamshaFor(a.name) + deeptamshaFor(b.name)) / 2;
    final current = separation(a.tropicalLon, b.tropicalLon);
    if ((current - entry.value).abs() > orb) continue;

    for (final target in [entry.value, -entry.value]) {
      final gap = norm180(b.tropicalLon + target - a.tropicalLon);
      final days = gap / relative;
      if (days <= 0 || days > 30) continue;
      if (best == null || days < best.days) {
        best = (aspect: entry.key, days: days);
      }
    }
  }
  return best;
}

/// A recently perfected aspect the faster body is now separating from.
({String aspect, double days})? _separationBetween(GrahaRow a, GrahaRow b) {
  final relative = a.speed - b.speed;
  if (relative.abs() < 1e-6) return null;

  for (final entry in _ptolemaic.entries) {
    final orb = (deeptamshaFor(a.name) + deeptamshaFor(b.name)) / 2;
    final current = separation(a.tropicalLon, b.tropicalLon);
    if ((current - entry.value).abs() > orb) continue;
    for (final target in [entry.value, -entry.value]) {
      final gap = norm180(b.tropicalLon + target - a.tropicalLon);
      final days = gap / relative;
      // Negative days means the aspect is behind them.
      if (days < 0 && days > -15) return (aspect: entry.key, days: -days);
    }
  }
  return null;
}

/// The two classical ways a perfection fails.
String? _denial(NatalChart chart, GrahaRow a, GrahaRow b, double days) {
  // Refranation: a significator stations before it gets there. A body already
  // very slow is about to turn.
  for (final s in [a, b]) {
    final mean = _meanSpeed(s.name);
    if (s.speed.abs() < mean * 0.08) {
      return 'refranation — ${s.name} is stationary and will turn back before '
          'the aspect perfects. The matter is called off by the party it '
          'signifies.';
    }
  }

  // Prohibition: a third body reaches one of them first.
  for (final p in chart.grahas) {
    if (!_traditionalBodies.contains(p.name)) continue;
    if (p.name == a.name || p.name == b.name) continue;
    for (final target in [a, b]) {
      final interfering = _applicationBetween(p, target);
      if (interfering != null && interfering.days < days) {
        return 'prohibition — ${p.name} reaches ${target.name} first, by '
            '${interfering.aspect}. Something intervenes before the matter can '
            'complete.';
      }
    }
  }
  return null;
}

/// Traditional orbs, by the planet's own "radius of light". The same figures
/// the Tajika tradition calls deeptamsha, which is not a coincidence — both
/// inherit them from the same Hellenistic source.
double deeptamshaFor(String planet) => switch (planet) {
      'Sun' => 15,
      'Moon' => 12,
      'Mars' => 8,
      'Mercury' => 7,
      'Jupiter' => 9,
      'Venus' => 7,
      'Saturn' => 9,
      _ => 5,
    };

double _meanSpeed(String planet) => switch (planet) {
      'Moon' => 13.18,
      'Sun' => 0.99,
      'Mercury' => 1.38,
      'Venus' => 1.20,
      'Mars' => 0.52,
      'Jupiter' => 0.083,
      'Saturn' => 0.034,
      _ => 1.0,
    };

// ---------------------------------------------------------------------------
// The whole judgment
// ---------------------------------------------------------------------------

class HoraryJudgment {
  const HoraryJudgment({
    required this.question,
    required this.house,
    required this.chart,
    required this.considerations,
    required this.fitToJudge,
    required this.querent,
    required this.moon,
    required this.quesited,
    required this.perfection,
    required this.voidMoon,
    required this.dignities,
  });

  final String question;
  final int house;
  final NatalChart chart;
  final List<Consideration> considerations;
  final bool fitToJudge;
  final Significator querent;
  final Significator moon;
  final Significator quesited;
  final Perfection perfection;
  final VoidOfCourse voidMoon;
  final List<DignityScore> dignities;

  String get answer {
    if (!fitToJudge) return 'not fit to judge';
    if (voidMoon.isVoid && !perfection.perfects) return 'no';
    if (perfection.perfects) {
      return perfection.route == PerfectionRoute.direct ? 'yes' : 'yes, with help';
    }
    return 'no';
  }
}

HoraryJudgment judgeHorary({
  required NatalChart chart,
  required String question,
  required int house,
}) {
  final checks = considerations(chart);
  final sig = significatorsForQuestion(chart, house);
  final night = chart.isNightChart;

  return HoraryJudgment(
    question: question,
    house: house,
    chart: chart,
    considerations: checks,
    fitToJudge: fitToJudge(checks),
    querent: sig.querent,
    moon: sig.moon,
    quesited: sig.quesited,
    perfection: judgePerfection(chart, sig.querent.planet, sig.quesited.planet),
    voidMoon: voidOfCourse(chart),
    dignities: [
      for (final p in [sig.querent.planet, sig.quesited.planet, 'Moon'])
        essentialDignity(
          p,
          chart.grahas.where((g) => g.name == p).first.tropicalLon,
          night: night,
        ),
    ],
  );
}

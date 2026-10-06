/// Progressions, directions and return charts.
///
/// Gaps G-26 and G-27. The Western half of the app could describe a chart but
/// could say nothing about *when* — it had no equivalent of the dasha system.
/// Secondary progressions are that equivalent, and the solar return is a
/// standing annual appointment in Western practice.
///
/// Implemented:
///
///   * **Secondary progressions**, day-for-a-year, with the progressed Moon
///     and the progressed lunation phase that most practitioners time by;
///   * **Solar arc directions**, where the whole chart advances by the Sun's
///     own progressed arc;
///   * **Tertiary progressions**, day-for-a-lunar-month;
///   * **Solar and lunar returns**, with an optional precession correction and
///     an optional relocation (G-36, in part — a return read for where the
///     person actually is, not where they were born);
///   * **Profections**, which are traditional rather than modern but belong
///     next to the other annual techniques (part of G-32).
library;

import '../domain/models.dart';
import 'astro/ephemeris.dart';
import 'astro/units.dart';
import 'chart_builder.dart';
import 'tables.dart';

const _tropicalYear = 365.2421897;

// ---------------------------------------------------------------------------
// Secondary progressions
// ---------------------------------------------------------------------------

class ProgressedChart {
  const ProgressedChart({
    required this.method,
    required this.forDate,
    required this.progressedInstant,
    required this.positions,
    required this.ascendant,
    required this.midheaven,
    required this.moonPhase,
    required this.notes,
  });

  final String method;

  /// The date the progression was taken for.
  final DateTime forDate;

  /// The actual ephemeris instant used — a few days after birth.
  final DateTime progressedInstant;

  final Map<String, BodyPosition> positions;
  final double ascendant;
  final double midheaven;

  /// Where the progressed Moon stands relative to the progressed Sun.
  final ProgressedLunation moonPhase;

  final List<String> notes;

  double? longitudeOf(String body) => positions[body]?.longitude;
}

/// The progressed lunation cycle — a roughly thirty-year rhythm that many
/// practitioners treat as the backbone of a life's chapters.
class ProgressedLunation {
  const ProgressedLunation({
    required this.elongation,
    required this.phase,
    required this.meaning,
  });
  final double elongation;
  final String phase;
  final String meaning;
}

const _phases = <(double, String, String)>[
  (0, 'New', 'A beginning taken on instinct, before its shape is clear.'),
  (45, 'Crescent', 'The first resistance, and the effort to keep going anyway.'),
  (90, 'First quarter', 'A crisis of action. Build it or drop it.'),
  (135, 'Gibbous', 'Refinement, doubt, and the work of getting it right.'),
  (180, 'Full', 'Everything is visible, including what does not work.'),
  (225, 'Disseminating', 'Sharing what was learned; the meaning settles.'),
  (270, 'Last quarter', 'A crisis of consciousness. The structure is questioned.'),
  (315, 'Balsamic', 'Winding down. Release, and preparation for the next cycle.'),
];

ProgressedLunation _lunationOf(double sun, double moon) {
  final elongation = norm360(moon - sun);
  var best = _phases.first;
  for (final p in _phases) {
    if (elongation >= p.$1) best = p;
  }
  return ProgressedLunation(
    elongation: elongation,
    phase: best.$2,
    meaning: best.$3,
  );
}

/// Secondary progressions: one day after birth stands for one year of life.
///
/// The progressed Moon moves roughly one degree a month and changes sign every
/// two and a half years, which is why it is the hand on the dial that Western
/// practitioners actually read.
ProgressedChart secondaryProgressions(
  NatalChart chart,
  DateTime forDate, {
  bool progressAngles = true,
}) {
  final years = forDate.difference(chart.utc).inMilliseconds /
      (_tropicalYear * 86400000);
  final instant = chart.utc.add(
      Duration(milliseconds: (years * 86400000).round()));

  final sky = computeSky(
    utc: instant,
    latitude: chart.input.place.latitude,
    longitudeEast: chart.input.place.longitude,
    settings: chart.settings,
  );

  // Progressed angles by the "solar arc" convention: the MC advances with the
  // Sun's progressed motion. The alternative is naibod or true motion; this is
  // the commonest and the one to state plainly rather than leave implicit.
  final natalSun = chart.graha('Sun').tropicalLon;
  final arc = norm360(sky.bodies['Sun']!.longitude - natalSun);
  final mc = progressAngles
      ? norm360(chart.mcTropical + arc)
      : sky.western.midheaven;
  final asc = progressAngles
      ? norm360(chart.lagnaTropical + arc)
      : sky.western.ascendant;

  final lunation = _lunationOf(
      sky.bodies['Sun']!.longitude, sky.bodies['Moon']!.longitude);

  final notes = <String>[
    'Progressed for ${years.toStringAsFixed(1)} years — the sky as it stood '
        '${years.toStringAsFixed(0)} days after birth.',
    'Progressed Moon at ${formatDms(sky.bodies['Moon']!.longitude)} '
        '${signs[signIndex(sky.bodies['Moon']!.longitude)].name}.',
    'Progressed lunation: ${lunation.phase}. ${lunation.meaning}',
  ];

  // A progressed planet changing direction is rare and significant — it can
  // happen once in a life and marks a long reversal of that planet's affairs.
  for (final b in sky.bodies.values) {
    if (b.name == 'Sun' || b.name == 'Moon') continue;
    final natal = chart.grahas.where((g) => g.name == b.name).firstOrNull;
    if (natal == null) continue;
    if (natal.isRetrograde != b.isRetrograde) {
      notes.add(
        '${b.name} has changed direction by progression — it was '
        '${natal.isRetrograde ? 'retrograde' : 'direct'} at birth and is now '
        '${b.isRetrograde ? 'retrograde' : 'direct'}. This happens at most '
        'once in a life and turns that planet’s affairs around with it.',
      );
    }
  }

  return ProgressedChart(
    method: 'Secondary progressions (day for a year)',
    forDate: forDate,
    progressedInstant: instant,
    positions: sky.bodies,
    ascendant: asc,
    midheaven: mc,
    moonPhase: lunation,
    notes: notes,
  );
}

/// Tertiary progressions — a day for a lunar month. Faster, and used for
/// timing inside a year.
ProgressedChart tertiaryProgressions(NatalChart chart, DateTime forDate) {
  const synodicMonth = 27.321582;
  final months = forDate.difference(chart.utc).inMilliseconds /
      (synodicMonth * 86400000);
  final instant =
      chart.utc.add(Duration(milliseconds: (months * 86400000).round()));
  final sky = computeSky(
    utc: instant,
    latitude: chart.input.place.latitude,
    longitudeEast: chart.input.place.longitude,
    settings: chart.settings,
  );
  return ProgressedChart(
    method: 'Tertiary progressions (day for a lunar month)',
    forDate: forDate,
    progressedInstant: instant,
    positions: sky.bodies,
    ascendant: sky.western.ascendant,
    midheaven: sky.western.midheaven,
    moonPhase: _lunationOf(
        sky.bodies['Sun']!.longitude, sky.bodies['Moon']!.longitude),
    notes: const [],
  );
}

// ---------------------------------------------------------------------------
// Solar arc directions
// ---------------------------------------------------------------------------

class DirectedPoint {
  const DirectedPoint({
    required this.name,
    required this.natal,
    required this.directed,
  });
  final String name;
  final double natal;
  final double directed;
}

class SolarArcChart {
  const SolarArcChart({
    required this.forDate,
    required this.arc,
    required this.points,
    required this.contacts,
  });

  final DateTime forDate;

  /// How far the whole chart has advanced, degrees.
  final double arc;
  final List<DirectedPoint> points;

  /// Directed points landing on natal points.
  final List<String> contacts;
}

/// Solar arc directions: every point advances by the Sun's progressed arc.
///
/// About a degree a year, which makes the technique unusually easy to check by
/// eye — and unusually unforgiving of an ephemeris that is a degree out, which
/// is one more reason the Tier 1 work had to come first.
SolarArcChart solarArc(NatalChart chart, DateTime forDate, {double orb = 1.0}) {
  final years = forDate.difference(chart.utc).inMilliseconds /
      (_tropicalYear * 86400000);
  final instant =
      chart.utc.add(Duration(milliseconds: (years * 86400000).round()));
  final sky = computeSky(
    utc: instant, latitude: chart.input.place.latitude,
    longitudeEast: chart.input.place.longitude,
    settings: chart.settings, bodyNames: const ['Sun']);
  final arc = norm360(sky.bodies['Sun']!.longitude - chart.graha('Sun').tropicalLon);

  final points = <DirectedPoint>[
    for (final g in chart.grahas)
      DirectedPoint(
        name: g.name,
        natal: g.tropicalLon,
        directed: norm360(g.tropicalLon + arc),
      ),
    DirectedPoint(
      name: 'MC',
      natal: chart.mcTropical,
      directed: norm360(chart.mcTropical + arc),
    ),
  ];

  final contacts = <String>[];
  for (final d in points) {
    for (final natal in chart.grahas) {
      if (natal.name == d.name) continue;
      for (final (angle, label) in const [
        (0.0, 'conjunct'), (90.0, 'square'), (180.0, 'opposite'), (120.0, 'trine'),
      ]) {
        final gap = (separation(d.directed, natal.tropicalLon) - angle).abs();
        if (gap <= orb) {
          contacts.add('Directed ${d.name} $label natal ${natal.name} '
              '(${gap.toStringAsFixed(2)}° from exact)');
        }
      }
    }
  }

  return SolarArcChart(
    forDate: forDate,
    arc: arc,
    points: points,
    contacts: contacts,
  );
}

// ---------------------------------------------------------------------------
// Return charts
// ---------------------------------------------------------------------------

class ReturnChart {
  const ReturnChart({
    required this.body,
    required this.exact,
    required this.chart,
    required this.precessionCorrected,
    required this.relocatedTo,
  });

  final String body;

  /// The exact moment the body returned to its natal longitude.
  final DateTime exact;
  final NatalChart chart;
  final bool precessionCorrected;

  /// Where the return was cast for, when that is not the birthplace.
  final Place? relocatedTo;

  String get label => '$body return';
}

/// Finds the exact instant a body returns to its natal longitude, then casts
/// a chart for it.
///
/// [precessionCorrected] shifts the target by the precession accumulated since
/// birth, which is the sidereal-minded correction some practitioners insist on
/// and others reject; it is a switch rather than a decision the software makes.
///
/// [relocateTo] casts the return for where the person actually is. A solar
/// return read for a birthplace someone left thirty years ago has the wrong
/// angles, and the angles are most of what a return chart says.
ReturnChart? returnChart(
  NatalChart chart, {
  required String body,
  required DateTime near,
  bool precessionCorrected = false,
  Place? relocateTo,
}) {
  final natal = chart.grahas.where((g) => g.name == body).firstOrNull;
  if (natal == null) return null;

  var target = natal.tropicalLon;
  if (precessionCorrected) {
    final yearsSince = near.difference(chart.utc).inDays / 365.2425;
    target = norm360(target + yearsSince * 50.29 / 3600.0);
  }

  final window = body == 'Moon'
      ? const Duration(days: 16)
      : const Duration(days: 200);

  double gap(DateTime t) {
    final sky = computeSky(
      utc: t, latitude: 0, longitudeEast: 0, bodyNames: [body]);
    return norm180(sky.bodies[body]!.longitude - target);
  }

  // Bracket the crossing.
  var lo = near.subtract(window);
  var previous = gap(lo);
  final step = body == 'Moon'
      ? const Duration(hours: 6)
      : const Duration(days: 1);
  DateTime? exact;
  var cursor = lo;
  final end = near.add(window);
  while (cursor.isBefore(end)) {
    final next = cursor.add(step);
    final current = gap(next);
    if (previous.sign != current.sign && (previous.abs() + current.abs()) < 90) {
      lo = cursor;
      var hi = next;
      for (var i = 0; i < 44; i++) {
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

  final place = relocateTo ?? chart.input.place;
  final input = BirthInput(
    id: '${chart.input.id}-$body-return',
    name: '${chart.input.name} — $body return',
    localDateTime: exact.toLocal(),
    place: place,
    timeSource: TimeSource.hospital,
  );

  return ReturnChart(
    body: body,
    exact: exact,
    chart: buildChart(input, exact, settings: chart.settings),
    precessionCorrected: precessionCorrected,
    relocatedTo: relocateTo,
  );
}

/// The solar return covering a given year.
ReturnChart? solarReturn(
  NatalChart chart,
  int year, {
  bool precessionCorrected = false,
  Place? relocateTo,
}) {
  final birthday = DateTime.utc(
      year, chart.utc.month, chart.utc.day, chart.utc.hour, chart.utc.minute);
  return returnChart(
    chart,
    body: 'Sun',
    near: birthday,
    precessionCorrected: precessionCorrected,
    relocateTo: relocateTo,
  );
}

/// The lunar return covering a given month.
ReturnChart? lunarReturn(NatalChart chart, DateTime near, {Place? relocateTo}) =>
    returnChart(chart, body: 'Moon', near: near, relocateTo: relocateTo);

// ---------------------------------------------------------------------------
// Relocation (G-36)
// ---------------------------------------------------------------------------

/// The same birth moment, read for a different place.
///
/// The planets do not move — only the angles and the houses do, and the angles
/// are most of what a chart says about circumstance. "Where should I live" is
/// among the most requested consultations there is, and this is the one line
/// of it that was missing once real house cusps existed (G-02).
NatalChart relocated(NatalChart chart, Place to) {
  final input = BirthInput(
    id: '${chart.input.id}-reloc',
    name: '${chart.input.name} — ${to.label}',
    localDateTime: chart.input.localDateTime,
    place: to,
    timeSource: chart.input.timeSource,
    notes: 'Relocated from ${chart.input.place.label}. The planets are '
        'unchanged; the angles and houses are not.',
  );
  return buildChart(input, chart.utc, settings: chart.settings);
}

// ---------------------------------------------------------------------------
// Profections (G-32, in part)
// ---------------------------------------------------------------------------

class Profection {
  const Profection({
    required this.age,
    required this.house,
    required this.sign,
    required this.lordOfYear,
    required this.note,
  });
  final int age;
  final int house;
  final int sign;

  /// The time lord of the year — the planet the year is read through.
  final String lordOfYear;
  final String note;
}

/// Annual profections: one house per year of life, from the ascendant.
///
/// The simplest time-lord technique there is, and the one the Hellenistic
/// revival put back at the centre of Western practice. The lord of the year is
/// the planet whose transits and directions matter most for those twelve
/// months; everything else is background.
Profection annualProfection(NatalChart chart, DateTime forDate) {
  final age = _ageAt(chart.utc, forDate);
  final house = age % 12 + 1;
  final lagnaSign = chart.input.timeUnknown
      ? signIndex(chart.graha('Moon').tropicalLon)
      : signIndex(chart.lagnaTropical);
  final sign = (lagnaSign + house - 1) % 12;
  final lord = signs[sign].ruler;

  return Profection(
    age: age,
    house: house,
    sign: sign,
    lordOfYear: lord,
    note: 'At $age the year profects to the ${ordinal(house)} house, '
        '${signs[sign].name}. $lord is lord of the year: watch where it sits '
        'natally, what it rules, and what transits it.',
  );
}

/// Monthly profections — the same idea one turn faster.
Profection monthlyProfection(NatalChart chart, DateTime forDate) {
  final annual = annualProfection(chart, forDate);
  final birthdayThisYear = DateTime.utc(
      forDate.year, chart.utc.month, chart.utc.day);
  final anchor = forDate.isBefore(birthdayThisYear)
      ? DateTime.utc(forDate.year - 1, chart.utc.month, chart.utc.day)
      : birthdayThisYear;
  final monthsIn = (forDate.difference(anchor).inDays / 30.4375).floor() % 12;
  final sign = (annual.sign + monthsIn) % 12;
  return Profection(
    age: annual.age,
    house: (annual.house - 1 + monthsIn) % 12 + 1,
    sign: sign,
    lordOfYear: signs[sign].ruler,
    note: 'Month $monthsIn of the profected year: ${signs[sign].name}, '
        'ruled by ${signs[sign].ruler}.',
  );
}

int _ageAt(DateTime birth, DateTime at) {
  var age = at.year - birth.year;
  final hadBirthday = at.month > birth.month ||
      (at.month == birth.month && at.day >= birth.day);
  if (!hadBirthday) age -= 1;
  return age < 0 ? 0 : age;
}

/// Birth-time rectification.
///
/// Gap G-38. A large share of real consultations begin with a time that is
/// wrong by twenty minutes, and rectification is skilled paid work. It is also
/// nearly impossible without a tool that shows what moves as the time moves —
/// which is precisely what the app could not do.
///
/// Two methods, because they answer different questions:
///
///   * **Sensitivity** — for a given uncertainty, what actually changes? Some
///     charts are stable across an hour and some change ascendant twice in ten
///     minutes, and knowing which is the first thing to establish.
///   * **Event fitting** — score candidate times against dated life events,
///     using the techniques that are sensitive to the minute: the ascendant,
///     the house placements, the dasha stack, and solar arc directions to the
///     angles.
///
/// The output is deliberately a ranked list with its workings, never a single
/// "rectified time". Rectification is a judgment, and a tool that hands back
/// one number invites it to be trusted more than it should be.
library;

import '../domain/models.dart';
import 'astro/ephemeris.dart';
import 'astro/units.dart';
import 'chart_builder.dart';
import 'predictive.dart';
import 'tables.dart';
import 'time_convert.dart';

// ---------------------------------------------------------------------------
// Sensitivity
// ---------------------------------------------------------------------------

class TimeSensitivity {
  const TimeSensitivity({
    required this.window,
    required this.ascendantSigns,
    required this.ascendantRange,
    required this.houseChanges,
    required this.navamsaLagnaSigns,
    required this.moonNakshatraChanges,
    required this.notes,
  });

  final Duration window;

  /// Distinct lagna signs across the window.
  final List<int> ascendantSigns;

  /// How many degrees the ascendant travels.
  final double ascendantRange;

  /// Grahas that change house somewhere in the window.
  final List<String> houseChanges;

  final List<int> navamsaLagnaSigns;

  /// True when the Moon crosses a nakshatra boundary — which would move every
  /// dasha date in the life.
  final bool moonNakshatraChanges;

  final List<String> notes;

  bool get isStable =>
      ascendantSigns.length == 1 && houseChanges.isEmpty && !moonNakshatraChanges;
}

/// What a birth time's uncertainty actually costs.
TimeSensitivity sensitivityOf(
  BirthInput input, {
  Duration window = const Duration(minutes: 30),
  ChartSettings settings = const ChartSettings(),
  int samples = 21,
}) {
  final centre = input.localDateTime;
  final signsSeen = <int>{};
  final navamsaSeen = <int>{};
  final nakshatraSeen = <int>{};
  final housesByPlanet = <String, Set<int>>{};
  var minAsc = 360.0;
  var maxAsc = 0.0;

  for (var i = 0; i < samples; i++) {
    final offset = window.inMilliseconds * (i / (samples - 1) - 0.5);
    final at = centre.add(Duration(milliseconds: offset.round()));
    final candidate = input.copyWith(localDateTime: at);
    final chart = buildChart(candidate, toUtc(candidate), settings: settings);

    signsSeen.add(signIndex(chart.lagnaSidereal));
    navamsaSeen.add(chart.navamsaLagna);
    nakshatraSeen.add(nakshatraOf(chart.graha('Moon').siderealLon).index);

    // Track the ascendant's travel on the short arc, so a window that
    // straddles 0° Aries does not report a 360° range.
    final relative = norm180(chart.lagnaSidereal - _reference(input, settings));
    if (relative < minAsc) minAsc = relative;
    if (relative > maxAsc) maxAsc = relative;

    for (final g in chart.grahas) {
      if (g.name == 'Lagna') continue;
      housesByPlanet.putIfAbsent(g.name, () => {}).add(g.house);
    }
  }

  final moving = <String>[
    for (final e in housesByPlanet.entries)
      if (e.value.length > 1) e.key,
  ];

  final notes = <String>[];
  if (signsSeen.length == 1) {
    notes.add(
      'The lagna stays in ${signs[signsSeen.first].name} across the whole '
      'window, so the rising sign is not in doubt — only its degree.',
    );
  } else {
    notes.add(
      'The lagna crosses ${signsSeen.length} signs in this window: '
      '${signsSeen.map((s) => signs[s].name).join(', ')}. Until that is '
      'settled, nothing measured from the lagna can be relied on.',
    );
  }
  if (moving.isNotEmpty) {
    notes.add(
      '${moving.join(', ')} change house within the window. Those are the '
      'placements an event will have to decide.',
    );
  }
  if (nakshatraSeen.length > 1) {
    notes.add(
      'The Moon crosses a nakshatra boundary here, which changes the '
      'Vimshottari lord and moves every mahadasha date in the life. This is '
      'the most consequential thing in the window and the easiest to settle: '
      'ask what decade the person’s life changed.',
    );
  }
  if (navamsaSeen.length > 1) {
    notes.add(
      'The navamsa lagna changes across the window — ${navamsaSeen.length} '
      'possibilities. D9 is nine times as sensitive to the birth time as D1, '
      'which is what makes it useful for rectifying.',
    );
  }

  return TimeSensitivity(
    window: window,
    ascendantSigns: signsSeen.toList()..sort(),
    ascendantRange: (maxAsc - minAsc).abs(),
    houseChanges: moving,
    navamsaLagnaSigns: navamsaSeen.toList()..sort(),
    moonNakshatraChanges: nakshatraSeen.length > 1,
    notes: notes,
  );
}

double _reference(BirthInput input, ChartSettings settings) {
  final chart = buildChart(input, toUtc(input), settings: settings);
  return chart.lagnaSidereal;
}

// ---------------------------------------------------------------------------
// Event fitting
// ---------------------------------------------------------------------------

/// A dated thing that happened, and what it is about.
class LifeEvent {
  const LifeEvent({
    required this.when,
    required this.description,
    required this.houses,
    this.weight = 1.0,
  });

  final DateTime when;
  final String description;

  /// The houses the event belongs to. Marriage is 7, a move is 4, a promotion
  /// is 10 — and the more precisely the houses are named, the sharper the fit.
  final List<int> houses;

  final double weight;
}

/// Common events, so a reader is not asked to know which houses to name.
const eventTemplates = <({String label, List<int> houses})>[
  (label: 'Marriage', houses: [7, 2, 11]),
  (label: 'Birth of a child', houses: [5, 9, 11]),
  (label: 'Moved house', houses: [4, 3, 12]),
  (label: 'Started a job', houses: [10, 6, 2]),
  (label: 'Lost a job', houses: [10, 6, 12]),
  (label: 'Started a business', houses: [10, 7, 11]),
  (label: 'Serious illness or surgery', houses: [6, 8, 12]),
  (label: 'Death of a parent', houses: [4, 9, 8]),
  (label: 'Emigrated', houses: [12, 9, 4]),
  (label: 'Graduated', houses: [4, 5, 9]),
  (label: 'Separation or divorce', houses: [7, 6, 12]),
  (label: 'Inheritance or windfall', houses: [8, 2, 11]),
];

class CandidateTime {
  const CandidateTime({
    required this.time,
    required this.score,
    required this.lagnaSign,
    required this.lagnaDegree,
    required this.matches,
  });

  final DateTime time;
  final double score;
  final int lagnaSign;
  final double lagnaDegree;

  /// One line per event, saying whether and why it fits.
  final List<String> matches;
}

class RectificationResult {
  const RectificationResult({
    required this.candidates,
    required this.sensitivity,
    required this.notes,
  });

  final List<CandidateTime> candidates;
  final TimeSensitivity sensitivity;
  final List<String> notes;

  CandidateTime? get best => candidates.isEmpty ? null : candidates.first;
}

/// Scores candidate birth times against dated events.
///
/// The scoring uses the three things that move fastest with the birth time:
/// which house the dasha lords rule from the lagna, whether solar-arc
/// directions contact an angle near the event, and whether the profected year
/// lands on a house the event belongs to.
RectificationResult rectify(
  BirthInput input,
  List<LifeEvent> events, {
  Duration window = const Duration(hours: 2),
  Duration step = const Duration(minutes: 4),
  ChartSettings settings = const ChartSettings(),
  int keep = 10,
}) {
  final centre = input.localDateTime;
  final half = window.inMilliseconds ~/ 2;
  final candidates = <CandidateTime>[];

  for (var offset = -half; offset <= half; offset += step.inMilliseconds) {
    final at = centre.add(Duration(milliseconds: offset));
    final candidate = input.copyWith(localDateTime: at);
    final utc = toUtc(candidate);
    final chart = buildChart(candidate, utc, settings: settings);

    var score = 0.0;
    final matches = <String>[];

    for (final event in events) {
      var eventScore = 0.0;
      final reasons = <String>[];

      // 1. The running dasha lords should rule or occupy a house the event
      //    belongs to.
      final md = chart.mahadashaAt(event.when.toUtc());
      final ad = chart.antardashaAt(event.when.toUtc());
      for (final (lord, weight) in [(md?.lord, 2.0), (ad?.lord, 1.5)]) {
        if (lord == null) continue;
        final row = chart.grahas.where((g) => g.name == lord).firstOrNull;
        if (row == null) continue;
        if (event.houses.contains(row.house)) {
          eventScore += weight;
          reasons.add('$lord sits in the ${ordinal(row.house)}');
        }
        // Houses the lord rules from this lagna.
        final lagnaSign = signIndex(chart.lagnaSidereal);
        for (final h in event.houses) {
          if (signs[(lagnaSign + h - 1) % 12].ruler == lord) {
            eventScore += weight * 0.75;
            reasons.add('$lord rules the ${ordinal(h)}');
          }
        }
      }

      // 2. A solar-arc direction onto an angle, which is the sharpest
      //    time-sensitive test there is.
      final arc = solarArc(chart, event.when.toUtc(), orb: 1.0);
      final angular = arc.contacts.where((c) =>
          c.contains('MC') || c.contains('Lagna')).toList();
      if (angular.isNotEmpty) {
        eventScore += 2.0;
        reasons.add('solar arc contacts an angle');
      }

      // 3. The profected year should land on a house the event belongs to.
      final profection = annualProfection(chart, event.when.toUtc());
      if (event.houses.contains(profection.house)) {
        eventScore += 1.5;
        reasons.add('the year profects to the ${ordinal(profection.house)}');
      }

      score += eventScore * event.weight;
      if (reasons.isNotEmpty) {
        matches.add('${event.description}: ${reasons.join(', ')}.');
      }
    }

    candidates.add(CandidateTime(
      time: at,
      score: score,
      lagnaSign: signIndex(chart.lagnaSidereal),
      lagnaDegree: chart.lagnaSidereal % 30,
      matches: matches,
    ));
  }

  candidates.sort((a, b) => b.score.compareTo(a.score));

  final sensitivity =
      sensitivityOf(input, window: window, settings: settings);

  final notes = <String>[
    'This is a ranking, not an answer. Rectification is a judgment, and a tool '
        'that hands back one time invites it to be trusted more than it should '
        'be.',
    'Only the fast-moving tests are scored — the dasha lords’ houses, solar '
        'arc onto the angles, and the profected year. Anything that does not '
        'move with the birth time cannot help here, however striking it looks.',
    if (events.length < 3)
      'Three events is the practical minimum, and five or more is better. With '
          '${events.length} the ranking is suggestive at best.',
    if (sensitivity.isStable)
      'Note that the chart barely changes across this window, so no amount of '
          'event fitting will separate the candidates. Widen the window.',
  ];

  return RectificationResult(
    candidates: candidates.take(keep).toList(),
    sensitivity: sensitivity,
    notes: notes,
  );
}

/// The ascendant at a given moment, for a live slider.
///
/// Cheap enough to call on every frame: it places one body and solves the
/// angles rather than building a whole chart.
({int sign, double degree, int navamsa}) ascendantAt(
  BirthInput input,
  DateTime local, {
  ChartSettings settings = const ChartSettings(),
}) {
  final candidate = input.copyWith(localDateTime: local);
  final sky = computeSky(
    utc: toUtc(candidate),
    latitude: input.place.latitude,
    longitudeEast: input.place.longitude,
    settings: settings,
    bodyNames: const ['Sun'],
  );
  final lagna = sky.siderealAscendant;
  return (
    sign: signIndex(lagna),
    degree: lagna % 30,
    navamsa: navamsaSign(lagna),
  );
}

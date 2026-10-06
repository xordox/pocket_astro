/// The transit timeline.
///
/// Gap G-28. The gochara engine judged one instant — where the slow grahas
/// stand right now. That answers "what is happening" and cannot answer "when",
/// which is the question people actually book consultations about.
///
/// This module searches a date range and returns dated events:
///
///   * exact contacts between a transiting body and a natal point, solved to
///     the minute rather than reported as "within orb";
///   * **stations**, direct and retrograde;
///   * **triple passes** — the three-contact shape a retrograde loop makes
///     over a natal point, which is the *story* of a transit: contact,
///     retreat, resolution. Without station detection it cannot be told at all,
///     which is why this depended on G-01;
///   * **ingresses**, tropical and sidereal;
///   * lunations and eclipses (G-35);
///   * sign and nakshatra changes for the Vedic side.
///
/// Everything is found by bracketing a sign change in a continuous function
/// and bisecting. Slower than a closed form and immune to the class of bug
/// where an event is missed because the step size stepped over it.
library;

import 'dart:math' as math;

import '../domain/models.dart';
import 'astro/ephemeris.dart';
import 'astro/units.dart';
import 'aspects.dart';
import 'tables.dart';

/// What kind of thing happened.
enum TransitEventKind {
  aspect,
  ingress,
  station,
  nakshatraChange,
  newMoon,
  fullMoon,
  eclipseSolar,
  eclipseLunar,
  combustion,
}

class TransitEvent {
  const TransitEvent({
    required this.kind,
    required this.at,
    required this.body,
    required this.title,
    required this.detail,
    this.target = '',
    this.aspect = '',
    this.pass = 0,
    this.passesTotal = 0,
    this.retrograde = false,
  });

  final TransitEventKind kind;

  /// Exact instant, UTC, solved to better than a minute.
  final DateTime at;

  final String body;
  final String title;
  final String detail;

  /// The natal point contacted, for aspects.
  final String target;
  final String aspect;

  /// Which pass of a multi-pass transit this is, 1-based. Zero when the
  /// transit only perfects once.
  final int pass;
  final int passesTotal;

  final bool retrograde;

  bool get isMultiPass => passesTotal > 1;
}

/// The bodies worth tracking against a natal chart, and how wide a net to cast.
const _transitBodies = [
  'Jupiter', 'Saturn', 'Uranus', 'Neptune', 'Pluto', 'Rahu', 'Mars', 'Chiron',
];

const _natalPoints = [
  'Sun', 'Moon', 'Mercury', 'Venus', 'Mars', 'Jupiter', 'Saturn',
  'Uranus', 'Neptune', 'Pluto', 'Lagna', 'Rahu',
];

double _longitudeOf(String body, DateTime at) {
  final sky = computeSky(
    utc: at,
    latitude: 0,
    longitudeEast: 0,
    bodyNames: [body],
  );
  return sky.bodies[body]!.longitude;
}

double _speedOf(String body, DateTime at) {
  final sky = computeSky(
    utc: at, latitude: 0, longitudeEast: 0, bodyNames: [body]);
  return sky.bodies[body]!.speed;
}

/// Bisects a sign change of [f] between two instants.
DateTime _bisect(
  double Function(DateTime) f,
  DateTime lo,
  DateTime hi, {
  int iterations = 48,
}) {
  var a = lo;
  var b = hi;
  final fa = f(a);
  for (var i = 0; i < iterations; i++) {
    final mid = a.add(Duration(
        microseconds: b.difference(a).inMicroseconds ~/ 2));
    final fm = f(mid);
    if (fm == 0) return mid;
    if ((fa < 0) == (fm < 0)) {
      a = mid;
    } else {
      b = mid;
    }
  }
  return a.add(Duration(microseconds: b.difference(a).inMicroseconds ~/ 2));
}

/// How fine a comb to run over the range, per body.
Duration _stepFor(String body) => switch (body) {
      'Moon' => const Duration(hours: 2),
      'Mercury' || 'Venus' || 'Sun' => const Duration(days: 1),
      'Mars' => const Duration(days: 2),
      _ => const Duration(days: 4),
    };

// ---------------------------------------------------------------------------
// Exact aspect contacts
// ---------------------------------------------------------------------------

/// Every exact contact between a transiting body and the natal chart.
///
/// Multi-pass transits are grouped, so the caller can say "Pluto squares your
/// Sun three times: 3 March, 12 August, 19 January" rather than reporting
/// three unrelated events.
List<TransitEvent> transitAspects(
  NatalChart chart, {
  required DateTime from,
  required DateTime to,
  List<String> bodies = _transitBodies,
  List<String> points = _natalPoints,
  List<AspectDef> aspects = majorAspects,
}) {
  final natal = {
    for (final g in chart.grahas)
      if (points.contains(g.name)) g.name: g.tropicalLon,
  };

  final raw = <TransitEvent>[];

  for (final body in bodies) {
    final step = _stepFor(body);
    for (final entry in natal.entries) {
      for (final def in aspects) {
        final targetLon = norm360(entry.value + def.angle);

        double gap(DateTime t) => norm180(_longitudeOf(body, t) - targetLon);

        var cursor = from;
        var previous = gap(cursor);
        while (cursor.isBefore(to)) {
          final next = cursor.add(step);
          final current = gap(next);
          // A crossing, but not the 180-degree wrap.
          if (previous.sign != current.sign &&
              (previous.abs() + current.abs()) < 90) {
            final exact = _bisect(gap, cursor, next);
            raw.add(TransitEvent(
              kind: TransitEventKind.aspect,
              at: exact,
              body: body,
              target: entry.key,
              aspect: def.name,
              retrograde: _speedOf(body, exact) < 0,
              title: 'Transiting $body ${def.name} natal ${entry.key}',
              detail: '',
            ));
          }
          previous = current;
          cursor = next;
        }
      }
    }
  }

  return _groupPasses(raw);
}

/// Groups repeated contacts of the same pair into numbered passes.
///
/// A retrograde loop produces three hits on the same point within about a
/// year. Presented flat they look like three separate events; presented as
/// passes they are one story with a beginning, a retreat and a resolution.
List<TransitEvent> _groupPasses(List<TransitEvent> events) {
  final byPair = <String, List<TransitEvent>>{};
  for (final e in events) {
    byPair.putIfAbsent('${e.body}|${e.target}|${e.aspect}', () => []).add(e);
  }

  final out = <TransitEvent>[];
  for (final group in byPair.values) {
    group.sort((a, b) => a.at.compareTo(b.at));
    // Contacts more than eighteen months apart are separate visits, not passes
    // of one loop.
    final clusters = <List<TransitEvent>>[];
    for (final e in group) {
      if (clusters.isEmpty ||
          e.at.difference(clusters.last.last.at).inDays > 550) {
        clusters.add([e]);
      } else {
        clusters.last.add(e);
      }
    }
    for (final cluster in clusters) {
      for (var i = 0; i < cluster.length; i++) {
        final e = cluster[i];
        final total = cluster.length;
        out.add(TransitEvent(
          kind: e.kind,
          at: e.at,
          body: e.body,
          target: e.target,
          aspect: e.aspect,
          retrograde: e.retrograde,
          pass: total > 1 ? i + 1 : 0,
          passesTotal: total,
          title: e.title,
          detail: total > 1
              ? 'Pass ${i + 1} of $total${e.retrograde ? ', retrograde' : ''}. '
                  '${_passNote(i, total)}'
              : 'A single exact contact.',
        ));
      }
    }
  }
  out.sort((a, b) => a.at.compareTo(b.at));
  return out;
}

String _passNote(int index, int total) {
  if (total < 2) return '';
  if (index == 0) return 'The opening contact — the theme arrives.';
  if (index == total - 1) return 'The closing contact — where it settles.';
  return 'The retrograde pass — the theme is reconsidered rather than advanced.';
}

// ---------------------------------------------------------------------------
// Stations
// ---------------------------------------------------------------------------

/// Every station in the range.
///
/// A station is where a planet's longitude speed crosses zero. Practitioners
/// treat the days either side as the loudest part of a transit, and the app
/// could not find them at all until speed existed.
List<TransitEvent> stations({
  required DateTime from,
  required DateTime to,
  List<String> bodies = const [
    'Mercury', 'Venus', 'Mars', 'Jupiter', 'Saturn', 'Uranus', 'Neptune', 'Pluto',
  ],
}) {
  final out = <TransitEvent>[];
  for (final body in bodies) {
    final step = body == 'Mercury' ? const Duration(days: 1) : const Duration(days: 2);
    var cursor = from;
    var previous = _speedOf(body, cursor);
    while (cursor.isBefore(to)) {
      final next = cursor.add(step);
      final current = _speedOf(body, next);
      if (previous.sign != current.sign) {
        final exact = _bisect((t) => _speedOf(body, t), cursor, next, iterations: 40);
        final turningRetrograde = previous > 0;
        final lon = _longitudeOf(body, exact);
        out.add(TransitEvent(
          kind: TransitEventKind.station,
          at: exact,
          body: body,
          retrograde: turningRetrograde,
          title: '$body stations '
              '${turningRetrograde ? 'retrograde' : 'direct'}',
          detail: 'At ${formatDms(lon)} ${signs[signIndex(lon)].name}. '
              '${turningRetrograde ? 'The next few weeks revisit rather than advance this ground.' : 'What stalled here begins to move again.'}',
        ));
      }
      previous = current;
      cursor = next;
    }
  }
  out.sort((a, b) => a.at.compareTo(b.at));
  return out;
}

// ---------------------------------------------------------------------------
// Ingresses
// ---------------------------------------------------------------------------

/// Sign changes, tropical or sidereal.
///
/// Sidereal ingresses fall on different dates from tropical ones — that is
/// what the ayanamsa *is* — so the mode has to be explicit rather than assumed.
List<TransitEvent> ingresses({
  required DateTime from,
  required DateTime to,
  List<String> bodies = const [
    'Sun', 'Mercury', 'Venus', 'Mars', 'Jupiter', 'Saturn',
    'Uranus', 'Neptune', 'Pluto', 'Rahu',
  ],
  ChartSettings settings = const ChartSettings(),
  bool sidereal = true,
}) {
  final out = <TransitEvent>[];
  for (final body in bodies) {
    final step = _stepFor(body);
    double lonAt(DateTime t) {
      final sky = computeSky(
        utc: t, latitude: 0, longitudeEast: 0,
        settings: settings, bodyNames: [body]);
      return sidereal ? sky.sidereal(body) : sky.bodies[body]!.longitude;
    }

    var cursor = from;
    var previousSign = signIndex(lonAt(cursor));
    while (cursor.isBefore(to)) {
      final next = cursor.add(step);
      final currentSign = signIndex(lonAt(next));
      if (currentSign != previousSign) {
        final boundary = currentSign * 30.0;
        final exact = _bisect(
          (t) => norm180(lonAt(t) - boundary),
          cursor,
          next,
        );
        out.add(TransitEvent(
          kind: TransitEventKind.ingress,
          at: exact,
          body: body,
          retrograde: _speedOf(body, exact) < 0,
          title: '$body enters ${signs[currentSign].name}',
          detail: sidereal ? 'Sidereal ingress.' : 'Tropical ingress.',
        ));
        previousSign = currentSign;
      }
      cursor = next;
    }
  }
  out.sort((a, b) => a.at.compareTo(b.at));
  return out;
}

/// Nakshatra changes — the Vedic counterpart of an ingress, and finer grained.
List<TransitEvent> nakshatraChanges({
  required DateTime from,
  required DateTime to,
  List<String> bodies = const ['Sun', 'Jupiter', 'Saturn', 'Rahu'],
  ChartSettings settings = const ChartSettings(),
}) {
  final out = <TransitEvent>[];
  for (final body in bodies) {
    final step = _stepFor(body);
    double lonAt(DateTime t) => computeSky(
          utc: t, latitude: 0, longitudeEast: 0,
          settings: settings, bodyNames: [body],
        ).sidereal(body);

    var cursor = from;
    var previous = nakshatraOf(lonAt(cursor)).index;
    while (cursor.isBefore(to)) {
      final next = cursor.add(step);
      final current = nakshatraOf(lonAt(next)).index;
      if (current != previous) {
        final boundary = current * nakshatraWidth;
        final exact =
            _bisect((t) => norm180(lonAt(t) - boundary), cursor, next);
        out.add(TransitEvent(
          kind: TransitEventKind.nakshatraChange,
          at: exact,
          body: body,
          title: '$body enters ${nakshatras[current].name}',
          detail: 'Lord: ${nakshatras[current].lord}. '
              '${nakshatras[current].meaning}.',
        ));
        previous = current;
      }
      cursor = next;
    }
  }
  out.sort((a, b) => a.at.compareTo(b.at));
  return out;
}

// ---------------------------------------------------------------------------
// Lunations and eclipses (G-35)
// ---------------------------------------------------------------------------

/// New and full Moons, with eclipses picked out of them.
///
/// An eclipse is a lunation near a node. The latitude test is what separates
/// the two, and it needed the Moon's ecliptic latitude to survive the pipeline
/// (G-08). Eclipse seasons are the loudest thing in a modern forecast and the
/// engine previously had no concept of them.
List<TransitEvent> lunations({
  required DateTime from,
  required DateTime to,
}) {
  final out = <TransitEvent>[];
  const step = Duration(hours: 12);

  double elongation(DateTime t) {
    final sky = computeSky(
      utc: t, latitude: 0, longitudeEast: 0,
      bodyNames: const ['Sun', 'Moon']);
    return norm180(sky.bodies['Moon']!.longitude - sky.bodies['Sun']!.longitude);
  }

  double opposition(DateTime t) {
    final sky = computeSky(
      utc: t, latitude: 0, longitudeEast: 0,
      bodyNames: const ['Sun', 'Moon']);
    return norm180(
        sky.bodies['Moon']!.longitude - sky.bodies['Sun']!.longitude - 180);
  }

  for (final (f, kind) in [
    (elongation, TransitEventKind.newMoon),
    (opposition, TransitEventKind.fullMoon),
  ]) {
    var cursor = from;
    var previous = f(cursor);
    while (cursor.isBefore(to)) {
      final next = cursor.add(step);
      final current = f(next);
      if (previous.sign != current.sign && (previous.abs() + current.abs()) < 90) {
        final exact = _bisect(f, cursor, next);
        final sky = computeSky(
          utc: exact, latitude: 0, longitudeEast: 0,
          bodyNames: const ['Sun', 'Moon']);
        final lat = sky.bodies['Moon']!.latitude.abs();
        final lon = sky.bodies['Moon']!.longitude;

        // Eclipse limits: a solar eclipse needs the Moon within about 1.5° of
        // the ecliptic at conjunction, a lunar one within about 1.0° at
        // opposition.
        final isNew = kind == TransitEventKind.newMoon;
        final limit = isNew ? 1.57 : 1.05;
        final eclipse = lat <= limit;

        out.add(TransitEvent(
          kind: eclipse
              ? (isNew
                  ? TransitEventKind.eclipseSolar
                  : TransitEventKind.eclipseLunar)
              : kind,
          at: exact,
          body: 'Moon',
          title: eclipse
              ? (isNew ? 'Solar eclipse' : 'Lunar eclipse')
              : (isNew ? 'New Moon' : 'Full Moon'),
          detail: '${formatDms(lon)} ${signs[signIndex(lon)].name}'
              '${eclipse ? ' — the Moon is ${lat.toStringAsFixed(2)}° from the node, inside the eclipse limit.' : '.'}',
        ));
      }
      previous = current;
      cursor = next;
    }
  }

  out.sort((a, b) => a.at.compareTo(b.at));
  return out;
}

// ---------------------------------------------------------------------------
// One timeline
// ---------------------------------------------------------------------------

class TransitTimeline {
  const TransitTimeline({
    required this.from,
    required this.to,
    required this.events,
  });
  final DateTime from;
  final DateTime to;
  final List<TransitEvent> events;

  List<TransitEvent> get multiPass =>
      events.where((e) => e.isMultiPass && e.pass == 1).toList();

  List<TransitEvent> ofKind(TransitEventKind kind) =>
      events.where((e) => e.kind == kind).toList();

  /// Grouped by calendar month, which is how a forecast is read.
  Map<String, List<TransitEvent>> get byMonth {
    final out = <String, List<TransitEvent>>{};
    for (final e in events) {
      final key = '${e.at.year}-${e.at.month.toString().padLeft(2, '0')}';
      out.putIfAbsent(key, () => []).add(e);
    }
    return out;
  }
}

/// The whole timeline for a chart over a window.
///
/// Costs real work — every event is solved by bisection — so the default
/// window is a year and the caller is expected to pick deliberately.
TransitTimeline buildTimeline(
  NatalChart chart, {
  DateTime? from,
  Duration span = const Duration(days: 365),
  bool includeIngresses = true,
  bool includeLunations = true,
  bool includeStations = true,
}) {
  final start = from ?? DateTime.now().toUtc();
  final end = start.add(span);
  final events = <TransitEvent>[
    ...transitAspects(chart, from: start, to: end),
    if (includeStations) ...stations(from: start, to: end),
    if (includeIngresses)
      ...ingresses(from: start, to: end, settings: chart.settings),
    if (includeLunations) ...lunations(from: start, to: end),
  ];
  events.sort((a, b) => a.at.compareTo(b.at));
  return TransitTimeline(from: start, to: end, events: events);
}

/// The next exact contact of a named transit, if there is one in the window.
TransitEvent? nextContact(
  NatalChart chart,
  String body,
  String natalPoint,
  String aspectName, {
  DateTime? from,
  Duration within = const Duration(days: 1460),
}) {
  final start = from ?? DateTime.now().toUtc();
  final hits = transitAspects(
    chart,
    from: start,
    to: start.add(within),
    bodies: [body],
    points: [natalPoint],
    aspects: allAspects.where((a) => a.name == aspectName).toList(),
  );
  return hits.isEmpty ? null : hits.first;
}

/// Saturn returns, Jupiter returns and the rest (G-27, in part).
///
/// A return is a transiting body arriving back at its natal longitude — the
/// zero-orb conjunction. The Saturn return is the one transit a general
/// audience knows by name, and the app could not date it.
List<TransitEvent> planetaryReturns(
  NatalChart chart,
  String body, {
  DateTime? from,
  Duration within = const Duration(days: 365 * 90),
}) {
  final natal = chart.grahas.where((g) => g.name == body).firstOrNull;
  if (natal == null) return const [];
  final start = from ?? chart.utc;
  final end = start.add(within);
  final step = _stepFor(body);

  double gap(DateTime t) => norm180(_longitudeOf(body, t) - natal.tropicalLon);

  final out = <TransitEvent>[];
  var cursor = start;
  var previous = gap(cursor);

  // A search that begins at birth sits on the answer already: the body is at
  // its natal degree by definition, so the very first step reports a "return"
  // at age zero. Wait until it has genuinely left the neighbourhood before
  // looking for crossings.
  var departed = previous.abs() > 10.0;

  while (cursor.isBefore(end)) {
    final next = cursor.add(step);
    final current = gap(next);
    if (!departed) {
      if (current.abs() > 10.0) departed = true;
      previous = current;
      cursor = next;
      continue;
    }
    if (previous.sign != current.sign && (previous.abs() + current.abs()) < 90) {
      final exact = _bisect(gap, cursor, next);
      final age = exact.difference(chart.utc).inDays / 365.2425;
      out.add(TransitEvent(
        kind: TransitEventKind.aspect,
        at: exact,
        body: body,
        target: body,
        aspect: 'return',
        title: '$body return',
        detail: 'Age ${age.toStringAsFixed(1)}. '
            '$body arrives back where it stood at birth.',
      ));
      departed = false;
    }
    previous = current;
    cursor = next;
  }
  return out;
}

/// Sade sati windows, dated rather than described.
///
/// The existing forecast could say "Saturn is in sade sati now". This says
/// when each phase began and when it ends, which is the question that gets
/// asked.
List<({DateTime start, DateTime end, String phase})> sadeSatiWindows(
  NatalChart chart, {
  DateTime? from,
  Duration within = const Duration(days: 365 * 60),
}) {
  final moon = chart.grahas.where((g) => g.name == 'Moon').firstOrNull;
  if (moon == null) return const [];
  final moonSign = signIndex(moon.siderealLon);
  final start = from ?? chart.utc;
  final end = start.add(within);

  final windows = <({DateTime start, DateTime end, String phase})>[];
  final phases = {
    (moonSign + 11) % 12: 'rising — the twelfth from the Moon',
    moonSign: 'peak — Saturn over the Moon itself',
    (moonSign + 1) % 12: 'setting — the second from the Moon',
  };

  DateTime? currentStart;
  String? currentPhase;
  var cursor = start;
  while (cursor.isBefore(end)) {
    final sky = computeSky(
      utc: cursor, latitude: 0, longitudeEast: 0,
      settings: chart.settings, bodyNames: const ['Saturn']);
    final sign = signIndex(sky.sidereal('Saturn'));
    final phase = phases[sign];
    if (phase != currentPhase) {
      if (currentStart != null && currentPhase != null) {
        windows.add((start: currentStart, end: cursor, phase: currentPhase));
      }
      currentStart = phase == null ? null : cursor;
      currentPhase = phase;
    }
    cursor = cursor.add(const Duration(days: 10));
  }
  if (currentStart != null && currentPhase != null) {
    windows.add((start: currentStart, end: end, phase: currentPhase));
  }
  return windows;
}

/// The strongest transits running at an instant, ranked.
///
/// Useful on a "today" screen: not every exact hit, but what is actually
/// loudest right now.
List<AspectHit> currentTransitHits(
  NatalChart chart,
  DateTime at, {
  OrbPolicy policy = const OrbPolicy(),
}) {
  final sky = computeSky(
    utc: at,
    latitude: chart.input.place.latitude,
    longitudeEast: chart.input.place.longitude,
    settings: chart.settings,
  );

  final out = <AspectHit>[];
  for (final body in _transitBodies) {
    final t = sky.bodies[body];
    if (t == null) continue;
    for (final natal in chart.grahas) {
      if (!_natalPoints.contains(natal.name)) continue;
      final delta = separation(t.longitude, natal.tropicalLon);
      for (final def in majorAspects) {
        final maxOrb = policy.orbFor(def, body, natal.name) * 0.6;
        final orb = (delta - def.angle).abs();
        if (orb > maxOrb) continue;
        out.add(AspectHit(
          a: 't.$body',
          b: natal.name,
          name: def.name,
          angle: def.angle,
          orb: orb,
          maxOrb: maxOrb,
          kind: def.kind,
          applying: t.speed > 0
              ? norm180(natal.tropicalLon + def.angle - t.longitude) > 0
              : norm180(natal.tropicalLon + def.angle - t.longitude) < 0,
        ));
      }
    }
  }
  out.sort((a, b) => a.orb.compareTo(b.orb));
  return out;
}

/// Convenience: how many days until the next station of a body.
int? daysToNextStation(String body, {DateTime? from}) {
  final start = from ?? DateTime.now().toUtc();
  final found = stations(
    from: start, to: start.add(const Duration(days: 400)), bodies: [body]);
  if (found.isEmpty) return null;
  return math.max(0, found.first.at.difference(start).inDays);
}

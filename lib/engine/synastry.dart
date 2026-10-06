/// Western relationship astrology.
///
/// Gap G-37. Compatibility in this app was Ashtakoota and nothing else. The
/// koota score does not substitute: a client asking about their partner's
/// Venus square their Saturn is asking a question the app could not parse, and
/// relationship work is the highest-demand consultation category in the
/// Western market.
///
///   * **Synastry** — the cross-aspect grid, with house overlays both ways.
///   * **Composite** — the midpoint chart, which describes the relationship
///     as a third thing rather than two people compared.
///   * **Davison** — the real chart for the midpoint in time and space, which
///     unlike a composite is an actual moment with actual planets in it.
library;

import 'dart:math' as math;

import '../domain/models.dart';
import 'astro/ephemeris.dart';
import 'astro/houses.dart';
import 'astro/units.dart';
import 'aspects.dart';
import 'chart_builder.dart';
import 'tables.dart';

// ---------------------------------------------------------------------------
// Synastry
// ---------------------------------------------------------------------------

class SynastryHit {
  const SynastryHit({
    required this.fromA,
    required this.toB,
    required this.aspect,
    required this.orb,
    required this.maxOrb,
    required this.note,
  });
  final String fromA;
  final String toB;
  final String aspect;
  final double orb;
  final double maxOrb;
  final String note;

  double get strength => (1 - orb / maxOrb).clamp(0.0, 1.0);
}

class HouseOverlay {
  const HouseOverlay({
    required this.planet,
    required this.house,
    required this.note,
  });
  final String planet;
  final int house;
  final String note;
}

class SynastryReport {
  const SynastryReport({
    required this.nameA,
    required this.nameB,
    required this.hits,
    required this.aInB,
    required this.bInA,
    required this.summary,
    required this.score,
  });

  final String nameA;
  final String nameB;

  /// A's planets aspecting B's, and the reverse.
  final List<SynastryHit> hits;

  /// Where A's planets fall in B's houses, and the reverse. House overlays are
  /// what decide the *area of life* a contact plays out in, and they are
  /// asymmetric — which is the point.
  final List<HouseOverlay> aInB;
  final List<HouseOverlay> bInA;

  final List<String> summary;

  /// A rough 0–100 reading, deliberately blunt. Relationship astrology does
  /// not reduce to a number and the app says so rather than implying it does.
  final int score;

  List<SynastryHit> get strongest {
    final copy = [...hits];
    copy.sort((a, b) => b.strength.compareTo(a.strength));
    return copy.take(12).toList();
  }
}

/// Which cross-contacts the tradition reads as the load-bearing ones.
const _significantPairs = <String, String>{
  'Sun|Moon': 'The classic marriage contact — one person’s vitality meeting '
      'the other’s instinct.',
  'Sun|Venus': 'Warmth and attraction that does not need working at.',
  'Venus|Mars': 'Straightforward physical chemistry.',
  'Moon|Venus': 'Ease at home; the daily texture is affectionate.',
  'Moon|Saturn': 'One person steadies the other, or weighs on them. Both at '
      'different times.',
  'Venus|Saturn': 'Commitment, and the risk of duty replacing pleasure.',
  'Sun|Saturn': 'Authority in the relationship — respect, or a parent-child '
      'imbalance.',
  'Moon|Mars': 'Quick feeling, quick friction.',
  'Sun|Uranus': 'Excitement, and difficulty settling.',
  'Venus|Neptune': 'Idealisation. Beautiful, and worth checking against '
      'reality.',
  'Moon|Pluto': 'Depth and compulsion. Very hard to walk away from.',
  'Lagna|Venus': 'Immediate attraction on sight.',
  'Lagna|Saturn': 'A sobering presence — takes time to warm.',
};

String _noteFor(String a, String b, String aspect) {
  final harmonious = aspect == 'trine' || aspect == 'sextile';
  final key = _significantPairs['$a|$b'] ?? _significantPairs['$b|$a'];
  if (key == null) return '';
  final tone = aspect == 'conjunction'
      ? ' Fused, for better and worse.'
      : harmonious
          ? ' It flows here.'
          : ' It has to be worked at here.';
  return key + tone;
}

const _synastryBodies = [
  'Sun', 'Moon', 'Mercury', 'Venus', 'Mars', 'Jupiter', 'Saturn',
  'Uranus', 'Neptune', 'Pluto', 'Lagna', 'Chiron',
];

/// The full cross-aspect grid between two charts.
SynastryReport synastry(
  NatalChart a,
  NatalChart b, {
  OrbPolicy policy = const OrbPolicy(),
}) {
  final hits = <SynastryHit>[];

  for (final ga in a.grahas) {
    if (!_synastryBodies.contains(ga.name)) continue;
    for (final gb in b.grahas) {
      if (!_synastryBodies.contains(gb.name)) continue;
      final delta = separation(ga.tropicalLon, gb.tropicalLon);
      for (final def in policy.includeMinor ? allAspects : majorAspects) {
        // Synastry orbs are traditionally tighter than natal ones.
        final maxOrb = policy.orbFor(def, ga.name, gb.name) * 0.75;
        final orb = (delta - def.angle).abs();
        if (orb > maxOrb) continue;
        hits.add(SynastryHit(
          fromA: ga.name,
          toB: gb.name,
          aspect: def.name,
          orb: orb,
          maxOrb: maxOrb,
          note: _noteFor(ga.name, gb.name, def.name),
        ));
      }
    }
  }
  hits.sort((x, y) => x.orb.compareTo(y.orb));

  final aInB = <HouseOverlay>[];
  final bInA = <HouseOverlay>[];
  if (!b.input.timeUnknown && b.sky != null) {
    for (final ga in a.grahas) {
      if (ga.name == 'Lagna' || !_synastryBodies.contains(ga.name)) continue;
      final house = b.sky!.western.houseOf(ga.tropicalLon);
      aInB.add(HouseOverlay(
        planet: ga.name,
        house: house,
        note: '${a.input.name}’s ${ga.name} lands in ${b.input.name}’s '
            '${ordinal(house)} house — ${houseTopics[house]}.',
      ));
    }
  }
  if (!a.input.timeUnknown && a.sky != null) {
    for (final gb in b.grahas) {
      if (gb.name == 'Lagna' || !_synastryBodies.contains(gb.name)) continue;
      final house = a.sky!.western.houseOf(gb.tropicalLon);
      bInA.add(HouseOverlay(
        planet: gb.name,
        house: house,
        note: '${b.input.name}’s ${gb.name} lands in ${a.input.name}’s '
            '${ordinal(house)} house — ${houseTopics[house]}.',
      ));
    }
  }

  // A blunt score, with its bluntness stated.
  var positive = 0.0;
  var negative = 0.0;
  for (final h in hits) {
    final weight = h.strength *
        (const {'Sun', 'Moon', 'Venus', 'Lagna'}.contains(h.fromA) ? 1.5 : 1.0);
    if (h.aspect == 'trine' || h.aspect == 'sextile') {
      positive += weight;
    } else if (h.aspect == 'square' || h.aspect == 'opposition') {
      negative += weight * 0.7;
    } else if (h.aspect == 'conjunction') {
      positive += weight * 0.6;
      negative += weight * 0.2;
    }
  }
  final raw = positive + negative == 0
      ? 50
      : (positive / (positive + negative) * 100).round();
  final score = raw.clamp(5, 95);

  final summary = <String>[
    'Synastry compares two charts as two people. The composite and Davison '
        'charts below describe the relationship itself, which is a different '
        'question and often a different answer.',
    if (hits.where((h) => h.note.isNotEmpty).isNotEmpty)
      'Load-bearing contacts: '
          '${hits.where((h) => h.note.isNotEmpty).take(4).map((h) => '${h.fromA}–${h.toB} ${h.aspect}').join(', ')}.',
    'The number is a summary of aspect tone, not a verdict. Squares between '
        'charts are where two people have to negotiate, and long relationships '
        'usually have several.',
  ];

  return SynastryReport(
    nameA: a.input.name,
    nameB: b.input.name,
    hits: hits,
    aInB: aInB,
    bInA: bInA,
    summary: summary,
    score: score,
  );
}

// ---------------------------------------------------------------------------
// Composite
// ---------------------------------------------------------------------------

class CompositeChart {
  const CompositeChart({
    required this.positions,
    required this.ascendant,
    required this.midheaven,
    required this.aspects,
    required this.method,
  });
  final Map<String, double> positions;
  final double ascendant;
  final double midheaven;
  final List<AspectHit> aspects;
  final String method;
}

/// The midpoint composite.
///
/// Each point is the midpoint of the two natal positions, taken on the short
/// arc. The angles are the midpoints of the angles, which is the "derived
/// ascendant" convention; the alternative is to recompute them from the
/// composite midheaven, and saying which was used is part of G-46's habit.
CompositeChart compositeChart(NatalChart a, NatalChart b) {
  final positions = <String, double>{};
  final byB = {for (final g in b.grahas) g.name: g};

  for (final ga in a.grahas) {
    final gb = byB[ga.name];
    if (gb == null) continue;
    final diff = norm180(gb.tropicalLon - ga.tropicalLon);
    positions[ga.name] = norm360(ga.tropicalLon + diff / 2);
  }

  final ascDiff = norm180(b.lagnaTropical - a.lagnaTropical);
  final asc = norm360(a.lagnaTropical + ascDiff / 2);
  final mcDiff = norm180(b.mcTropical - a.mcTropical);
  final mc = norm360(a.mcTropical + mcDiff / 2);

  final rows = [
    for (final e in positions.entries)
      GrahaRow(
        name: e.key,
        tropicalLon: e.value,
        siderealLon: e.value,
        sign: signs[signIndex(e.value)].name,
        house: 0,
        nakshatra: nakshatraOf(e.value).name,
        pada: padaOf(e.value),
        dignity: '',
        westernHouse: 0,
      ),
  ];

  return CompositeChart(
    positions: positions,
    ascendant: asc,
    midheaven: mc,
    aspects: westernAspects(rows),
    method: 'Midpoint composite, with derived angles taken as the midpoints of '
        'the two ascendants and midheavens.',
  );
}

// ---------------------------------------------------------------------------
// Davison
// ---------------------------------------------------------------------------

/// The Davison relationship chart — a real chart for the midpoint in time and
/// space between two births.
///
/// Unlike a composite this is an actual moment with actual planets in it, so
/// it can be progressed and transited like any other chart. That is the whole
/// argument for preferring it.
NatalChart davisonChart(NatalChart a, NatalChart b) {
  final midMillis = (a.utc.millisecondsSinceEpoch +
          b.utc.millisecondsSinceEpoch) ~/
      2;
  final mid = DateTime.fromMillisecondsSinceEpoch(midMillis, isUtc: true);

  final lat = (a.input.place.latitude + b.input.place.latitude) / 2;
  // Longitudes have to be averaged on the short arc, or two places either side
  // of the date line produce a midpoint in the wrong hemisphere.
  final lonDiff = norm180(b.input.place.longitude - a.input.place.longitude);
  final lon = norm180(a.input.place.longitude + lonDiff / 2);

  final place = Place(
    name: 'Davison midpoint',
    region: '${a.input.place.name} / ${b.input.place.name}',
    latitude: lat,
    longitude: lon,
    timezone: 'UTC',
  );

  final input = BirthInput(
    id: '${a.input.id}-${b.input.id}-davison',
    name: '${a.input.name} & ${b.input.name}',
    localDateTime: mid,
    place: place,
    timeSource: TimeSource.hospital,
    notes: 'Davison relationship chart: the midpoint in time and space between '
        'the two births. A real moment, so it can be progressed and transited.',
  );

  return buildChart(input, mid, settings: a.settings);
}

// ---------------------------------------------------------------------------
// Relationship timing
// ---------------------------------------------------------------------------

/// How far apart two charts' angles are — a quick proxy for whether two people
/// were born at compatible times of day, which affects every house overlay.
double angleDistance(NatalChart a, NatalChart b) =>
    separation(a.lagnaTropical, b.lagnaTropical);

/// The composite chart's own houses, cast for a chosen location.
///
/// A composite has no birthplace of its own, so the honest thing is to make
/// the reader choose one and say that they did.
HouseCusps compositeHouses(
  CompositeChart composite,
  Place at,
  DateTime when, {
  HouseSystem system = HouseSystem.placidus,
}) {
  final sky = computeSky(
    utc: when,
    latitude: at.latitude,
    longitudeEast: at.longitude,
    bodyNames: const ['Sun'],
  );
  return computeHouses(
    ramc: sky.localSiderealTime,
    latitude: at.latitude,
    obliquity: sky.obliquity,
    system: system,
  );
}

/// Simple textual read of the strongest overlays, for the summary card.
List<String> overlayHighlights(SynastryReport report) {
  final out = <String>[];
  for (final o in [...report.aInB, ...report.bInA]) {
    if (const {1, 5, 7, 8, 10}.contains(o.house) &&
        const {'Sun', 'Moon', 'Venus', 'Mars', 'Saturn'}.contains(o.planet)) {
      out.add(o.note);
    }
  }
  return out.take(math.min(6, out.length)).toList();
}

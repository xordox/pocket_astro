/// Ashtakavarga: the bindu computation behind Charak's transit filter.
///
/// The benefic-point tables live in `assets/kb/ashtakavarga.json`, transcribed
/// from Charak, *Elements of Vedic Astrology*, ch. XXX. This file turns them
/// into numbers for an actual chart: the seven bhinnashtakavargas with their
/// prastara (which contributor gave each bindu), the sarvashtakavarga, the
/// kakshya a transiting graha occupies, and the transit verdicts that follow.
///
/// Charak's framing is kept throughout: ashtakavarga is a transit filter and is
/// subservient to the natal promise and the running dasha. It never creates an
/// event on its own.
library;

import '../domain/models.dart';
import 'kb.dart';
import 'tables.dart';

/// The seven grahas that have an ashtakavarga. Rahu and Ketu contribute
/// nothing and receive nothing (Charak XXX, point 1).
const avPlanets = ['Sun', 'Moon', 'Mars', 'Mercury', 'Jupiter', 'Venus', 'Saturn'];

/// The eight reference points a bindu can come from.
const avContributors = [...avPlanets, 'Lagna'];

/// Classical per-graha bindu totals. These are invariant: a contributor gives
/// a fixed number of points wherever it sits, so the totals never move.
const avExpectedTotals = <String, int>{
  'Sun': 48, 'Moon': 49, 'Mars': 39, 'Mercury': 54,
  'Jupiter': 56, 'Venus': 52, 'Saturn': 39,
};

/// 337 across the seven bhinnashtakavargas.
const avSarvaTotal = 337;

/// Eight kakshyas of 3°45' fill each sign.
const kakshyaArcDeg = 3.75;

/// Fallback kakshya ownership, from 0° of every sign outward.
const _kakshyaOrderFallback = [
  'Saturn', 'Jupiter', 'Mars', 'Sun', 'Venus', 'Mercury', 'Moon', 'Lagna',
];

// ---------------------------------------------------------------------------
// Results
// ---------------------------------------------------------------------------

/// One graha's bhinnashtakavarga: bindus per sign, and who gave each one.
class Bhinna {
  Bhinna(this.planet, this.contributors);

  final String planet;

  /// Twelve sets, indexed by sign (0 = Aries). Each holds the contributors
  /// that placed a bindu in that sign — the prastara chart.
  final List<Set<String>> contributors;

  /// Bindus in a sign index (0 = Aries).
  int inSign(int sign) => contributors[sign % 12].length;

  /// Bindus in a whole-sign house counted from [lagnaSign].
  int inHouse(int house, int lagnaSign) =>
      inSign((lagnaSign + house - 1) % 12);

  List<int> get bySign => [for (var s = 0; s < 12; s++) inSign(s)];

  int get total => bySign.fold(0, (a, b) => a + b);
}

/// A transiting graha judged against its own bhinnashtakavarga.
class AvTransit {
  const AvTransit({
    required this.planet,
    required this.sign,
    required this.bindus,
    required this.houseFromLagna,
    required this.houseFromMoon,
    required this.verdict,
    required this.reading,
    required this.kakshyaOwner,
    required this.kakshyaHasBindu,
  });

  final String planet;
  final int sign;
  final int bindus;
  final int houseFromLagna;
  final int houseFromMoon;

  /// `delivers` (5+), `mixed` (4) or `withholds` (0-3).
  final String verdict;

  /// The classical result for this bindu count.
  final String reading;

  /// Which kakshya of the sign the graha currently occupies.
  final String kakshyaOwner;

  /// True when that kakshya's owner contributed a bindu here — the daily filter.
  final bool kakshyaHasBindu;

  String get line =>
      '$planet in ${signs[sign].name} holds $bindus bindu'
      '${bindus == 1 ? '' : 's'} in its own ashtakavarga '
      '(house $houseFromLagna from lagna, $houseFromMoon from the Moon): '
      '$verdict. $reading '
      'Kakshya of $kakshyaOwner${kakshyaHasBindu ? ' — with a bindu.' : ' — no bindu.'}';
}

/// The day-grade from how many transiting grahas sit in a kakshya with a bindu.
class KakshyaDay {
  const KakshyaDay({
    required this.score,
    required this.quality,
    required this.withBindu,
    required this.withoutBindu,
  });

  /// 0 to 7.
  final int score;
  final String quality;
  final List<String> withBindu;
  final List<String> withoutBindu;

  String get line =>
      '$score of 7 grahas transit a kakshya carrying a bindu. $quality'
      '${withBindu.isEmpty ? '' : ' With: ${withBindu.join(', ')}.'}'
      '${withoutBindu.isEmpty ? '' : ' Without: ${withoutBindu.join(', ')}.'}';
}

/// One of Charak's sarvashtakavarga house comparisons, evaluated.
class AvComparison {
  const AvComparison({required this.rule, required this.holds, required this.means});
  final String rule;
  final bool holds;
  final String means;
}

/// A chart's complete ashtakavarga.
class AshtakavargaChart {
  AshtakavargaChart({
    required this.bhinna,
    required this.lagnaSign,
    required this.moonSign,
    required this.natalSigns,
  });

  final Map<String, Bhinna> bhinna;
  final int lagnaSign;
  final int moonSign;

  /// Natal sign index of each of the seven grahas, for the dignity override.
  final Map<String, int> natalSigns;

  /// Sarvashtakavarga: the seven bhinnashtakavargas summed, by sign.
  List<int> get sarvaBySign => [
        for (var s = 0; s < 12; s++)
          avPlanets.fold(0, (a, p) => a + (bhinna[p]?.inSign(s) ?? 0)),
      ];

  int sarvaInSign(int sign) => sarvaBySign[sign % 12];

  int sarvaInHouse(int house) => sarvaInSign((lagnaSign + house - 1) % 12);

  int get sarvaTotal => sarvaBySign.fold(0, (a, b) => a + b);

  /// Houses whose sarva bindus beat the classical average of 28.
  List<int> get strongHouses => [
        for (var h = 1; h <= 12; h++)
          if (sarvaInHouse(h) > PredictionKb.current.sarvaAverage) h,
      ];

  List<int> get weakHouses => [
        for (var h = 1; h <= 12; h++)
          if (sarvaInHouse(h) < PredictionKb.current.sarvaAverage) h,
      ];

  /// The largest step between two adjacent houses. Charak XXX point 10: a
  /// quantum jump marks a real rise or fall as slow grahas cross that boundary.
  ({int fromHouse, int toHouse, int delta}) get biggestJump {
    var best = (fromHouse: 1, toHouse: 2, delta: 0);
    for (var h = 1; h <= 12; h++) {
      final next = h == 12 ? 1 : h + 1;
      final d = sarvaInHouse(next) - sarvaInHouse(h);
      if (d.abs() > best.delta.abs()) {
        best = (fromHouse: h, toHouse: next, delta: d);
      }
    }
    return best;
  }

  /// Bindus a graha holds in the sign it natally occupies.
  int ownBindus(String planet) {
    final sign = natalSigns[planet];
    if (sign == null) return 0;
    return bhinna[planet]?.inSign(sign) ?? 0;
  }

  /// Charak XXX points 7 and 8: dignity and bindus argue with each other.
  ///
  /// A strong graha sitting on few bindus loses much of its effect; a weak one
  /// on more than average keeps much of its efficacy. Four is the borderline
  /// in a bhinnashtakavarga. Returns null when dignity and bindus agree, so
  /// there is nothing to reconcile.
  String? dignityOverride(String planet, String dignity) {
    final sign = natalSigns[planet];
    if (sign == null) return null;
    final b = bhinna[planet]?.inSign(sign) ?? 0;
    final notes = PredictionKb.current.avDignityOverride;
    final borderline = PredictionKb.current.avMixedAt;
    if ((dignity == 'exalted' || dignity == 'own sign') && b < borderline) {
      return '$planet is $dignity in ${signs[sign].name} but holds only $b '
          'bindu${b == 1 ? '' : 's'} there. '
          '${notes['strong_planet_low_bindu'] ?? ''}';
    }
    if (dignity == 'debilitated' && b > borderline) {
      return '$planet is debilitated in ${signs[sign].name} yet holds $b '
          'bindus there. ${notes['weak_planet_high_bindu'] ?? ''}';
    }
    return null;
  }

  /// Evaluates Charak's sarvashtakavarga house comparisons against this chart.
  List<AvComparison> get comparisons {
    final raw = (PredictionKb.current.avComparisons);
    final avg = PredictionKb.current.sarvaAverage;
    final out = <AvComparison>[];
    for (final c in raw) {
      final rule = c['rule'] as String? ?? '';
      final means = c['means'] as String? ?? '';
      final holds = switch (rule) {
        'lagna_and_8_above_average' =>
          sarvaInHouse(1) > avg && sarvaInHouse(8) > avg,
        '11_above_10' => sarvaInHouse(11) > sarvaInHouse(10),
        '12_above_11' => sarvaInHouse(12) > sarvaInHouse(11),
        '2_above_12' => sarvaInHouse(2) > sarvaInHouse(12),
        '6_strong' => sarvaInHouse(6) > avg,
        '5_above_10_without_strong_11' =>
          sarvaInHouse(5) > sarvaInHouse(10) && sarvaInHouse(11) <= avg,
        _ => false,
      };
      out.add(AvComparison(rule: rule, holds: holds, means: means));
    }
    return out;
  }
}

// ---------------------------------------------------------------------------
// Computation
// ---------------------------------------------------------------------------

/// Computes the ashtakavarga for a built chart.
///
/// Returns null when the birth time is unknown: the lagna is one of the eight
/// contributors, so without it the totals cannot reach 337 and every threshold
/// in the technique — the average of 28, the 5-bindu transit rule — becomes
/// meaningless. PocketAstro withholds it rather than computing a seven-eighths
/// version that looks authoritative.
AshtakavargaChart? ashtakavargaFor(NatalChart chart) {
  if (chart.input.timeUnknown) return null;
  final lons = <String, double>{};
  for (final g in chart.grahas) {
    if (avPlanets.contains(g.name)) lons[g.name] = g.siderealLon;
  }
  return computeAshtakavarga(
    siderealLongitudes: lons,
    lagnaSidereal: chart.lagnaSidereal,
  );
}

/// Computes the ashtakavarga from raw sidereal longitudes.
///
/// Charak XXX point 1: the calculation runs on rashi (sign) positions, never on
/// bhava positions, even where a bhava chart differs from the rashi chart.
AshtakavargaChart? computeAshtakavarga({
  required Map<String, double> siderealLongitudes,
  required double lagnaSidereal,
}) {
  final table = PredictionKb.current.bhinnashtakavarga;
  if (table.isEmpty) return null;

  final lagnaSign = signIndex(lagnaSidereal);
  final signOfContributor = <String, int>{'Lagna': lagnaSign};
  for (final p in avPlanets) {
    final lon = siderealLongitudes[p];
    if (lon == null) return null; // an incomplete chart yields no ashtakavarga
    signOfContributor[p] = signIndex(lon);
  }

  final bhinna = <String, Bhinna>{};
  for (final subject in avPlanets) {
    final rows = table[subject];
    if (rows is! Map) return null;
    final contributors = List<Set<String>>.generate(12, (_) => <String>{});
    for (final contributor in avContributors) {
      final houses = rows[contributor];
      if (houses is! List) continue;
      final base = signOfContributor[contributor]!;
      for (final h in houses) {
        final house = (h as num).toInt();
        // The listed house is counted from the contributor's own sign, with
        // its own sign as the 1st.
        contributors[(base + house - 1) % 12].add(contributor);
      }
    }
    bhinna[subject] = Bhinna(subject, contributors);
  }

  return AshtakavargaChart(
    bhinna: bhinna,
    lagnaSign: lagnaSign,
    moonSign: signIndex(siderealLongitudes['Moon']!),
    natalSigns: {
      for (final p in avPlanets) p: signIndex(siderealLongitudes[p]!),
    },
  );
}

// ---------------------------------------------------------------------------
// Kakshya
// ---------------------------------------------------------------------------

/// Which kakshya of its sign a longitude falls in, 0 to 7 from 0° of the sign.
int kakshyaIndex(double siderealLon) =>
    ((siderealLon % 30.0) / kakshyaArcDeg).floor().clamp(0, 7);

/// The graha that owns that kakshya.
String kakshyaOwner(double siderealLon) {
  final order = PredictionKb.current.kakshyaOrder;
  final list = order.length == 8 ? order : _kakshyaOrderFallback;
  return list[kakshyaIndex(siderealLon)];
}

// ---------------------------------------------------------------------------
// Transit judgment
// ---------------------------------------------------------------------------

/// Judges one transiting graha against its own bhinnashtakavarga.
AvTransit? judgeTransit(
  AshtakavargaChart av,
  String planet,
  double transitSiderealLon,
) {
  final b = av.bhinna[planet];
  if (b == null) return null;
  final sign = signIndex(transitSiderealLon);
  final bindus = b.inSign(sign);
  final threshold = PredictionKb.current.avTransitThreshold;
  final mixedAt = PredictionKb.current.avMixedAt;
  final verdict = bindus >= threshold
      ? 'delivers'
      : bindus == mixedAt
          ? 'mixed'
          : 'withholds';
  final owner = kakshyaOwner(transitSiderealLon);
  return AvTransit(
    planet: planet,
    sign: sign,
    bindus: bindus,
    houseFromLagna: wholeSignHouse(av.lagnaSign, sign),
    houseFromMoon: wholeSignHouse(av.moonSign, sign),
    verdict: verdict,
    reading: PredictionKb.current.bhinnaReading(bindus),
    kakshyaOwner: owner,
    kakshyaHasBindu: b.contributors[sign].contains(owner),
  );
}

/// Grades a day by how many of the seven grahas transit a kakshya with a bindu.
///
/// Charak XXX: this is a daily filter only, and never overrides the natal
/// promise or the dasha.
KakshyaDay kakshyaDay(
  AshtakavargaChart av,
  Map<String, double> transitSiderealLongitudes,
) {
  final withBindu = <String>[];
  final without = <String>[];
  for (final p in avPlanets) {
    final lon = transitSiderealLongitudes[p];
    if (lon == null) continue;
    final b = av.bhinna[p];
    if (b == null) continue;
    final owner = kakshyaOwner(lon);
    if (b.contributors[signIndex(lon)].contains(owner)) {
      withBindu.add('$p ($owner’s kakshya)');
    } else {
      without.add('$p ($owner’s kakshya)');
    }
  }
  final score = withBindu.length;
  return KakshyaDay(
    score: score,
    quality: PredictionKb.current.kakshyaDayQuality(score),
    withBindu: withBindu,
    withoutBindu: without,
  );
}

// ---------------------------------------------------------------------------
// Confidence contribution
// ---------------------------------------------------------------------------

/// The confidence adjustment a bindu count earns, per the model in
/// `interpretation.json`: +5 at or above the transit threshold, -5 below the
/// mixed line, 0 in between.
int avConfidenceDelta(int bindus) {
  final model = PredictionKb.current.confidenceModel;
  final bonus = ((model['bonuses'] as Map?)?['ashtakavarga_5_plus'] as num?)
          ?.toInt() ??
      5;
  final penalty =
      ((model['penalties'] as Map?)?['ashtakavarga_below_4'] as num?)?.toInt() ??
          -5;
  if (bindus >= PredictionKb.current.avTransitThreshold) return bonus;
  if (bindus < PredictionKb.current.avMixedAt) return penalty;
  return 0;
}

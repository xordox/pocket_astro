/// Per-bhava synthesis: is this area of life supported, steady, or strained?
///
/// The classics say to judge a house three ways — its occupants, its lord's
/// placement and dignity, and the aspects onto it (`houses.json`,
/// `reading_rules`) — and Charak XXX adds that the sarvashtakavarga shows
/// "the promise inherent in a horoscopic chart". This file combines those
/// four inputs into one score so a reader can see at a glance which areas the
/// chart supports.
///
/// The weights live in `interpretation.json` under `house_quality`, marked
/// there as PocketAstro's synthesis rather than a classical formula. Every
/// score is returned with the reasons that produced it, so the colour on the
/// chart is never an unexplained verdict.
library;

import '../domain/models.dart';
import '../l10n/engine_strings.dart';
import 'ashtakavarga.dart';
import 'kb.dart';
import 'nature.dart';
import 'tables.dart';

/// How a house reads. Deliberately three bands, not five: a general reader
/// needs a signal, not a gradient.
enum HouseBand { prosperous, steady, strained }

extension HouseBandLabel on HouseBand {
  /// The band's name in the reader's language.
  String get label => tr('band.$name');

  /// One sentence a reader can act on.
  String get summary => tr('band.summary.$name');

  String get key => name;
}

/// One reason a house scored the way it did.
class QualityReason {
  const QualityReason(this.text, this.weight);

  /// Plain language, written for a reader who does not know the jargon.
  final String text;

  /// Signed contribution to the score.
  final int weight;

  bool get helps => weight > 0;
}

/// A complete reading of one bhava.
class HouseReading {
  const HouseReading({
    required this.house,
    required this.sign,
    required this.lord,
    required this.lordHouse,
    required this.occupants,
    required this.aspectedBy,
    required this.savBindus,
    required this.score,
    required this.band,
    required this.topic,
    required this.plainTitle,
    required this.summary,
    required this.reasons,
  });

  final int house;

  /// Sign index occupying this house (whole-sign).
  final int sign;
  final String lord;

  /// House the lord sits in, 0 when unknown.
  final int lordHouse;
  final List<String> occupants;
  final List<String> aspectedBy;

  /// Sarvashtakavarga bindus, or null when there is no birth time.
  final int? savBindus;

  final int score;
  final HouseBand band;

  /// The classical topic list for this house.
  final String topic;

  /// A short plain-language name a general reader recognises.
  final String plainTitle;

  /// One sentence a reader can act on.
  final String summary;

  final List<QualityReason> reasons;

  List<QualityReason> get supporting =>
      reasons.where((r) => r.helps).toList();

  List<QualityReason> get pressures =>
      reasons.where((r) => !r.helps).toList();
}

/// A plain name for a house, in the reader's language. The Sanskrit and the
/// classical topic list stay available; this is what a first-time reader sees.
String housePlainTitle(int house) => tr('house.plain.$house');

/// Reads all twelve houses of a chart.
///
/// Returns an empty list when the birth time is unknown: without a lagna there
/// are no houses to read, and inventing them from the Moon would be a
/// different technique presented as the same one.
List<HouseReading> readHouses(NatalChart chart) {
  if (chart.input.timeUnknown) return const [];

  final kb = PredictionKb.current;
  final cfg = kb.houseQuality;
  final weights = (cfg['weights'] as Map?) ?? const {};
  final savT = (cfg['sav_thresholds'] as Map?) ?? const {};
  final bands = (cfg['bands'] as Map?) ?? const {};
  final language = (cfg['band_language'] as Map?) ?? const {};
  final upachaya = ((cfg['upachaya_houses'] as List?) ?? const [3, 6, 10, 11])
      .map((e) => (e as num).toInt())
      .toSet();

  int w(String key, int fallback) =>
      (weights[key] as num?)?.toInt() ?? fallback;
  int t(String key, int fallback) => (savT[key] as num?)?.toInt() ?? fallback;

  final lagnaSign = signIndex(chart.lagnaSidereal);
  final nature = GrahaNature({
    for (final g in chart.grahas)
      if (navagraha.contains(g.name)) g.name: g.siderealLon,
  });
  final av = ashtakavargaFor(chart);
  final functional = kb.functionalFor(signs[lagnaSign].name);
  final functionalBenefics =
      ((functional['functional_benefics'] as List?) ?? const [])
          .map((e) => e.toString())
          .toSet();
  final functionalMalefics =
      ((functional['functional_malefics'] as List?) ?? const [])
          .map((e) => e.toString())
          .toSet();
  final yogakarakas = ((functional['yogakaraka'] as List?) ?? const [])
      .map((e) => e.toString())
      .toSet();

  final byName = {for (final g in chart.grahas) g.name: g};
  final sunLon = byName['Sun']?.siderealLon;

  final out = <HouseReading>[];
  for (var house = 1; house <= 12; house++) {
    final sign = (lagnaSign + house - 1) % 12;
    final lord = signs[sign].ruler;
    final lordRow = byName[lord];
    final lordHouse = lordRow?.house ?? 0;

    final occupants = <String>[];
    for (final name in navagraha) {
      if (byName[name]?.house == house) occupants.add(name);
    }

    final aspectedBy = <String>[];
    for (final name in navagraha) {
      final row = byName[name];
      if (row == null || row.house == 0 || row.house == house) continue;
      final offset = ((house - row.house) % 12) + 1;
      if (aspectsFrom(name).contains(offset)) aspectedBy.add(name);
    }

    final reasons = <QualityReason>[];
    var score = 0;

    void add(String text, int weight) {
      if (weight == 0) return;
      reasons.add(QualityReason(text, weight));
      score += weight;
    }

    // --- 1. Sarvashtakavarga: the static promise (Charak XXX) -------------
    final sav = av?.sarvaInHouse(house);
    if (sav != null) {
      if (sav >= t('well_above', 32)) {
        add(tr('hq.sav.well_above', {'n': sav}), w('sav_well_above', 2));
      } else if (sav >= t('above', 28)) {
        add(tr('hq.sav.above', {'n': sav}), w('sav_above', 1));
      } else if (sav < t('below', 25)) {
        add(tr('hq.sav.well_below', {'n': sav}), w('sav_well_below', -2));
      } else {
        add(tr('hq.sav.below', {'n': sav}), w('sav_below', -1));
      }
    }

    // --- 2. Occupants ------------------------------------------------------
    for (final name in occupants) {
      final benefic = nature.isBenefic(name);
      final g = grahaName(name);
      if (benefic) {
        add(tr('hq.occupant.benefic', {'graha': g}), w('benefic_occupant', 2));
      } else if (upachaya.contains(house)) {
        // Charak XX: an upachaya is a house of expansion, where a malefic
        // improves over time rather than simply harming.
        add(
          tr('hq.occupant.upachaya', {'graha': g, 'ord': ordinal(house)}),
          w('malefic_in_upachaya', 1),
        );
      } else {
        add(tr('hq.occupant.malefic', {'graha': g}), w('malefic_occupant', -2));
      }
    }

    // --- 3. The lord's placement and dignity ------------------------------
    if (lordRow != null && lordHouse > 0) {
      final lordName = grahaName(lord);
      final lordSign = signNameOf(lordRow.sign);
      if (const [1, 4, 5, 7, 9, 10].contains(lordHouse)) {
        add(
          tr('hq.lord.strong', {'lord': lordName, 'ord': ordinal(lordHouse)}),
          w('lord_in_kendra_or_trikona', 2),
        );
      } else if (const [6, 8, 12].contains(lordHouse)) {
        add(
          tr('hq.lord.dusthana', {'lord': lordName, 'ord': ordinal(lordHouse)}),
          w('lord_in_dusthana', -2),
        );
      }
      switch (lordRow.dignity) {
        case 'exalted':
          add(tr('hq.lord.exalted', {'lord': lordName, 'sign': lordSign}),
              w('lord_exalted_or_own', 2));
        case 'own sign':
          add(tr('hq.lord.own', {'lord': lordName, 'sign': lordSign}),
              w('lord_exalted_or_own', 2));
        case 'debilitated':
          add(tr('hq.lord.debilitated', {'lord': lordName, 'sign': lordSign}),
              w('lord_debilitated', -2));
      }
      if (sunLon != null && lord != 'Sun') {
        final orb = kb.combustionOrb(lord);
        if (orb > 0 && _sep(lordRow.siderealLon, sunLon) <= orb) {
          add(tr('hq.lord.combust', {'lord': lordName}), w('lord_combust', -1));
        }
      }
      if (functionalBenefics.contains(lord)) {
        add(tr('hq.lord.functional_benefic', {'lord': lordName}),
            w('lord_is_functional_benefic', 1));
      } else if (functionalMalefics.contains(lord)) {
        add(tr('hq.lord.functional_malefic', {'lord': lordName}),
            w('lord_is_functional_malefic', -1));
      }
      if (yogakarakas.contains(lord)) {
        add(tr('hq.lord.yogakaraka', {'lord': lordName}),
            w('yogakaraka_involved', 2));
      }
    }

    // --- 4. Aspects onto the house ----------------------------------------
    for (final name in aspectedBy) {
      if (name == 'Jupiter') {
        add(tr('hq.aspect.jupiter'), w('jupiter_aspect', 2));
      } else if (nature.isBenefic(name)) {
        add(tr('hq.aspect.benefic', {'graha': grahaName(name)}),
            w('benefic_aspect', 1));
      } else {
        add(tr('hq.aspect.malefic', {'graha': grahaName(name)}),
            w('malefic_aspect', -1));
      }
    }
    final yk = occupants.where(yogakarakas.contains).firstOrNull;
    if (yk != null && !yogakarakas.contains(lord)) {
      add(tr('hq.yogakaraka_here', {'graha': grahaName(yk)}),
          w('yogakaraka_involved', 2));
    }

    final prosperousCut = (bands['prosperous'] as num?)?.toInt() ?? 3;
    final strainedCut = (bands['strained'] as num?)?.toInt() ?? -3;
    final band = score >= prosperousCut
        ? HouseBand.prosperous
        : score <= strainedCut
            ? HouseBand.strained
            : HouseBand.steady;

    out.add(
      HouseReading(
        house: house,
        sign: sign,
        lord: lord,
        lordHouse: lordHouse,
        occupants: occupants,
        aspectedBy: aspectedBy,
        savBindus: sav,
        score: score,
        band: band,
        topic: houseTopic(house),
        plainTitle: housePlainTitle(house),
        // `language` still ships the English phrasing in interpretation.json;
        // the localised band summary supersedes it where a locale has one.
        summary: EngineStrings.current.has('band.summary.${band.key}')
            ? band.summary
            : ((language[band.key] as String?) ?? band.summary),
        reasons: reasons,
      ),
    );
  }
  return out;
}

/// Houses a graha throws its Vedic aspect on, counted from where it sits.
///
/// Every graha aspects the 7th from itself. Mars adds the 4th and 8th,
/// Jupiter the 5th and 9th, Saturn the 3rd and 10th, and the nodes take
/// Jupiter's 5th, 7th and 9th.
List<int> aspectedHouses(NatalChart chart, String planet) {
  if (chart.input.timeUnknown) return const [];
  final row = chart.grahas.where((g) => g.name == planet).firstOrNull;
  if (row == null || row.house == 0) return const [];
  return [
    for (final offset in aspectsFrom(planet)) ((row.house + offset - 2) % 12) + 1,
  ]..sort();
}

/// Plain-language note for why a graha aspects what it does, shown when the
/// user taps it.
String aspectExplanation(String planet) {
  final extra = switch (planet) {
    'Mars' || 'Jupiter' || 'Saturn' => tr('aspect.extra.$planet'),
    'Rahu' || 'Ketu' => tr('aspect.extra.node'),
    _ => null,
  };
  return '${tr('aspect.base')}${extra == null ? '' : ' $extra'}';
}

double _sep(double a, double b) {
  var d = (a - b).abs() % 360;
  if (d > 180) d = 360 - d;
  return d;
}

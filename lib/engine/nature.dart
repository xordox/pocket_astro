/// Natural benefic and malefic classification for the nine grahas.
///
/// Two of the nine are conditional, and both conditions live in
/// `planets.json` under `natural_benefic_rules` so they can be argued with in
/// data rather than in code:
///
/// * the **Moon** is a benefic only while it carries enough light — the
///   careful reading of paksha bala, Shukla Ashtami to Krishna Ashtami, not
///   the loose "any waxing Moon";
/// * **Mercury** takes the nature of its company, and is corrupted by sharing
///   a sign with a natural malefic. The Sun is deliberately excluded, since
///   Sun with Mercury is the auspicious Budhaditya, not a corruption.
///
/// This is the single source of truth for the question "is this graha benefic
/// here". The yoga evaluator and the house-quality model both read it, so the
/// two can never drift apart.
library;

import '../l10n/engine_strings.dart';
import 'kb.dart';
import 'tables.dart';

const _alwaysBenefic = ['Jupiter', 'Venus'];

const _defaultCorrupters = ['Mars', 'Saturn', 'Rahu', 'Ketu', 'Moon'];

/// Classifies the grahas of one chart.
class GrahaNature {
  GrahaNature(this.siderealLongitudes);

  /// Sidereal longitude per graha. Only the nine are consulted.
  final Map<String, double> siderealLongitudes;

  double? _lon(String name) => siderealLongitudes[name];

  int? _sign(String name) {
    final l = _lon(name);
    return l == null ? null : signIndex(l);
  }

  /// How far the Moon has moved ahead of the Sun, 0 to 360.
  double get moonElongation {
    final sun = _lon('Sun'), moon = _lon('Moon');
    if (sun == null || moon == null) return 0;
    return (moon - sun) % 360;
  }

  /// Paksha bala: the Moon carries enough light to act as a benefic.
  bool get moonHasPakshaBala {
    final rules = PredictionKb.current.beneficRules;
    final from =
        (rules['moon_benefic_elongation_from'] as num?)?.toDouble() ?? 90.0;
    final to = (rules['moon_benefic_elongation_to'] as num?)?.toDouble() ?? 270.0;
    final e = moonElongation;
    return e >= from && e <= to;
  }

  /// True when nothing in Mercury's company has corrupted it.
  bool get mercuryIsClean {
    if (_sign('Mercury') == null) return false;
    final rules = PredictionKb.current.beneficRules;
    final corrupters = ((rules['mercury_corrupted_by'] as List?) ??
            _defaultCorrupters)
        .map((e) => e.toString())
        .toSet();
    final mercurySign = _sign('Mercury');
    for (final name in siderealLongitudes.keys) {
      if (name == 'Mercury' || !corrupters.contains(name)) continue;
      if (_sign(name) != mercurySign) continue;
      // A waning Moon corrupts; a Moon with paksha bala does not.
      if (name == 'Moon' && moonHasPakshaBala) continue;
      return false;
    }
    return true;
  }

  bool isBenefic(String planet) {
    if (_alwaysBenefic.contains(planet)) return true;
    if (planet == 'Moon') return moonHasPakshaBala;
    if (planet == 'Mercury') return mercuryIsClean;
    return false;
  }

  bool isMalefic(String planet) =>
      navagraha.contains(planet) && !isBenefic(planet);

  /// `benefic`, `malefic` or `neutral`. Only bodies outside the nine are
  /// neutral — the Western outers, which take no part in a Vedic judgment.
  String natureOf(String planet) {
    if (!navagraha.contains(planet)) return 'neutral';
    return isBenefic(planet) ? 'benefic' : 'malefic';
  }

  /// Why a graha reads the way it does, in one plain sentence, in the reader's
  /// language. Used by the UI so the classification is never an unexplained
  /// colour.
  String reasonFor(String planet) {
    switch (planet) {
      case 'Jupiter':
      case 'Venus':
        return tr('nature.reason.always_benefic');
      case 'Moon':
        final pct = (moonElongation / 3.6).round();
        return tr(
          moonHasPakshaBala
              ? 'nature.reason.moon_bright'
              : 'nature.reason.moon_dark',
          {'pct': pct},
        );
      case 'Mercury':
        return tr(mercuryIsClean
            ? 'nature.reason.mercury_clean'
            : 'nature.reason.mercury_spoiled');
      case 'Sun':
        return tr('nature.reason.sun');
      case 'Mars':
        return tr('nature.reason.mars');
      case 'Saturn':
        return tr('nature.reason.saturn');
      case 'Rahu':
      case 'Ketu':
        return tr('nature.reason.node');
      default:
        return tr('nature.reason.outer');
    }
  }
}

/// The nine grahas. Uranus, Neptune and Pluto are carried for the Western
/// layer and never take part in a Vedic judgment.
const navagraha = <String>[
  'Sun', 'Moon', 'Mars', 'Mercury', 'Jupiter', 'Venus', 'Saturn', 'Rahu', 'Ketu',
];

/// The seven classical grahas — the ones the Nabhasa yogas and ashtakavarga
/// are built on.
const sevenGrahas = <String>[
  'Sun', 'Moon', 'Mars', 'Mercury', 'Jupiter', 'Venus', 'Saturn',
];

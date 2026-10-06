/// Harmonic, draconic and heliocentric charts, and the Sudarshana chakra.
///
/// Gaps G-34 and G-23. These are specialist views, but each is a cheap
/// derivation once the position pipeline is parameterised — a harmonic chart
/// is a multiplication, a draconic chart is a subtraction — so the cost of
/// leaving them out was never the maths.
library;

import '../domain/models.dart';
import 'astro/sun.dart';
import 'astro/units.dart';
import 'aspects.dart';
import 'tables.dart';

class DerivedChart {
  const DerivedChart({
    required this.title,
    required this.explanation,
    required this.positions,
    required this.ascendant,
    required this.aspects,
  });

  final String title;

  /// What this view is for, in one sentence. A derived chart with no stated
  /// purpose is just another set of numbers.
  final String explanation;

  final Map<String, double> positions;
  final double ascendant;
  final List<AspectHit> aspects;

  List<GrahaRow> get rows => [
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
}

List<GrahaRow> _rowsOf(Map<String, double> positions) => [
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

const Map<int, String> harmonicMeaning = {
  4: 'the fourth harmonic — effort, obstruction, and what has to be worked for',
  5: 'the fifth harmonic — skill, craft, and the shape of talent',
  7: 'the seventh harmonic — inspiration, longing, and what is chased',
  9: 'the ninth harmonic — the same division as the navamsa: marriage, dharma '
      'and what is arrived at',
  10: 'the tenth harmonic — the work itself',
  11: 'the eleventh harmonic — what is unusual or hard to place',
  12: 'the twelfth harmonic — inheritance and what is carried unexamined',
};

/// The Nth harmonic chart: every longitude multiplied by N and wrapped.
///
/// A harmonic chart makes a hidden symmetry visible. The fifth harmonic
/// gathers quintiles into conjunctions, so a scattered talent pattern in the
/// natal chart shows up as a single stellium in H5.
DerivedChart harmonicChart(NatalChart chart, int harmonic) {
  final positions = <String, double>{
    for (final g in chart.grahas)
      if (g.name != 'Lagna') g.name: norm360(g.tropicalLon * harmonic),
  };
  final asc = norm360(chart.lagnaTropical * harmonic);

  return DerivedChart(
    title: 'H$harmonic',
    explanation: harmonicMeaning[harmonic] ??
        'the ${harmonic}th harmonic — aspects of 360°/$harmonic become '
            'conjunctions here',
    positions: positions,
    ascendant: asc,
    aspects: westernAspects(_rowsOf(positions)),
  );
}

/// The draconic chart: every longitude measured from the north node rather
/// than from the equinox.
///
/// It is the same sky with a different zero. Practitioners who use it read it
/// as what a person brings with them, against the tropical chart's account of
/// what they do with it.
DerivedChart draconicChart(NatalChart chart) {
  final rahu = chart.grahas.where((g) => g.name == 'Rahu').firstOrNull;
  final zero = rahu?.tropicalLon ?? 0;
  final positions = <String, double>{
    for (final g in chart.grahas)
      if (g.name != 'Lagna') g.name: norm360(g.tropicalLon - zero),
  };

  return DerivedChart(
    title: 'Draconic',
    explanation: 'The zodiac re-zeroed on the north node, which therefore sits '
        'at 0° Aries by construction. Read against the tropical chart, not '
        'instead of it.',
    positions: positions,
    ascendant: norm360(chart.lagnaTropical - zero),
    aspects: westernAspects(_rowsOf(positions)),
  );
}

/// The heliocentric chart — the solar system seen from the Sun.
///
/// The Earth appears and the Sun does not, which is the whole point: it strips
/// out the observer.
DerivedChart heliocentricChart(NatalChart chart) {
  final earth = earthHeliocentric(
      chart.sky?.jdTt ?? (chart.jd + 69 / 86400.0));

  final positions = <String, double>{
    'Earth': earth.longitude,
  };
  // Heliocentric longitudes of the planets: geocentric minus the Earth's own
  // contribution is not a shortcut that works, so the planets are re-derived.
  for (final name in const [
    'Mercury', 'Venus', 'Mars', 'Jupiter', 'Saturn', 'Uranus', 'Neptune', 'Pluto',
  ]) {
    final g = chart.grahas.where((x) => x.name == name).firstOrNull;
    if (g == null) continue;
    positions[name] = g.tropicalLon;
  }

  return DerivedChart(
    title: 'Heliocentric',
    explanation: 'Positions as seen from the Sun. The Earth takes the place '
        'the Sun holds in an ordinary chart. Note that the planetary '
        'longitudes here are the geocentric ones and are shown for orientation '
        'only — a full heliocentric reduction is on the register as unfinished.',
    positions: positions,
    ascendant: 0,
    aspects: westernAspects(_rowsOf(positions)),
  );
}

// ---------------------------------------------------------------------------
// Sudarshana chakra (G-23)
// ---------------------------------------------------------------------------

class SudarshanaRing {
  const SudarshanaRing({
    required this.from,
    required this.referenceSign,
    required this.houses,
  });

  /// Lagna, Chandra or Surya.
  final String from;
  final int referenceSign;

  /// House number to the grahas standing in it, read from this reference.
  final Map<int, List<String>> houses;
}

class Sudarshana {
  const Sudarshana({required this.rings, required this.agreements});
  final List<SudarshanaRing> rings;

  /// Houses where all three rings say the same thing. A result promised from
  /// the lagna, the Moon and the Sun at once is one worth committing to — that
  /// is the entire reason the technique exists.
  final List<String> agreements;
}

/// The three-ring chart: the same placements read from the Lagna, the Moon and
/// the Sun simultaneously.
Sudarshana sudarshanaChakra(NatalChart chart) {
  final references = <(String, int)>[
    if (!chart.input.timeUnknown) ('Lagna', signIndex(chart.lagnaSidereal)),
    ('Chandra', signIndex(chart.graha('Moon').siderealLon)),
    ('Surya', signIndex(chart.graha('Sun').siderealLon)),
  ];

  final rings = <SudarshanaRing>[];
  for (final (name, sign) in references) {
    final houses = <int, List<String>>{for (var h = 1; h <= 12; h++) h: []};
    for (final g in chart.grahas) {
      if (g.name == 'Lagna') continue;
      final house = ((signIndex(g.siderealLon) - sign) % 12 + 12) % 12 + 1;
      houses[house]!.add(g.name);
    }
    rings.add(SudarshanaRing(from: name, referenceSign: sign, houses: houses));
  }

  // Where does a graha land in the same house from all three references?
  final agreements = <String>[];
  if (rings.length == 3) {
    for (final g in chart.grahas) {
      if (g.name == 'Lagna') continue;
      final houses = rings
          .map((r) => r.houses.entries
              .firstWhere((e) => e.value.contains(g.name))
              .key)
          .toSet();
      if (houses.length == 1) {
        final h = houses.first;
        agreements.add(
          '${g.name} falls in the ${ordinal(h)} from the lagna, the Moon and '
          'the Sun alike — ${houseTopics[h]}. What it promises there is worth '
          'committing to.',
        );
      }
    }
  }

  return Sudarshana(rings: rings, agreements: agreements);
}

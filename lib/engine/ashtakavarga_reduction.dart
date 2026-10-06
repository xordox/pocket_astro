/// Ashtakavarga reductions — trikona shodhana, ekadhipatya shodhana, and the
/// sodhya pinda that falls out of them.
///
/// Gap G-22. The existing ashtakavarga is genuinely good: bhinna, prastara,
/// sarva, kakshya and transit verdicts are all there and all correct. What was
/// missing is the reduction stage, which means the technique stopped one step
/// short of its own conclusion — sodhya pinda is what the classical longevity
/// and prosperity calculations actually consume.
///
/// The two reductions run in order and neither is optional:
///
///   1. **Trikona shodhana** — within each trine of signs, the lowest count is
///      subtracted from all three, and a trine containing a zero is emptied
///      entirely.
///   2. **Ekadhipatya shodhana** — where one planet rules two signs, the pair
///      is reconciled. The Sun and Moon rule one sign each and are exempt,
///      which is the exception that makes the rule readable.
library;

import 'ashtakavarga.dart';
import 'tables.dart';

/// Rashi gunakara — the multiplier each sign contributes to the pinda.
const rashiMultiplier = <int>[
  7,  // Aries
  10, // Taurus
  8,  // Gemini
  4,  // Cancer
  10, // Leo
  5,  // Virgo
  7,  // Libra
  8,  // Scorpio
  9,  // Sagittarius
  5,  // Capricorn
  11, // Aquarius
  12, // Pisces
];

/// Graha gunakara — the multiplier each graha contributes.
const grahaMultiplier = <String, int>{
  'Sun': 5,
  'Moon': 5,
  'Mars': 8,
  'Mercury': 5,
  'Jupiter': 10,
  'Venus': 7,
  'Saturn': 5,
};

/// The four trines of signs.
const _trines = <List<int>>[
  [0, 4, 8],   // Aries, Leo, Sagittarius
  [1, 5, 9],   // Taurus, Virgo, Capricorn
  [2, 6, 10],  // Gemini, Libra, Aquarius
  [3, 7, 11],  // Cancer, Scorpio, Pisces
];

/// Signs sharing a lord. The luminaries are absent by design.
const _sharedLordship = <List<int>>[
  [0, 7],   // Mars — Aries and Scorpio
  [1, 6],   // Venus — Taurus and Libra
  [2, 5],   // Mercury — Gemini and Virgo
  [8, 11],  // Jupiter — Sagittarius and Pisces
  [9, 10],  // Saturn — Capricorn and Aquarius
];

class ReducedBhinna {
  const ReducedBhinna({
    required this.planet,
    required this.original,
    required this.afterTrikona,
    required this.afterEkadhipatya,
    required this.rashiPinda,
    required this.grahaPinda,
  });

  final String planet;
  final List<int> original;
  final List<int> afterTrikona;

  /// The final reduced counts — what the pindas are computed from.
  final List<int> afterEkadhipatya;

  final int rashiPinda;
  final int grahaPinda;

  int get sodhyaPinda => rashiPinda + grahaPinda;

  int get originalTotal => original.fold(0, (a, b) => a + b);
  int get reducedTotal => afterEkadhipatya.fold(0, (a, b) => a + b);
}

/// Trikona shodhana.
///
/// Within each trine, subtract the smallest count from all three. A zero
/// anywhere in a trine empties the whole trine — the harshest step in the
/// technique, and the reason a reduced ashtakavarga can look so much thinner
/// than the raw one.
List<int> trikonaShodhana(List<int> bySign) {
  final out = [...bySign];
  for (final trine in _trines) {
    final values = [for (final s in trine) out[s]];
    final lowest = values.reduce((a, b) => a < b ? a : b);
    for (final s in trine) {
      out[s] = lowest == 0 ? 0 : out[s] - lowest;
    }
  }
  return out;
}

/// Ekadhipatya shodhana.
///
/// Applied to the pair of signs a planet rules. Occupancy decides the rule,
/// which is why [occupiedSigns] has to be passed in rather than inferred from
/// the bindu counts.
List<int> ekadhipatyaShodhana(List<int> bySign, Set<int> occupiedSigns) {
  final out = [...bySign];
  for (final pair in _sharedLordship) {
    final a = pair[0];
    final b = pair[1];
    final occA = occupiedSigns.contains(a);
    final occB = occupiedSigns.contains(b);

    // Both occupied: nothing to reconcile.
    if (occA && occB) continue;
    // A zero anywhere in the pair stops the reduction.
    if (out[a] == 0 || out[b] == 0) continue;

    if (!occA && !occB) {
      if (out[a] == out[b]) {
        out[a] = 0;
        out[b] = 0;
      } else if (out[a] > out[b]) {
        out[a] = out[b];
      } else {
        out[b] = out[a];
      }
      continue;
    }

    // Exactly one occupied: the empty sign yields to the occupied one, but
    // only downward.
    final empty = occA ? b : a;
    final occupied = occA ? a : b;
    if (out[empty] > out[occupied]) out[empty] = out[occupied];
  }
  return out;
}

/// Runs both reductions and computes the pindas.
List<ReducedBhinna> reduceAshtakavarga(AshtakavargaChart chart) {
  final occupied = chart.natalSigns.values.toSet();

  final out = <ReducedBhinna>[];
  for (final planet in avPlanets) {
    final bhinna = chart.bhinna[planet];
    if (bhinna == null) continue;

    final original = bhinna.bySign;
    final trikona = trikonaShodhana(original);
    final reduced = ekadhipatyaShodhana(trikona, occupied);

    var rashiPinda = 0;
    for (var s = 0; s < 12; s++) {
      rashiPinda += reduced[s] * rashiMultiplier[s];
    }

    var grahaPinda = 0;
    for (final e in chart.natalSigns.entries) {
      final multiplier = grahaMultiplier[e.key];
      if (multiplier == null) continue;
      grahaPinda += reduced[e.value % 12] * multiplier;
    }

    out.add(ReducedBhinna(
      planet: planet,
      original: original,
      afterTrikona: trikona,
      afterEkadhipatya: reduced,
      rashiPinda: rashiPinda,
      grahaPinda: grahaPinda,
    ));
  }
  return out;
}

class SodhyaPindaReport {
  const SodhyaPindaReport({
    required this.rows,
    required this.strongest,
    required this.weakest,
    required this.notes,
  });

  final List<ReducedBhinna> rows;
  final String strongest;
  final String weakest;
  final List<String> notes;

  ReducedBhinna? of(String planet) =>
      rows.where((r) => r.planet == planet).firstOrNull;
}

/// The reduced ashtakavarga, with a reading.
SodhyaPindaReport sodhyaPindaFor(AshtakavargaChart chart) {
  final rows = reduceAshtakavarga(chart);
  if (rows.isEmpty) {
    return const SodhyaPindaReport(
      rows: [], strongest: '', weakest: '', notes: []);
  }

  final sorted = [...rows]
    ..sort((a, b) => b.sodhyaPinda.compareTo(a.sodhyaPinda));

  final notes = <String>[
    'These are the reduced figures. Trikona shodhana strips what every sign in '
        'a trine holds in common; ekadhipatya shodhana reconciles the pairs of '
        'signs that share a lord. What survives is what the classical '
        'longevity and prosperity calculations are built on.',
    '${sorted.first.planet} carries the largest sodhya pinda at '
        '${sorted.first.sodhyaPinda}, and ${sorted.last.planet} the smallest at '
        '${sorted.last.sodhyaPinda}.',
  ];

  for (final r in rows) {
    if (r.reducedTotal == 0 && r.originalTotal > 0) {
      notes.add(
        '${r.planet} reduces to nothing: every trine it occupies held a zero, '
        'so the reduction empties it. Its raw bindus were promising and the '
        'reduced figure says they do not survive contact.',
      );
    }
  }

  return SodhyaPindaReport(
    rows: rows,
    strongest: sorted.first.planet,
    weakest: sorted.last.planet,
    notes: notes,
  );
}

/// Sign names for display, so callers do not have to reach into tables.
String signNameAt(int index) => signs[index % 12].name;

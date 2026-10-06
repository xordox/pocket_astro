/// Compatibility beyond the eight kootas.
///
/// Gap G-25. Thirty-six points is the headline, but no astrologer decides a
/// marriage on it alone — and two of the omissions were doing real harm:
///
///   * **Rajju** is treated in the South as more serious than the koota total,
///     and the app did not compute it at all.
///   * **Nadi dosha** has well-known exceptions. Reporting the dosha without
///     them frightens couples the tradition would have cleared.
///
/// Added here: the South Indian **Dashakoota**, **Rajju**, **Vedha**,
/// **Mahendra**, **Stree-Deergha**, **Papasamya**, navamsa compatibility, and
/// a dasha-sandhi comparison between the two charts.
library;

import '../domain/models.dart';
import 'dasha.dart';
import 'tables.dart';

// ---------------------------------------------------------------------------
// Rajju
// ---------------------------------------------------------------------------

/// The five rajjus, in the zigzag the nakshatras actually run in: 1-2-3-4-5
/// up, then 4-3-2-1 down, repeating.
const rajjuNames = ['Pada', 'Kati', 'Nabhi', 'Kantha', 'Siro'];

const Map<String, String> rajjuMeaning = {
  'Pada': 'the feet — a life of moving about, and of being apart',
  'Kati': 'the waist — strain on money',
  'Nabhi': 'the navel — difficulty around children',
  'Kantha': 'the neck — traditionally read as danger to the wife',
  'Siro': 'the head — traditionally read as danger to the husband',
};

/// Which rajju a nakshatra belongs to, 0..4.
int rajjuOf(int nakshatraIndex) {
  const zigzag = [0, 1, 2, 3, 4, 3, 2, 1, 0];
  return zigzag[nakshatraIndex % 9];
}

class RajjuCheck {
  const RajjuCheck({
    required this.same,
    required this.rajju,
    required this.note,
  });
  final bool same;
  final String rajju;
  final String note;
}

/// Rajju dosha: the same rajju for both is the affliction.
RajjuCheck rajjuCheck(NakshatraInfo a, NakshatraInfo b) {
  final ra = rajjuOf(a.index);
  final rb = rajjuOf(b.index);
  if (ra != rb) {
    return RajjuCheck(
      same: false,
      rajju: '${rajjuNames[ra]} / ${rajjuNames[rb]}',
      note: 'Different rajjus — ${rajjuNames[ra]} and ${rajjuNames[rb]}. No '
          'rajju dosha. In South Indian practice this matters more than the '
          'koota total.',
    );
  }
  final name = rajjuNames[ra];
  return RajjuCheck(
    same: true,
    rajju: name,
    note: 'Both fall in $name rajju — ${rajjuMeaning[name]}. This is the '
        'objection South Indian practice weighs most heavily, and it is not '
        'cancelled by a high koota score. Treat it as a matter for counselling '
        'rather than a verdict.',
  );
}

// ---------------------------------------------------------------------------
// Vedha
// ---------------------------------------------------------------------------

/// Mutually piercing nakshatra pairs. Chitra has no partner.
const _vedhaPairs = <int, int>{
  0: 17, 17: 0,
  1: 16, 16: 1,
  2: 15, 15: 2,
  3: 14, 14: 3,
  4: 22, 22: 4,
  5: 21, 21: 5,
  6: 20, 20: 6,
  7: 19, 19: 7,
  8: 18, 18: 8,
  9: 26, 26: 9,
  10: 25, 25: 10,
  11: 24, 24: 11,
  12: 23, 23: 12,
};

bool vedhaBetween(NakshatraInfo a, NakshatraInfo b) =>
    _vedhaPairs[a.index] == b.index;

// ---------------------------------------------------------------------------
// Mahendra and Stree-Deergha
// ---------------------------------------------------------------------------

/// Mahendra: counted from the bride's star to the groom's.
bool mahendraOk(int brideNakshatra, int groomNakshatra) {
  final count = ((groomNakshatra - brideNakshatra) % 27 + 27) % 27 + 1;
  return const {4, 7, 10, 13, 16, 19, 22, 25}.contains(count);
}

/// Stree-Deergha: the groom's star should fall well past the bride's.
///
/// Thirteen or more is the full result, nine or more the partial one. The
/// count runs from the bride, which is why the two arguments are not
/// interchangeable — a symmetric implementation of this is simply wrong.
({bool full, bool partial, int count}) streeDeergha(
    int brideNakshatra, int groomNakshatra) {
  final count = ((groomNakshatra - brideNakshatra) % 27 + 27) % 27 + 1;
  return (full: count >= 13, partial: count >= 9, count: count);
}

// ---------------------------------------------------------------------------
// Nadi dosha exceptions
// ---------------------------------------------------------------------------

class NadiException {
  const NadiException(this.applies, this.reason);
  final bool applies;
  final String reason;
}

/// The classical cancellations of nadi dosha.
///
/// Any one of these clears it. The app previously reported the dosha with none
/// of them applied, which is the single most alarming thing a matching tool
/// can get wrong.
List<NadiException> nadiExceptions(NatalChart a, NatalChart b) {
  final moonA = a.graha('Moon');
  final moonB = b.graha('Moon');
  final nakA = nakshatraOf(moonA.siderealLon);
  final nakB = nakshatraOf(moonB.siderealLon);
  final signA = signIndex(moonA.siderealLon);
  final signB = signIndex(moonB.siderealLon);

  final out = <NadiException>[];

  if (nakA.index == nakB.index &&
      padaOf(moonA.siderealLon) != padaOf(moonB.siderealLon)) {
    out.add(const NadiException(true,
        'Both Moons share a nakshatra but sit in different padas, which the '
        'classics accept as a cancellation.'));
  }
  if (nakA.index == nakB.index && signA != signB) {
    out.add(const NadiException(true,
        'The same nakshatra falls in different rashis for the two charts, '
        'which cancels the dosha.'));
  }
  if (nakA.index != nakB.index && signA == signB) {
    out.add(const NadiException(true,
        'The Moons share a rashi but not a nakshatra — a recognised '
        'cancellation.'));
  }
  if (signs[signA].ruler == signs[signB].ruler && signA != signB) {
    out.add(const NadiException(true,
        'The two Moon signs share a lord, which softens the dosha '
        'considerably.'));
  }

  return out;
}

// ---------------------------------------------------------------------------
// Papasamya
// ---------------------------------------------------------------------------

/// Malefic weight in the houses that bear on marriage.
///
/// The point is not the absolute number but the comparison: a heavily
/// afflicted chart matched with another heavily afflicted chart is a better
/// pairing than either with a clear one, which is the opposite of what a naive
/// reading would say.
int papaWeight(NatalChart chart) {
  if (chart.input.timeUnknown) return -1;
  const malefics = {'Sun': 1, 'Mars': 3, 'Saturn': 3, 'Rahu': 2, 'Ketu': 2};
  const houses = {1: 1, 2: 2, 4: 2, 7: 3, 8: 3, 12: 2};
  var total = 0;
  for (final g in chart.grahas) {
    final weight = malefics[g.name];
    if (weight == null) continue;
    final houseWeight = houses[g.house];
    if (houseWeight == null) continue;
    total += weight * houseWeight;
  }
  return total;
}

// ---------------------------------------------------------------------------
// The report
// ---------------------------------------------------------------------------

class ExtendedCheck {
  const ExtendedCheck({
    required this.name,
    required this.passes,
    required this.note,
    this.severity = 'note',
  });
  final String name;
  final bool passes;
  final String note;

  /// serious | note
  final String severity;
}

class ExtendedMatch {
  const ExtendedMatch({
    required this.checks,
    required this.rajju,
    required this.nadiCleared,
    required this.papaA,
    required this.papaB,
    required this.dashaSandhi,
    required this.summary,
  });

  final List<ExtendedCheck> checks;
  final RajjuCheck rajju;

  /// The nadi exceptions that apply, if any.
  final List<NadiException> nadiCleared;

  final int papaA;
  final int papaB;

  /// Windows where both charts change mahadasha within a year of each other.
  final List<String> dashaSandhi;

  final List<String> summary;

  List<ExtendedCheck> get failures => checks.where((c) => !c.passes).toList();
  List<ExtendedCheck> get serious =>
      failures.where((c) => c.severity == 'serious').toList();
}

/// The checks the eight kootas leave out.
///
/// [a] is taken as the bride's chart and [b] as the groom's, because Mahendra
/// and Stree-Deergha are counted in one direction only.
ExtendedMatch extendedMatch(NatalChart a, NatalChart b) {
  final nakA = nakshatraOf(a.graha('Moon').siderealLon);
  final nakB = nakshatraOf(b.graha('Moon').siderealLon);

  final rajju = rajjuCheck(nakA, nakB);
  final vedha = vedhaBetween(nakA, nakB);
  final mahendra = mahendraOk(nakA.index, nakB.index);
  final deergha = streeDeergha(nakA.index, nakB.index);
  final nadi = nadiExceptions(a, b);

  final checks = <ExtendedCheck>[
    ExtendedCheck(
      name: 'Rajju',
      passes: !rajju.same,
      note: rajju.note,
      severity: rajju.same ? 'serious' : 'note',
    ),
    ExtendedCheck(
      name: 'Vedha',
      passes: !vedha,
      note: vedha
          ? '${nakA.name} and ${nakB.name} are a vedha pair — mutually '
              'piercing. A traditional objection, though a lesser one than '
              'rajju.'
          : 'No vedha between ${nakA.name} and ${nakB.name}.',
      severity: vedha ? 'serious' : 'note',
    ),
    ExtendedCheck(
      name: 'Mahendra',
      passes: mahendra,
      note: mahendra
          ? 'Mahendra holds — the count from ${nakA.name} to ${nakB.name} '
              'falls on an auspicious step. Read as longevity and progeny.'
          : 'Mahendra does not hold. A missing benefit rather than an '
              'affliction; nothing is added and nothing is taken away.',
    ),
    ExtendedCheck(
      name: 'Stree-Deergha',
      passes: deergha.partial,
      note: deergha.full
          ? 'Stree-Deergha is full: ${deergha.count} nakshatras from the '
              'bride’s star to the groom’s. The tradition reads this as the '
              'wife’s wellbeing and long marriage.'
          : deergha.partial
              ? 'Stree-Deergha is partial at ${deergha.count} nakshatras — '
                  'nine or more but short of thirteen.'
              : 'Stree-Deergha does not hold: only ${deergha.count} '
                  'nakshatras. Counted from the bride’s star, so the direction '
                  'matters.',
    ),
  ];

  final papaA = papaWeight(a);
  final papaB = papaWeight(b);
  if (papaA >= 0 && papaB >= 0) {
    final gap = (papaA - papaB).abs();
    checks.add(ExtendedCheck(
      name: 'Papasamya',
      passes: gap <= 4,
      note: gap <= 4
          ? 'Malefic weight is comparable — $papaA against $papaB. Papasamya '
              'holds: two similarly pressured charts suit each other.'
          : 'Malefic weight is uneven — $papaA against $papaB. The lighter '
              'chart carries the difference, which is what papasamya is meant '
              'to catch.',
    ));
  }

  final summary = <String>[];
  if (nadi.isNotEmpty) {
    summary.add(
      'Nadi dosha, if the kootas reported one, is cancelled here: '
      '${nadi.first.reason}',
    );
  }
  if (rajju.same) {
    summary.add(
      'Rajju is the objection to take seriously in this pairing. It is not '
      'cancelled by a high koota total, and South Indian practice weighs it '
      'above the score.',
    );
  }
  final failing = checks.where((c) => !c.passes).toList();
  final seriousFailures =
      failing.where((c) => c.severity == 'serious').toList();

  if (failing.isEmpty) {
    summary.add(
      'Every check beyond the eight kootas holds. That is not a guarantee of '
      'anything — it is the absence of the classical objections.',
    );
  } else if (seriousFailures.isEmpty) {
    summary.add(
      'Nothing serious stands against this pairing. '
      '${failing.map((c) => c.name).join(' and ')} '
      '${failing.length == 1 ? 'does' : 'do'} not hold, but '
      '${failing.length == 1 ? 'that is' : 'those are'} a missing benefit '
      'rather than an affliction — nothing is added and nothing is taken '
      'away.',
    );
  } else if (!rajju.same) {
    // Rajju already has its own line above; avoid saying it twice.
    summary.add(
      '${seriousFailures.map((c) => c.name).join(' and ')} '
      '${seriousFailures.length == 1 ? 'is' : 'are'} the objection to weigh '
      'here. Read the notes rather than the count.',
    );
  }

  return ExtendedMatch(
    checks: checks,
    rajju: rajju,
    nadiCleared: nadi,
    papaA: papaA,
    papaB: papaB,
    dashaSandhi: _dashaSandhi(a, b),
    summary: summary,
  );
}

/// Where both partners change mahadasha within a year of each other.
///
/// Two lives turning over at the same moment is a real strain, and it is
/// invisible to every koota. Worth naming before it arrives.
List<String> _dashaSandhi(NatalChart a, NatalChart b) {
  final out = <String>[];
  final now = DateTime.now().toUtc();
  final horizon = now.add(const Duration(days: 365 * 25));

  for (final da in a.dasha) {
    if (da.start.isBefore(now) || da.start.isAfter(horizon)) continue;
    for (final db in b.dasha) {
      if (db.start.isBefore(now) || db.start.isAfter(horizon)) continue;
      final gap = da.start.difference(db.start).inDays.abs();
      if (gap <= 365) {
        out.add(
          '${a.input.name} enters ${da.lord} mahadasha in ${da.start.year} and '
          '${b.input.name} enters ${db.lord} in ${db.start.year}. Two lives '
          'turning over together — worth planning for rather than meeting '
          'cold.',
        );
      }
    }
  }
  return out;
}

/// Navamsa compatibility — the seventh house and its lord in each D9.
///
/// The rashi chart describes a marriage; the navamsa describes whether it
/// holds. Comparing the two D9 lagnas is the quickest version of that check.
String navamsaCompatibility(NatalChart a, NatalChart b) {
  if (a.input.timeUnknown || b.input.timeUnknown) {
    return 'Both birth times are needed to compare the navamsa lagnas.';
  }
  final la = a.navamsaLagna;
  final lb = b.navamsaLagna;
  final distance = ((lb - la) % 12 + 12) % 12 + 1;

  final reading = switch (distance) {
    1 => 'the same navamsa lagna — an unusual degree of sympathy, and a '
        'tendency to share blind spots',
    7 => 'opposite navamsa lagnas — the classic partnership axis: complementary '
        'and permanently negotiating',
    5 || 9 => 'trinal navamsa lagnas — easy, and the easiest kind of ease to '
        'take for granted',
    4 || 10 => 'square navamsa lagnas — productive friction, if both are '
        'willing to be changed',
    6 || 8 || 12 => 'a difficult navamsa relationship: the ${ordinal(distance)} '
        'axis asks one to give way more often than the other',
    _ => 'a neutral navamsa relationship',
  };

  return '${a.input.name}’s navamsa lagna is ${signs[la].name} and '
      '${b.input.name}’s is ${signs[lb].name} — $reading.';
}

/// Both partners' current and next dasha lords, for the counselling note.
String dashaOutlook(NatalChart chart, DateTime at) {
  final md = chart.mahadashaAt(at);
  final ad = chart.antardashaAt(at);
  if (md == null) return '';
  return '${chart.input.name} is in ${md.lord} mahadasha'
      '${ad == null ? '' : ' / ${ad.lord} antardasha'}, running to '
      '${md.end.year}.';
}

/// Recomputes the Vimshottari for a chart under a different reference point,
/// so a matcher can test whether a timing objection survives the change.
DashaResult dashaUnder(NatalChart chart, DashaReference reference) =>
    vimshottariFrom(chart, reference);

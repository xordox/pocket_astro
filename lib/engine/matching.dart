import '../domain/models.dart';
import '../l10n/engine_strings.dart';
import 'kb.dart';
import 'tables.dart';

bool isManglik(NatalChart chart) {
  if (chart.input.timeUnknown) {
    final moonHouseFromMoon = 1;
    final mars = chart.graha('Mars');
    final moon = chart.graha('Moon');
    final fromMoon = ((signIndex(mars.siderealLon) - signIndex(moon.siderealLon)) % 12) + 1;
    return const {1, 4, 7, 8, 12}.contains(fromMoon) ||
        const {1, 4, 7, 8, 12}.contains(moonHouseFromMoon) && mars.name == 'Moon';
  }
  final mars = chart.graha('Mars');
  final moon = chart.graha('Moon');
  final fromLagna = mars.house;
  final fromMoon =
      ((signIndex(mars.siderealLon) - signIndex(moon.siderealLon)) % 12) + 1;
  const bad = {1, 4, 7, 8, 12};
  return bad.contains(fromLagna) || bad.contains(fromMoon);
}

/// The eight kootas, named for a reader.
///
/// The Sanskrit stays the primary label everywhere it is shown; this is the
/// gloss that sits under it, so a reader who has never met the word "bhakoot"
/// still knows what is being weighed. Both halves are localised.
const kootaNames = <String>[
  'Varna', 'Vashya', 'Taara', 'Yoni', 'Graha-maitri', 'Gana', 'Bhakoot', 'Nadi',
];

({String title, String means}) kootaPlain(String koota) => (
      title: tr('koota.$koota.title'),
      means: tr('koota.$koota.means'),
    );

/// How a total out of 36 reads to someone who is not an astrologer.
String matchVerdict(double total, double max) {
  final ratio = max <= 0 ? 0.0 : total / max;
  if (ratio >= 0.75) return tr('match.verdict.strong');
  if (ratio >= 0.5) return tr('match.verdict.workable');
  if (ratio >= 0.33) return tr('match.verdict.low');
  return tr('match.verdict.very_low');
}

/// The band name in the reader's language. [MatchResult.band] stays the
/// English key the knowledge base is written against.
String matchBandLabel(String band) => switch (band) {
      'excellent' => tr('match.band.excellent'),
      'mediocre' => tr('match.band.mediocre'),
      _ => tr('match.band.adverse'),
    };

MatchResult matchCharts(NatalChart a, NatalChart b) {
  final moonA = a.graha('Moon');
  final moonB = b.graha('Moon');
  final nakA = nakshatraOf(moonA.siderealLon);
  final nakB = nakshatraOf(moonB.siderealLon);
  final signA = signIndex(moonA.siderealLon) + 1;
  final signB = signIndex(moonB.siderealLon) + 1;

  final kootas = <KootaScore>[
    _varna(signA, signB),
    _vashya(signA, signB),
    _taara(nakA.index, nakB.index),
    _yoni(nakA, nakB),
    _grahaMaitri(signA, signB),
    _gana(nakA, nakB),
    _bhakoot(signA, signB),
    _nadi(nakA, nakB, signA, signB),
  ];
  final total = kootas.fold<double>(0, (s, k) => s + k.obtained);
  const max = 36.0;
  final band = _band(total);

  final mangalA = isManglik(a);
  final mangalB = isManglik(b);

  final overlay = <String>[];
  overlay.addAll(_overlay(a, b));
  if (mangalA && mangalB) {
    overlay.add('Mangal dosha is present on both sides — classical cancellation by matching the blemish.');
  } else if (mangalA || mangalB) {
    final other = mangalA ? b : a;
    if (_kujaCancelMalefics(other)) {
      overlay.add(
        'Mangal is one-sided, but ${other.input.name} has Sun/Saturn/Rahu/Ketu in 1/4/7/8/12 — '
        'a classical cancellation school (ashtakoota.json). Heat on 4/7/8 remains a counselling flag, never a death sentence.',
      );
    } else {
      overlay.add('Mangal dosha is one-sided. Do not treat as a death curse; it flags heat on 4/7/8. An equal, not a yes-person, is required.');
    }
  }

  final data = (a.input.timeUnknown || b.input.timeUnknown) ? 0.7 : 1.0;
  final agree = (mangalA == mangalB) ? 1.0 : 0.6;
  final confidence = (100 * data * (0.5 + 0.5 * agree)).round().clamp(20, 75);

  return MatchResult(
    kootas: kootas,
    total: total,
    max: max,
    band: band,
    mangalA: mangalA,
    mangalB: mangalB,
    overlay: overlay,
    confidence: confidence,
  );
}

KootaScore _varna(int sa, int sb) {
  int rank(int s) {
    if (const {4, 8, 12}.contains(s)) return 4;
    if (const {1, 5, 9}.contains(s)) return 3;
    if (const {2, 6, 10}.contains(s)) return 2;
    return 1;
  }

  final ok = rank(sa) >= rank(sb);
  return KootaScore(
    name: 'Varna',
    obtained: ok ? 1 : 0,
    max: 1,
    note: ok ? 'Groom Moon-varna same or higher.' : 'Bride Moon-varna higher.',
  );
}

KootaScore _vashya(int sa, int sb) {
  String cls(int s, {required bool firstHalf}) {
    if (s == 5) return 'wild';
    if (s == 8) return 'insect';
    if (s == 1 || s == 2) return 'quad';
    if (s == 9) return firstHalf ? 'human' : 'quad';
    if (s == 10) return firstHalf ? 'quad' : 'water';
    if (s == 4 || s == 12) return 'water';
    return 'human';
  }

  final ca = cls(sa, firstHalf: true);
  final cb = cls(sb, firstHalf: true);
  final same = ca == cb;
  final points = same ? 2.0 : 1.0;
  return KootaScore(
    name: 'Vashya',
    obtained: points,
    max: 2,
    note: same ? 'Same animal class.' : 'Partial vashya (simplified table).',
  );
}

KootaScore _taara(int ia, int ib) {
  double one(int from, int to) {
    final count = ((to - from) % 27) + 1;
    final r = count % 9;
    final rem = r == 0 ? 9 : r;
    return const {3, 5, 7}.contains(rem) ? 0.0 : 1.5;
  }

  final pts = one(ia, ib) + one(ib, ia);
  return KootaScore(
    name: 'Taara',
    obtained: pts,
    max: 3,
    note: pts == 3
        ? 'Both counts auspicious.'
        : pts == 0
            ? 'Both counts Vipat/Pratyari/Vadha.'
            : 'One direction is malefic.',
  );
}

const _mortal = {
  'Horse': 'Buffalo',
  'Buffalo': 'Horse',
  'Elephant': 'Lion',
  'Lion': 'Elephant',
  'Goat': 'Monkey',
  'Monkey': 'Goat',
  'Serpent': 'Mongoose',
  'Mongoose': 'Serpent',
  'Dog': 'Deer',
  'Deer': 'Dog',
  'Cat': 'Rat',
  'Rat': 'Cat',
  'Cow': 'Tiger',
  'Tiger': 'Cow',
};

KootaScore _yoni(NakshatraInfo a, NakshatraInfo b) {
  double pts;
  String note;
  if (a.yoni == b.yoni) {
    pts = 4;
    note = 'Same yoni (${a.yoni}).';
  } else if (_mortal[a.yoni] == b.yoni) {
    pts = 0;
    note = 'Mortal-enemy yonis (${a.yoni}–${b.yoni}).';
  } else {
    pts = 2;
    note = 'Neutral yonis (${a.yoni}–${b.yoni}).';
  }
  return KootaScore(name: 'Yoni', obtained: pts, max: 4, note: note);
}

KootaScore _grahaMaitri(int sa, int sb) {
  final la = signs[sa - 1].ruler;
  final lb = signs[sb - 1].ruler;
  final ab = relation(la, lb);
  final ba = relation(lb, la);
  double pts;
  if (la == lb || (ab == 'friend' && ba == 'friend')) {
    pts = 5;
  } else if ((ab == 'friend' && ba == 'neutral') || (ab == 'neutral' && ba == 'friend')) {
    pts = 4;
  } else if (ab == 'neutral' && ba == 'neutral') {
    pts = 3;
  } else if ((ab == 'friend' && ba == 'enemy') || (ab == 'enemy' && ba == 'friend')) {
    pts = 1;
  } else if ((ab == 'neutral' && ba == 'enemy') || (ab == 'enemy' && ba == 'neutral')) {
    pts = 0.5;
  } else {
    pts = 0;
  }
  return KootaScore(
    name: 'Graha-maitri',
    obtained: pts,
    max: 5,
    note: '$la ($ab) ↔ $lb ($ba).',
  );
}

KootaScore _gana(NakshatraInfo a, NakshatraInfo b) {
  final key = '${a.gana}-${b.gana}';
  final table = PredictionKb.matching['gana'];
  double pts;
  if (table is Map && table['points'] is Map && (table['points'] as Map)[key] != null) {
    pts = ((table['points'] as Map)[key] as num).toDouble();
  } else if (a.gana == b.gana) {
    pts = 6;
  } else if ({a.gana, b.gana}.contains('deva') && {a.gana, b.gana}.contains('manushya')) {
    pts = 5;
  } else if ({a.gana, b.gana}.contains('manushya') && {a.gana, b.gana}.contains('rakshasa')) {
    pts = 1;
  } else {
    pts = 0;
  }
  return KootaScore(
    name: 'Gana',
    obtained: pts,
    max: 6,
    note: '${a.gana} + ${b.gana}.',
  );
}

KootaScore _bhakoot(int sa, int sb) {
  final dist = ((sb - sa) % 12);
  final other = ((sa - sb) % 12);
  final pair = {dist, other};
  final is212 = pair.contains(1) && pair.contains(11);
  final is68 = pair.contains(5) && pair.contains(7);
  final is59 = pair.contains(4) && pair.contains(8);
  final zero = is212 || is68 || is59;
  if (zero && (is212 || is68)) {
    final la = signs[sa - 1].ruler;
    final lb = signs[sb - 1].ruler;
    if (relation(la, lb) == 'friend' && relation(lb, la) == 'friend') {
      return KootaScore(
        name: 'Bhakoot',
        obtained: 7,
        max: 7,
        note:
            'Moon signs are ${is212 ? '2/12' : '6/8'}, mitigated because rashi lords $la and $lb are friends (Charak XXVII).',
      );
    }
  }
  return KootaScore(
    name: 'Bhakoot',
    obtained: zero ? 0 : 7,
    max: 7,
    note: zero
        ? 'Moon signs are ${is212 ? '2/12' : is68 ? '6/8' : '5/9'}.'
        : 'Moon signs are not 2/12, 6/8, or 5/9.',
  );
}

KootaScore _nadi(NakshatraInfo a, NakshatraInfo b, int sa, int sb) {
  if (a.nadi != b.nadi) {
    return const KootaScore(name: 'Nadi', obtained: 8, max: 8, note: 'Different nadi.');
  }
  if (sa == sb && a.index != b.index) {
    return const KootaScore(
      name: 'Nadi',
      obtained: 8,
      max: 8,
      note: 'Same nadi cancelled: same rashi, different nakshatra.',
    );
  }
  if (a.index == b.index && sa != sb) {
    return const KootaScore(
      name: 'Nadi',
      obtained: 8,
      max: 8,
      note: 'Same nadi cancelled: same nakshatra, different rashi.',
    );
  }
  return KootaScore(
    name: 'Nadi',
    obtained: 0,
    max: 8,
    note: 'Same nadi (${a.nadi}) — classical Nadi dosha. Not a ban on love; discuss health/lineage language carefully.',
  );
}

List<String> _overlay(NatalChart a, NatalChart b) {
  final out = <String>[];
  int si(NatalChart c, String p) => signIndex(c.graha(p).siderealLon);
  void contact(String pa, String pb, String label) {
    final d = (si(a, pa) - si(b, pb)).abs() % 12;
    if (d == 0 || d == 6) out.add('$label: ${a.input.name} $pa contacts ${b.input.name} $pb.');
  }

  contact('Moon', 'Moon', 'Mind');
  contact('Sun', 'Sun', 'Pride (two kings if tight)');
  contact('Moon', 'Sun', 'Attraction');
  contact('Venus', 'Mars', 'Passion');
  contact('Mars', 'Venus', 'Passion');
  contact('Mercury', 'Mercury', 'Talk');
  contact('Jupiter', 'Venus', 'Comfort');
  contact('Rahu', 'Moon', 'Karmic pull');
  contact('Ketu', 'Sun', 'Karmic pull');
  if (out.isEmpty) {
    out.add('No exact sign-conjunction/opposition of luminaries. Read the 7th lords and D9 next.');
  }
  return out;
}

String _band(double total) {
  final bands = PredictionKb.matching['score_bands'];
  if (bands is Map) {
    for (final name in const ['excellent', 'mediocre', 'adverse']) {
      final r = bands[name];
      if (r is List && r.length >= 2) {
        final lo = (r[0] as num).toDouble();
        final hi = (r[1] as num).toDouble();
        if (total >= lo && total <= hi) {
          return name == 'adverse' ? 'traditionally not recommended' : name;
        }
      }
    }
  }
  if (total >= 24) return 'excellent';
  if (total >= 12) return 'mediocre';
  return 'traditionally not recommended';
}

bool _kujaCancelMalefics(NatalChart c) {
  if (c.input.timeUnknown) return false;
  const houses = {1, 4, 7, 8, 12};
  for (final p in ['Sun', 'Saturn', 'Rahu', 'Ketu']) {
    try {
      if (houses.contains(c.graha(p).house)) return true;
    } catch (_) {}
  }
  return false;
}

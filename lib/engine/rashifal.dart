/// The daily reading, by moon sign.
///
/// This is *rashifal* as the classical tradition actually does it: gochara —
/// where the grahas are today — counted from a moon sign, not sun-sign copy
/// written by a person. Every sentence in a reading comes from
/// `results_from_moon` in the knowledge base, selected by the house a graha
/// genuinely occupies from that rashi today. Nothing here is composed prose,
/// and nothing is invented for a sign that has no transit to report.
///
/// It is the coarsest reading the app produces, and it says so. A rashi is
/// one twelfth of the population; the Today tab, which reads the same transits
/// against one birth chart with its ashtakavarga, tarabala and running dasha,
/// is strictly better. The UI links to it whenever the reader has a chart.
///
/// Sources: `assets/kb/transits.json` — Charak ch. XXIX (Gochara) for the
/// house results, the benefic-house table, and the vedha pairs.
library;

import '../domain/models.dart';
import '../l10n/engine_strings.dart';
import 'astronomy.dart';
import 'kb.dart';
import 'panchanga.dart';
import 'tables.dart';
import 'time_convert.dart';
import 'today.dart' show DayGrade;

/// The nine grahas a daily reading considers, slowest last so the list reads
/// from "changes today" to "the standing weather".
const rashifalGrahas = [
  'Moon',
  'Sun',
  'Mercury',
  'Venus',
  'Mars',
  'Jupiter',
  'Saturn',
  'Rahu',
  'Ketu',
];

/// How much each graha is allowed to move the day's tone.
///
/// The Moon carries the day because it changes sign every two and a bit days;
/// Jupiter and Saturn carry weight because when they are wrong they stay wrong
/// for a year. The fast inner grahas are colour, not structure.
const _weight = <String, int>{
  'Moon': 2,
  'Sun': 1,
  'Mercury': 1,
  'Venus': 1,
  'Mars': 1,
  'Jupiter': 2,
  'Saturn': 2,
  'Rahu': 1,
  'Ketu': 1,
};

/// One graha's transit, judged from one rashi.
class RashiLine {
  const RashiLine({
    required this.graha,
    required this.house,
    required this.sign,
    required this.benefic,
    required this.obstructed,
    required this.reading,
  });

  final String graha;

  /// Whole-sign house counted from the rashi being read, 1 to 12.
  final int house;

  /// The sign the graha is actually standing in today.
  final int sign;

  /// True when this house is one of the graha's classical benefic houses.
  final bool benefic;

  /// True when a benefic transit is cancelled by vedha — another graha sitting
  /// in the paired obstructing house. Most modern readings skip this and lose
  /// accuracy for it.
  final bool obstructed;

  /// The knowledge base's reading for this graha in this house from the Moon.
  final String reading;

  /// What this line contributes to the day's tone.
  int get score {
    final w = _weight[graha] ?? 1;
    if (benefic) return obstructed ? 0 : w;
    return -w;
  }

  /// Lines a reader should see first: the strongest claims, either way.
  int get prominence => score.abs() * 10 + (graha == 'Moon' ? 5 : 0);
}

/// One rashi's day.
class RashiDay {
  const RashiDay({
    required this.sign,
    required this.date,
    required this.grade,
    required this.score,
    required this.moonHouse,
    required this.lines,
  });

  /// Moon-sign index, 0 = Aries.
  final int sign;
  final DateTime date;
  final DayGrade grade;
  final int score;

  /// Where the transiting Moon is from this rashi — the day's centre.
  final int moonHouse;

  /// All nine, ordered by how much they have to say.
  final List<RashiLine> lines;

  String get name => signName(sign);

  /// The line the Moon contributes, which is the one that changes daily.
  RashiLine get moonLine => lines.firstWhere((l) => l.graha == 'Moon');

  /// The two or three worth putting on a card.
  List<RashiLine> get highlights =>
      lines.where((l) => l.score != 0).take(3).toList();

  /// One sentence a reader can stop at.
  String get headline => tr('rashi.headline.${grade.name}', {
        'sign': name,
        'house': ordinal(moonHouse),
      });
}

/// Today's reading for every rashi, in zodiac order.
///
/// Computed in one pass: the transit positions are the same for all twelve
/// signs, only the house each falls in differs. Running the ephemeris once
/// rather than twelve times is what makes this cheap enough to put on the
/// home screen.
List<RashiDay> rashifalForAll({
  required Place place,
  DateTime? now,
}) {
  final at = (now ?? DateTime.now()).toUtc();
  final pan = panchangaFor(
    at: at,
    latitude: place.latitude,
    longitudeEast: place.longitude,
    timezone: place.timezone,
  );

  // The panchanga is reckoned at the governing sunrise, and so is the reading:
  // a rashifal is for a day, not for the instant the app was opened.
  final jd = julianDayUtc(pan.daylight.sunrise.toUtc());
  final ayanamsa = lahiriAyanamsa(jd);
  final signs = <String, int>{};
  for (final graha in rashifalGrahas) {
    final tropical = switch (graha) {
      'Sun' => sunLongitude(jd),
      'Moon' => moonLongitude(jd),
      'Rahu' => meanNodeLongitude(jd),
      'Ketu' => norm360(meanNodeLongitude(jd) + 180),
      _ => planetLongitude(graha, jd),
    };
    signs[graha] = signIndex(norm360(tropical - ayanamsa));
  }

  return [
    for (var rashi = 0; rashi < 12; rashi++) _forSign(rashi, pan, signs),
  ];
}

/// Today's reading for one rashi.
RashiDay rashifalFor(int sign, {required Place place, DateTime? now}) =>
    rashifalForAll(place: place, now: now)[sign % 12];

RashiDay _forSign(int rashi, PanchangaDay pan, Map<String, int> signs) {
  final kb = PredictionKb.current;

  // Which houses from this rashi are occupied, so vedha can be checked.
  final occupied = <int>{
    for (final e in signs.entries) wholeSignHouse(rashi, e.value),
  };

  final lines = <RashiLine>[];
  for (final graha in rashifalGrahas) {
    final sign = signs[graha];
    if (sign == null) continue;
    final house = wholeSignHouse(rashi, sign);
    final benefic = kb.beneficTransitHouses(graha).contains(house);
    final obstructing = kb.vedhaPairs(graha)[house];
    lines.add(
      RashiLine(
        graha: graha,
        house: house,
        sign: sign,
        benefic: benefic,
        // Vedha only cancels a benefic result, and only when the obstructing
        // house actually holds something.
        obstructed:
            benefic && obstructing != null && occupied.contains(obstructing),
        reading: kb.gocharaFromMoon(graha, house),
      ),
    );
  }

  lines.sort((a, b) => b.prominence.compareTo(a.prominence));
  final score = lines.fold<int>(0, (a, l) => a + l.score);

  return RashiDay(
    sign: rashi,
    date: pan.date,
    grade: _gradeOf(score - _neutralBaseline()),
    score: score,
    moonHouse: wholeSignHouse(rashi, signs['Moon'] ?? 0),
    lines: lines,
  );
}

/// The score an average day produces, derived from the tables themselves.
///
/// This exists because the raw tally is structurally negative and reading it
/// as-is would grade almost every sign "guarded" almost every day. Benefic
/// houses are a minority for most grahas — Saturn, Mars, Rahu and Ketu are
/// favourable in only three houses out of twelve — so a graha picked at random
/// contributes a negative number more often than a positive one. Summed over
/// nine grahas the neutral point sits near −2.7, not zero.
///
/// Computing it from `beneficTransitHouses` rather than hardcoding −2.7 means
/// the scale re-centres itself if the knowledge base is ever recompiled with
/// different tables, instead of silently drifting.
///
/// The consequence for a reader is the honest one: "mixed" means an ordinary
/// day for that sign, and "guarded" means a day genuinely worse than usual —
/// rather than every sign being told the sky is against them every morning.
double _neutralBaseline() {
  var expected = 0.0;
  for (final graha in rashifalGrahas) {
    final benefic = PredictionKb.current.beneficTransitHouses(graha).length;
    final w = (_weight[graha] ?? 1).toDouble();
    expected += (benefic / 12) * w - ((12 - benefic) / 12) * w;
  }
  return expected;
}

/// The same four-band vocabulary the Today tab uses, so a reader who has both
/// is not asked to learn two scales.
///
/// Graded on the distance from [_neutralBaseline], not on the raw tally.
///
/// The cut points are not round numbers because the distribution is not
/// symmetric. Sampling a full year across all twelve rashis (4,380 readings)
/// puts the mean at the baseline by construction but the *median* about 2.3
/// below it: benefic houses are scarce for most grahas, so the tail of bad
/// days is long and the bulk sits left of the mean. Cutting at ±0 would call
/// a perfectly ordinary Tuesday "guarded" for nearly half of all signs.
///
/// These four thresholds sit near the 24th, 58th and 83rd percentiles of that
/// year, which spreads readings roughly 24/34/25/17 across guarded, mixed,
/// workable and favourable. So "guarded" means a day in the worst quarter for
/// that sign — a claim worth making — rather than the app's default mood.
DayGrade _gradeOf(double relative) {
  if (relative >= 1.5) return DayGrade.favourable;
  if (relative >= -1.5) return DayGrade.workable;
  if (relative >= -4.5) return DayGrade.mixed;
  return DayGrade.guarded;
}

/// The neutral point, exposed so a test can assert the scale is centred and
/// the UI could show "better/worse than usual" if it ever wanted to.
double get rashifalNeutralScore => _neutralBaseline();

/// The moon sign a saved chart reads from, for marking "your rashi".
int rashiOf(NatalChart chart) => signIndex(chart.graha('Moon').siderealLon);

/// The moon sign of a birth record, without building the whole chart.
///
/// The home screen needs this for every saved profile just to label one card.
/// `chartFor` would run an ephemeris, a dasha tree, 77 yoga conditions and an
/// ashtakavarga to answer a question that is one Moon longitude deep.
int moonRashiOf(BirthInput input) {
  final jd = julianDayUtc(toUtc(input));
  return signIndex(norm360(moonLongitude(jd) - lahiriAyanamsa(jd)));
}

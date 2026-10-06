/// One day, read against one chart.
///
/// The panchanga in `panchanga.dart` describes the day for everybody in a
/// place. This file is the half that is personal: tarabala and chandrabala
/// measure today's Moon against *your* birth Moon, the kakshya count measures
/// today's transits against *your* ashtakavarga, and the running dasha says
/// which chapter the day lands in.
///
/// The order of judgment is the one the rest of the app follows and the one
/// the classics insist on: the natal promise first, the dasha second, and the
/// day's transit last. A daily filter can colour a day. It cannot create an
/// event the chart never promised, and it cannot delete one the dasha is
/// delivering. [TodayReport.grade] is therefore a tone, not a verdict, and the
/// UI says so out loud.
///
/// Sources: Charak, *Elements of Vedic Astrology* — ch. XXVI (Muhurta),
/// XXIX (Gochara), XXX (Ashtakavarga); tables in `assets/kb/panchanga.json`.
library;

import '../domain/models.dart';
import '../l10n/engine_strings.dart';
import 'ashtakavarga.dart';
import 'astronomy.dart';
import 'dasha.dart';
import 'kb.dart';
import 'panchanga.dart';
import 'tables.dart';

/// Where today's Moon falls counted from the birth Moon's nakshatra.
class Tarabala {
  const Tarabala({
    required this.count,
    required this.tara,
    required this.name,
    required this.reading,
    required this.malefic,
  });

  /// Inclusive nakshatra count, 1 to 27.
  final int count;

  /// The tara itself, 1 to 9.
  final int tara;
  final String name;
  final String reading;
  final bool malefic;
}

/// Where today's Moon falls counted from the birth Moon's sign.
class Chandrabala {
  const Chandrabala({
    required this.house,
    required this.good,
    required this.bad,
    required this.rule,
  });

  /// Whole-sign house of the transiting Moon from the janma rashi, 1 to 12.
  final int house;
  final bool good;
  final bool bad;
  final String rule;
}

/// One thing the day is suited to, or one thing to hold back on.
class DayCue {
  const DayCue({
    required this.text,
    required this.favour,
    required this.because,
  });

  final String text;

  /// True for "lean into", false for "hold off".
  final bool favour;

  /// The classical reason, shown when the reader asks why.
  final String because;
}

/// How the day reads overall: a tone, never a verdict.
enum DayGrade { favourable, workable, mixed, guarded }

extension DayGradeText on DayGrade {
  String get label => tr('today.grade.$name');
  String get summary => tr('today.grade.$name.sub');
}

class TodayReport {
  const TodayReport({
    required this.now,
    required this.panchanga,
    required this.grade,
    required this.score,
    required this.tarabala,
    required this.chandrabala,
    required this.kakshya,
    required this.moonHouse,
    required this.md,
    required this.ad,
    required this.pd,
    required this.cues,
    required this.guidance,
    required this.remedy,
    required this.place,
  });

  final DateTime now;
  final PanchangaDay panchanga;

  final DayGrade grade;

  /// The raw tally behind [grade], shown in the working-out.
  final int score;

  final Tarabala tarabala;

  /// Null when the birth Moon sign is unusable — never in practice, but the
  /// type says what the engine guarantees.
  final Chandrabala chandrabala;

  /// Null when the birth time is unknown: the ashtakavarga needs the lagna as
  /// its eighth contributor.
  final KakshyaDay? kakshya;

  /// Whole-sign house the transiting Moon occupies from the natal lagna, or
  /// from the natal Moon when the birth time is unknown.
  final int moonHouse;

  final DashaSpan? md;
  final DashaSpan? ad;
  final DashaSpan? pd;

  final List<DayCue> cues;

  /// Two or three sentences a reader can stop at.
  final List<String> guidance;

  /// The behavioural remedy for the graha carrying today, if there is one.
  final String remedy;

  /// The place the day was reckoned at — sunrise is local, so this matters.
  final Place place;

  List<DayCue> get favour => cues.where((c) => c.favour).toList();
  List<DayCue> get hold => cues.where((c) => !c.favour).toList();
}

/// Reads [chart] against the day containing [now].
TodayReport todayFor(NatalChart chart, {DateTime? now}) {
  now ??= DateTime.now().toUtc();
  final place = chart.input.place;

  final pan = panchangaFor(
    at: now,
    latitude: place.latitude,
    longitudeEast: place.longitude,
    timezone: place.timezone,
  );

  final natalMoon = chart.graha('Moon');
  final natalNakshatra = nakshatraOf(natalMoon.siderealLon);
  final moonSign = signIndex(natalMoon.siderealLon);
  final lagnaSign =
      chart.input.timeUnknown ? moonSign : signIndex(chart.lagnaSidereal);

  final tarabala = _tarabala(natalNakshatra.index, pan.nakshatra.number - 1);
  final chandrabala = _chandrabala(moonSign, signIndex(pan.moonSidereal));
  final moonHouse = wholeSignHouse(lagnaSign, signIndex(pan.moonSidereal));

  final md = chart.mahadashaAt(now);
  final ad = chart.antardashaAt(now);
  final pd = ad == null ? null : pratyantaraAt(ad, now);

  final kakshya = _kakshyaToday(chart, pan.daylight.sunrise);

  final score = _score(pan, tarabala, chandrabala, kakshya);
  final grade = _gradeOf(score);

  return TodayReport(
    now: now,
    panchanga: pan,
    grade: grade,
    score: score,
    tarabala: tarabala,
    chandrabala: chandrabala,
    kakshya: kakshya,
    moonHouse: moonHouse,
    md: md,
    ad: ad,
    pd: pd,
    cues: _cues(pan, tarabala, chandrabala, kakshya, moonHouse),
    guidance: _guidance(chart, pan, grade, tarabala, chandrabala, md, ad, pd,
        moonHouse),
    remedy: _remedy(pan, md, ad),
    place: place,
  );
}

// ---------------------------------------------------------------------------
// The two Moon strengths
// ---------------------------------------------------------------------------

Tarabala _tarabala(int natalIndex, int todayIndex) {
  final count = ((todayIndex - natalIndex) % 27) + 1;
  final tara = ((count - 1) % 9) + 1;
  final table = PredictionKb.module('panchanga')['tarabala'];
  final rows = table is Map ? table['taras'] : null;
  final row = rows is List && rows.length >= tara
      ? rows[tara - 1] as Map<String, dynamic>
      : const <String, dynamic>{};
  final malefic = table is Map && table['malefic_taras'] is List
      ? (table['malefic_taras'] as List).contains(row['name'])
      : false;
  return Tarabala(
    count: count,
    tara: tara,
    name: row['name'] as String? ?? '$tara',
    reading: row['reading'] as String? ?? '',
    malefic: malefic,
  );
}

Chandrabala _chandrabala(int natalMoonSign, int transitMoonSign) {
  final house = wholeSignHouse(natalMoonSign, transitMoonSign);
  final table = PredictionKb.module('panchanga')['chandrabala'];
  final good = table is Map && table['good_houses_from_janma_rashi'] is List
      ? (table['good_houses_from_janma_rashi'] as List).contains(house)
      : false;
  final bad = table is Map && table['bad_houses_from_janma_rashi'] is List
      ? (table['bad_houses_from_janma_rashi'] as List).contains(house)
      : false;
  return Chandrabala(
    house: house,
    good: good,
    bad: bad,
    rule: table is Map ? (table['rule'] as String? ?? '') : '',
  );
}

/// Today's seven grahas judged against the natal bhinnashtakavarga kakshyas.
///
/// Charak treats this as the daily filter proper — and only as a filter. It
/// needs the lagna, so an unknown birth time withholds it rather than guessing.
KakshyaDay? _kakshyaToday(NatalChart chart, DateTime reference) {
  final av = ashtakavargaFor(chart);
  if (av == null) return null;
  final jd = julianDayUtc(reference.toUtc());
  final ayanamsa = lahiriAyanamsa(jd);
  final lons = <String, double>{};
  for (final p in avPlanets) {
    final tropical = p == 'Sun'
        ? sunLongitude(jd)
        : p == 'Moon'
            ? moonLongitude(jd)
            : planetLongitude(p, jd);
    lons[p] = norm360(tropical - ayanamsa);
  }
  return kakshyaDay(av, lons);
}

// ---------------------------------------------------------------------------
// The tally
// ---------------------------------------------------------------------------

/// Adds up the day's filters. Deliberately small numbers: no single classical
/// filter is allowed to swing a day on its own.
int _score(
  PanchangaDay pan,
  Tarabala tara,
  Chandrabala chandra,
  KakshyaDay? kakshya,
) {
  var score = 0;

  if (tara.malefic) {
    score -= 2;
  } else if (tara.tara == 1) {
    score += 0; // Janma tara: mixed, by the book.
  } else {
    score += 2;
  }

  if (chandra.good) score += 2;
  if (chandra.bad) score -= 2;

  if (!pan.tithi.auspicious) score -= 2; // rikta
  if (!pan.yoga.auspicious) score -= 1;
  if (!pan.karana.auspicious) score -= 1; // Vishti / Bhadra

  if (kakshya != null) {
    if (kakshya.score >= 5) {
      score += 2;
    } else if (kakshya.score == 4) {
      score += 1;
    } else if (kakshya.score == 2) {
      score -= 1;
    } else if (kakshya.score <= 1) {
      score -= 2;
    }
  }

  return score;
}

DayGrade _gradeOf(int score) {
  if (score >= 5) return DayGrade.favourable;
  if (score >= 2) return DayGrade.workable;
  if (score >= -1) return DayGrade.mixed;
  return DayGrade.guarded;
}

// ---------------------------------------------------------------------------
// Suggestions
// ---------------------------------------------------------------------------

List<DayCue> _cues(
  PanchangaDay pan,
  Tarabala tara,
  Chandrabala chandra,
  KakshyaDay? kakshya,
  int moonHouse,
) {
  final out = <DayCue>[];
  final panchangaKb = PredictionKb.module('panchanga');
  final varaRow = panchangaKb['vara'] is Map
      ? (panchangaKb['vara'] as Map)[varaNames[pan.date.weekday - 1]]
      : null;

  final varaLabel = pan.vara.name;

  if (varaRow is Map) {
    for (final item in (varaRow['good_for'] as List? ?? const [])) {
      if (item is! String) continue;
      out.add(
        DayCue(
          text: item,
          favour: true,
          because: tr('today.why.vara_good', {'vara': varaLabel}),
        ),
      );
    }
    for (final item in (varaRow['avoid'] as List? ?? const [])) {
      if (item is! String) continue;
      // Wednesday's "avoid" entry is prose about Abhijit rather than an
      // activity; it belongs with the windows, not in a hold-off list.
      if (item.contains(';') || item.length > 60) continue;
      out.add(
        DayCue(
          text: item,
          favour: false,
          because: tr('today.why.vara_avoid', {'vara': varaLabel}),
        ),
      );
    }
  }

  // The tithi group is the classical "what is this day shaped like" answer.
  if (pan.tithi.meaning.isNotEmpty) {
    out.add(
      DayCue(
        text: pan.tithi.meaning,
        favour: pan.tithi.auspicious,
        because: tr('today.why.tithi', {
          'tithi': pan.tithi.name,
          'paksha': pan.pakshaName,
        }),
      ),
    );
  }

  if (tara.malefic) {
    out.add(
      DayCue(
        text: tr('today.cue.tara_bad'),
        favour: false,
        because: '${tara.name}: ${tara.reading}',
      ),
    );
  } else if (tara.tara != 1) {
    out.add(
      DayCue(
        text: tr('today.cue.tara_good'),
        favour: true,
        because: '${tara.name}: ${tara.reading}',
      ),
    );
  }

  if (chandra.bad) {
    out.add(
      DayCue(
        text: tr('today.cue.chandra_bad', {'house': ordinal(chandra.house)}),
        favour: false,
        because: chandra.rule,
      ),
    );
  } else if (chandra.good) {
    out.add(
      DayCue(
        text: tr('today.cue.chandra_good', {'house': ordinal(chandra.house)}),
        favour: true,
        because: chandra.rule,
      ),
    );
  }

  if (!pan.karana.auspicious) {
    out.add(
      DayCue(
        text: tr('today.cue.vishti'),
        favour: false,
        because: tr('today.why.karana', {'karana': pan.karana.name}),
      ),
    );
  }

  if (kakshya != null && kakshya.score <= 2) {
    out.add(
      DayCue(
        text: tr('today.cue.kakshya_low'),
        favour: false,
        because: kakshya.line,
      ),
    );
  } else if (kakshya != null && kakshya.score >= 5) {
    out.add(
      DayCue(
        text: tr('today.cue.kakshya_high'),
        favour: true,
        because: kakshya.line,
      ),
    );
  }

  // The Moon's house from the lagna is the day's centre of gravity.
  out.add(
    DayCue(
      text: tr('today.cue.moon_house', {'topic': houseTopic(moonHouse)}),
      favour: true,
      because: tr('today.why.moon_house', {'house': ordinal(moonHouse)}),
    ),
  );

  return out;
}

List<String> _guidance(
  NatalChart chart,
  PanchangaDay pan,
  DayGrade grade,
  Tarabala tara,
  Chandrabala chandra,
  DashaSpan? md,
  DashaSpan? ad,
  DashaSpan? pd,
  int moonHouse,
) {
  final kb = PredictionKb.current;
  final out = <String>[];

  out.add(
    tr('today.guide.open', {
      'grade': grade.label.toLowerCase(),
      'tithi': pan.tithi.name,
      'paksha': pan.pakshaName,
      'nakshatra': pan.nakshatra.name,
      'vara': pan.vara.name,
    }),
  );

  out.add(
    tr('today.guide.moon', {
      'sign': signName(signIndex(pan.moonSidereal)),
      'house': ordinal(moonHouse),
      'topic': houseTopic(moonHouse),
    }),
  );

  if (md != null) {
    final lord = ad?.lord ?? md.lord;
    final push = kb.dashaPush(lord);
    final wait = kb.dashaWait(lord);
    out.add(
      tr('today.guide.dasha', {
        'md': grahaName(md.lord),
        'ad': grahaName(lord),
        'push': push,
        'wait': wait,
      }),
    );
  }

  if (tara.malefic || chandra.bad) {
    out.add(tr('today.guide.soft_day'));
  } else if (grade == DayGrade.favourable) {
    out.add(tr('today.guide.strong_day'));
  }

  final abhijit = pan.window('abhijit');
  if (abhijit != null && abhijit.favourable) {
    out.add(tr('today.guide.abhijit'));
  }

  out.add(tr('today.guide.order'));
  return out;
}

/// The behavioural remedy PocketAstro leads with, for the graha carrying the
/// day. Stones and rituals stay where they are — this is the practical line.
String _remedy(PanchangaDay pan, DashaSpan? md, DashaSpan? ad) {
  final lord = ad?.lord ?? md?.lord;
  for (final candidate in [lord, _varaLord(pan)]) {
    if (candidate == null) continue;
    final row = PredictionKb.current.remedyFor(candidate);
    final practical = row['practical'];
    if (practical is String && practical.isNotEmpty) {
      return tr('today.remedy', {
        'graha': grahaName(candidate),
        'practical': practical,
      });
    }
  }
  return '';
}

String? _varaLord(PanchangaDay pan) {
  final vara = PredictionKb.module('panchanga')['vara'];
  if (vara is! Map) return null;
  final row = vara[varaNames[pan.date.weekday - 1]];
  return row is Map ? row['lord'] as String? : null;
}

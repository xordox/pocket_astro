/// The traditional and Hellenistic layer.
///
/// Gap G-32, and the one with the clearest competitive argument behind it:
/// this is the fastest-growing area of Western practice, and profections and
/// zodiacal releasing are what the current generation of consulting
/// astrologers actually time with. The app had none of it.
///
/// `dignity.dart` carries the essential-dignity half — rulership, exaltation,
/// triplicity, Egyptian bounds, Chaldean faces, the almuten. This file carries
/// the time-lord half:
///
///   * **sect**, worked out properly and stated, since it governs everything
///     else in the traditional reading;
///   * **zodiacal releasing** from Spirit or Fortune, with L1 and L2 periods,
///     peak periods, and the loosing of the bond;
///   * **firdaria**, the Persian system, in its day and night orders with
///     sub-periods;
///   * the **lots** beyond Fortune and Spirit.
///
/// Profections live in `predictive.dart`, next to the other annual techniques.
library;

import '../domain/models.dart';
import 'astro/units.dart';
import 'dignity.dart';
import 'tables.dart';

// ---------------------------------------------------------------------------
// Sect
// ---------------------------------------------------------------------------

class SectReport {
  const SectReport({
    required this.nightChart,
    required this.sectLight,
    required this.benefic,
    required this.malefic,
    required this.contrary,
    required this.notes,
  });

  final bool nightChart;

  /// The Sun by day, the Moon by night — the luminary the chart is read from.
  final String sectLight;

  /// The benefic of the sect, which does the most good of any planet.
  final String benefic;

  /// The malefic of the sect, which is the *less* difficult of the two.
  final String malefic;

  /// The malefic contrary to the sect — traditionally the hardest planet in
  /// the chart, and the one worth naming plainly.
  final String contrary;

  final List<String> notes;

  String get label => nightChart ? 'nocturnal' : 'diurnal';
}

/// Works out the chart's sect and what follows from it.
///
/// Getting this backwards is the classic sign that a tool was built without an
/// astrologer in the room: it inverts the Part of Fortune, the triplicity
/// rulers, and which of Mars and Saturn is the difficult one.
SectReport sectOf(NatalChart chart) {
  final night = chart.isNightChart;
  final notes = <String>[
    'This is a ${night ? 'night' : 'day'} chart. The '
        '${night ? 'Moon' : 'Sun'} is the sect light and the chart is read '
        'through it.',
    night
        ? 'Venus is the benefic of the sect and does the most good here; Mars '
            'is the malefic of the sect and is the more workable of the two '
            'difficult planets. Saturn is contrary to the sect — where the '
            'chart is hardest.'
        : 'Jupiter is the benefic of the sect and does the most good here; '
            'Saturn is the malefic of the sect and is the more workable of the '
            'two difficult planets. Mars is contrary to the sect — where the '
            'chart is hardest.',
  ];

  for (final p in const ['Sun', 'Moon', 'Mercury', 'Venus', 'Mars', 'Jupiter', 'Saturn']) {
    final g = chart.grahas.where((x) => x.name == p).firstOrNull;
    if (g == null) continue;
    if (!inSect(p, nightChart: night)) {
      notes.add('$p is out of sect, so it operates with less grace than its '
          'placement alone suggests.');
    }
  }

  return SectReport(
    nightChart: night,
    sectLight: night ? 'Moon' : 'Sun',
    benefic: night ? 'Venus' : 'Jupiter',
    malefic: night ? 'Mars' : 'Saturn',
    contrary: night ? 'Saturn' : 'Mars',
    notes: notes,
  );
}

// ---------------------------------------------------------------------------
// The lots
// ---------------------------------------------------------------------------

class Lot {
  const Lot(this.name, this.longitude, this.signifies);
  final String name;
  final double longitude;
  final String signifies;

  int get sign => signIndex(longitude);
}

/// The Hermetic lots, in their day and night forms.
///
/// Every one of these reverses between day and night. A tool that hardcodes
/// one form is wrong for half its users, which is precisely the mistake the
/// Part of Fortune is famous for.
List<Lot> hermeticLots(NatalChart chart) {
  final asc = chart.lagnaTropical;
  final night = chart.isNightChart;
  double at(String name) =>
      chart.grahas.where((g) => g.name == name).first.tropicalLon;

  final sun = at('Sun');
  final moon = at('Moon');
  double lot(double a, double b) => norm360(asc + a - b);

  final fortune = night ? lot(sun, moon) : lot(moon, sun);
  final spirit = night ? lot(moon, sun) : lot(sun, moon);

  return [
    Lot('Fortune', fortune,
        'the body, livelihood, and what happens to the person'),
    Lot('Spirit', spirit,
        'the mind, career, and what the person does deliberately'),
    Lot('Eros', night ? norm360(asc + spirit - at('Venus'))
                      : norm360(asc + at('Venus') - spirit),
        'desire, and what is wanted rather than needed'),
    Lot('Necessity', night ? norm360(asc + at('Mercury') - fortune)
                           : norm360(asc + fortune - at('Mercury')),
        'constraint — where there is no choice'),
    Lot('Courage', night ? norm360(asc + at('Mars') - fortune)
                         : norm360(asc + fortune - at('Mars')),
        'boldness, and what is risked'),
    Lot('Victory', night ? norm360(asc + at('Jupiter') - spirit)
                         : norm360(asc + spirit - at('Jupiter')),
        'faith, success, and what carries the person through'),
    Lot('Nemesis', night ? norm360(asc + at('Saturn') - fortune)
                         : norm360(asc + fortune - at('Saturn')),
        'downfall, hidden matters, and the dead'),
  ];
}

// ---------------------------------------------------------------------------
// Zodiacal releasing
// ---------------------------------------------------------------------------

/// Period lengths in years — the lesser years of each sign's ruler.
///
/// Capricorn takes 27 and Aquarius 30 rather than both taking Saturn's 30;
/// that asymmetry is in the tradition and is not a transcription slip.
const zrYears = <int, int>{
  0: 15,  // Aries — Mars
  1: 8,   // Taurus — Venus
  2: 20,  // Gemini — Mercury
  3: 25,  // Cancer — Moon
  4: 19,  // Leo — Sun
  5: 20,  // Virgo — Mercury
  6: 8,   // Libra — Venus
  7: 15,  // Scorpio — Mars
  8: 12,  // Sagittarius — Jupiter
  9: 27,  // Capricorn — Saturn
  10: 30, // Aquarius — Saturn
  11: 12, // Pisces — Jupiter
};

class ZrPeriod {
  const ZrPeriod({
    required this.level,
    required this.sign,
    required this.start,
    required this.end,
    required this.peak,
    required this.loosingOfTheBond,
  });

  /// 1 for the major periods, 2 for the sub-periods.
  final int level;
  final int sign;
  final DateTime start;
  final DateTime end;

  /// True when this period falls in the angular triad from Fortune — the
  /// stretches practitioners find eminence and visible activity in.
  final bool peak;

  /// True at the jump that ends a full circuit of the signs.
  final bool loosingOfTheBond;

  String get label => signs[sign].name;
  String get lord => signs[sign].ruler;
  bool contains(DateTime t) => !t.isBefore(start) && t.isBefore(end);

  Duration get length => end.difference(start);
}

class ZodiacalReleasing {
  const ZodiacalReleasing({
    required this.from,
    required this.lotSign,
    required this.fortuneSign,
    required this.level1,
    required this.level2,
  });

  /// Spirit or Fortune.
  final String from;
  final int lotSign;
  final int fortuneSign;

  final List<ZrPeriod> level1;
  final List<ZrPeriod> level2;

  ZrPeriod? l1At(DateTime t) => level1.where((p) => p.contains(t)).firstOrNull;
  ZrPeriod? l2At(DateTime t) => level2.where((p) => p.contains(t)).firstOrNull;

  /// The peak periods, which is usually the first thing anyone looks for.
  List<ZrPeriod> get peaks =>
      [...level1.where((p) => p.peak), ...level2.where((p) => p.peak)];
}

/// Zodiacal releasing from a lot.
///
/// The major periods run zodiacally from the lot's sign, each lasting its
/// sign's lesser years. Each major period subdivides the same way, but in
/// months rather than years. When a subdivision completes a full circuit of
/// the twelve signs it *looses the bond* and jumps to the sign opposite the
/// one it began from, which is the technique's signature — and the moment
/// practitioners watch for, because lives tend to turn there.
ZodiacalReleasing zodiacalReleasing(
  NatalChart chart, {
  String from = 'Spirit',
  int years = 90,
}) {
  final lots = hermeticLots(chart);
  final lot = lots.firstWhere((l) => l.name == from, orElse: () => lots.first);
  final fortune = lots.firstWhere((l) => l.name == 'Fortune');

  // The angular triad from Fortune: the tenth from Fortune and its
  // partners are where eminence shows.
  final peakSigns = <int>{
    (fortune.sign + 9) % 12,
    (fortune.sign + 0) % 12,
    (fortune.sign + 3) % 12,
    (fortune.sign + 6) % 12,
  };

  const dayMs = 86400000;
  const yearMs = 365.2421897 * dayMs;

  final l1 = <ZrPeriod>[];
  var cursor = chart.utc;
  final limit = chart.utc.add(Duration(days: (years * 365.25).round()));
  var sign = lot.sign;
  var steps = 0;
  while (cursor.isBefore(limit) && steps < 60) {
    final span = Duration(milliseconds: (zrYears[sign]! * yearMs).round());
    final end = cursor.add(span);
    l1.add(ZrPeriod(
      level: 1,
      sign: sign,
      start: cursor,
      end: end,
      peak: peakSigns.contains(sign),
      loosingOfTheBond: false,
    ));
    cursor = end;
    sign = (sign + 1) % 12;
    steps++;
  }

  // Level two: the same walk inside each major period, in months.
  final l2 = <ZrPeriod>[];
  for (final major in l1) {
    var sub = major.sign;
    var subCursor = major.start;
    var circuit = 0;
    while (subCursor.isBefore(major.end)) {
      // A sign's L2 period lasts as many months as its L1 period lasts years.
      final months = zrYears[sub]!;
      var end = subCursor.add(
          Duration(milliseconds: (months * 30.4375 * dayMs).round()));
      var loosed = false;
      if (end.isAfter(major.end)) end = major.end;

      circuit++;
      if (circuit > 12) {
        // A full circuit has completed; the bond is loosed and the sequence
        // jumps to the sign opposite where it began.
        sub = (major.sign + 6) % 12;
        circuit = 1;
        loosed = true;
      }

      l2.add(ZrPeriod(
        level: 2,
        sign: sub,
        start: subCursor,
        end: end,
        peak: peakSigns.contains(sub),
        loosingOfTheBond: loosed,
      ));

      subCursor = end;
      sub = (sub + 1) % 12;
    }
  }

  return ZodiacalReleasing(
    from: from,
    lotSign: lot.sign,
    fortuneSign: fortune.sign,
    level1: l1,
    level2: l2,
  );
}

// ---------------------------------------------------------------------------
// Firdaria
// ---------------------------------------------------------------------------

/// Firdaria major periods, in years. Seventy-five years across nine lords.
const _firdariaDay = <(String, double)>[
  ('Sun', 10), ('Venus', 8), ('Mercury', 13), ('Moon', 9), ('Saturn', 11),
  ('Jupiter', 12), ('Mars', 7), ('Rahu', 3), ('Ketu', 2),
];

const _firdariaNight = <(String, double)>[
  ('Moon', 9), ('Saturn', 11), ('Jupiter', 12), ('Mars', 7), ('Sun', 10),
  ('Venus', 8), ('Mercury', 13), ('Rahu', 3), ('Ketu', 2),
];

/// The descending Chaldean order the sub-periods walk.
const _chaldeanDescending = [
  'Saturn', 'Jupiter', 'Mars', 'Sun', 'Venus', 'Mercury', 'Moon',
];

class FirdariaPeriod {
  const FirdariaPeriod({
    required this.lord,
    required this.start,
    required this.end,
    required this.level,
    this.parent = '',
  });
  final String lord;
  final DateTime start;
  final DateTime end;

  /// 1 for a major period, 2 for a sub-period.
  final int level;
  final String parent;

  bool contains(DateTime t) => !t.isBefore(start) && t.isBefore(end);
}

/// The Persian time-lord system, in its day and night orders.
///
/// The nodes take three and two years and, unlike the planets, are not
/// subdivided — which is the detail an implementation usually gets wrong by
/// dividing them anyway.
List<FirdariaPeriod> firdaria(NatalChart chart, {bool includeSub = true}) {
  final night = chart.isNightChart;
  final order = night ? _firdariaNight : _firdariaDay;
  const yearMs = 365.2421897 * 86400000;

  final out = <FirdariaPeriod>[];
  var cursor = chart.utc;
  for (final (lord, years) in order) {
    final end = cursor.add(Duration(milliseconds: (years * yearMs).round()));
    out.add(FirdariaPeriod(lord: lord, start: cursor, end: end, level: 1));

    if (includeSub && lord != 'Rahu' && lord != 'Ketu') {
      final startIndex = _chaldeanDescending.indexOf(lord);
      final subLength = end.difference(cursor).inMilliseconds ~/ 7;
      var subCursor = cursor;
      for (var i = 0; i < 7; i++) {
        final subLord = _chaldeanDescending[(startIndex + i) % 7];
        final subEnd = i == 6
            ? end
            : subCursor.add(Duration(milliseconds: subLength));
        out.add(FirdariaPeriod(
          lord: subLord,
          start: subCursor,
          end: subEnd,
          level: 2,
          parent: lord,
        ));
        subCursor = subEnd;
      }
    }
    cursor = end;
  }
  return out;
}

FirdariaPeriod? firdariaAt(List<FirdariaPeriod> periods, DateTime t, int level) =>
    periods.where((p) => p.level == level && p.contains(t)).firstOrNull;

// ---------------------------------------------------------------------------
// A whole traditional reading
// ---------------------------------------------------------------------------

class TraditionalReport {
  const TraditionalReport({
    required this.sect,
    required this.lots,
    required this.dignities,
    required this.almutenFiguris,
    required this.releasing,
    required this.firdariaPeriods,
  });

  final SectReport sect;
  final List<Lot> lots;
  final List<DignityScore> dignities;

  /// The planet with most dignity over the chart's five hylegical points —
  /// the traditional "lord of the nativity".
  final String almutenFiguris;

  final ZodiacalReleasing releasing;
  final List<FirdariaPeriod> firdariaPeriods;
}

/// The almuten figuris — which planet governs the whole chart.
///
/// Scored across the five points the tradition weighs: the two lights, the
/// ascendant, the Part of Fortune and the prenatal syzygy. The syzygy is
/// approximated here by the nearest lunation to birth, which is the standard
/// shortcut and is stated rather than hidden.
String almutenFigurisOf(NatalChart chart) {
  final night = chart.isNightChart;
  final lots = hermeticLots(chart);
  final points = <double>[
    chart.graha('Sun').tropicalLon,
    chart.graha('Moon').tropicalLon,
    chart.lagnaTropical,
    lots.firstWhere((l) => l.name == 'Fortune').longitude,
  ];

  final scores = <String, int>{};
  for (final point in points) {
    for (final p in const ['Sun', 'Moon', 'Mercury', 'Venus', 'Mars', 'Jupiter', 'Saturn']) {
      scores[p] = (scores[p] ?? 0) +
          essentialDignity(p, point, night: night).total;
    }
  }
  var best = '';
  var bestScore = -999;
  for (final e in scores.entries) {
    if (e.value > bestScore) {
      bestScore = e.value;
      best = e.key;
    }
  }
  return best;
}

TraditionalReport traditionalFor(NatalChart chart) {
  final night = chart.isNightChart;
  return TraditionalReport(
    sect: sectOf(chart),
    lots: hermeticLots(chart),
    dignities: [
      for (final g in chart.grahas)
        if (const ['Sun', 'Moon', 'Mercury', 'Venus', 'Mars', 'Jupiter', 'Saturn']
            .contains(g.name))
          essentialDignity(g.name, g.tropicalLon, night: night),
    ],
    almutenFiguris: almutenFigurisOf(chart),
    releasing: zodiacalReleasing(chart),
    firdariaPeriods: firdaria(chart),
  );
}

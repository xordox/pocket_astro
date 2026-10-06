/// Muhurta — electional search.
///
/// Gap G-21. The panchanga produced the day's windows, which is the almanac
/// half of the subject. The electional half was missing entirely: "when should
/// I sign this?" is one of the commonest paid questions in practice, and
/// answering it means searching forward, not describing today.
///
/// The search walks a date range in fixed steps and scores each candidate
/// moment against a stated purpose. Everything that contributes to or against
/// a score is recorded, so the answer is a set of reasons rather than a
/// number — an electional recommendation a practitioner cannot inspect is one
/// they cannot defend.
library;

import '../domain/models.dart';
import 'astro/ephemeris.dart';
import 'panchanga.dart';
import 'tables.dart';

/// What the moment is being chosen for.
enum MuhurtaPurpose {
  marriage,
  travel,
  business,
  property,
  education,
  medical,
  newVenture,
  general,
}

extension MuhurtaPurposeInfo on MuhurtaPurpose {
  String get label => switch (this) {
        MuhurtaPurpose.marriage => 'Marriage',
        MuhurtaPurpose.travel => 'Travel',
        MuhurtaPurpose.business => 'Business or a contract',
        MuhurtaPurpose.property => 'Property or moving in',
        MuhurtaPurpose.education => 'Study or beginning a course',
        MuhurtaPurpose.medical => 'Surgery or treatment',
        MuhurtaPurpose.newVenture => 'Starting something new',
        MuhurtaPurpose.general => 'Anything',
      };

  /// The nakshatras the tradition favours for this purpose.
  Set<int> get favouredNakshatras => switch (this) {
        MuhurtaPurpose.marriage =>
          {3, 11, 12, 16, 20, 21, 25, 26}, // Rohini, U.Phal, Hasta, Anuradha…
        MuhurtaPurpose.travel => {0, 4, 6, 12, 14, 21, 23, 26},
        MuhurtaPurpose.business => {2, 7, 12, 13, 20, 21, 22},
        MuhurtaPurpose.property => {3, 7, 11, 20, 21, 25},
        MuhurtaPurpose.education => {6, 7, 12, 16, 21, 26},
        MuhurtaPurpose.medical => {0, 8, 13, 17, 18, 23},
        MuhurtaPurpose.newVenture => {0, 3, 6, 7, 12, 20, 21},
        MuhurtaPurpose.general => {3, 7, 12, 20, 21, 26},
      };

  /// Which houses of the electional chart carry the matter.
  List<int> get houses => switch (this) {
        MuhurtaPurpose.marriage => [1, 7],
        MuhurtaPurpose.travel => [3, 9, 12],
        MuhurtaPurpose.business => [2, 7, 10, 11],
        MuhurtaPurpose.property => [4],
        MuhurtaPurpose.education => [4, 5, 9],
        MuhurtaPurpose.medical => [1, 6, 8],
        MuhurtaPurpose.newVenture => [1, 10, 11],
        MuhurtaPurpose.general => [1, 10],
      };

  String get caution => switch (this) {
        MuhurtaPurpose.medical =>
          'Electional astrology is not medical advice. A surgeon’s calendar '
              'comes first; this can only choose among the times they offer.',
        MuhurtaPurpose.marriage =>
          'A marriage muhurta is traditionally chosen against both charts, not '
              'a calendar alone.',
        _ => '',
      };
}

/// One thing that counted for or against a moment.
class MuhurtaFactor {
  const MuhurtaFactor(this.name, this.points, this.note);
  final String name;

  /// Positive helps, negative hurts.
  final int points;
  final String note;
}

class MuhurtaWindow {
  const MuhurtaWindow({
    required this.start,
    required this.end,
    required this.score,
    required this.factors,
    required this.tithi,
    required this.nakshatra,
    required this.vara,
    required this.lagnaSign,
  });

  final DateTime start;
  final DateTime end;

  /// Higher is better. Not a percentage — a sum of named reasons.
  final int score;
  final List<MuhurtaFactor> factors;

  final String tithi;
  final String nakshatra;
  final String vara;
  final int lagnaSign;

  List<MuhurtaFactor> get helps =>
      factors.where((f) => f.points > 0).toList();
  List<MuhurtaFactor> get hurts =>
      factors.where((f) => f.points < 0).toList();

  String get verdict {
    if (score >= 10) return 'strong';
    if (score >= 5) return 'workable';
    if (score >= 0) return 'thin';
    return 'avoid';
  }
}

class MuhurtaSearch {
  const MuhurtaSearch({
    required this.purpose,
    required this.from,
    required this.to,
    required this.windows,
    required this.rejected,
    required this.notes,
  });

  final MuhurtaPurpose purpose;
  final DateTime from;
  final DateTime to;

  /// Best first.
  final List<MuhurtaWindow> windows;

  /// How many candidates were discarded outright, so a thin result reads as
  /// "the sky was unhelpful" rather than "the search was lazy".
  final int rejected;

  final List<String> notes;
}

/// Tithis the tradition calls burnt for beginnings.
const _dagdhaTithis = {4, 6, 8, 9, 12, 14};

/// Weekday lords, Sunday first.
const _varaLords = ['Sun', 'Moon', 'Mars', 'Mercury', 'Jupiter', 'Venus', 'Saturn'];

/// Searches a range for good moments.
///
/// [native] is optional. With it, tarabala and chandrabala are judged from the
/// person's own Moon, which is what turns a generic almanac into an election
/// for them.
MuhurtaSearch searchMuhurta({
  required MuhurtaPurpose purpose,
  required DateTime from,
  required DateTime to,
  required Place place,
  NatalChart? native,
  Duration step = const Duration(minutes: 30),
  int limit = 12,
  ChartSettings settings = const ChartSettings(),
}) {
  final candidates = <MuhurtaWindow>[];
  var rejected = 0;

  final nativeNakshatra = native == null
      ? null
      : nakshatraOf(native.graha('Moon').siderealLon).index;
  final nativeMoonSign = native == null
      ? null
      : signIndex(native.graha('Moon').siderealLon);

  // The panchanga is per day, so it is computed once per date rather than per
  // candidate — otherwise a fortnight at half-hour steps would solve sunrise
  // seven hundred times.
  final panchangaCache = <String, PanchangaDay>{};

  var cursor = from;
  while (cursor.isBefore(to)) {
    final local = cursor.toLocal();
    final key = '${local.year}-${local.month}-${local.day}';
    final day = panchangaCache.putIfAbsent(
      key,
      () => panchangaFor(
        at: cursor,
        latitude: place.latitude,
        longitudeEast: place.longitude,
        timezone: place.timezone,
      ),
    );

    final factors = <MuhurtaFactor>[];
    var score = 0;

    // Daylight only, unless the purpose says otherwise.
    final inDaylight = cursor.isAfter(day.daylight.sunrise.toUtc()) &&
        cursor.isBefore(day.daylight.sunset.toUtc());
    if (!inDaylight && purpose != MuhurtaPurpose.marriage) {
      rejected++;
      cursor = cursor.add(step);
      continue;
    }

    // Hard rejections: the inauspicious eighths.
    var blocked = false;
    for (final id in const ['rahu', 'yamaganda', 'gulika']) {
      final w = day.window(id);
      if (w == null) continue;
      if (cursor.isAfter(w.start.toUtc()) && cursor.isBefore(w.end.toUtc())) {
        blocked = true;
        break;
      }
    }
    if (blocked) {
      rejected++;
      cursor = cursor.add(step);
      continue;
    }

    // Vishti karana — Bhadra — is a flat refusal for anything auspicious.
    if (day.karana.name.toLowerCase().contains('vishti')) {
      rejected++;
      cursor = cursor.add(step);
      continue;
    }

    final sky = computeSky(
      utc: cursor,
      latitude: place.latitude,
      longitudeEast: place.longitude,
      settings: settings,
    );
    final lagnaSign = signIndex(sky.siderealAscendant);
    final moonSign = signIndex(sky.sidereal('Moon'));
    final moonNakshatra = nakshatraOf(sky.sidereal('Moon')).index;

    // Nakshatra suitability.
    if (purpose.favouredNakshatras.contains(moonNakshatra)) {
      score += 4;
      factors.add(MuhurtaFactor(
        'Nakshatra',
        4,
        '${nakshatras[moonNakshatra].name} is among the stars the tradition '
            'favours for ${purpose.label.toLowerCase()}.',
      ));
    }

    // Tithi.
    final tithiNumber = day.tithi.number;
    if (_dagdhaTithis.contains(tithiNumber % 15)) {
      score -= 3;
      factors.add(MuhurtaFactor('Tithi', -3,
          '${day.tithi.name} is one of the burnt tithis for beginnings.'));
    } else {
      score += 2;
      factors.add(
          MuhurtaFactor('Tithi', 2, '${day.tithi.name} carries no objection.'));
    }

    // Weekday lord against the purpose.
    final varaLord = _varaLords[local.weekday % 7];
    final varaGood = switch (purpose) {
      MuhurtaPurpose.marriage => const {'Venus', 'Jupiter', 'Mercury', 'Moon'},
      MuhurtaPurpose.travel => const {'Mercury', 'Venus', 'Moon'},
      MuhurtaPurpose.business => const {'Mercury', 'Jupiter', 'Venus'},
      MuhurtaPurpose.property => const {'Venus', 'Mercury', 'Jupiter'},
      MuhurtaPurpose.education => const {'Mercury', 'Jupiter'},
      MuhurtaPurpose.medical => const {'Mars', 'Saturn', 'Sun'},
      MuhurtaPurpose.newVenture => const {'Sun', 'Jupiter', 'Mercury'},
      MuhurtaPurpose.general => const {'Jupiter', 'Venus', 'Mercury'},
    }.contains(varaLord);
    if (varaGood) {
      score += 2;
      factors.add(MuhurtaFactor('Weekday', 2,
          '$varaLord rules the day, which suits ${purpose.label.toLowerCase()}.'));
    }

    // The lagna itself: benefics angular help, malefics in the lagna or the
    // eighth are the classic spoilers.
    const benefics = {'Jupiter', 'Venus', 'Mercury'};
    const malefics = {'Mars', 'Saturn', 'Rahu', 'Ketu'};
    for (final name in [...benefics, ...malefics]) {
      final body = sky.bodies[name];
      if (body == null) continue;
      final house =
          ((signIndex(sky.sidereal(name)) - lagnaSign) % 12 + 12) % 12 + 1;
      if (benefics.contains(name) && const {1, 4, 5, 7, 9, 10, 11}.contains(house)) {
        score += 2;
        factors.add(MuhurtaFactor('Lagna', 2,
            '$name stands in the ${ordinal(house)} from the electional lagna.'));
      }
      if (malefics.contains(name) && const {1, 7, 8, 12}.contains(house)) {
        score -= 3;
        factors.add(MuhurtaFactor('Lagna', -3,
            '$name sits in the ${ordinal(house)} — the classic objection.'));
      }
    }

    // The houses that carry the matter should not be occupied by malefics.
    for (final h in purpose.houses) {
      final signOfHouse = (lagnaSign + h - 1) % 12;
      for (final name in malefics) {
        if (signIndex(sky.sidereal(name)) == signOfHouse) {
          score -= 2;
          factors.add(MuhurtaFactor('House ${ordinal(h)}', -2,
              '$name occupies the ${ordinal(h)}, which carries the matter.'));
        }
      }
    }

    // The Moon should not be waning into its last days for a beginning.
    if (day.paksha == 'krishna' && tithiNumber >= 12) {
      score -= 2;
      factors.add(const MuhurtaFactor('Moon', -2,
          'The Moon is nearly dark. The tradition asks for a waxing Moon to '
          'begin things under.'));
    }

    // Tarabala and chandrabala, if a native was supplied.
    if (nativeNakshatra != null) {
      final count = ((moonNakshatra - nativeNakshatra) % 27 + 27) % 27 + 1;
      final tara = ((count - 1) % 9) + 1;
      const maleficTaras = {3, 5, 7};
      if (maleficTaras.contains(tara)) {
        score -= 4;
        factors.add(MuhurtaFactor('Tarabala', -4,
            'Tara $tara from ${native!.input.name}’s birth star — one of the '
            'three the tradition avoids.'));
      } else {
        score += 3;
        factors.add(MuhurtaFactor('Tarabala', 3,
            'Tara $tara from ${native!.input.name}’s birth star is favourable.'));
      }
    }
    if (nativeMoonSign != null) {
      final from12 = ((moonSign - nativeMoonSign) % 12 + 12) % 12 + 1;
      if (const {4, 8, 12}.contains(from12)) {
        score -= 3;
        factors.add(MuhurtaFactor('Chandrabala', -3,
            'The transiting Moon is in the ${ordinal(from12)} from '
            '${native!.input.name}’s natal Moon.'));
      } else if (const {1, 3, 6, 7, 10, 11}.contains(from12)) {
        score += 2;
        factors.add(MuhurtaFactor('Chandrabala', 2,
            'The Moon is in the ${ordinal(from12)} from the natal Moon — a '
            'supportive position.'));
      }
    }

    // Abhijit is a standing exception that overrides most objections.
    final abhijit = day.window('abhijit');
    if (abhijit != null &&
        abhijit.favourable &&
        cursor.isAfter(abhijit.start.toUtc()) &&
        cursor.isBefore(abhijit.end.toUtc())) {
      score += 3;
      factors.add(const MuhurtaFactor('Abhijit', 3,
          'Inside the Abhijit muhurta, which the classics treat as reliable '
          'even when the day is otherwise mixed.'));
    }

    candidates.add(MuhurtaWindow(
      start: cursor,
      end: cursor.add(step),
      score: score,
      factors: factors,
      tithi: day.tithi.name,
      nakshatra: nakshatras[moonNakshatra].name,
      vara: day.vara.name,
      lagnaSign: lagnaSign,
    ));

    cursor = cursor.add(step);
  }

  // Merge adjacent candidates of the same quality into a single window, so the
  // reader gets "10:30 to 12:00" rather than three consecutive rows.
  final merged = <MuhurtaWindow>[];
  for (final c in candidates) {
    if (merged.isNotEmpty &&
        merged.last.end == c.start &&
        merged.last.score == c.score) {
      final previous = merged.removeLast();
      merged.add(MuhurtaWindow(
        start: previous.start,
        end: c.end,
        score: c.score,
        factors: previous.factors,
        tithi: previous.tithi,
        nakshatra: previous.nakshatra,
        vara: previous.vara,
        lagnaSign: previous.lagnaSign,
      ));
    } else {
      merged.add(c);
    }
  }

  merged.sort((a, b) {
    final byScore = b.score.compareTo(a.score);
    return byScore != 0 ? byScore : a.start.compareTo(b.start);
  });

  final notes = <String>[
    'Rahu kaal, Yamaganda, Gulika and Vishti karana are refusals rather than '
        'penalties — moments inside them are not scored at all.',
    if (purpose.caution.isNotEmpty) purpose.caution,
    if (merged.isEmpty)
      'Nothing in this range cleared the hard filters. Widen the window rather '
          'than lowering the bar.',
    if (native != null)
      'Tarabala and chandrabala are judged against ${native.input.name}’s '
          'natal Moon, so these windows are for them and not for anyone else.',
  ];

  return MuhurtaSearch(
    purpose: purpose,
    from: from,
    to: to,
    windows: merged.take(limit).toList(),
    rejected: rejected,
    notes: notes,
  );
}

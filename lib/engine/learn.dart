/// A syllabus, read against the reader's own chart.
///
/// The lesson prose lives in `assets/kb/learn.json` — like every other body of
/// classical text in this app — so a translation is a new overlay file and not
/// a Dart change. What this file adds is the part a textbook cannot: each
/// lesson ends on a line computed from the reader's own chart, so the idea and
/// the worked example arrive together.
///
/// Where a lesson's example needs an ascendant, an unknown birth time gets the
/// same treatment it gets everywhere else in PocketAstro — the example is
/// withheld and the reason is stated, rather than quietly invented.
library;

import '../domain/models.dart';
import '../l10n/engine_strings.dart';
import 'ashtakavarga.dart';
import 'kb.dart';
import 'tables.dart';
import 'yoga.dart';

class LessonPoint {
  const LessonPoint({required this.heading, required this.body});
  final String heading;
  final String body;
}

/// The one question a reader should be able to answer before moving on.
class LessonCheck {
  const LessonCheck({required this.question, required this.answer});
  final String question;
  final String answer;
}

class Lesson {
  const Lesson({
    required this.id,
    required this.levelId,
    required this.number,
    required this.title,
    required this.hook,
    required this.minutes,
    required this.points,
    required this.check,
    required this.inYourChart,
  });

  final String id;
  final String levelId;

  /// 1-based position across the whole syllabus, so a reader can see how far
  /// through the course a lesson sits.
  final int number;

  final String title;

  /// The one sentence the lesson exists to deliver.
  final String hook;

  final int minutes;
  final List<LessonPoint> points;
  final LessonCheck check;

  /// The lesson's idea, found in this reader's chart. Empty when the lesson
  /// has no chart-specific example.
  final String inYourChart;
}

class LearnLevel {
  const LearnLevel({
    required this.id,
    required this.title,
    required this.blurb,
    required this.lessons,
  });

  /// `basic` | `intermediate` | `advanced`
  final String id;
  final String title;
  final String blurb;
  final List<Lesson> lessons;
}

class Syllabus {
  const Syllabus(this.levels);

  final List<LearnLevel> levels;

  List<Lesson> get lessons => [for (final l in levels) ...l.lessons];

  int get lessonCount => lessons.length;

  Lesson? byId(String id) {
    for (final lesson in lessons) {
      if (lesson.id == id) return lesson;
    }
    return null;
  }

  /// The next lesson not in [done], in syllabus order. Null when finished.
  Lesson? nextAfter(Set<String> done) {
    for (final lesson in lessons) {
      if (!done.contains(lesson.id)) return lesson;
    }
    return null;
  }

  int doneIn(LearnLevel level, Set<String> done) =>
      level.lessons.where((l) => done.contains(l.id)).length;
}

/// Builds the syllabus, attaching each lesson's worked example from [chart].
///
/// Passing null returns the same syllabus with the examples left out, which is
/// what a reader browsing without a chart open should see.
Syllabus syllabusFor(NatalChart? chart) {
  final rawLevels = PredictionKb.module('learn')['levels'];
  if (rawLevels is! List) return const Syllabus([]);

  final levels = <LearnLevel>[];
  var number = 0;
  for (final rawLevel in rawLevels) {
    if (rawLevel is! Map) continue;
    final rawLessons = rawLevel['lessons'];
    if (rawLessons is! List) continue;
    final levelId = rawLevel['id'] as String? ?? '';
    final lessons = <Lesson>[];
    for (final raw in rawLessons) {
      if (raw is! Map) continue;
      number++;
      final id = raw['id'] as String? ?? '$number';
      final points = raw['points'];
      final check = raw['check'];
      lessons.add(
        Lesson(
          id: id,
          levelId: levelId,
          number: number,
          title: raw['title'] as String? ?? id,
          hook: raw['hook'] as String? ?? '',
          minutes: raw['minutes'] is int ? raw['minutes'] as int : 5,
          points: [
            if (points is List)
              for (final p in points)
                if (p is Map)
                  LessonPoint(
                    heading: p['heading'] as String? ?? '',
                    body: p['body'] as String? ?? '',
                  ),
          ],
          check: LessonCheck(
            question: check is Map ? check['question'] as String? ?? '' : '',
            answer: check is Map ? check['answer'] as String? ?? '' : '',
          ),
          inYourChart: chart == null ? '' : _example(id, chart),
        ),
      );
    }
    levels.add(
      LearnLevel(
        id: levelId,
        title: rawLevel['title'] as String? ?? levelId,
        blurb: rawLevel['blurb'] as String? ?? '',
        lessons: lessons,
      ),
    );
  }
  return Syllabus(levels);
}

// ---------------------------------------------------------------------------
// The worked examples
// ---------------------------------------------------------------------------

/// The lesson's idea, located in this chart.
///
/// Every branch is wrapped: a syllabus must render even if one example cannot
/// be computed, because a failed example is a missing sentence and a thrown
/// example is a blank tab.
String _example(String id, NatalChart chart) {
  try {
    return _exampleOrThrow(id, chart);
  } catch (_) {
    return '';
  }
}

String _exampleOrThrow(String id, NatalChart chart) {
  final noTime = chart.input.timeUnknown;
  final moon = chart.graha('Moon');
  final sun = chart.graha('Sun');

  switch (id) {
    case 'what-a-chart-is':
      return tr('learn.example.what_a_chart_is', {
        'place': chart.input.place.label,
        'lat': chart.input.place.latitude.toStringAsFixed(2),
        'lon': chart.input.place.longitude.toStringAsFixed(2),
      });

    case 'the-two-zodiacs':
      return tr('learn.example.two_zodiacs', {
        'sidereal': '${formatDms(sun.siderealLon)} ${signName(signIndex(sun.siderealLon))}',
        'tropical': '${formatDms(sun.tropicalLon)} ${signName(signIndex(sun.tropicalLon))}',
        'ayanamsa': chart.ayanamsa.toStringAsFixed(2),
      });

    case 'the-nine-grahas':
      final best = _bestDignity(chart);
      if (best == null) {
        return tr('learn.example.nine_grahas_none', {
          'graha': grahaName(sun.name),
          'sign': signNameOf(sun.sign),
        });
      }
      return tr('learn.example.nine_grahas', {
        'graha': grahaName(best.name),
        'sign': signNameOf(best.sign),
        'dignity': dignityWord(best.dignity),
      });

    case 'the-twelve-houses':
      if (noTime) return tr('learn.example.needs_time');
      final tenth = (signIndex(chart.lagnaSidereal) + 9) % 12;
      return tr('learn.example.twelve_houses', {
        'sign': signName(tenth),
        'lord': grahaName(signs[tenth].ruler),
        'topic': houseTopic(10),
      });

    case 'your-three-signs':
      if (noTime) {
        return tr('learn.example.three_signs_no_time', {
          'moon': signName(signIndex(moon.siderealLon)),
          'sun': signName(signIndex(sun.siderealLon)),
        });
      }
      return tr('learn.example.three_signs', {
        'rising': signName(signIndex(chart.lagnaSidereal)),
        'moon': signName(signIndex(moon.siderealLon)),
        'sun': signName(signIndex(sun.siderealLon)),
      });

    case 'house-lords':
      if (noTime) return tr('learn.example.needs_time');
      final lagnaSign = signIndex(chart.lagnaSidereal);
      final lord = signs[lagnaSign].ruler;
      return tr('learn.example.house_lords', {
        'lord': grahaName(lord),
        'rising': signName(lagnaSign),
        'house': ordinal(chart.graha(lord).house),
        'topic': houseTopic(chart.graha(lord).house),
      });

    case 'aspects':
      if (noTime) return tr('learn.example.needs_time');
      final saturn = chart.graha('Saturn');
      final houses = aspectsFrom('Saturn')
          .map((o) => ((saturn.house + o - 2) % 12) + 1)
          .toList()
        ..sort();
      return tr('learn.example.aspects', {
        'house': ordinal(saturn.house),
        'houses': houses.map(ordinal).join(' \u00b7 '),
      });

    case 'nakshatras':
      final nak = nakshatraOf(moon.siderealLon);
      return tr('learn.example.nakshatras', {
        'nakshatra': nakshatraName(nak.name),
        'pada': '${padaOf(moon.siderealLon)}',
        'lord': grahaName(nak.lord),
      });

    case 'dignity-and-strength':
      final shown = moon.dignity.isEmpty ? _bestDignity(chart) ?? moon : moon;
      if (shown.dignity.isEmpty) {
        return tr('learn.example.dignity_none', {
          'graha': grahaName(shown.name),
          'sign': signNameOf(shown.sign),
        });
      }
      return tr('learn.example.dignity', {
        'graha': grahaName(shown.name),
        'sign': signNameOf(shown.sign),
        'dignity': dignityWord(shown.dignity),
      });

    case 'vimshottari':
      final md = chart.dasha.isEmpty ? null : chart.dasha.first;
      if (md == null) return '';
      final nak = nakshatraOf(moon.siderealLon);
      return tr('learn.example.vimshottari', {
        'lord': grahaName(md.lord),
        'nakshatra': nakshatraName(nak.name),
        'years': '${vimshottariYears[md.lord]?.round() ?? 0}',
      });

    case 'yogas':
      final report = yogaReport(chart);
      final standing = [...report.standing]
        ..sort((a, b) => b.weight.compareTo(a.weight));
      if (standing.isEmpty) return tr('learn.example.yogas_none');
      return tr('learn.example.yogas', {
        'count': '${standing.length}',
        'name': standing.first.name,
      });

    case 'divisional-charts':
      if (noTime) return tr('learn.example.needs_time');
      return tr('learn.example.vargas', {
        'rising': signName(signIndex(chart.lagnaSidereal)),
        'navamsa': signName(chart.navamsaLagna),
      });

    case 'ashtakavarga':
      final av = ashtakavargaFor(chart);
      if (av == null) return tr('learn.example.needs_time');
      final tenth = av.sarvaInHouse(10);
      return tr('learn.example.ashtakavarga', {
        'bindus': '$tenth',
        'verdict': tr(
          tenth > 28 ? 'learn.av.above' : 'learn.av.below',
        ),
      });

    case 'gochara':
      return tr('learn.example.gochara', {
        'moon': signName(signIndex(moon.siderealLon)),
        'nakshatra': nakshatraName(nakshatraOf(moon.siderealLon).name),
      });

    case 'order-of-judgment':
      return tr('learn.example.order');
  }
  return '';
}

/// The most teachable dignity in the chart: an exaltation if there is one,
/// then an own sign, and a debilitation only if nothing better stands — that
/// last case is worth showing, because cancellation is part of the lesson.
///
/// Returns null when no graha holds a dignity at all, which is ordinary.
GrahaRow? _bestDignity(NatalChart chart) {
  const rank = {'exalted': 3, 'own sign': 2, 'debilitated': 1};
  GrahaRow? best;
  var bestScore = 0;
  for (final g in chart.grahas) {
    final score = rank[g.dignity] ?? 0;
    if (score > bestScore) {
      bestScore = score;
      best = g;
    }
  }
  return best;
}

/// The chart carries dignity as a raw English label, which is right for a
/// degree table and wrong for a lesson. This is where it becomes a word in
/// the reader's language.
String dignityWord(String label) => switch (label) {
      'exalted' => tr('dignity.exalted'),
      'debilitated' => tr('dignity.debilitated'),
      'own sign' => tr('dignity.own'),
      _ => label,
    };

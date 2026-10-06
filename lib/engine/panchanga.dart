/// The five limbs of the day, and the windows cut out of its daylight.
///
/// Everything here is reckoned the way an almanac reckons it: the Vedic day
/// begins at sunrise, and the limb running *at that sunrise* names the day.
/// A tithi can end an hour later and the day still carries its name — so the
/// engine reports both the governing limb and the moment it gives way, which
/// is the part a reader actually plans around.
///
/// Sources: Charak, *Elements of Vedic Astrology*, ch. XXVI (Muhurta);
/// the arcs and segment tables live in `assets/kb/panchanga.json`.
library;

import 'package:timezone/timezone.dart' as tz;

import '../l10n/engine_strings.dart';
import 'astronomy.dart';
import 'kb.dart';
import 'tables.dart';
import 'tz_lookup.dart';

/// Standard refraction-corrected horizon for sunrise and sunset.
const _horizonAltitude = -0.833;

/// Weekday names in the order `DateTime.weekday` uses, 1 = Monday.
const varaNames = <String>[
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

/// One limb of the panchanga: which one it is, what it is called, and when it
/// hands over.
class Limb {
  const Limb({
    required this.kind,
    required this.number,
    required this.name,
    required this.meaning,
    required this.endsAt,
    this.auspicious = true,
  });

  /// `tithi` | `vara` | `nakshatra` | `yoga` | `karana`
  final String kind;

  /// 1-based index within the limb's own cycle.
  final int number;

  final String name;

  /// What the knowledge base says this limb is for. May be empty.
  final String meaning;

  /// Local time the limb gives way to the next, or null when it runs past the
  /// search horizon (the vara, which simply lasts until the next sunrise).
  final DateTime? endsAt;

  final bool auspicious;

  String get label => tr('panchanga.limb.$kind');
}

/// A named stretch of the day — an inauspicious segment, or Abhijit.
class DayWindow {
  const DayWindow({
    required this.id,
    required this.start,
    required this.end,
    required this.favourable,
    required this.use,
  });

  /// `rahu` | `yamaganda` | `gulika` | `abhijit`
  final String id;
  final DateTime start;
  final DateTime end;
  final bool favourable;

  /// The knowledge base's note on what the window is for.
  final String use;

  String get title => tr('panchanga.window.$id');
}

/// Sunrise, sunset and the daylight span of one Vedic day, in local time.
class DayLight {
  const DayLight({
    required this.sunrise,
    required this.sunset,
    required this.estimated,
  });

  final DateTime sunrise;
  final DateTime sunset;

  /// True when the Sun never crossed the horizon on this date and the span is
  /// a 6am–6pm stand-in. Above the Arctic circle the muhurta segments are a
  /// convention, not an observation, and the reader is told so.
  final bool estimated;

  Duration get length => sunset.difference(sunrise);
}

/// The five limbs for one Vedic day, plus the windows inside its daylight.
class PanchangaDay {
  const PanchangaDay({
    required this.date,
    required this.daylight,
    required this.tithi,
    required this.vara,
    required this.nakshatra,
    required this.yoga,
    required this.karana,
    required this.windows,
    required this.paksha,
    required this.moonSidereal,
    required this.sunSidereal,
  });

  /// The local civil date the governing sunrise falls on.
  final DateTime date;
  final DayLight daylight;

  final Limb tithi;
  final Limb vara;
  final Limb nakshatra;
  final Limb yoga;
  final Limb karana;

  /// `shukla` (waxing) or `krishna` (waning).
  final String paksha;

  final double moonSidereal;
  final double sunSidereal;

  final List<DayWindow> windows;

  List<Limb> get limbs => [tithi, vara, nakshatra, yoga, karana];

  DayWindow? window(String id) {
    for (final w in windows) {
      if (w.id == id) return w;
    }
    return null;
  }

  String get pakshaName => tr('panchanga.paksha.$paksha');
}

// ---------------------------------------------------------------------------
// Sunrise and sunset
// ---------------------------------------------------------------------------

/// Sunrise and sunset for the local civil date [date] at the given place.
///
/// Solved by scanning the day for the moment the Sun's altitude crosses the
/// refracted horizon, then bisecting to the second. A scan rather than a
/// closed form because it degrades honestly at high latitude: no crossing
/// means no sunrise, and the caller is told rather than handed a NaN.
DayLight daylightFor({
  required DateTime date,
  required double latitude,
  required double longitudeEast,
  required String timezone,
}) {
  final loc = locationFor(timezone);
  final start = tz.TZDateTime(loc, date.year, date.month, date.day);
  final end = start.add(const Duration(days: 1));

  final rise = _horizonCrossing(start, end, latitude, longitudeEast, true);
  final set = _horizonCrossing(start, end, latitude, longitudeEast, false);

  if (rise == null || set == null || !set.isAfter(rise)) {
    return DayLight(
      sunrise: start.add(const Duration(hours: 6)),
      sunset: start.add(const Duration(hours: 18)),
      estimated: true,
    );
  }
  return DayLight(
    sunrise: tz.TZDateTime.from(rise, loc),
    sunset: tz.TZDateTime.from(set, loc),
    estimated: false,
  );
}

DateTime? _horizonCrossing(
  DateTime from,
  DateTime to,
  double latitude,
  double longitudeEast,
  bool rising,
) {
  double above(DateTime t) =>
      sunAltitude(julianDayUtc(t.toUtc()), latitude, longitudeEast) -
      _horizonAltitude;

  const step = Duration(minutes: 4);
  var low = from;
  var previous = above(low);
  for (var t = from.add(step); !t.isAfter(to); t = t.add(step)) {
    final current = above(t);
    final crossed =
        rising ? (previous <= 0 && current > 0) : (previous >= 0 && current < 0);
    if (crossed) {
      var high = t;
      for (var i = 0; i < 22; i++) {
        final mid = low.add(
          Duration(microseconds: high.difference(low).inMicroseconds ~/ 2),
        );
        if ((above(mid) > 0) == rising) {
          high = mid;
        } else {
          low = mid;
        }
      }
      return high;
    }
    low = t;
    previous = current;
  }
  return null;
}

// ---------------------------------------------------------------------------
// The five limbs
// ---------------------------------------------------------------------------

/// The panchanga governing [at] — that is, reckoned from the sunrise the
/// moment falls after.
PanchangaDay panchangaFor({
  required DateTime at,
  required double latitude,
  required double longitudeEast,
  required String timezone,
}) {
  final loc = locationFor(timezone);
  final local = tz.TZDateTime.from(at, loc);

  var date = DateTime(local.year, local.month, local.day);
  var light = daylightFor(
    date: date,
    latitude: latitude,
    longitudeEast: longitudeEast,
    timezone: timezone,
  );
  // Before sunrise the previous Vedic day is still running.
  if (local.isBefore(light.sunrise)) {
    date = DateTime(local.year, local.month, local.day)
        .subtract(const Duration(days: 1));
    light = daylightFor(
      date: date,
      latitude: latitude,
      longitudeEast: longitudeEast,
      timezone: timezone,
    );
  }

  final reference = light.sunrise;
  final jd = julianDayUtc(reference.toUtc());
  final ayanamsa = lahiriAyanamsa(jd);
  final sunTropical = sunLongitude(jd);
  final moonTropical = moonLongitude(jd);
  final sunSidereal = norm360(sunTropical - ayanamsa);
  final moonSidereal = norm360(moonTropical - ayanamsa);

  final kb = PredictionKb.module('panchanga');

  return PanchangaDay(
    date: date,
    daylight: light,
    paksha: _elongation(jd) < 180 ? 'shukla' : 'krishna',
    moonSidereal: moonSidereal,
    sunSidereal: sunSidereal,
    tithi: _tithiLimb(kb, reference, loc),
    vara: _varaLimb(kb, date),
    nakshatra: _nakshatraLimb(reference, loc),
    yoga: _yogaLimb(kb, reference, loc),
    karana: _karanaLimb(kb, reference, loc),
    windows: _windows(kb, date, light, loc),
  );
}

double _elongation(double jd) =>
    norm360(moonLongitude(jd) - sunLongitude(jd));

Limb _tithiLimb(Map<String, dynamic> kb, DateTime at, tz.Location loc) {
  final jd = julianDayUtc(at.toUtc());
  final elongation = _elongation(jd);
  final number = (elongation / 12).floor() + 1;
  final rows = kb['tithi'] is Map ? (kb['tithi'] as Map)['list'] : null;
  final row = rows is List && rows.length >= number
      ? rows[number - 1] as Map<String, dynamic>
      : const <String, dynamic>{};
  return Limb(
    kind: 'tithi',
    number: number,
    name: row['name'] as String? ?? '$number',
    meaning: row['group_meaning'] as String? ?? '',
    auspicious: row['group'] != 'rikta',
    endsAt: _crossingOf(_elongation, number * 12.0, at, loc,
        const Duration(hours: 30)),
  );
}

Limb _nakshatraLimb(DateTime at, tz.Location loc) {
  double moon(double jd) => norm360(moonLongitude(jd) - lahiriAyanamsa(jd));
  final info = nakshatraOf(moon(julianDayUtc(at.toUtc())));
  final number = info.index + 1;
  return Limb(
    kind: 'nakshatra',
    number: number,
    name: nakshatraName(info.name),
    meaning: PredictionKb.current.nakshatraTone(info.name),
    endsAt: _crossingOf(moon, number * nakshatraWidth, at, loc,
        const Duration(hours: 30)),
  );
}

Limb _yogaLimb(Map<String, dynamic> kb, DateTime at, tz.Location loc) {
  double sum(double jd) {
    final ayanamsa = lahiriAyanamsa(jd);
    return norm360(
      norm360(moonLongitude(jd) - ayanamsa) + norm360(sunLongitude(jd) - ayanamsa),
    );
  }

  final arc = 360.0 / 27.0;
  final value = sum(julianDayUtc(at.toUtc()));
  final number = (value / arc).floor() + 1;
  final yoga = kb['yoga'] is Map ? kb['yoga'] as Map : const {};
  final names = yoga['names'];
  final bad = yoga['inauspicious'];
  final name = names is List && names.length >= number
      ? names[number - 1] as String
      : '$number';
  return Limb(
    kind: 'yoga',
    number: number,
    name: name,
    meaning: '',
    auspicious: !(bad is List && bad.contains(name)),
    endsAt: _crossingOf(sum, number * arc, at, loc, const Duration(hours: 30)),
  );
}

Limb _karanaLimb(Map<String, dynamic> kb, DateTime at, tz.Location loc) {
  final elongation = _elongation(julianDayUtc(at.toUtc()));
  final number = (elongation / 6).floor() + 1; // 1..60 across the lunar month
  final karana = kb['karana'] is Map ? kb['karana'] as Map : const {};
  final movable = karana['movable'] is List
      ? (karana['movable'] as List).cast<String>()
      : const <String>[];
  final fixed = karana['fixed'] is List
      ? (karana['fixed'] as List).cast<String>()
      : const <String>[];

  // Sixty karanas fill a lunar month. Kimstughna opens it; the seven movable
  // karanas then repeat eight times; Shakuni, Chatushpada and Naga close it.
  String name;
  if (number == 1) {
    name = fixed.isNotEmpty ? fixed.last : 'Kimstughna';
  } else if (number >= 58) {
    final tail = fixed.length >= 4 ? fixed.sublist(0, 3) : const <String>[];
    name = tail.length == 3 ? tail[number - 58] : '$number';
  } else {
    name = movable.isEmpty ? '$number' : movable[(number - 2) % movable.length];
  }
  final bad = karana['inauspicious'];
  final flagged = bad is List &&
      bad.any((e) => e is String && e.split(' ').first == name);
  return Limb(
    kind: 'karana',
    number: number,
    name: name,
    meaning: '',
    auspicious: !flagged,
    endsAt: _crossingOf(_elongation, number * 6.0, at, loc,
        const Duration(hours: 18)),
  );
}

Limb _varaLimb(Map<String, dynamic> kb, DateTime date) {
  final english = varaNames[date.weekday - 1];
  final row = kb['vara'] is Map
      ? ((kb['vara'] as Map)[english] as Map<String, dynamic>? ?? const {})
      : const <String, dynamic>{};
  return Limb(
    kind: 'vara',
    number: date.weekday,
    name: tr('vara.$english'),
    meaning: row['nature'] as String? ?? '',
    endsAt: null, // runs to the next sunrise
  );
}

/// Finds when an angle function next reaches [target] degrees.
///
/// The angle wraps, so "reached" is detected as the wrap itself: the gap to
/// the target sits just under 360° before the crossing and just over 0° after.
DateTime? _crossingOf(
  double Function(double jd) angle,
  double target,
  DateTime from,
  tz.Location loc,
  Duration horizon,
) {
  bool past(DateTime t) =>
      norm360(angle(julianDayUtc(t.toUtc())) - target) < 180.0;

  const step = Duration(minutes: 10);
  final end = from.add(horizon);
  var low = from;
  if (past(low)) return null;
  for (var t = from.add(step); !t.isAfter(end); t = t.add(step)) {
    if (past(t)) {
      var high = t;
      for (var i = 0; i < 20; i++) {
        final mid = low.add(
          Duration(microseconds: high.difference(low).inMicroseconds ~/ 2),
        );
        if (past(mid)) {
          high = mid;
        } else {
          low = mid;
        }
      }
      return tz.TZDateTime.from(high, loc);
    }
    low = t;
  }
  return null;
}

// ---------------------------------------------------------------------------
// Windows cut out of the daylight
// ---------------------------------------------------------------------------

List<DayWindow> _windows(
  Map<String, dynamic> kb,
  DateTime date,
  DayLight light,
  tz.Location loc,
) {
  final english = varaNames[date.weekday - 1];
  final periods = kb['inauspicious_periods'] is Map
      ? kb['inauspicious_periods'] as Map
      : const {};
  final out = <DayWindow>[];

  DateTime at(double fraction) => tz.TZDateTime.from(
        light.sunrise.add(
          Duration(
            microseconds: (light.length.inMicroseconds * fraction).round(),
          ),
        ),
        loc,
      );

  void eighth(String id, String key) {
    final row = periods[key];
    if (row is! Map) return;
    final segments = row['segments'];
    if (segments is! Map) return;
    final n = segments[english];
    if (n is! int || n < 1 || n > 8) return;
    out.add(
      DayWindow(
        id: id,
        start: at((n - 1) / 8),
        end: at(n / 8),
        favourable: false,
        use: row['use'] as String? ?? '',
      ),
    );
  }

  eighth('rahu', 'rahu_kaal');
  eighth('yamaganda', 'yamaganda');
  eighth('gulika', 'gulika_kaal');

  // Abhijit is the eighth of the fifteen daylight muhurtas, and the classics
  // call it weak on Wednesday rather than absent.
  final abhijit = kb['abhijit_muhurta'] is Map
      ? kb['abhijit_muhurta'] as Map
      : const {};
  final weak = english == 'Wednesday';
  final quality = abhijit['quality'] as String? ?? '';
  final exception = abhijit['exception'] as String? ?? '';
  out.add(
    DayWindow(
      id: 'abhijit',
      start: at(7 / 15),
      end: at(8 / 15),
      favourable: !weak,
      // On Wednesday the window is marked unfavourable, so its note must say
      // why rather than still reading as a recommendation.
      use: weak && exception.isNotEmpty ? exception : quality,
    ),
  );

  out.sort((a, b) => a.start.compareTo(b.start));
  return out;
}

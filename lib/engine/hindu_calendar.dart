/// The Hindu calendar around the five limbs.
///
/// Gap G-24. The panchanga computed tithi, vara, nakshatra, yoga and karana
/// correctly, and then stopped. What was missing is everything that makes it a
/// *calendar* rather than a data readout: which month it is, which year, which
/// season, when the Sun changes sign, and which of the days ahead people
/// actually keep.
///
/// Two things here are genuinely regional rather than merely detailed, and the
/// module refuses to pick a side on either:
///
/// * **Amanta and Purnimanta month reckoning.** The south ends a month at the
///   new moon and the north at the full moon, so for the dark fortnight the
///   two traditions give a date a *different month name*. Both are reported.
/// * **Adhika masa.** A lunar month in which the Sun changes no sign is
///   intercalary, and the same date then belongs to a month that the other
///   reckoning does not have. It is detected rather than assumed away.
library;

import 'astro/ephemeris.dart';
import 'astro/units.dart';
import 'panchanga.dart';
import 'tables.dart';

// ---------------------------------------------------------------------------
// Names
// ---------------------------------------------------------------------------

/// The twelve lunar months, Chaitra first.
const lunarMonths = [
  'Chaitra', 'Vaishakha', 'Jyeshtha', 'Ashadha', 'Shravana', 'Bhadrapada',
  'Ashwina', 'Kartika', 'Margashirsha', 'Pausha', 'Magha', 'Phalguna',
];

/// The six seasons, two lunar months each.
const ritus = [
  'Vasanta', 'Grishma', 'Varsha', 'Sharad', 'Hemanta', 'Shishira',
];

const ritusMeaning = <String, String>{
  'Vasanta': 'spring',
  'Grishma': 'summer',
  'Varsha': 'the rains',
  'Sharad': 'autumn',
  'Hemanta': 'early winter',
  'Shishira': 'late winter',
};

/// The sixty-year Jovian cycle.
const samvatsaras = [
  'Prabhava', 'Vibhava', 'Shukla', 'Pramoda', 'Prajapati', 'Angirasa',
  'Shrimukha', 'Bhava', 'Yuva', 'Dhata', 'Ishvara', 'Bahudhanya',
  'Pramathi', 'Vikrama', 'Vrisha', 'Chitrabhanu', 'Svabhanu', 'Tarana',
  'Parthiva', 'Vyaya', 'Sarvajit', 'Sarvadhari', 'Virodhi', 'Vikriti',
  'Khara', 'Nandana', 'Vijaya', 'Jaya', 'Manmatha', 'Durmukhi',
  'Hevilambi', 'Vilambi', 'Vikari', 'Sharvari', 'Plava', 'Shubhakrit',
  'Shobhakrit', 'Krodhi', 'Vishvavasu', 'Parabhava', 'Plavanga', 'Kilaka',
  'Saumya', 'Sadharana', 'Virodhikrit', 'Paridhavi', 'Pramadi', 'Ananda',
  'Rakshasa', 'Nala', 'Pingala', 'Kalayukti', 'Siddharthi', 'Raudri',
  'Durmati', 'Dundubhi', 'Rudhirodgari', 'Raktakshi', 'Krodhana', 'Akshaya',
];

/// The twelve solar months, named for the sign the Sun occupies.
const solarMonths = [
  'Mesha', 'Vrishabha', 'Mithuna', 'Karka', 'Simha', 'Kanya',
  'Tula', 'Vrischika', 'Dhanu', 'Makara', 'Kumbha', 'Meena',
];

// ---------------------------------------------------------------------------
// Result
// ---------------------------------------------------------------------------

class HinduDate {
  const HinduDate({
    required this.gregorian,
    required this.amantaMonth,
    required this.purnimantaMonth,
    required this.paksha,
    required this.tithiNumber,
    required this.tithiName,
    required this.isAdhikaMasa,
    required this.solarMonth,
    required this.ritu,
    required this.ayana,
    required this.shakaYear,
    required this.vikramYear,
    required this.samvatsara,
    required this.nextSankranti,
    required this.nextSankrantiSign,
  });

  final DateTime gregorian;

  /// The month under southern reckoning, which ends at the new moon.
  final String amantaMonth;

  /// The month under northern reckoning, which ends at the full moon. Differs
  /// from [amantaMonth] through the whole dark fortnight.
  final String purnimantaMonth;

  final String paksha;
  final int tithiNumber;
  final String tithiName;

  /// True when this falls inside an intercalary month.
  final bool isAdhikaMasa;

  /// The sign the Sun occupies — the solar month, which the lunar one is
  /// named from.
  final String solarMonth;

  final String ritu;

  /// `Uttarayana` while the Sun moves north, `Dakshinayana` while it moves
  /// south.
  final String ayana;

  final int shakaYear;
  final int vikramYear;
  final String samvatsara;

  final DateTime nextSankranti;
  final String nextSankrantiSign;

  bool get monthNamesAgree => amantaMonth == purnimantaMonth;

  String get monthLine => monthNamesAgree
      ? amantaMonth
      : '$amantaMonth (amanta) · $purnimantaMonth (purnimanta)';

  String get ritmuMeaning => ritusMeaning[ritu] ?? '';
}

// ---------------------------------------------------------------------------
// Solving
// ---------------------------------------------------------------------------

double _sunSidereal(DateTime at, ChartSettings settings) => computeSky(
      utc: at,
      latitude: 0,
      longitudeEast: 0,
      settings: settings,
      bodyNames: const ['Sun'],
    ).sidereal('Sun');

double _elongation(DateTime at, ChartSettings settings) {
  final sky = computeSky(
    utc: at, latitude: 0, longitudeEast: 0,
    settings: settings, bodyNames: const ['Sun', 'Moon']);
  return norm360(sky.bodies['Moon']!.longitude - sky.bodies['Sun']!.longitude);
}

DateTime _bisect(
  double Function(DateTime) f,
  DateTime lo,
  DateTime hi,
) {
  var a = lo;
  var b = hi;
  final fa = f(a);
  for (var i = 0; i < 44; i++) {
    final mid =
        a.add(Duration(microseconds: b.difference(a).inMicroseconds ~/ 2));
    if ((fa < 0) == (f(mid) < 0)) {
      a = mid;
    } else {
      b = mid;
    }
  }
  return a;
}

/// The new moon at or before [at].
DateTime newMoonBefore(DateTime at, ChartSettings settings) {
  var cursor = at;
  for (var i = 0; i < 40; i++) {
    final next = cursor.subtract(const Duration(hours: 18));
    final a = norm180(_elongation(cursor, settings));
    final b = norm180(_elongation(next, settings));
    if (a.sign != b.sign && (a.abs() + b.abs()) < 90) {
      return _bisect((t) => norm180(_elongation(t, settings)), next, cursor);
    }
    cursor = next;
  }
  return at.subtract(const Duration(days: 29));
}

/// The next sidereal sign change of the Sun after [at] — a sankranti.
({DateTime at, int sign}) nextSankrantiAfter(
    DateTime at, ChartSettings settings) {
  final startSign = signIndex(_sunSidereal(at, settings));
  var cursor = at;
  for (var i = 0; i < 40; i++) {
    final next = cursor.add(const Duration(days: 1));
    final sign = signIndex(_sunSidereal(next, settings));
    if (sign != startSign) {
      final boundary = sign * 30.0;
      final exact = _bisect(
        (t) => norm180(_sunSidereal(t, settings) - boundary),
        cursor,
        next,
      );
      return (at: exact, sign: sign);
    }
    cursor = next;
  }
  return (at: at.add(const Duration(days: 30)), sign: (startSign + 1) % 12);
}

/// Builds the calendar around a panchanga day.
///
/// [day] supplies the tithi and paksha, which are already solved there; this
/// adds everything the calendar needs around them.
///
/// Everything is referred to **the governing sunrise**, not to whatever
/// instant the caller happened to ask about. The Vedic day runs sunrise to
/// sunrise and the panchanga's limbs are already fixed that way, so deriving
/// the month from a different moment lets the two disagree: a new moon at
/// seven in the evening would start the next month while the tithi on that
/// day was still Amavasya, and every festival in the dark fortnight would
/// land a month early. That is precisely the bug this replaced.
HinduDate hinduDateFor({
  required PanchangaDay day,
  DateTime? utc,
  ChartSettings settings = const ChartSettings(),
}) {
  final reference = day.daylight.sunrise.toUtc();
  final sunNow = _sunSidereal(reference, settings);
  final solarSign = signIndex(sunNow);

  // The lunar month is named from the *sankranti it contains*: the month in
  // which the Sun enters Mesha is Vaishakha, the one in which it enters Meena
  // is Chaitra. The Sun is in sign S at the opening new moon and enters S+1
  // during the month, so the month's index is S+2.
  //
  // Checked against 2024: the new moon of 10 March has the Sun in Kumbha, so
  // the month is Chaitra — and Holi, the full moon of 25 March, falls inside
  // it. Getting this wrong by one shifts every festival by a month, which is
  // exactly what the first version of this file did.
  final thisNewMoon = newMoonBefore(reference, settings);
  final sunAtNewMoon = signIndex(_sunSidereal(thisNewMoon, settings));
  final amantaIndex = (sunAtNewMoon + 2) % 12;

  // Adhika masa: a lunar month inside which the Sun changes no sign at all.
  final previousNewMoon =
      newMoonBefore(thisNewMoon.subtract(const Duration(days: 2)), settings);
  final sunAtPrevious = signIndex(_sunSidereal(previousNewMoon, settings));
  final isAdhika = sunAtPrevious == sunAtNewMoon;

  // A purnimanta month ends at the full moon, so it is made of the dark
  // fortnight of one amanta month followed by the bright fortnight of the
  // next. The two reckonings therefore agree through the *dark* fortnight and
  // differ by one through the bright one — which is the opposite of the
  // intuitive guess, and worth stating rather than deriving each time.
  //
  // The anchor: Holi is the full moon of 25 March 2024, universally called
  // Phalguna Purnima. That full moon falls in amanta Chaitra. So for a bright
  // fortnight, purnimanta is one *behind* amanta.
  final purnimantaIndex =
      day.paksha == 'shukla' ? (amantaIndex + 11) % 12 : amantaIndex;

  final ritu = ritus[(amantaIndex ~/ 2) % 6];

  // The Sun moves north from Makara to Mithuna.
  final ayana = (solarSign >= 9 || solarSign <= 2)
      ? 'Uttarayana'
      : 'Dakshinayana';

  // Shaka and Vikram years both turn at Chaitra, not in January.
  final local = day.date;
  final beforeNewYear = amantaIndex >= 9 && local.month <= 3;
  final shaka = local.year - 78 - (beforeNewYear ? 1 : 0);
  final vikram = local.year + 57 - (beforeNewYear ? 1 : 0);

  // The southern reckoning of the sixty-year cycle, anchored on the Shaka
  // year. Shaka 1946 is Krodhi, which this reproduces.
  final samvatsara = samvatsaras[((shaka + 11) % 60 + 60) % 60];

  final sankranti = nextSankrantiAfter(reference, settings);

  return HinduDate(
    gregorian: local,
    amantaMonth: isAdhika ? 'Adhika ${lunarMonths[amantaIndex]}'
        : lunarMonths[amantaIndex],
    purnimantaMonth: isAdhika
        ? 'Adhika ${lunarMonths[purnimantaIndex]}'
        : lunarMonths[purnimantaIndex],
    paksha: day.paksha,
    tithiNumber: day.tithi.number,
    tithiName: day.tithi.name,
    isAdhikaMasa: isAdhika,
    solarMonth: solarMonths[solarSign],
    ritu: ritu,
    ayana: ayana,
    shakaYear: shaka,
    vikramYear: vikram,
    samvatsara: samvatsara,
    nextSankranti: sankranti.at,
    nextSankrantiSign: solarMonths[sankranti.sign],
  );
}

// ---------------------------------------------------------------------------
// Observances
// ---------------------------------------------------------------------------

class Observance {
  const Observance({
    required this.name,
    required this.date,
    required this.note,
    this.isFast = false,
  });

  final String name;
  final DateTime date;
  final String note;

  /// Ekadashi and the like, where the day is kept by fasting.
  final bool isFast;
}

/// When during the day a festival's tithi has to be current.
///
/// This is not a refinement — it decides the date. A tithi governs a Vedic day
/// if it is current at sunrise, but several festivals are fixed to a different
/// hour instead, and then the day that *holds* that hour wins. Vijayadashami
/// is kept when Dashami prevails in the afternoon and Shivaratri when
/// Chaturdashi prevails at midnight, so both routinely fall a day away from
/// the sunrise reckoning. Computing them at sunrise puts them on the wrong
/// day about half the time.
enum ObservanceWindow {
  /// The default: the tithi current at sunrise.
  sunrise,

  /// Midday — the middle of the daylight span.
  madhyahna,

  /// The late afternoon, about seven tenths of the way through daylight.
  aparahna,

  /// Just after sunset.
  pradosha,

  /// Vedic midnight — halfway between sunset and the next sunrise.
  nishita,
}

/// The tithi at an instant, 1..30.
///
/// Twelve degrees of elongation each, counted from the new moon.
int tithiAt(DateTime utc, {ChartSettings settings = const ChartSettings()}) =>
    (_elongation(utc, settings) / 12).floor() + 1;

/// The instant a window falls on, for a given day's daylight.
DateTime windowInstant(ObservanceWindow window, DayLight light) {
  final sunrise = light.sunrise;
  final sunset = light.sunset;
  final daylight = sunset.difference(sunrise);
  return switch (window) {
    ObservanceWindow.sunrise => sunrise,
    ObservanceWindow.madhyahna =>
      sunrise.add(Duration(microseconds: daylight.inMicroseconds ~/ 2)),
    ObservanceWindow.aparahna => sunrise
        .add(Duration(microseconds: (daylight.inMicroseconds * 0.7).round())),
    ObservanceWindow.pradosha => sunset.add(const Duration(minutes: 40)),
    // The night runs sunset to the next sunrise, about twelve hours later.
    ObservanceWindow.nishita => sunset.add(Duration(
        microseconds:
            (Duration(hours: 24).inMicroseconds - daylight.inMicroseconds) ~/ 2)),
  };
}

/// The tithi within its own fortnight, 1..15.
///
/// The panchanga numbers tithis 1..30 across the whole lunar month, so the
/// fifteenth of the dark fortnight — Amavasya — is tithi 30, not tithi 15.
/// Every rule below is written in the natural form ("krishna 14") and
/// converted here, because stating them as 29 is how a table of festivals
/// silently acquires an off-by-fifteen.
int tithiInPaksha(int tithiNumber) =>
    tithiNumber <= 15 ? tithiNumber : tithiNumber - 15;

/// A festival, as a rule rather than a date.
///
/// **Months are stated in purnimanta reckoning**, because that is how every
/// one of these festivals is actually quoted: Holi is Phalguna Purnima, Diwali
/// is Kartika Amavasya, Shivaratri is Phalguna Krishna Chaturdashi. Writing
/// them in amanta terms would mean translating every source by hand, and a
/// translation done fifteen times is a translation got wrong once.
class _Rule {
  const _Rule(this.name, this.month, this.paksha, this.tithi, this.note,
      {this.window = ObservanceWindow.sunrise});
  final String name;

  /// When the tithi has to be current for the day to carry the festival.
  final ObservanceWindow window;

  /// Purnimanta month index, Chaitra = 0.
  final int month;
  final String paksha;

  /// 1..15 within the fortnight.
  final int tithi;
  final String note;
}

const _rules = <_Rule>[
  _Rule('Ram Navami', 0, 'shukla', 9, 'The birth of Rama.'),
  _Rule('Hanuman Jayanti', 0, 'shukla', 15, 'Chaitra Purnima.'),
  _Rule('Akshaya Tritiya', 1, 'shukla', 3,
      'Traditionally the most auspicious day of the year to begin anything.'),
  _Rule('Buddha Purnima', 1, 'shukla', 15, 'Vaishakha Purnima.'),
  _Rule('Guru Purnima', 3, 'shukla', 15, 'The teacher’s day.'),
  _Rule('Raksha Bandhan', 4, 'shukla', 15, 'Shravana Purnima.'),
  _Rule('Krishna Janmashtami', 5, 'krishna', 8, 'The birth of Krishna.',
      window: ObservanceWindow.nishita),
  _Rule('Ganesh Chaturthi', 5, 'shukla', 4, 'Beginnings and obstacles.',
      window: ObservanceWindow.madhyahna),
  _Rule('Navaratri begins', 6, 'shukla', 1, 'Nine nights of the goddess.'),
  _Rule('Vijayadashami', 6, 'shukla', 10,
      'Dussehra — the day of victory, and a standing muhurta in its own right.',
      window: ObservanceWindow.aparahna),
  _Rule('Karva Chauth', 7, 'krishna', 4, 'Kept for a husband’s long life.',
      window: ObservanceWindow.pradosha),
  _Rule('Diwali', 7, 'krishna', 15, 'Kartika Amavasya.',
      window: ObservanceWindow.pradosha),
  _Rule('Chhath', 7, 'shukla', 6, 'Kept to the Sun.'),
  _Rule('Maha Shivaratri', 11, 'krishna', 14, 'The great night of Shiva.',
      window: ObservanceWindow.nishita),
  _Rule('Holi', 11, 'shukla', 15, 'Phalguna Purnima.'),
];

String _windowName(ObservanceWindow w) => switch (w) {
      ObservanceWindow.sunrise => 'sunrise',
      ObservanceWindow.madhyahna => 'midday',
      ObservanceWindow.aparahna => 'aparahna, the late afternoon',
      ObservanceWindow.pradosha => 'pradosha, just after sunset',
      ObservanceWindow.nishita => 'nishita, Vedic midnight',
    };

/// Observances in a date range.
///
/// Solved by walking the range a day at a time and testing each rule against
/// that day's month, paksha and tithi — which is how the calendar itself
/// works, and avoids a table of dates that would be wrong within a year.
List<Observance> observancesBetween({
  required DateTime from,
  required DateTime to,
  required double latitude,
  required double longitudeEast,
  required String timezone,
  ChartSettings settings = const ChartSettings(),
}) {
  final out = <Observance>[];
  final seen = <String>{};

  // Walked at local mid-morning rather than at UTC midnight. A UTC midnight
  // east of Greenwich is already the following local day, so the naive loop
  // reported every observance one day early.
  var cursor = DateTime.utc(from.year, from.month, from.day, 6);
  while (cursor.isBefore(to)) {
    final day = panchangaFor(
      at: cursor,
      latitude: latitude,
      longitudeEast: longitudeEast,
      timezone: timezone,
    );
    final hindu = hinduDateFor(day: day, settings: settings);

    final monthIndex = lunarMonths.indexWhere(
        (m) => hindu.purnimantaMonth.endsWith(m));

    for (final rule in _rules) {
      if (rule.month != monthIndex) continue;
      // An adhika month does not carry the festivals of the month it doubles.
      if (hindu.isAdhikaMasa) continue;

      // The tithi is tested at the window the festival is actually kept in,
      // which for several of them is not sunrise.
      final at = rule.window == ObservanceWindow.sunrise
          ? hindu.tithiNumber
          : tithiAt(
              windowInstant(rule.window, day.daylight).toUtc(),
              settings: settings,
            );
      final paksha = at <= 15 ? 'shukla' : 'krishna';
      if (rule.paksha != paksha) continue;
      if (rule.tithi != tithiInPaksha(at)) continue;
      if (!seen.add('${rule.name}-${day.date.year}')) continue;

      out.add(Observance(
        name: rule.name,
        date: day.date,
        note: rule.window == ObservanceWindow.sunrise
            ? rule.note
            : '${rule.note} Kept when the tithi prevails at '
                '${_windowName(rule.window)}, which is why it can fall a day '
                'either side of the sunrise reckoning.',
      ));
    }

    // Ekadashi falls twice a lunar month and is the commonest observance of
    // all, so it is generated rather than listed.
    if (tithiInPaksha(hindu.tithiNumber) == 11) {
      final key = 'ekadashi-${day.date.toIso8601String().substring(0, 10)}';
      if (seen.add(key)) {
        out.add(Observance(
          name: '${hindu.paksha == 'shukla' ? 'Shukla' : 'Krishna'} Ekadashi',
          date: day.date,
          note: 'Kept by fasting, in ${hindu.monthLine}.',
          isFast: true,
        ));
      }
    }
    if (hindu.tithiNumber == 15) {
      final key = 'purnima-${day.date.toIso8601String().substring(0, 10)}';
      if (seen.add(key)) {
        out.add(Observance(
          name: 'Purnima',
          date: day.date,
          note: 'Full moon ending ${hindu.purnimantaMonth}.',
        ));
      }
    }
    if (hindu.tithiNumber == 30) {
      final key = 'amavasya-${day.date.toIso8601String().substring(0, 10)}';
      if (seen.add(key)) {
        out.add(Observance(
          name: 'Amavasya',
          date: day.date,
          note: 'New moon ending ${hindu.amantaMonth}.',
        ));
      }
    }

    cursor = cursor.add(const Duration(days: 1));
  }

  out.sort((a, b) => a.date.compareTo(b.date));
  return out;
}

/// The twelve sankrantis of a year, with Makara Sankranti named.
List<({DateTime at, String sign, String name})> sankrantisIn(
  int year, {
  ChartSettings settings = const ChartSettings(),
}) {
  final out = <({DateTime at, String sign, String name})>[];
  var cursor = DateTime.utc(year, 1, 1);
  final end = DateTime.utc(year + 1, 1, 1);
  while (cursor.isBefore(end)) {
    final next = nextSankrantiAfter(cursor, settings);
    if (!next.at.isBefore(end)) break;
    out.add((
      at: next.at,
      sign: solarMonths[next.sign],
      name: '${solarMonths[next.sign]} Sankranti',
    ));
    cursor = next.at.add(const Duration(days: 2));
  }
  return out;
}

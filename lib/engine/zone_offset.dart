/// What offset a birth time will actually be read with.
///
/// Gap G-40, second half — and the half that turned out to matter most, for a
/// reason worth recording. The assessment assumed the app was missing
/// historical timezone data. It was not: the `timezone` package's `latest_all`
/// database carries the full IANA transition history, so Kolkata before 1906
/// already resolved to Madras Mean Time at +05:21, New York in 1943 to Eastern
/// War Time, and London in 1947 to British Double Summer Time at +02:00.
///
/// The real defect was quieter. The app applied whatever the database said and
/// never showed it. A one-hour timezone error moves the ascendant by fifteen
/// degrees, and it is the commonest cause of a wrong reading in the whole
/// field — so the offset has to be *visible and confirmable*, not merely
/// correct. That is what this file is for.
///
/// It also adds the one case the IANA database genuinely cannot answer:
/// **local mean time**. Before a place adopted standard time — and, in older
/// records, well after — a recorded birth time is often sun time at that
/// longitude rather than zone time. That is a question about the record, not
/// about geography, so it has to be a choice the reader makes.
library;

import 'package:timezone/timezone.dart' as tz;

import '../domain/models.dart';
import 'tz_lookup.dart';

/// How a recorded clock time should be interpreted.
enum TimeStandard {
  /// The civil time of the place — what a clock on the wall said. Right for
  /// essentially every birth after standard time was adopted locally.
  zone,

  /// Local mean time: sun time at the birth longitude. Right for births
  /// before local standardisation, and for records known to be kept that way.
  localMean,
}

extension TimeStandardInfo on TimeStandard {
  String get label => switch (this) {
        TimeStandard.zone => 'Clock time',
        TimeStandard.localMean => 'Local mean time',
      };

  String get explanation => switch (this) {
        TimeStandard.zone =>
          'What a clock on the wall said, including any wartime or summer-time '
              'rule in force that day.',
        TimeStandard.localMean =>
          'Sun time at the birth longitude, ignoring zones entirely. Right for '
              'births before the place adopted standard time, and for older '
              'records known to be kept that way.',
      };

  String get storageKey => name;

  static TimeStandard fromKey(String? key) {
    if (key == null) return TimeStandard.zone;
    for (final s in TimeStandard.values) {
      if (s.name == key) return s;
    }
    return TimeStandard.zone;
  }
}

/// The offset a chart will be built with, and whether it deserves a second
/// look.
class ZoneReading {
  const ZoneReading({
    required this.offset,
    required this.abbreviation,
    required this.standard,
    required this.isDaylightSaving,
    required this.isWarTime,
    required this.isPreStandard,
    required this.localMeanOffset,
    required this.notes,
  });

  /// The offset applied, east of Greenwich positive.
  final Duration offset;

  /// What the database calls it — IST, EWT, BDST, MMT, or a bare "+0545".
  final String abbreviation;

  final TimeStandard standard;

  /// True when a summer-time rule was in force.
  final bool isDaylightSaving;

  /// True when the abbreviation names a wartime rule. These are the offsets
  /// readers most often get wrong, because they are not in anyone's mental
  /// model of a country's timezone.
  final bool isWarTime;

  /// True when the offset is not a whole or half hour, which almost always
  /// means the place had not yet adopted standard time and the database is
  /// reporting its historical local mean time.
  final bool isPreStandard;

  /// What pure local mean time at this longitude would have been, for
  /// comparison.
  final Duration localMeanOffset;

  /// Things the reader should see before trusting the chart.
  final List<String> notes;

  String get formatted => _format(offset);
  String get localMeanFormatted => _format(localMeanOffset);

  /// How far the two readings are apart — how much the chart moves if the
  /// record turns out to be local mean time after all.
  Duration get disagreement => offset - localMeanOffset;

  /// Degrees of ascendant the disagreement is worth, very roughly. The
  /// ascendant moves about fifteen degrees an hour, faster or slower with
  /// latitude, so this is an order of magnitude rather than a figure.
  double get ascendantDegrees =>
      (disagreement.inSeconds / 3600.0) * 15.0;

  bool get worthConfirming =>
      isWarTime || isPreStandard || disagreement.inMinutes.abs() >= 8;

  static String _format(Duration d) {
    final sign = d.isNegative ? '-' : '+';
    final a = d.abs();
    return '$sign${a.inHours.toString().padLeft(2, '0')}:'
        '${(a.inMinutes % 60).toString().padLeft(2, '0')}';
  }
}

/// Abbreviations that name a wartime rule.
const _warTimeMarkers = {
  'EWT', 'CWT', 'MWT', 'PWT', // United States, 1942–45
  'EPT', 'CPT', 'MPT', 'PPT', // "Peace time", 1945
  'BDST', // British Double Summer Time, 1941–45 and 1947
  'CEMT', // Central European Midsummer Time
};

/// Reads the offset that will be applied to a birth record.
ZoneReading readZone({
  required DateTime localDateTime,
  required Place place,
  TimeStandard standard = TimeStandard.zone,
}) {
  final localMean = Duration(
    milliseconds: (place.longitude / 15.0 * 3600 * 1000).round(),
  );

  if (standard == TimeStandard.localMean) {
    return ZoneReading(
      offset: localMean,
      abbreviation: 'LMT',
      standard: standard,
      isDaylightSaving: false,
      isWarTime: false,
      isPreStandard: true,
      localMeanOffset: localMean,
      notes: [
        'Read as local mean time — sun time at '
            '${place.longitude.toStringAsFixed(2)}° longitude, '
            '${ZoneReading._format(localMean)} from Greenwich. No zone or '
            'summer-time rule is applied.',
      ],
    );
  }

  final loc = locationFor(place.timezone);
  final t = tz.TZDateTime(
    loc,
    localDateTime.year,
    localDateTime.month,
    localDateTime.day,
    localDateTime.hour,
    localDateTime.minute,
    localDateTime.second,
  );

  final offset = t.timeZoneOffset;
  final abbreviation = t.timeZoneName;

  // A January and a July sample tell us whether this zone observes summer
  // time at all in this era, which is what makes "is this one of them" a
  // meaningful question rather than a guess.
  final january = tz.TZDateTime(loc, localDateTime.year, 1, 15).timeZoneOffset;
  final july = tz.TZDateTime(loc, localDateTime.year, 7, 15).timeZoneOffset;
  final observesSummerTime = january != july;
  final standardOffset = january < july ? january : july;
  final isDst = observesSummerTime && offset != standardOffset;

  final isWarTime = _warTimeMarkers.contains(abbreviation);
  final isPreStandard = offset.inSeconds % 900 != 0;

  final notes = <String>[];
  if (isWarTime) {
    notes.add(
      'This date falls inside a wartime clock rule — the database reports '
      '$abbreviation. Wartime offsets are the ones most often missed, because '
      'they are not in anyone’s mental model of a country’s timezone. '
      'Worth confirming against the birth record.',
    );
  }
  if (isPreStandard) {
    notes.add(
      'The offset here is ${ZoneReading._format(offset)}, which is not a whole '
      'or half hour. That almost always means the place had not yet adopted '
      'standard time on this date and the database is reporting its historical '
      'local mean time. If the record was kept by a railway or a church clock '
      'it may have used a different one.',
    );
  }
  if (isDst) {
    notes.add(
      'A summer-time rule was in force: $abbreviation, an hour ahead of the '
      'standard ${ZoneReading._format(standardOffset)}. If the recorded time '
      'was written down without adjusting, the chart is an hour out.',
    );
  }

  final disagreement = offset - localMean;
  if (disagreement.inMinutes.abs() >= 8) {
    notes.add(
      'Clock time and local mean time differ by '
      '${disagreement.inMinutes.abs()} minutes here, worth about '
      '${((disagreement.inSeconds / 3600.0) * 15).abs().toStringAsFixed(1)}° '
      'of ascendant. For an older record, ask which one the time was kept in.',
    );
  }

  return ZoneReading(
    offset: offset,
    abbreviation: abbreviation,
    standard: standard,
    isDaylightSaving: isDst,
    isWarTime: isWarTime,
    isPreStandard: isPreStandard,
    localMeanOffset: localMean,
    notes: notes,
  );
}

/// Converts a birth record to UTC, honouring the chosen time standard.
///
/// This is the one place the two standards diverge, and it is deliberately
/// tiny: local mean time is longitude arithmetic and nothing else.
DateTime toUtcWith(BirthInput input, TimeStandard standard) {
  if (standard == TimeStandard.localMean) {
    final d = input.timeUnknown
        ? DateTime(input.localDateTime.year, input.localDateTime.month,
            input.localDateTime.day, 12)
        : input.localDateTime;
    final offset = Duration(
      milliseconds: (input.place.longitude / 15.0 * 3600 * 1000).round(),
    );
    return DateTime.utc(
      d.year, d.month, d.day, d.hour, d.minute, d.second,
    ).subtract(offset);
  }

  final loc = locationFor(input.place.timezone);
  final d = input.timeUnknown
      ? tz.TZDateTime(loc, input.localDateTime.year, input.localDateTime.month,
          input.localDateTime.day, 12)
      : tz.TZDateTime(
          loc,
          input.localDateTime.year,
          input.localDateTime.month,
          input.localDateTime.day,
          input.localDateTime.hour,
          input.localDateTime.minute,
          input.localDateTime.second,
        );
  return d.toUtc();
}

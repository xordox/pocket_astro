/// Getting charts in and out.
///
/// Gap G-41. Charts lived in one local file with no way to move them, which
/// meant the app could only ever be someone's second tool: nobody retypes
/// eight hundred client records to try something.
///
/// Two formats, chosen for different jobs:
///
/// * **JSON** — full fidelity, including the time standard, tags, notes and
///   the calculation settings. This is the backup format, and importing one
///   reproduces the library exactly.
/// * **CSV** — lossy but universal. Every astrology program and every
///   spreadsheet can read it, and a practitioner moving from another tool
///   almost always can produce one.
///
/// **Not implemented, deliberately:** the native binary formats of Solar Fire,
/// Jagannatha Hora and the AAF exchange format. Each is a specific
/// byte-for-byte contract, and a writer built from a half-remembered spec
/// produces files that other programs accept and silently misread — which is
/// worse than not offering it. They stay on the register as unfinished rather
/// than being approximated here.
library;

import 'dart:convert';

import '../domain/models.dart';
import '../engine/tz_lookup.dart';
import '../engine/zone_offset.dart';
import 'bundled_atlas.dart';

/// The current backup schema. Bumped when a field's meaning changes, so an
/// older file can be migrated rather than misread.
const interchangeVersion = 1;

class ImportOutcome {
  const ImportOutcome({
    required this.imported,
    required this.skipped,
    required this.problems,
  });

  final List<BirthInput> imported;

  /// Rows that parsed but were rejected, with the reason. A silent drop is the
  /// worst possible behaviour for an import: the reader believes they have all
  /// their charts and finds out otherwise months later.
  final int skipped;
  final List<String> problems;

  bool get isEmpty => imported.isEmpty;
}

// ---------------------------------------------------------------------------
// JSON
// ---------------------------------------------------------------------------

/// A complete, reproducible backup.
String exportJson(
  List<BirthInput> profiles, {
  Map<String, dynamic>? settings,
  Map<String, List<Consultation>> consultations = const {},
}) {
  return const JsonEncoder.withIndent('  ').convert({
    'format': 'pocketastro',
    'version': interchangeVersion,
    'exported': DateTime.now().toUtc().toIso8601String(),
    'profiles': [for (final p in profiles) p.toJson()],
    'settings': ?settings,
    if (consultations.isNotEmpty)
      'consultations': {
        for (final e in consultations.entries)
          e.key: [for (final c in e.value) c.toJson()],
      },
  });
}

ImportOutcome importJson(String raw) {
  final problems = <String>[];
  final imported = <BirthInput>[];
  var skipped = 0;

  dynamic decoded;
  try {
    decoded = jsonDecode(raw);
  } catch (e) {
    return ImportOutcome(
      imported: const [],
      skipped: 0,
      problems: ['This file is not valid JSON, so nothing could be read.'],
    );
  }

  if (decoded is! Map || decoded['profiles'] is! List) {
    return const ImportOutcome(
      imported: [],
      skipped: 0,
      problems: [
        'This is valid JSON but not a PocketAstro backup — it has no '
            '"profiles" list.'
      ],
    );
  }

  final version = decoded['version'];
  if (version is int && version > interchangeVersion) {
    problems.add(
      'This backup was written by a newer version of the app (format $version, '
      'this build reads $interchangeVersion). Anything it does not recognise '
      'has been left out.',
    );
  }

  // Decoded one at a time, so a single bad record costs that record rather
  // than the whole file — the same rule the profile store already follows.
  for (final row in decoded['profiles'] as List) {
    if (row is! Map) {
      skipped++;
      continue;
    }
    try {
      final input = BirthInput.fromJson(row.cast<String, dynamic>());
      final problem = _validate(input);
      if (problem != null) {
        skipped++;
        problems.add('${input.name}: $problem');
        continue;
      }
      imported.add(input);
    } catch (e) {
      skipped++;
      problems.add('One record could not be read: $e');
    }
  }

  return ImportOutcome(
    imported: imported,
    skipped: skipped,
    problems: problems,
  );
}

// ---------------------------------------------------------------------------
// CSV
// ---------------------------------------------------------------------------

const _csvHeader =
    'name,date,time,place,region,latitude,longitude,timezone,'
    'time_source,time_standard,tags,notes';

String _csvEscape(String v) {
  if (v.contains(',') || v.contains('"') || v.contains('\n')) {
    return '"${v.replaceAll('"', '""')}"';
  }
  return v;
}

String _two(int n) => n.toString().padLeft(2, '0');

/// A row per chart, readable by anything.
String exportCsv(List<BirthInput> profiles) {
  final out = StringBuffer(_csvHeader)..write('\n');
  for (final p in profiles) {
    final d = p.localDateTime;
    out.writeAll([
      _csvEscape(p.name),
      '${d.year}-${_two(d.month)}-${_two(d.day)}',
      p.timeUnknown ? '' : '${_two(d.hour)}:${_two(d.minute)}',
      _csvEscape(p.place.name),
      _csvEscape(p.place.region),
      p.place.latitude.toStringAsFixed(6),
      p.place.longitude.toStringAsFixed(6),
      p.place.timezone,
      p.timeSource.name,
      p.timeStandard.name,
      _csvEscape(p.tags.join(' ')),
      _csvEscape(p.notes),
    ], ',');
    out.write('\n');
  }
  return out.toString();
}

/// Splits one CSV line, honouring quotes.
List<String> _splitCsvLine(String line) {
  final out = <String>[];
  final field = StringBuffer();
  var inQuotes = false;

  for (var i = 0; i < line.length; i++) {
    final c = line[i];
    if (inQuotes) {
      if (c == '"') {
        if (i + 1 < line.length && line[i + 1] == '"') {
          field.write('"');
          i++;
        } else {
          inQuotes = false;
        }
      } else {
        field.write(c);
      }
    } else if (c == '"') {
      inQuotes = true;
    } else if (c == ',') {
      out.add(field.toString());
      field.clear();
    } else {
      field.write(c);
    }
  }
  out.add(field.toString());
  return out;
}

/// Reads a CSV export.
///
/// Tolerant by design about column order and about which columns are present —
/// a file from another program will not match ours exactly, and refusing it
/// over a missing "time_standard" would defeat the purpose.
///
/// Three things are genuinely required, because a chart cannot exist without
/// them: a name, a date, and a location the app can resolve. The location can
/// be a place name the atlas knows or a latitude and longitude; a missing
/// timezone is filled in from the nearest bundled place, but a missing place
/// entirely is a row that cannot become a chart.
ImportOutcome importCsv(String raw, {String idPrefix = 'csv'}) {
  final lines = raw
      .split(RegExp(r'\r?\n'))
      .where((l) => l.trim().isNotEmpty)
      .toList();
  if (lines.isEmpty) {
    return const ImportOutcome(
      imported: [], skipped: 0, problems: ['The file is empty.']);
  }

  final header = _splitCsvLine(lines.first)
      .map((h) => h.trim().toLowerCase().replaceAll(' ', '_'))
      .toList();
  int col(List<String> names) {
    for (final n in names) {
      final i = header.indexOf(n);
      if (i >= 0) return i;
    }
    return -1;
  }

  final iName = col(['name', 'chart', 'person']);
  final iDate = col(['date', 'birth_date', 'birthdate', 'dob']);
  final iTime = col(['time', 'birth_time', 'birthtime']);
  final iPlace = col(['place', 'city', 'location', 'birthplace']);
  final iRegion = col(['region', 'country', 'state']);
  final iLat = col(['latitude', 'lat']);
  final iLon = col(['longitude', 'lon', 'lng', 'long']);
  final iTz = col(['timezone', 'tz', 'zone']);
  final iSource = col(['time_source', 'source']);
  final iStandard = col(['time_standard', 'standard']);
  final iTags = col(['tags', 'tag']);
  final iNotes = col(['notes', 'note']);

  final problems = <String>[];
  if (iName < 0 || iDate < 0 || (iPlace < 0 && (iLat < 0 || iLon < 0))) {
    return const ImportOutcome(
      imported: [],
      skipped: 0,
      problems: [
        'A CSV needs a name column, a date column, and a location — either a '
            'place name the atlas can look up, or a latitude and longitude. '
            'A row without a location cannot become a chart.'
      ],
    );
  }

  final imported = <BirthInput>[];
  var skipped = 0;

  for (var row = 1; row < lines.length; row++) {
    final f = _splitCsvLine(lines[row]);
    String at(int i) => i >= 0 && i < f.length ? f[i].trim() : '';

    final name = at(iName);
    final dateText = at(iDate);
    if (name.isEmpty || dateText.isEmpty) {
      skipped++;
      continue;
    }

    final date = _parseDate(dateText);
    if (date == null) {
      skipped++;
      problems.add('Row ${row + 1} ($name): could not read the date '
          '"$dateText". Use YYYY-MM-DD.');
      continue;
    }

    final timeText = at(iTime);
    final time = _parseTime(timeText);
    final unknownTime = timeText.isEmpty || time == null;

    final place = _resolvePlace(
      name: at(iPlace),
      region: at(iRegion),
      latitude: double.tryParse(at(iLat)),
      longitude: double.tryParse(at(iLon)),
      timezone: at(iTz),
    );
    if (place == null) {
      skipped++;
      problems.add(
        'Row ${row + 1} ($name): the birthplace could not be resolved. Give '
        'either a place name the atlas knows, or a latitude, longitude and '
        'timezone.',
      );
      continue;
    }

    final input = BirthInput(
      id: '$idPrefix-$row-${DateTime.now().microsecondsSinceEpoch}',
      name: name,
      localDateTime: DateTime(
        date.year, date.month, date.day,
        unknownTime ? 12 : time.hour,
        unknownTime ? 0 : time.minute,
      ),
      place: place,
      timeSource: unknownTime
          ? TimeSource.unknown
          : _parseSource(at(iSource)),
      timeStandard: TimeStandardInfo.fromKey(
          at(iStandard).isEmpty ? null : at(iStandard)),
      tags: at(iTags).split(RegExp(r'[ ;|]+')).where((t) => t.isNotEmpty).toList(),
      notes: at(iNotes),
    );

    final problem = _validate(input);
    if (problem != null) {
      skipped++;
      problems.add('Row ${row + 1} ($name): $problem');
      continue;
    }
    imported.add(input);
  }

  return ImportOutcome(
    imported: imported, skipped: skipped, problems: problems);
}

DateTime? _parseDate(String text) {
  final iso = DateTime.tryParse(text);
  if (iso != null) return iso;

  // D/M/Y and M/D/Y are genuinely ambiguous, and guessing wrong silently
  // moves a birthday. Only accept a slash form when the day is unambiguous.
  final m = RegExp(r'^(\d{1,2})[/.](\d{1,2})[/.](\d{4})$').firstMatch(text);
  if (m != null) {
    final a = int.parse(m.group(1)!);
    final b = int.parse(m.group(2)!);
    final year = int.parse(m.group(3)!);
    if (a > 12 && b <= 12) return DateTime(year, b, a);
    if (b > 12 && a <= 12) return DateTime(year, a, b);
    return null; // ambiguous — better to reject the row than to guess
  }
  return null;
}

({int hour, int minute})? _parseTime(String text) {
  if (text.isEmpty) return null;
  final m = RegExp(r'^(\d{1,2})[:.](\d{2})').firstMatch(text);
  if (m == null) return null;
  var hour = int.parse(m.group(1)!);
  final minute = int.parse(m.group(2)!);
  final lower = text.toLowerCase();
  if (lower.contains('pm') && hour < 12) hour += 12;
  if (lower.contains('am') && hour == 12) hour = 0;
  if (hour > 23 || minute > 59) return null;
  return (hour: hour, minute: minute);
}

TimeSource _parseSource(String text) {
  for (final s in TimeSource.values) {
    if (s.name == text.toLowerCase()) return s;
  }
  return TimeSource.memory;
}

/// Turns whatever location columns a file happens to have into a [Place].
///
/// Coordinates win when present. Otherwise the bundled atlas is asked, which
/// is what makes a two-column "name, date" file importable at all.
Place? _resolvePlace({
  required String name,
  required String region,
  double? latitude,
  double? longitude,
  required String timezone,
}) {
  if (latitude != null && longitude != null) {
    var zone = timezone;
    if (zone.isEmpty || !isKnownZone(zone)) {
      // Fall back to the nearest bundled place, so a file with coordinates but
      // no zone still imports.
      zone = BundledAtlas.instance.nearest(latitude, longitude)?.timezone ?? '';
    }
    if (zone.isEmpty) return null;
    final place = Place(
      name: name.isEmpty ? 'Unnamed place' : name,
      region: region,
      latitude: latitude,
      longitude: longitude,
      timezone: zone,
    );
    return place.isWellFormed ? place : null;
  }

  if (name.isEmpty) return null;
  final query = region.isEmpty ? name : '$name $region';
  final hits = BundledAtlas.instance.search(query, limit: 1);
  if (hits.isEmpty) return null;
  return hits.first.toPlace();
}

String? _validate(BirthInput input) {
  if (input.name.trim().isEmpty) return 'no name';
  if (!input.place.isWellFormed) return 'the coordinates are out of range';
  if (!isKnownZone(input.place.timezone)) {
    return 'the timezone "${input.place.timezone}" is not in the database';
  }
  return null;
}

// ---------------------------------------------------------------------------
// Consultations (G-42)
// ---------------------------------------------------------------------------

/// One session with a client.
///
/// Notes attached to a *date* rather than to the chart in general, which is
/// what makes the second session useful: "what did we talk about last time"
/// is a question about an occasion, not about a person.
class Consultation {
  const Consultation({
    required this.id,
    required this.chartId,
    required this.when,
    required this.summary,
    this.notes = '',
    this.topics = const [],
  });

  final String id;
  final String chartId;
  final DateTime when;

  /// One line, for the list.
  final String summary;

  /// Everything else.
  final String notes;

  /// What the session was about, reusing the chart's own tag vocabulary.
  final List<String> topics;

  Map<String, dynamic> toJson() => {
        'id': id,
        'chartId': chartId,
        'when': when.toIso8601String(),
        'summary': summary,
        'notes': notes,
        'topics': topics,
      };

  factory Consultation.fromJson(Map<String, dynamic> j) => Consultation(
        id: j['id'] as String,
        chartId: j['chartId'] as String,
        when: DateTime.parse(j['when'] as String),
        summary: j['summary'] as String? ?? '',
        notes: j['notes'] as String? ?? '',
        topics: [
          for (final t in (j['topics'] as List? ?? const []))
            if (t is String) t,
        ],
      );
}

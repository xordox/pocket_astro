import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../domain/models.dart';
import '../engine/tz_lookup.dart';
import 'interchange.dart';

class LocalStore {
  Future<File> _file() async {
    final dir = await getApplicationDocumentsDirectory();
    return File(p.join(dir.path, 'pocketastro_profiles.json'));
  }

  /// Profiles, decoded one at a time.
  ///
  /// Per-entry rather than all-or-nothing on purpose: a single unreadable
  /// record used to empty the whole library, and the next [saveProfiles] then
  /// wrote that emptiness back to disk. One bad row now costs one row.
  Future<List<BirthInput>> loadProfiles() async {
    List<dynamic> raw;
    try {
      final f = await _file();
      if (!await f.exists()) return [];
      final decoded = jsonDecode(await f.readAsString());
      if (decoded is! List) return [];
      raw = decoded;
    } catch (_) {
      return [];
    }
    final out = <BirthInput>[];
    for (final e in raw) {
      try {
        final input = BirthInput.fromJson(e as Map<String, dynamic>);
        // The same gate `placeFromGeoJson` applies to remote data, applied to
        // stored data. Without it a truncated or hand-edited record decodes
        // fine — Place.fromJson is deliberately tolerant — renders in the
        // library, and then throws UnknownTimezone out of initState the moment
        // it is tapped. Dropping the row keeps "one bad row costs one row"
        // true; letting it through costs the reader a crash loop.
        if (!input.place.isWellFormed || !isKnownZone(input.place.timezone)) {
          continue;
        }
        out.add(input);
      } catch (_) {
        // Skip the unreadable row and keep the reader's other charts.
      }
    }
    return out;
  }

  Future<void> saveProfiles(List<BirthInput> profiles) async {
    final f = await _file();
    await f.writeAsString(jsonEncode(profiles.map((e) => e.toJson()).toList()));
  }

  Future<File> _localeFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File(p.join(dir.path, 'pocketastro_locale.txt'));
  }

  /// The language the reader chose, or null the first time they open the app.
  Future<String?> loadLocale() async {
    try {
      final f = await _localeFile();
      if (!await f.exists()) return null;
      final code = (await f.readAsString()).trim();
      return code.isEmpty ? null : code;
    } catch (_) {
      return null;
    }
  }

  Future<void> saveLocale(String code) async {
    try {
      await (await _localeFile()).writeAsString(code);
    } catch (_) {
      // A read-only store is not a reason to refuse the language change.
    }
  }

  Future<File> _placesFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File(p.join(dir.path, 'pocketastro_places.json'));
  }

  /// Birthplaces the reader has used before — their own atlas, grown from use.
  ///
  /// A place found online once is available offline forever after, which is
  /// what keeps a second chart for the same town possible on a plane.
  Future<List<Place>> loadRecentPlaces() async {
    try {
      final f = await _placesFile();
      if (!await f.exists()) return [];
      final decoded = jsonDecode(await f.readAsString());
      if (decoded is! List) return [];
      final out = <Place>[];
      for (final e in decoded) {
        try {
          final place = Place.fromJson(e as Map<String, dynamic>);
          // A remembered place must never be offered back unusable.
          if (place.isWellFormed && isKnownZone(place.timezone)) out.add(place);
        } catch (_) {
          // Same rule as profiles: skip the row, keep the rest.
        }
      }
      return out;
    } catch (_) {
      return [];
    }
  }

  Future<void> saveRecentPlaces(List<Place> places) async {
    try {
      await (await _placesFile())
          .writeAsString(jsonEncode(places.map((e) => e.toJson()).toList()));
    } catch (_) {
      // A place that fails to persist is still usable for this chart.
    }
  }

  Future<File> _settingsFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File(p.join(dir.path, 'chart_settings.json'));
  }

  /// The reader's calculation choices — ayanamsa, house system, node type and
  /// the rest (G-46).
  ///
  /// Stored separately from the profiles so that a malformed settings file can
  /// never take the library down with it, and so that resetting to defaults is
  /// one file deletion rather than a migration.
  Future<Map<String, dynamic>?> loadChartSettings() async {
    try {
      final f = await _settingsFile();
      if (!await f.exists()) return null;
      final raw = jsonDecode(await f.readAsString());
      return raw is Map<String, dynamic> ? raw : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> saveChartSettings(Map<String, dynamic> settings) async {
    final f = await _settingsFile();
    await f.writeAsString(jsonEncode(settings));
  }

  Future<File> _consultationsFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File(p.join(dir.path, 'consultations.json'));
  }

  /// Session notes, keyed by chart id (G-42).
  ///
  /// Held apart from the profiles so that a client record can grow without
  /// rewriting the chart file on every note, and so that exporting charts
  /// without sessions — or sessions without charts — stays possible.
  Future<Map<String, List<Consultation>>> loadConsultations() async {
    try {
      final f = await _consultationsFile();
      if (!await f.exists()) return {};
      final raw = jsonDecode(await f.readAsString());
      if (raw is! Map) return {};
      final out = <String, List<Consultation>>{};
      for (final e in raw.entries) {
        final rows = e.value;
        if (rows is! List) continue;
        final parsed = <Consultation>[];
        for (final row in rows) {
          // Per-entry, like the profiles: one unreadable note must not take
          // a client's whole history with it.
          try {
            if (row is Map) {
              parsed.add(Consultation.fromJson(row.cast<String, dynamic>()));
            }
          } catch (_) {
            continue;
          }
        }
        out[e.key as String] = parsed;
      }
      return out;
    } catch (_) {
      return {};
    }
  }

  Future<void> saveConsultations(Map<String, List<Consultation>> all) async {
    final f = await _consultationsFile();
    await f.writeAsString(jsonEncode({
      for (final e in all.entries)
        e.key: [for (final c in e.value) c.toJson()],
    }));
  }

  /// Writes an export to a file the reader can share out (G-41).
  Future<File> writeExport(String filename, String contents) async {
    final dir = await getApplicationDocumentsDirectory();
    final f = File(p.join(dir.path, filename));
    await f.writeAsString(contents);
    return f;
  }

  Future<File> _learnedFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File(p.join(dir.path, 'pocketastro_learned.json'));
  }

  /// Lesson ids the reader has finished. Progress is per device and never
  /// leaves it, like everything else here.
  Future<Set<String>> loadLearned() async {
    try {
      final f = await _learnedFile();
      if (!await f.exists()) return <String>{};
      final raw = jsonDecode(await f.readAsString());
      return raw is List ? raw.whereType<String>().toSet() : <String>{};
    } catch (_) {
      return <String>{};
    }
  }

  Future<void> saveLearned(Set<String> ids) async {
    try {
      await (await _learnedFile()).writeAsString(jsonEncode(ids.toList()));
    } catch (_) {
      // Losing a tick mark is not a reason to fail the lesson the reader is
      // in the middle of.
    }
  }

  Future<File> reportsDirFile(String name) async {
    final dir = await getApplicationDocumentsDirectory();
    final folder = Directory(p.join(dir.path, 'reports'));
    if (!await folder.exists()) await folder.create(recursive: true);
    return File(p.join(folder.path, name));
  }
}

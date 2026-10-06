/// An in-memory [LocalStore] for widget tests.
///
/// Extracted so the new screens can be pumped without touching the file
/// system, and so a settings test can assert on what was actually written.
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as pathlib;
import 'package:pocket_astro/data/interchange.dart';
import 'package:pocket_astro/data/local_store.dart';
import 'package:pocket_astro/domain/models.dart';

class MemoryStore implements LocalStore {
  MemoryStore([this._profiles = const []]);

  List<BirthInput> _profiles;
  Map<String, dynamic>? _settings;
  Map<String, List<Consultation>> _consultations = {};
  String? _locale;
  Set<String> _learned = {};
  List<Place> _places = [];

  @override
  Future<List<BirthInput>> loadProfiles() async => _profiles;

  @override
  Future<void> saveProfiles(List<BirthInput> profiles) async =>
      _profiles = profiles;

  @override
  Future<Map<String, dynamic>?> loadChartSettings() async =>
      _settings == null ? null : jsonDecode(jsonEncode(_settings)) as Map<String, dynamic>;

  @override
  Future<void> saveChartSettings(Map<String, dynamic> settings) async =>
      _settings = settings;

  @override
  Future<String?> loadLocale() async => _locale;

  @override
  Future<void> saveLocale(String code) async => _locale = code;

  @override
  Future<Set<String>> loadLearned() async => _learned;

  @override
  Future<void> saveLearned(Set<String> ids) async => _learned = ids;

  @override
  Future<Map<String, List<Consultation>>> loadConsultations() async =>
      {for (final e in _consultations.entries) e.key: [...e.value]};

  @override
  Future<void> saveConsultations(Map<String, List<Consultation>> all) async =>
      _consultations = {for (final e in all.entries) e.key: [...e.value]};

  @override
  Future<File> writeExport(String filename, String contents) async {
    _exports[filename] = contents;
    // Tests assert on [exports] rather than on the file, but the signature has
    // to return one, so it goes to the system temp directory and not to the
    // real documents directory.
    final f = File(pathlib.join(Directory.systemTemp.path, filename));
    await f.writeAsString(contents);
    return f;
  }

  /// What was exported, for assertions.
  final Map<String, String> _exports = {};

  Map<String, String> get exports => Map.unmodifiable(_exports);

  @override
  Future<List<Place>> loadRecentPlaces() async => _places;

  @override
  Future<void> saveRecentPlaces(List<Place> places) async => _places = places;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      super.noSuchMethod(invocation);
}

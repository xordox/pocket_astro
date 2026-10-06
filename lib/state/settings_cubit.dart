/// The reader's calculation choices.
///
/// Gap G-46, and the delivery vehicle for G-02, G-03, G-04 and G-07. Ayanamsa,
/// house system, node type and topocentric mode used to be constants compiled
/// into the engine. They are choices — different schools give different
/// answers and none of them is the software's to make — so they live here,
/// persist across sessions, and travel with every chart that gets built.
library;

import 'package:bloc/bloc.dart';

import '../data/local_store.dart';
import '../engine/aspects.dart';
import '../engine/astronomy.dart';

class AppSettings {
  const AppSettings({
    this.chart = const ChartSettings(),
    this.orbs = const OrbPolicy(),
    this.showChalit = true,
    this.showMinorAspects = true,
    this.showDeclinations = true,
  });

  final ChartSettings chart;
  final OrbPolicy orbs;

  /// Whether the graha table carries a bhava chalit column beside the
  /// whole-sign one (G-16).
  final bool showChalit;

  final bool showMinorAspects;
  final bool showDeclinations;

  AppSettings copyWith({
    ChartSettings? chart,
    OrbPolicy? orbs,
    bool? showChalit,
    bool? showMinorAspects,
    bool? showDeclinations,
  }) =>
      AppSettings(
        chart: chart ?? this.chart,
        orbs: orbs ?? this.orbs,
        showChalit: showChalit ?? this.showChalit,
        showMinorAspects: showMinorAspects ?? this.showMinorAspects,
        showDeclinations: showDeclinations ?? this.showDeclinations,
      );

  Map<String, dynamic> toJson() => {
        'chart': chart.toJson(),
        'orbs': orbs.toJson(),
        'showChalit': showChalit,
        'showMinorAspects': showMinorAspects,
        'showDeclinations': showDeclinations,
      };

  factory AppSettings.fromJson(Map<String, dynamic> j) => AppSettings(
        chart: ChartSettings.fromJson(
            (j['chart'] as Map?)?.cast<String, dynamic>() ?? const {}),
        orbs: OrbPolicy.fromJson(
            (j['orbs'] as Map?)?.cast<String, dynamic>() ?? const {}),
        showChalit: j['showChalit'] as bool? ?? true,
        showMinorAspects: j['showMinorAspects'] as bool? ?? true,
        showDeclinations: j['showDeclinations'] as bool? ?? true,
      );

  /// Whether these settings depart from the app's defaults — used to show a
  /// "not the defaults" marker, so a reader who changed something six months
  /// ago is reminded rather than puzzled.
  bool get isDefault =>
      chart.ayanamsa == Ayanamsa.lahiri &&
      chart.houseSystem == HouseSystem.placidus &&
      chart.vedicHouseSystem == HouseSystem.wholeSign &&
      !chart.trueNode &&
      !chart.topocentric;
}

/// Holds the settings and writes every change straight to disk.
///
/// Deliberately eager: a reader who changes the ayanamsa and force-quits
/// should not come back to a chart computed the old way.
class SettingsCubit extends Cubit<AppSettings> {
  SettingsCubit(this._store) : super(const AppSettings());

  final LocalStore _store;

  Future<void> start() async {
    final raw = await _store.loadChartSettings();
    if (raw == null) return;
    try {
      emit(AppSettings.fromJson(raw));
    } catch (_) {
      // A settings file we cannot read is not worth crashing over; the
      // defaults are always a valid chart.
    }
  }

  Future<void> _persist(AppSettings next) async {
    emit(next);
    await _store.saveChartSettings(next.toJson());
  }

  Future<void> setAyanamsa(Ayanamsa value) =>
      _persist(state.copyWith(chart: state.chart.copyWith(ayanamsa: value)));

  Future<void> setHouseSystem(HouseSystem value) =>
      _persist(state.copyWith(chart: state.chart.copyWith(houseSystem: value)));

  Future<void> setVedicHouseSystem(HouseSystem value) => _persist(
      state.copyWith(chart: state.chart.copyWith(vedicHouseSystem: value)));

  Future<void> setTrueNode(bool value) =>
      _persist(state.copyWith(chart: state.chart.copyWith(trueNode: value)));

  Future<void> setTopocentric(bool value) =>
      _persist(state.copyWith(chart: state.chart.copyWith(topocentric: value)));

  Future<void> setElevation(double metres) => _persist(
      state.copyWith(chart: state.chart.copyWith(elevationMetres: metres)));

  Future<void> setMinorBodies(bool value) => _persist(state.copyWith(
      chart: state.chart.copyWith(includeMinorBodies: value)));

  Future<void> setShowChalit(bool value) =>
      _persist(state.copyWith(showChalit: value));

  Future<void> setMinorAspects(bool value) => _persist(state.copyWith(
        showMinorAspects: value,
        orbs: state.orbs.copyWith(includeMinor: value),
      ));

  Future<void> setShowDeclinations(bool value) =>
      _persist(state.copyWith(showDeclinations: value));

  Future<void> setAspectOrb(String aspect, double orb) {
    final next = Map<String, double>.from(state.orbs.aspectOrbs);
    next[aspect] = orb;
    return _persist(state.copyWith(orbs: state.orbs.copyWith(aspectOrbs: next)));
  }

  Future<void> resetOrbs() =>
      _persist(state.copyWith(orbs: OrbPolicy(includeMinor: state.showMinorAspects)));

  Future<void> resetAll() => _persist(const AppSettings());

  /// Applies a named preset.
  ///
  /// Presets are not a shortcut so much as an acknowledgement that these
  /// settings travel in groups: a KP practitioner needs the KP ayanamsa,
  /// Placidus cusps and topocentric positions together, and setting one of the
  /// three without the others produces a chart nobody uses.
  Future<void> applyPreset(SettingsPreset preset) =>
      _persist(state.copyWith(chart: preset.settings));
}

class SettingsPreset {
  const SettingsPreset({
    required this.name,
    required this.description,
    required this.settings,
  });
  final String name;
  final String description;
  final ChartSettings settings;
}

const settingsPresets = <SettingsPreset>[
  SettingsPreset(
    name: 'North Indian Parashari',
    description:
        'Lahiri, whole sign houses, mean node. What most Indian practice uses.',
    settings: ChartSettings(
      ayanamsa: Ayanamsa.lahiri,
      vedicHouseSystem: HouseSystem.wholeSign,
      houseSystem: HouseSystem.placidus,
    ),
  ),
  SettingsPreset(
    name: 'KP (Krishnamurti)',
    description:
        'KP ayanamsa, Placidus cusps and topocentric positions. All three '
        'together — KP is defined topocentrically and cannot be practised on '
        'geocentric figures.',
    settings: ChartSettings(
      ayanamsa: Ayanamsa.krishnamurti,
      houseSystem: HouseSystem.placidus,
      vedicHouseSystem: HouseSystem.placidus,
      trueNode: false,
      topocentric: true,
    ),
  ),
  SettingsPreset(
    name: 'Modern Western',
    description: 'Tropical, Placidus, true node. The default of most Western '
        'software.',
    settings: ChartSettings(
      ayanamsa: Ayanamsa.none,
      houseSystem: HouseSystem.placidus,
      vedicHouseSystem: HouseSystem.placidus,
      trueNode: true,
    ),
  ),
  SettingsPreset(
    name: 'Traditional / Hellenistic',
    description:
        'Tropical, whole sign houses, true node. Whole sign is the oldest '
        'division and the one the time-lord techniques assume.',
    settings: ChartSettings(
      ayanamsa: Ayanamsa.none,
      houseSystem: HouseSystem.wholeSign,
      vedicHouseSystem: HouseSystem.wholeSign,
      trueNode: true,
    ),
  ),
  SettingsPreset(
    name: 'Sidereal Western (Fagan–Bradley)',
    description: 'Fagan–Bradley ayanamsa with Placidus cusps.',
    settings: ChartSettings(
      ayanamsa: Ayanamsa.faganBradley,
      houseSystem: HouseSystem.placidus,
      vedicHouseSystem: HouseSystem.placidus,
      trueNode: true,
    ),
  ),
];

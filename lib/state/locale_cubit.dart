import 'package:bloc/bloc.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../data/local_store.dart';
import '../engine/kb.dart';
import '../l10n/engine_strings.dart';

/// The app's language.
///
/// Changing it does three things in one place, so the two localisation systems
/// can never fall out of step:
///
/// 1. swaps the Flutter locale, which drives the generated widget strings;
/// 2. installs the matching [EngineStrings] table, which drives text the
///    engine composes;
/// 3. reloads the knowledge base with that locale's overlay, which drives the
///    classical readings.
class LocaleCubit extends Cubit<Locale> {
  LocaleCubit(this._store) : super(const Locale('en'));

  final LocalStore _store;

  /// Loads the saved choice and primes both string systems.
  Future<void> start() async {
    final saved = await _store.loadLocale();
    final code = supportedLocaleCodes.contains(saved) ? saved! : 'en';
    await _apply(code);
  }

  Future<void> select(String code) async {
    if (!supportedLocaleCodes.contains(code) || code == state.languageCode) {
      return;
    }
    await _store.saveLocale(code);
    await _apply(code);
  }

  Future<void> _apply(String code) async {
    EngineStrings.install(code);
    await PredictionKb.loadFromAssets(locale: code);
    emit(Locale(code));
  }

  /// Registers every shipped locale's engine table once at startup, so
  /// switching language later is instant and cannot fail mid-session.
  static Future<void> preloadEngineStrings([AssetBundle? bundle]) async {
    final b = bundle ?? rootBundle;
    for (final code in supportedLocaleCodes) {
      if (code == 'en') continue; // English is compiled in.
      try {
        EngineStrings.register(
          code,
          await b.loadString('assets/kb/i18n/$code/engine.json'),
        );
      } catch (_) {
        // A missing overlay degrades that locale to English rather than
        // failing the app.
      }
    }
  }
}

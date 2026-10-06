import 'package:flutter/material.dart';

import 'app.dart';
import 'data/bundled_atlas.dart';
import 'engine/kb.dart';
import 'state/locale_cubit.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  bootstrapTimezones();
  // Every locale's engine table is registered up front, so switching language
  // later cannot fail halfway through a session.
  await LocaleCubit.preloadEngineStrings();
  // English first; LocaleCubit.start() reloads with the reader's choice.
  await PredictionKb.loadFromAssets();
  // The offline atlas (G-40). Awaited here because there is nothing on screen
  // yet, and because `localMatches` is synchronous by design — it has to be
  // resident before the first keystroke, not fetched on demand.
  await BundledAtlas.instance.load();
  runApp(const PocketAstroApp());
}

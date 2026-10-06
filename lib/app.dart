import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;

import 'data/geocoder.dart';
import 'data/local_store.dart';
import 'data/place_lookup.dart';
import 'l10n/generated/app_localizations.dart';
import 'state/learn_cubit.dart';
import 'state/place_lookup_cubit.dart';
import 'state/settings_cubit.dart';
import 'state/library_bloc.dart';
import 'state/locale_cubit.dart';
import 'state/match_cubit.dart';
import 'theme/theme.dart';
import 'ui/chart_screen.dart';
import 'ui/learn_screen.dart';
import 'ui/library_screen.dart';
import 'ui/rashifal_screen.dart';
import 'ui/match_screen.dart';
import 'ui/settings_screen.dart';

final _router = GoRouter(
  routes: [
    GoRoute(path: '/', builder: (c, s) => const LibraryScreen()),
    GoRoute(path: '/new', builder: (c, s) => const BirthFormScreen()),
    GoRoute(
      path: '/edit/:id',
      builder: (c, s) => _EditGate(id: s.pathParameters['id']!),
    ),
    GoRoute(
      path: '/chart/:id',
      builder: (c, s) => ChartScreen(id: s.pathParameters['id']!),
    ),
    GoRoute(path: '/learn', builder: (c, s) => const LearnScreen()),
    GoRoute(path: '/settings', builder: (c, s) => const SettingsScreen()),
    GoRoute(path: '/rashifal', builder: (c, s) => const RashifalScreen()),
    GoRoute(
      path: '/match',
      builder: (c, s) => BlocProvider(
        create: (_) => MatchCubit(),
        child: const MatchScreen(),
      ),
    ),
  ],
);

class PocketAstroApp extends StatelessWidget {
  const PocketAstroApp({super.key, this.store, this.geocoder});

  final LocalStore? store;

  /// Injected so tests never reach the network, and so a strictly-offline
  /// build can pass [OfflineGeocoder] without touching anything else.
  final Geocoder? geocoder;

  @override
  Widget build(BuildContext context) {
    final resolved = store ?? LocalStore();
    final lookup = PlaceLookup(resolved, geocoder ?? OpenMeteoGeocoder());
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) => LibraryBloc(resolved)..add(const LibraryStarted()),
        ),
        BlocProvider(create: (_) => LocaleCubit(resolved)..start()),
        BlocProvider(create: (_) => LearnCubit(resolved)..start()),
        BlocProvider(create: (_) => PlaceLookupCubit(lookup)),
        BlocProvider(create: (_) => SettingsCubit(resolved)..start()),
      ],
      child: BlocBuilder<LocaleCubit, Locale>(
        builder: (context, locale) {
          return MaterialApp.router(
            onGenerateTitle: (context) => L.of(context).appTitle,
            debugShowCheckedModeBanner: false,
            theme: pocketTheme(),
            locale: locale,
            supportedLocales: L.supportedLocales,
            localizationsDelegates: const [
              L.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            routerConfig: _router,
          );
        },
      ),
    );
  }
}

class _EditGate extends StatelessWidget {
  const _EditGate({required this.id});
  final String id;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<LibraryBloc, LibraryState>(
      builder: (context, state) {
        final found = state.profiles.where((e) => e.id == id);
        if (found.isEmpty) {
          return const Scaffold(body: Center(child: Text('Not found')));
        }
        return BirthFormScreen(existing: found.first);
      },
    );
  }
}

void bootstrapTimezones() {
  tzdata.initializeTimeZones();
}

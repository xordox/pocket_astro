import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:uuid/uuid.dart';

import '../data/atlas.dart';
import '../data/local_store.dart';
import '../domain/models.dart';
import '../engine/astronomy.dart';
import '../engine/chart_builder.dart';
import '../engine/time_convert.dart';

sealed class LibraryEvent extends Equatable {
  const LibraryEvent();
  @override
  List<Object?> get props => [];
}

class LibraryStarted extends LibraryEvent {
  const LibraryStarted();
}

class LibraryUpsert extends LibraryEvent {
  const LibraryUpsert(this.profile);
  final BirthInput profile;
  @override
  List<Object?> get props => [profile.id, profile.name];
}

class LibraryRemove extends LibraryEvent {
  const LibraryRemove(this.id);
  final String id;
  @override
  List<Object?> get props => [id];
}

class LibraryLoadDemo extends LibraryEvent {
  const LibraryLoadDemo();
}

sealed class LibraryState extends Equatable {
  const LibraryState();
  @override
  List<Object?> get props => [];

  List<BirthInput> get profiles => const [];
}

class LibraryInitial extends LibraryState {
  const LibraryInitial();
}

class LibraryLoading extends LibraryState {
  const LibraryLoading();
}

class LibraryReady extends LibraryState {
  const LibraryReady(this._profiles);
  final List<BirthInput> _profiles;
  @override
  List<BirthInput> get profiles => _profiles;
  @override
  List<Object?> get props => [_profiles];
}

class LibraryFailure extends LibraryState {
  const LibraryFailure(this.message);
  final String message;
  @override
  List<Object?> get props => [message];
}

class LibraryBloc extends Bloc<LibraryEvent, LibraryState> {
  LibraryBloc(this._store) : super(const LibraryInitial()) {
    on<LibraryStarted>(_onStarted);
    on<LibraryUpsert>(_onUpsert);
    on<LibraryRemove>(_onRemove);
    on<LibraryLoadDemo>(_onDemo);
  }

  final LocalStore _store;

  Future<void> _onStarted(
    LibraryStarted event,
    Emitter<LibraryState> emit,
  ) async {
    emit(const LibraryLoading());
    try {
      emit(LibraryReady(await _store.loadProfiles()));
    } catch (e) {
      emit(LibraryFailure('$e'));
    }
  }

  Future<void> _onUpsert(
    LibraryUpsert event,
    Emitter<LibraryState> emit,
  ) async {
    final list = List<BirthInput>.from(state.profiles);
    final i = list.indexWhere((e) => e.id == event.profile.id);
    if (i >= 0) {
      list[i] = event.profile;
    } else {
      list.insert(0, event.profile);
    }
    await _store.saveProfiles(list);
    emit(LibraryReady(list));
  }

  Future<void> _onRemove(
    LibraryRemove event,
    Emitter<LibraryState> emit,
  ) async {
    final list = List<BirthInput>.from(state.profiles)
      ..removeWhere((e) => e.id == event.id);
    await _store.saveProfiles(list);
    emit(LibraryReady(list));
  }

  Future<void> _onDemo(
    LibraryLoadDemo event,
    Emitter<LibraryState> emit,
  ) async {
    await _onUpsert(LibraryUpsert(demoKathmandu()), emit);
  }

  BirthInput? byId(String id) {
    for (final p in state.profiles) {
      if (p.id == id) return p;
    }
    return null;
  }
}

/// Builds a chart under the reader's calculation settings.
///
/// The settings parameter is optional so that the many call sites that only
/// want "a chart for this person" keep working, but any screen with access to
/// [SettingsCubit] should pass them — otherwise a reader who chose the KP
/// ayanamsa gets Lahiri here and a quietly different chart (G-46).
NatalChart chartFor(BirthInput input, {ChartSettings? settings}) => buildChart(
      input,
      toUtc(input),
      settings: settings ?? const ChartSettings(),
    );

BirthInput demoKathmandu() {
  return BirthInput(
    id: const Uuid().v4(),
    name: 'Demo — 14 Apr 1992',
    localDateTime: DateTime(1992, 4, 14, 3, 57),
    place: kathmandu,
    timeSource: TimeSource.hospital,
    notes: 'Fixture from the PocketAstro knowledge-base readings.',
  );
}

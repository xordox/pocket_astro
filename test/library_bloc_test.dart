import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_astro/data/atlas.dart';
import 'package:pocket_astro/data/local_store.dart';
import 'package:pocket_astro/domain/models.dart';
import 'package:pocket_astro/state/library_bloc.dart';
import 'package:pocket_astro/state/match_cubit.dart';

class _MemStore extends LocalStore {
  List<BirthInput> saved = [];

  @override
  Future<List<BirthInput>> loadProfiles() async => saved;

  @override
  Future<void> saveProfiles(List<BirthInput> profiles) async {
    saved = List<BirthInput>.from(profiles);
  }
}

void main() {
  final sample = BirthInput(
    id: 'a',
    name: 'Asha',
    localDateTime: DateTime(1992, 4, 14, 3, 57),
    place: kathmandu,
    timeSource: TimeSource.hospital,
  );

  blocTest<LibraryBloc, LibraryState>(
    'starts empty then upserts a kundli',
    build: () => LibraryBloc(_MemStore()),
    act: (bloc) async {
      bloc.add(const LibraryStarted());
      await bloc.stream.firstWhere((s) => s is LibraryReady);
      bloc.add(LibraryUpsert(sample));
    },
    wait: const Duration(milliseconds: 20),
    expect: () => [
      const LibraryLoading(),
      const LibraryReady([]),
      LibraryReady([sample]),
    ],
  );

  blocTest<MatchCubit, MatchSelection>(
    'selects two different profiles',
    build: MatchCubit.new,
    act: (cubit) {
      cubit.selectA('a');
      cubit.selectB('b');
    },
    expect: () => [
      const MatchSelection(aId: 'a'),
      const MatchSelection(aId: 'a', bId: 'b'),
    ],
  );
}

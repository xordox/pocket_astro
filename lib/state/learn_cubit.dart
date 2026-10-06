import 'package:bloc/bloc.dart';

import '../data/local_store.dart';

/// Which lessons the reader has finished.
///
/// Progress is a set of lesson ids and nothing more — no scores, no streaks,
/// no dates. It is stored on the device with everything else the app knows,
/// and a store that cannot be written loses a tick mark rather than a lesson.
class LearnCubit extends Cubit<Set<String>> {
  LearnCubit(this._store) : super(const {});

  final LocalStore _store;

  Future<void> start() async => emit(await _store.loadLearned());

  bool isDone(String lessonId) => state.contains(lessonId);

  Future<void> toggle(String lessonId) async {
    final next = Set<String>.from(state);
    if (!next.remove(lessonId)) next.add(lessonId);
    emit(next);
    await _store.saveLearned(next);
  }

  /// Clears the course. Offered because a reader may want to start again, and
  /// because progress the reader cannot reset is progress they cannot trust.
  Future<void> reset() async {
    emit(const {});
    await _store.saveLearned(const {});
  }
}

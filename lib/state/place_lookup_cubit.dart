import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../data/geocoder.dart';
import '../data/place_lookup.dart';
import '../domain/models.dart';

/// The state of an *online* birthplace search.
///
/// Local matching is synchronous and is not modelled here — the widget calls
/// [PlaceLookup.localMatches] directly in `onChanged`. This cubit exists only
/// for the part that can be slow, can fail, and can come back after the reader
/// has left the screen.
sealed class PlaceLookupState extends Equatable {
  const PlaceLookupState();

  @override
  List<Object?> get props => [];
}

class PlaceIdle extends PlaceLookupState {
  const PlaceIdle();
}

class PlaceSearching extends PlaceLookupState {
  const PlaceSearching(this.query);
  final String query;

  @override
  List<Object?> get props => [query];
}

class PlaceFound extends PlaceLookupState {
  const PlaceFound(this.query, this.hits);
  final String query;
  final List<Place> hits;

  @override
  List<Object?> get props => [query, hits];
}

/// The service answered, and nothing it returned was usable.
class PlaceNotFound extends PlaceLookupState {
  const PlaceNotFound(this.query);
  final String query;

  @override
  List<Object?> get props => [query];
}

/// The service could not be reached. Distinct from [PlaceNotFound] because the
/// reader should be told to check their connection, not their spelling.
class PlaceUnreachable extends PlaceLookupState {
  const PlaceUnreachable(this.query);
  final String query;

  @override
  List<Object?> get props => [query];
}

class PlaceLookupCubit extends Cubit<PlaceLookupState> {
  PlaceLookupCubit(this.lookup) : super(const PlaceIdle());

  final PlaceLookup lookup;

  /// Sequence number for in-flight requests. A response is only allowed to
  /// emit if it belongs to the most recent search — otherwise a slow first
  /// query could overwrite the results of a fast second one.
  int _seq = 0;

  Future<void> search(String query, {String language = 'en'}) async {
    final q = query.trim();
    final n = ++_seq;
    emit(PlaceSearching(q));

    final result = await lookup.online(q, language: language);

    // The form may have been popped, or a newer search started, while this was
    // in flight. Either way this answer is no longer wanted.
    if (isClosed || n != _seq) return;

    emit(switch (result) {
      GeocodeHits(:final places) => PlaceFound(q, places),
      GeocodeEmpty() => PlaceNotFound(q),
      GeocodeUnreachable() => PlaceUnreachable(q),
    });
  }

  /// Re-issues the query the current state is about.
  Future<void> retry({String language = 'en'}) async {
    final q = switch (state) {
      PlaceSearching(:final query) => query,
      PlaceFound(:final query) => query,
      PlaceNotFound(:final query) => query,
      PlaceUnreachable(:final query) => query,
      PlaceIdle() => '',
    };
    if (q.isEmpty) return;
    await search(q, language: language);
  }

  /// Clears the panel and abandons anything in flight.
  void reset() {
    _seq++;
    if (!isClosed) emit(const PlaceIdle());
  }
}

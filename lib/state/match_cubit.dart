import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

class MatchSelection extends Equatable {
  const MatchSelection({this.aId, this.bId});

  final String? aId;
  final String? bId;

  bool get canScore => aId != null && bId != null && aId != bId;

  MatchSelection withA(String? id) => MatchSelection(aId: id, bId: bId);
  MatchSelection withB(String? id) => MatchSelection(aId: aId, bId: id);

  @override
  List<Object?> get props => [aId, bId];
}

class MatchCubit extends Cubit<MatchSelection> {
  MatchCubit() : super(const MatchSelection());

  void selectA(String? id) => emit(state.withA(id));
  void selectB(String? id) => emit(state.withB(id));
}

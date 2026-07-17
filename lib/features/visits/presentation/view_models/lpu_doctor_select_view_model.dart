import 'package:flutter_riverpod/flutter_riverpod.dart';

enum LpuVisitMode { single, manager }

class LpuDoctorSelectionState {
  final String query;
  final String? selectedManager;
  final LpuVisitMode mode;
  final Set<String> selectedIds;

  const LpuDoctorSelectionState({
    this.query = '',
    this.selectedManager,
    this.mode = LpuVisitMode.single,
    this.selectedIds = const <String>{},
  });

  bool get canContinue => mode == LpuVisitMode.manager
      ? selectedManager != null && selectedIds.isNotEmpty
      : selectedIds.isNotEmpty;

  LpuDoctorSelectionState copyWith({
    String? query,
    String? selectedManager,
    bool clearManager = false,
    LpuVisitMode? mode,
    Set<String>? selectedIds,
  }) {
    return LpuDoctorSelectionState(
      query: query ?? this.query,
      selectedManager: clearManager
          ? null
          : (selectedManager ?? this.selectedManager),
      mode: mode ?? this.mode,
      selectedIds: selectedIds ?? this.selectedIds,
    );
  }
}

class LpuDoctorSelectViewModel extends StateNotifier<LpuDoctorSelectionState> {
  LpuDoctorSelectViewModel() : super(const LpuDoctorSelectionState());

  void setQuery(String query) {
    state = state.copyWith(query: query);
  }

  void toggleDoctor(String id) {
    final selected = {...state.selectedIds};
    if (!selected.add(id)) selected.remove(id);
    state = state.copyWith(selectedIds: Set.unmodifiable(selected));
  }

  void selectDoctor(String id) {
    final selected = {...state.selectedIds, id};
    state = state.copyWith(selectedIds: Set.unmodifiable(selected));
  }

  void setManager(String? manager) {
    state = state.copyWith(
      selectedManager: manager,
      mode: manager == null ? LpuVisitMode.single : LpuVisitMode.manager,
      clearManager: manager == null,
    );
  }
}

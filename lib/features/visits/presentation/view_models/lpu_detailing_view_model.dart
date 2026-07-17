import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lima/core/models/models.dart';
import 'package:lima/features/knowledge/domain/repositories/knowledge_repository.dart';
import 'package:lima/features/visits/domain/repositories/doctors_directory_repository.dart';
import 'package:lima/features/visits/domain/entities/visit_interaction.dart';

class LpuDetailingViewState {
  final List<Doctor> doctors;
  final List<Drug> drugs;
  final Map<String, Drug> drugByName;
  final String query;
  final Map<String, DrugStatus> statuses;
  final bool isLoading;
  final bool isActionLocked;

  const LpuDetailingViewState({
    this.doctors = const [],
    this.drugs = const [],
    this.drugByName = const {},
    this.query = '',
    this.statuses = const {},
    this.isLoading = true,
    this.isActionLocked = false,
  });

  List<Drug> get filteredDrugs {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) return drugs;
    return drugs
        .where((drug) => drug.name.toLowerCase().contains(normalized))
        .toList(growable: false);
  }

  LpuDetailingViewState copyWith({
    List<Doctor>? doctors,
    List<Drug>? drugs,
    Map<String, Drug>? drugByName,
    String? query,
    Map<String, DrugStatus>? statuses,
    bool? isLoading,
    bool? isActionLocked,
  }) => LpuDetailingViewState(
    doctors: doctors ?? this.doctors,
    drugs: drugs ?? this.drugs,
    drugByName: drugByName ?? this.drugByName,
    query: query ?? this.query,
    statuses: statuses ?? this.statuses,
    isLoading: isLoading ?? this.isLoading,
    isActionLocked: isActionLocked ?? this.isActionLocked,
  );
}

class LpuDetailingViewModel extends StateNotifier<LpuDetailingViewState> {
  final DoctorsDirectoryRepository _doctorsRepository;
  final KnowledgeRepository _knowledgeRepository;

  LpuDetailingViewModel(this._doctorsRepository, this._knowledgeRepository)
    : super(const LpuDetailingViewState());

  Future<void> load({
    required int organizationId,
    required List<int> doctorIds,
  }) async {
    state = state.copyWith(isLoading: true);
    final doctors = await _doctorsRepository.getDoctorModels(
      orgId: organizationId,
      includeGlobalFallback: false,
    );
    final filteredDoctors = doctors
        .where((doctor) => doctorIds.contains(doctor.id))
        .toList(growable: false);
    final loadedDrugs = await _knowledgeRepository.getKnowledgeDrugs(
      onlyWithPositivePrice: false,
    );
    final sortedDrugs =
        loadedDrugs.where((drug) => drug.name.trim().isNotEmpty).toList()
          ..sort((a, b) => a.name.compareTo(b.name));
    final drugByName = <String, Drug>{
      for (final drug in sortedDrugs) drug.name.toLowerCase(): drug,
    };
    if (!mounted) return;
    state = state.copyWith(
      doctors: List.unmodifiable(filteredDoctors),
      drugs: List.unmodifiable(sortedDrugs),
      drugByName: Map.unmodifiable(drugByName),
      isLoading: false,
    );
  }

  void setQuery(String query) => state = state.copyWith(query: query);

  void setStatus(String drugName, DrugStatus? status) {
    final statuses = Map<String, DrugStatus>.from(state.statuses);
    if (status == null) {
      statuses.remove(drugName);
    } else {
      statuses[drugName] = status;
    }
    state = state.copyWith(statuses: Map.unmodifiable(statuses));
  }

  void lockAction() => state = state.copyWith(isActionLocked: true);
}

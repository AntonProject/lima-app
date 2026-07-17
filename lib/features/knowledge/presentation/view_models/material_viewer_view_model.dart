import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/models/models.dart';
import '../../domain/repositories/knowledge_repository.dart';
import '../../domain/services/material_access_service.dart';

class MaterialViewerViewState {
  final Drug? drug;
  final List<DrugMaterial> materials;
  final int currentIndex;
  final bool isLoading;
  final String? error;
  final Map<int, String> localPaths;
  final Set<int> downloading;
  final Set<int> failed;

  const MaterialViewerViewState({
    this.drug,
    this.materials = const [],
    this.currentIndex = 0,
    this.isLoading = true,
    this.error,
    this.localPaths = const {},
    this.downloading = const {},
    this.failed = const {},
  });

  bool isDownloading(int index) => downloading.contains(index);

  bool hasFailed(int index) => failed.contains(index);

  MaterialViewerViewState copyWith({
    Drug? drug,
    List<DrugMaterial>? materials,
    int? currentIndex,
    bool? isLoading,
    String? error,
    bool clearError = false,
    Map<int, String>? localPaths,
    Set<int>? downloading,
    Set<int>? failed,
  }) {
    return MaterialViewerViewState(
      drug: drug ?? this.drug,
      materials: materials ?? this.materials,
      currentIndex: currentIndex ?? this.currentIndex,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      localPaths: localPaths ?? this.localPaths,
      downloading: downloading ?? this.downloading,
      failed: failed ?? this.failed,
    );
  }
}

class MaterialViewerViewModel extends StateNotifier<MaterialViewerViewState> {
  final KnowledgeRepository _repository;
  final MaterialAccessService _accessService;
  final int drugId;
  final int initialIndex;
  bool _loadInProgress = false;

  MaterialViewerViewModel(
    this._repository,
    this._accessService, {
    required this.drugId,
    required this.initialIndex,
  }) : super(const MaterialViewerViewState()) {
    load();
  }

  Future<void> load() async {
    if (_loadInProgress) return;
    _loadInProgress = true;
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final drug = await _repository.getDrugModel(
        drugId,
        onlyWithPositivePrice: false,
      );
      final materials = await _repository.getDrugMaterialModels(drugId);
      if (!mounted) return;
      final safeIndex = materials.isEmpty
          ? 0
          : initialIndex.clamp(0, materials.length - 1);
      state = state.copyWith(
        drug: drug,
        materials: List.unmodifiable(materials),
        currentIndex: safeIndex,
        isLoading: false,
      );
    } catch (error) {
      if (mounted) state = state.copyWith(isLoading: false, error: '$error');
    } finally {
      _loadInProgress = false;
    }
  }

  void setCurrentIndex(int index) {
    if (index < 0 || index >= state.materials.length) return;
    state = state.copyWith(currentIndex: index);
  }

  void retry(int index) {
    final failed = {...state.failed}..remove(index);
    state = state.copyWith(failed: Set.unmodifiable(failed));
  }

  Future<String?> ensureLocal(int index, {required String cacheName}) async {
    if (index < 0 || index >= state.materials.length) return null;
    final cached = state.localPaths[index];
    if (cached != null) return cached;
    if (state.isDownloading(index)) return null;

    final downloading = {...state.downloading}..add(index);
    final failed = {...state.failed}..remove(index);
    state = state.copyWith(
      downloading: Set.unmodifiable(downloading),
      failed: Set.unmodifiable(failed),
    );
    try {
      final path = await _accessService.ensureLocal(
        state.materials[index],
        cacheName: cacheName,
      );
      if (!mounted) return path;
      final paths = {...state.localPaths, index: path};
      downloading.remove(index);
      state = state.copyWith(
        localPaths: Map.unmodifiable(paths),
        downloading: Set.unmodifiable(downloading),
      );
      return path;
    } catch (error) {
      if (mounted) {
        downloading.remove(index);
        failed.add(index);
        state = state.copyWith(
          downloading: Set.unmodifiable(downloading),
          failed: Set.unmodifiable(failed),
          error: '$error',
        );
      }
      return null;
    }
  }
}

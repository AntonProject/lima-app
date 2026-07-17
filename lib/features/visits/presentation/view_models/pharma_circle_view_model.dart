import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lima/core/models/models.dart';
import 'package:lima/features/knowledge/domain/repositories/knowledge_repository.dart';

class PharmaCircleViewState {
  final List<Drug> drugs;
  final bool isLoading;
  final String query;
  final Map<int, Set<int>> shownDocumentIdsByDrug;
  final Map<int, String> shownDrugNamesByDrug;

  const PharmaCircleViewState({
    this.drugs = const [],
    this.isLoading = true,
    this.query = '',
    this.shownDocumentIdsByDrug = const {},
    this.shownDrugNamesByDrug = const {},
  });

  List<Drug> get filteredDrugs {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) return drugs;
    return drugs
        .where((drug) => drug.name.toLowerCase().contains(normalized))
        .toList(growable: false);
  }

  int get shownMaterialsCount =>
      shownDocumentIdsByDrug.values.fold(0, (sum, ids) => sum + ids.length);

  PharmaCircleViewState copyWith({
    List<Drug>? drugs,
    bool? isLoading,
    String? query,
    Map<int, Set<int>>? shownDocumentIdsByDrug,
    Map<int, String>? shownDrugNamesByDrug,
  }) => PharmaCircleViewState(
    drugs: drugs ?? this.drugs,
    isLoading: isLoading ?? this.isLoading,
    query: query ?? this.query,
    shownDocumentIdsByDrug:
        shownDocumentIdsByDrug ?? this.shownDocumentIdsByDrug,
    shownDrugNamesByDrug: shownDrugNamesByDrug ?? this.shownDrugNamesByDrug,
  );
}

class PharmaCircleViewModel extends StateNotifier<PharmaCircleViewState> {
  final KnowledgeRepository _repository;
  Future<void>? _activeLoad;

  PharmaCircleViewModel(this._repository)
    : super(const PharmaCircleViewState());

  Future<void> load() async {
    final active = _activeLoad;
    if (active != null) return active;
    final future = _loadInternal();
    _activeLoad = future;
    unawaited(
      future.whenComplete(() {
        if (identical(_activeLoad, future)) _activeLoad = null;
      }),
    );
    return future;
  }

  Future<void> _loadInternal() async {
    state = state.copyWith(isLoading: true);
    var loaded = await _repository.getKnowledgeDrugs(
      onlyWithPositivePrice: false,
      onlyWithDocuments: true,
    );
    if (loaded.isEmpty) {
      loaded = await _repository.getKnowledgeDrugs(
        onlyWithPositivePrice: false,
      );
    }
    if (!mounted) return;
    state = state.copyWith(drugs: List.unmodifiable(loaded), isLoading: false);
  }

  void setQuery(String query) {
    state = state.copyWith(query: query);
  }

  void clearShownMaterials(int drugId) {
    final documents = _copyDocumentSelections();
    documents.remove(drugId);
    final names = Map<int, String>.from(state.shownDrugNamesByDrug)
      ..remove(drugId);
    state = state.copyWith(
      shownDocumentIdsByDrug: _freezeDocuments(documents),
      shownDrugNamesByDrug: Map.unmodifiable(names),
    );
  }

  void markMaterialShown({
    required int drugId,
    required String drugName,
    required int documentId,
  }) {
    final documents = _copyDocumentSelections();
    documents.putIfAbsent(drugId, () => <int>{}).add(documentId);
    final names = Map<int, String>.from(state.shownDrugNamesByDrug)
      ..[drugId] = drugName;
    state = state.copyWith(
      shownDocumentIdsByDrug: _freezeDocuments(documents),
      shownDrugNamesByDrug: Map.unmodifiable(names),
    );
  }

  Map<int, Set<int>> _copyDocumentSelections() => {
    for (final entry in state.shownDocumentIdsByDrug.entries)
      entry.key: Set<int>.from(entry.value),
  };

  static Map<int, Set<int>> _freezeDocuments(Map<int, Set<int>> source) =>
      Map.unmodifiable({
        for (final entry in source.entries)
          entry.key: Set<int>.unmodifiable(entry.value),
      });
}

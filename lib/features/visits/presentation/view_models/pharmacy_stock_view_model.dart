import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lima/core/models/models.dart';
import 'package:lima/features/knowledge/domain/repositories/knowledge_repository.dart';

class PharmacyStockViewState {
  final List<Drug> drugs;
  final bool isLoading;
  final String query;
  final Map<int, int> quantities;
  final bool isActionLocked;

  const PharmacyStockViewState({
    this.drugs = const [],
    this.isLoading = true,
    this.query = '',
    this.quantities = const {},
    this.isActionLocked = false,
  });

  List<Drug> get filteredDrugs {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) return drugs;
    return drugs
        .where((drug) => drug.name.toLowerCase().contains(normalized))
        .toList(growable: false);
  }

  int get selectedCount =>
      quantities.values.fold(0, (sum, value) => sum + value);

  int availableStock(Drug drug) => drug.remainsStock ?? drug.stock ?? 0;

  bool isOverStock(Drug drug, int quantity) => quantity > availableStock(drug);

  bool get hasInvalidSelectedQty => quantities.entries.any((entry) {
    final drug = drugs.where((item) => item.id == entry.key).firstOrNull;
    return drug != null && isOverStock(drug, entry.value);
  });

  PharmacyStockViewState copyWith({
    List<Drug>? drugs,
    bool? isLoading,
    String? query,
    Map<int, int>? quantities,
    bool? isActionLocked,
  }) => PharmacyStockViewState(
    drugs: drugs ?? this.drugs,
    isLoading: isLoading ?? this.isLoading,
    query: query ?? this.query,
    quantities: quantities ?? this.quantities,
    isActionLocked: isActionLocked ?? this.isActionLocked,
  );
}

class PharmacyStockViewModel extends StateNotifier<PharmacyStockViewState> {
  final KnowledgeRepository _repository;
  Future<void>? _activeLoad;

  PharmacyStockViewModel(this._repository)
    : super(const PharmacyStockViewState());

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
    final loaded = await _repository.getKnowledgeDrugs();
    if (!mounted) return;
    state = state.copyWith(drugs: List.unmodifiable(loaded), isLoading: false);
  }

  void setQuery(String query) => state = state.copyWith(query: query);

  void setQuantity(int drugId, int quantity) {
    final updated = Map<int, int>.from(state.quantities)..[drugId] = quantity;
    state = state.copyWith(quantities: Map.unmodifiable(updated));
  }

  void replaceQuantities(Map<int, int> quantities) {
    state = state.copyWith(quantities: Map.unmodifiable(quantities));
  }

  void lockAction() => state = state.copyWith(isActionLocked: true);
}

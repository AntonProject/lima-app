import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lima/features/offline/domain/entities/sync_data_change.dart';
import 'package:lima/features/visits/domain/repositories/history_repository.dart';
import 'package:lima/features/visits/models/history_records.dart';

class HistoryViewState {
  final List<HistoryVisitRecord> records;
  final bool isLoading;
  final String? error;
  final HistoryFilterState filter;

  const HistoryViewState({
    this.records = const <HistoryVisitRecord>[],
    this.isLoading = false,
    this.error,
    this.filter = const HistoryFilterState(),
  });

  HistoryViewState copyWith({
    List<HistoryVisitRecord>? records,
    bool? isLoading,
    String? error,
    HistoryFilterState? filter,
    bool clearError = false,
  }) {
    return HistoryViewState(
      records: records ?? this.records,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      filter: filter ?? this.filter,
    );
  }
}

class HistoryFilterState {
  final int filterIndex;
  final int pageIndex;
  final String query;
  final bool todayOnly;

  const HistoryFilterState({
    this.filterIndex = 0,
    this.pageIndex = 0,
    this.query = '',
    this.todayOnly = false,
  });

  HistoryFilterState copyWith({
    int? filterIndex,
    int? pageIndex,
    String? query,
    bool? todayOnly,
  }) {
    return HistoryFilterState(
      filterIndex: filterIndex ?? this.filterIndex,
      pageIndex: pageIndex ?? this.pageIndex,
      query: query ?? this.query,
      todayOnly: todayOnly ?? this.todayOnly,
    );
  }
}

class HistoryViewModel extends StateNotifier<HistoryViewState> {
  final HistoryRepository _repository;
  StreamSubscription<SyncDataChange>? _changesSubscription;

  HistoryViewModel(this._repository) : super(const HistoryViewState()) {
    _changesSubscription = _repository.changes.listen((change) {
      if (change.containsAny(const [SyncDataTable.visits])) {
        unawaited(load());
      }
    });
  }

  Future<void> load() async {
    if (!mounted) return;
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final records = await _repository.getHistoryRecords();
      if (!mounted) return;
      state = state.copyWith(
        records: List.unmodifiable(records),
        isLoading: false,
      );
    } catch (error) {
      if (!mounted) return;
      state = state.copyWith(isLoading: false, error: '$error');
    }
  }

  void setFilterIndex(int value) {
    state = state.copyWith(
      filter: state.filter.copyWith(filterIndex: value, pageIndex: 0),
    );
  }

  void setQuery(String value) {
    state = state.copyWith(
      filter: state.filter.copyWith(query: value, pageIndex: 0),
    );
  }

  void setTodayOnly(bool value) {
    state = state.copyWith(
      filter: state.filter.copyWith(todayOnly: value, pageIndex: 0),
    );
  }

  void setPage(int value) {
    state = state.copyWith(filter: state.filter.copyWith(pageIndex: value));
  }

  @override
  void dispose() {
    _changesSubscription?.cancel();
    super.dispose();
  }
}

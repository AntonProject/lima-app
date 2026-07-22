import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/my_plan.dart';
import '../../domain/repositories/my_plan_repository.dart';

class MyPlanViewState {
  final int year;
  final MyPlanProgress? plan;
  final bool isLoading;
  final bool isRefreshing;
  final String? error;

  const MyPlanViewState({
    required this.year,
    this.plan,
    this.isLoading = false,
    this.isRefreshing = false,
    this.error,
  });

  MyPlanViewState copyWith({
    MyPlanProgress? plan,
    bool? isLoading,
    bool? isRefreshing,
    String? error,
    bool clearError = false,
  }) {
    return MyPlanViewState(
      year: year,
      plan: plan ?? this.plan,
      isLoading: isLoading ?? this.isLoading,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class MyPlanViewModel extends StateNotifier<MyPlanViewState> {
  final MyPlanRepository _repository;
  Future<void>? _activeLoad;

  MyPlanViewModel(this._repository, int year)
    : super(MyPlanViewState(year: year)) {
    unawaited(load());
  }

  Future<void> load({bool refreshOnly = false}) {
    final active = _activeLoad;
    if (active != null) return active;
    final future = _loadInternal(refreshOnly: refreshOnly);
    _activeLoad = future;
    unawaited(
      future.whenComplete(() {
        if (identical(_activeLoad, future)) _activeLoad = null;
      }),
    );
    return future;
  }

  Future<void> _loadInternal({required bool refreshOnly}) async {
    if (!refreshOnly && state.plan == null) {
      state = state.copyWith(isLoading: true, clearError: true);
      try {
        final cached = await _repository.getCachedPlan(state.year);
        if (!mounted) return;
        if (cached != null) {
          state = state.copyWith(
            plan: cached,
            isLoading: false,
            isRefreshing: true,
          );
        }
      } catch (_) {
        // A broken cache must not block a fresh server response.
      }
    } else if (mounted) {
      state = state.copyWith(
        isRefreshing: state.plan != null,
        isLoading: state.plan == null,
        clearError: true,
      );
    }

    try {
      final fresh = await _repository.refreshPlan(state.year);
      if (!mounted) return;
      state = state.copyWith(
        plan: fresh,
        isLoading: false,
        isRefreshing: false,
        clearError: true,
      );
    } catch (error) {
      if (!mounted) return;
      state = state.copyWith(
        isLoading: false,
        isRefreshing: false,
        error: '$error',
      );
    }
  }
}

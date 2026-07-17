import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/recent_visit.dart';
import '../../domain/repositories/home_repository.dart';

class HomeRecentVisitsState {
  final List<RecentVisit> visits;
  final bool isLoading;
  final String? error;

  const HomeRecentVisitsState({
    this.visits = const [],
    this.isLoading = false,
    this.error,
  });

  HomeRecentVisitsState copyWith({
    List<RecentVisit>? visits,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return HomeRecentVisitsState(
      visits: visits ?? this.visits,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class HomeRecentVisitsViewModel extends StateNotifier<HomeRecentVisitsState> {
  static final Map<int, List<RecentVisit>> _cacheByUser = {};

  final HomeRepository _repository;
  Future<void>? _activeLoad;

  HomeRecentVisitsViewModel(this._repository)
    : super(const HomeRecentVisitsState());

  static Future<void> preload(HomeRepository repository) async {
    try {
      final userId = await repository.getCurrentUserId();
      if (userId == null) return;
      _cacheByUser[userId] = await repository.getRecentVisits();
    } catch (_) {
      // Home retries on the first screen frame; preloading is best effort.
    }
  }

  Future<void> load() {
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
    final userId = await _repository.getCurrentUserId();
    final cached = userId == null ? null : _cacheByUser[userId];
    if (mounted) {
      state = state.copyWith(
        visits: cached ?? state.visits,
        isLoading: cached == null && state.visits.isEmpty,
        clearError: true,
      );
    }

    try {
      final fresh = await _repository.getRecentVisits();
      if (!mounted) return;
      if (userId != null) _cacheByUser[userId] = fresh;
      state = state.copyWith(visits: fresh, isLoading: false);
    } catch (error) {
      if (!mounted) return;
      state = state.copyWith(isLoading: false, error: '$error');
    }
  }
}

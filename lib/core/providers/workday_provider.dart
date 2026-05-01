import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/remote_api_service.dart';

enum WorkdayStatus { notStarted, started, ended, loading, error }

class WorkdayState {
  final WorkdayStatus status;
  final List<Map<String, dynamic>> dayTypes;
  final String? message;

  const WorkdayState({
    this.status = WorkdayStatus.notStarted,
    this.dayTypes = const [],
    this.message,
  });

  WorkdayState copyWith({
    WorkdayStatus? status,
    List<Map<String, dynamic>>? dayTypes,
    String? message,
  }) {
    return WorkdayState(
      status: status ?? this.status,
      dayTypes: dayTypes ?? this.dayTypes,
      message: message,
    );
  }
}

class WorkdayNotifier extends StateNotifier<WorkdayState> {
  final RemoteApiService _api;

  WorkdayNotifier(this._api) : super(const WorkdayState()) {
    refresh();
  }

  Future<void> refresh() async {
    try {
      final raw = await _api.getWorkdayStatus();
      final status = switch (raw) {
        'started' => WorkdayStatus.started,
        'ended' => WorkdayStatus.ended,
        _ => WorkdayStatus.notStarted,
      };
      state = state.copyWith(status: status, message: null);
    } catch (e) {
      state = state.copyWith(status: WorkdayStatus.error, message: '$e');
    }
  }

  Future<void> loadDayTypes() async {
    try {
      final dayTypes = await _api.getDayTypes();
      state = state.copyWith(dayTypes: dayTypes, message: null);
    } catch (e) {
      state = state.copyWith(message: '$e');
    }
  }

  Future<void> start({required int dayTypeId}) async {
    state = state.copyWith(status: WorkdayStatus.loading);
    try {
      await _api.startWorkday(dayTypeId: dayTypeId);
      state = state.copyWith(status: WorkdayStatus.started, message: null);
    } catch (e) {
      state = state.copyWith(status: WorkdayStatus.error, message: '$e');
      rethrow;
    }
  }

  Future<void> end() async {
    state = state.copyWith(status: WorkdayStatus.loading);
    try {
      await _api.endWorkday();
      state = state.copyWith(status: WorkdayStatus.ended, message: null);
    } catch (e) {
      state = state.copyWith(status: WorkdayStatus.error, message: '$e');
      rethrow;
    }
  }
}

final workdayProvider = StateNotifierProvider<WorkdayNotifier, WorkdayState>((
  ref,
) {
  return WorkdayNotifier(ref.watch(remoteApiServiceProvider));
});

import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/providers/auth_provider.dart';
import '../../features/workday/data/workday_repository_impl.dart';
import '../../features/workday/domain/entities/workday.dart' as workday_domain;
import '../../features/workday/domain/repositories/workday_repository.dart';
import '../db/local_database.dart';
import '../network/remote_api_service.dart';
import 'connectivity_provider.dart';
import '../network/api_client.dart';
import '../services/workday_location_service.dart';

typedef WorkdayPhase = workday_domain.WorkdayPhase;
typedef WorkdayDayType = workday_domain.DayType;
typedef WorkdaySnapshot = workday_domain.WorkdayStatus;

enum WorkdayAction { idle, starting, ending }

enum WorkdaySubmissionStatus { sent, queued, ignored }

class WorkdaySubmissionResult {
  final WorkdaySubmissionStatus status;

  const WorkdaySubmissionResult(this.status);

  bool get isQueued => status == WorkdaySubmissionStatus.queued;
}

/// A server-side workday error that is safe to show to a user.
///
/// Dio's default string contains request internals and intermittently flashed
/// as raw JSON in the UI. This keeps the backend's actual message, when one is
/// provided, while callers retain a translated fallback for network failures.
class WorkdayActionException implements Exception {
  final String? message;
  final Object cause;

  const WorkdayActionException({this.message, required this.cause});

  factory WorkdayActionException.from(Object error) {
    if (error is DioException) {
      final data = error.response?.data;
      if (data is Map) {
        final raw = data['message'] ?? data['error'] ?? data['detail'];
        final message = raw?.toString().trim();
        if (message != null && message.isNotEmpty) {
          return WorkdayActionException(message: message, cause: error);
        }
      }
    }
    return WorkdayActionException(cause: error);
  }

  @override
  String toString() => message ?? '$cause';
}

class WorkdayState {
  final bool? featureEnabled;
  final bool isLoading;
  final WorkdayAction action;
  final WorkdaySnapshot workday;
  final List<WorkdayDayType> dayTypes;
  final String? errorMessage;

  const WorkdayState({
    this.featureEnabled,
    this.isLoading = false,
    this.action = WorkdayAction.idle,
    this.workday = const WorkdaySnapshot(),
    this.dayTypes = const [],
    this.errorMessage,
  });

  /// The workday feature can still render its start action after completion.
  /// The API is the source of truth for whether another start is allowed.
  bool get isVisible => featureEnabled == true || workday.isStarted;
  bool get hasStartedWorkday => workday.isStarted || workday.isCompleted;
  bool get isActionInProgress => action != WorkdayAction.idle;

  WorkdayState copyWith({
    bool? featureEnabled,
    bool? isLoading,
    WorkdayAction? action,
    WorkdaySnapshot? workday,
    List<WorkdayDayType>? dayTypes,
    String? errorMessage,
    bool clearError = false,
  }) => WorkdayState(
    featureEnabled: featureEnabled ?? this.featureEnabled,
    isLoading: isLoading ?? this.isLoading,
    action: action ?? this.action,
    workday: workday ?? this.workday,
    dayTypes: dayTypes ?? this.dayTypes,
    errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
  );
}

class WorkdayNotifier extends StateNotifier<WorkdayState> {
  static const _alreadyStartedMessage = 'Рабочий день уже начат';

  final WorkdayRepository _repository;
  final bool Function() _isOffline;
  Future<void>? _refreshTask;

  WorkdayNotifier(this._repository, this._isOffline)
    : super(const WorkdayState()) {
    // Provider creation can happen while Home is building. Defer the first
    // state update so Riverpod never receives a mutation during that build.
    unawaited(Future<void>.microtask(_restoreAndRefresh));
  }

  Future<void> _restoreAndRefresh() async {
    final cached = await _repository.readCached();
    if (cached.status != null ||
        cached.featureEnabled != null ||
        cached.dayTypes.isNotEmpty) {
      state = state.copyWith(
        featureEnabled: cached.featureEnabled,
        workday: cached.status ?? const WorkdaySnapshot(),
        dayTypes: cached.dayTypes,
      );
    }
    await refresh();
  }

  Future<void> refresh() {
    final inFlight = _refreshTask;
    if (inFlight != null) return inFlight;

    final task = _refreshFromRemote();
    _refreshTask = task;
    return task.whenComplete(() {
      if (identical(_refreshTask, task)) _refreshTask = null;
    });
  }

  Future<void> _refreshFromRemote() async {
    state = state.copyWith(isLoading: true, clearError: true);
    Object? firstError;
    final feature = await _loadSection<bool?>(
      _repository.loadFeatureEnabled,
      onError: (error) => firstError ??= error,
    );
    final status = await _loadSection<WorkdaySnapshot>(
      _repository.loadStatus,
      onError: (error) => firstError ??= error,
    );
    final types = await _loadSection<List<WorkdayDayType>>(
      _repository.loadDayTypes,
      onError: (error) => firstError ??= error,
    );
    if (feature != null) state = state.copyWith(featureEnabled: feature);
    if (status != null) {
      // A queued local action is newer than a stale server status. The
      // repository owns the queue; this guard only preserves the optimistic
      // content while reconciliation is pending.
      final cached = await _repository.readCached();
      if (cached.status != null &&
          (cached.status!.isStarted || cached.status!.isCompleted) &&
          state.workday != cached.status) {
        state = state.copyWith(workday: status);
      } else {
        state = state.copyWith(workday: status);
      }
    }
    if (types != null) state = state.copyWith(dayTypes: types);
    state = state.copyWith(
      isLoading: false,
      errorMessage: firstError == null ? null : '$firstError',
      clearError: firstError == null,
    );
    unawaited(
      _repository.saveCached(
        workday_domain.WorkdayCachedState(
          featureEnabled: state.featureEnabled,
          status: state.workday,
          dayTypes: state.dayTypes,
        ),
      ),
    );
  }

  Future<T?> _loadSection<T>(
    Future<T> Function() load, {
    required void Function(Object error) onError,
  }) async {
    try {
      return await load();
    } catch (error) {
      onError(error);
      return null;
    }
  }

  Future<WorkdaySubmissionResult> start({
    required WorkdayDayType dayType,
  }) async {
    if (state.isActionInProgress) {
      return const WorkdaySubmissionResult(WorkdaySubmissionStatus.ignored);
    }
    if (_isOffline() && state.hasStartedWorkday) {
      final error = _alreadyStartedException();
      state = state.copyWith(errorMessage: error.message, clearError: false);
      throw error;
    }
    state = state.copyWith(action: WorkdayAction.starting, clearError: true);
    try {
      final result = await _repository.start(dayType);
      await _applyStarted(dayType);
      if (!result.queued) unawaited(refresh());
      return WorkdaySubmissionResult(
        result.queued
            ? WorkdaySubmissionStatus.queued
            : WorkdaySubmissionStatus.sent,
      );
    } catch (error) {
      state = state.copyWith(
        action: WorkdayAction.idle,
        errorMessage: '$error',
      );
      throw WorkdayActionException.from(error);
    }
  }

  Future<WorkdaySubmissionResult> end() async {
    if (state.isActionInProgress) {
      return const WorkdaySubmissionResult(WorkdaySubmissionStatus.ignored);
    }
    state = state.copyWith(action: WorkdayAction.ending, clearError: true);
    try {
      final result = await _repository.end();
      await _applyEnded();
      if (!result.queued) unawaited(refresh());
      return WorkdaySubmissionResult(
        result.queued
            ? WorkdaySubmissionStatus.queued
            : WorkdaySubmissionStatus.sent,
      );
    } catch (error) {
      state = state.copyWith(
        action: WorkdayAction.idle,
        errorMessage: '$error',
      );
      throw WorkdayActionException.from(error);
    }
  }

  Future<void> _applyStarted(WorkdayDayType dayType) async {
    state = state.copyWith(
      action: WorkdayAction.idle,
      workday: WorkdaySnapshot(
        isStarted: true,
        startTime: DateTime.now().toIso8601String(),
        dayTypeId: dayType.id,
        dayTypeName: dayType.name,
      ),
      clearError: true,
    );
    await _saveState();
  }

  Future<void> _applyEnded() async {
    state = state.copyWith(
      action: WorkdayAction.idle,
      workday: state.workday.copyWith(
        isStarted: false,
        isCompleted: true,
        endTime: DateTime.now().toIso8601String(),
      ),
      clearError: true,
    );
    await _saveState();
  }

  WorkdayActionException _alreadyStartedException() => WorkdayActionException(
    message: _alreadyStartedMessage,
    cause: StateError('A workday has already been started today'),
  );

  Future<void> _saveState() => _repository.saveCached(
    workday_domain.WorkdayCachedState(
      featureEnabled: state.featureEnabled,
      status: state.workday,
      dayTypes: state.dayTypes,
    ),
  );
}

final workdayProvider = StateNotifierProvider<WorkdayNotifier, WorkdayState>((
  ref,
) {
  final userId = ref.watch(authProvider.select((state) => state.user?.id));
  return WorkdayNotifier(
    WorkdayRepositoryImpl(
      api: ref.watch(remoteApiServiceProvider),
      prefs: ref.watch(sharedPreferencesProvider),
      db: ref.watch(localDatabaseProvider),
      locationService: const WorkdayLocationService(),
      userId: userId,
      isOffline: () => ref.read(isOfflineProvider),
    ),
    () => ref.read(isOfflineProvider),
  );
});

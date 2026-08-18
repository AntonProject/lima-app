import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/auth/providers/auth_provider.dart';
import '../db/local_database.dart';
import '../network/api_client.dart';
import '../network/remote_api_service.dart';
import 'connectivity_provider.dart';
import '../services/workday_location_service.dart';

enum WorkdayPhase { notStarted, active, completed }

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

class WorkdayDayType {
  final int id;
  final String name;
  final String description;

  const WorkdayDayType({
    required this.id,
    required this.name,
    required this.description,
  });

  factory WorkdayDayType.fromMap(Map<String, dynamic> map) {
    final rawId = map['id'];
    final id = rawId is num ? rawId.toInt() : int.tryParse('$rawId') ?? 0;
    return WorkdayDayType(
      id: id,
      name: '${map['name'] ?? ''}'.trim(),
      description: '${map['desc'] ?? map['description'] ?? ''}'.trim(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
  };
}

class WorkdaySnapshot {
  final bool isStarted;
  final bool isCompleted;
  final String? startTime;
  final String? endTime;
  final int? dayTypeId;
  final String? dayTypeName;
  final bool isLate;
  final String? duration;

  const WorkdaySnapshot({
    this.isStarted = false,
    this.isCompleted = false,
    this.startTime,
    this.endTime,
    this.dayTypeId,
    this.dayTypeName,
    this.isLate = false,
    this.duration,
  });

  WorkdayPhase get phase {
    if (isStarted && !isCompleted) return WorkdayPhase.active;
    return WorkdayPhase.notStarted;
  }

  factory WorkdaySnapshot.fromMap(Map<String, dynamic> map) {
    bool toBool(dynamic value) {
      if (value is bool) return value;
      if (value is num) return value != 0;
      return '$value'.toLowerCase() == 'true' || '$value' == '1';
    }

    int? toInt(dynamic value) {
      if (value is num) return value.toInt();
      return int.tryParse('$value');
    }

    String? toText(dynamic value) {
      final text = '$value'.trim();
      return text.isEmpty || text == 'null' ? null : text;
    }

    return WorkdaySnapshot(
      isStarted: toBool(map['is_started']),
      isCompleted: toBool(map['is_completed']),
      startTime: toText(map['start_time']),
      endTime: toText(map['end_time']),
      dayTypeId: toInt(map['day_type_id']),
      dayTypeName: toText(map['day_type_name']),
      isLate: toBool(map['is_late']),
      duration: toText(map['duration']),
    );
  }

  WorkdaySnapshot copyWith({
    bool? isStarted,
    bool? isCompleted,
    String? startTime,
    String? endTime,
    int? dayTypeId,
    String? dayTypeName,
    bool? isLate,
    String? duration,
  }) => WorkdaySnapshot(
    isStarted: isStarted ?? this.isStarted,
    isCompleted: isCompleted ?? this.isCompleted,
    startTime: startTime ?? this.startTime,
    endTime: endTime ?? this.endTime,
    dayTypeId: dayTypeId ?? this.dayTypeId,
    dayTypeName: dayTypeName ?? this.dayTypeName,
    isLate: isLate ?? this.isLate,
    duration: duration ?? this.duration,
  );

  Map<String, dynamic> toJson() => {
    'is_started': isStarted,
    'is_completed': isCompleted,
    'start_time': startTime,
    'end_time': endTime,
    'day_type_id': dayTypeId,
    'day_type_name': dayTypeName,
    'is_late': isLate,
    'duration': duration,
  };
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
  static const _featureKey = 'feature.workday.checkin.checkout';
  static const _cachePrefix = 'workday_state_v2';
  static const _alreadyStartedMessage = 'Рабочий день уже начат';

  final RemoteApiService _api;
  final SharedPreferences _prefs;
  final LocalDatabase _db;
  final WorkdayLocationService _locationService;
  final int? _userId;
  final bool Function() _isOffline;
  Future<void>? _refreshTask;

  WorkdayNotifier(
    this._api,
    this._prefs,
    this._db,
    this._locationService,
    this._userId,
    this._isOffline,
  ) : super(const WorkdayState()) {
    // Provider creation can happen while Home is building. Defer the first
    // state update so Riverpod never receives a mutation during that build.
    unawaited(Future<void>.microtask(_restoreAndRefresh));
  }

  String? get _cacheKey => _userId == null ? null : '$_cachePrefix::$_userId';

  Future<void> _restoreAndRefresh() async {
    _restoreCachedState();
    await refresh();
  }

  void _restoreCachedState() {
    final key = _cacheKey;
    if (key == null) return;
    final raw = _prefs.getString(key);
    if (raw == null || raw.isEmpty) return;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return;
      final map = Map<String, dynamic>.from(decoded);
      final rawTypes = map['day_types'];
      final types = rawTypes is List
          ? rawTypes
                .whereType<Map>()
                .map(
                  (row) =>
                      WorkdayDayType.fromMap(Map<String, dynamic>.from(row)),
                )
                .where((type) => type.id > 0 && type.name.isNotEmpty)
                .toList(growable: false)
          : const <WorkdayDayType>[];
      final rawSnapshot = map['workday'];
      state = WorkdayState(
        featureEnabled: map['feature_enabled'] is bool
            ? map['feature_enabled'] as bool
            : null,
        workday: rawSnapshot is Map
            ? WorkdaySnapshot.fromMap(Map<String, dynamic>.from(rawSnapshot))
            : const WorkdaySnapshot(),
        dayTypes: types,
      );
    } catch (_) {
      // A stale cache must never block home rendering.
    }
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
    try {
      final response = await Future.wait<dynamic>([
        _api.getGlobalBoolean(_featureKey),
        _api.getWorkdayStatus(),
        _api.getDayTypes(),
      ]);
      final featureEnabled = response[0] as bool?;
      final remoteWorkday = WorkdaySnapshot.fromMap(
        Map<String, dynamic>.from(response[1] as Map),
      );
      final userId = _userId;
      final pendingEvents = userId == null
          ? const <Map<String, dynamic>>[]
          : await _db.getPendingWorkdayEvents(userId);
      // A queued offline event is newer than the last server response. Keep
      // the cached optimistic status visible until the queue is drained.
      final workday =
          pendingEvents.isNotEmpty &&
              (state.workday.isStarted || state.workday.isCompleted)
          ? state.workday
          : remoteWorkday;
      final dayTypes = (response[2] as List<Map<String, dynamic>>)
          .map(WorkdayDayType.fromMap)
          .where((type) => type.id > 0 && type.name.isNotEmpty)
          .toList(growable: false);
      state = state.copyWith(
        featureEnabled: featureEnabled,
        isLoading: false,
        workday: workday,
        dayTypes: dayTypes,
        clearError: true,
      );
      unawaited(_persistState());
    } catch (error) {
      state = state.copyWith(isLoading: false, errorMessage: '$error');
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
    final coordinates = await _locationService.currentOrFallback();

    if (_isOffline()) {
      try {
        await _queueStart(dayType, coordinates.latitude, coordinates.longitude);
        await _applyStarted(dayType);
        return const WorkdaySubmissionResult(WorkdaySubmissionStatus.queued);
      } catch (error) {
        state = state.copyWith(
          action: WorkdayAction.idle,
          errorMessage: '$error',
        );
        throw WorkdayActionException.from(error);
      }
    }

    try {
      await _api.startWorkday(
        dayTypeId: dayType.id,
        latitude: coordinates.latitude,
        longitude: coordinates.longitude,
      );
      await _applyStarted(dayType);
      unawaited(refresh());
      return const WorkdaySubmissionResult(WorkdaySubmissionStatus.sent);
    } catch (error) {
      if (_isNetworkError(error)) {
        if (state.hasStartedWorkday) {
          final duplicateStartError = _alreadyStartedException();
          state = state.copyWith(
            action: WorkdayAction.idle,
            errorMessage: duplicateStartError.message,
          );
          throw duplicateStartError;
        }
        try {
          await _queueStart(
            dayType,
            coordinates.latitude,
            coordinates.longitude,
          );
          await _applyStarted(dayType);
          return const WorkdaySubmissionResult(WorkdaySubmissionStatus.queued);
        } catch (queueError) {
          state = state.copyWith(
            action: WorkdayAction.idle,
            errorMessage: '$queueError',
          );
          throw WorkdayActionException.from(queueError);
        }
      }
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
    final coordinates = await _locationService.currentOrFallback();

    if (_isOffline()) {
      try {
        await _queueEnd(coordinates.latitude, coordinates.longitude);
        await _applyEnded();
        return const WorkdaySubmissionResult(WorkdaySubmissionStatus.queued);
      } catch (error) {
        state = state.copyWith(
          action: WorkdayAction.idle,
          errorMessage: '$error',
        );
        throw WorkdayActionException.from(error);
      }
    }

    try {
      await _api.endWorkday(
        latitude: coordinates.latitude,
        longitude: coordinates.longitude,
      );
      await _applyEnded();
      unawaited(refresh());
      return const WorkdaySubmissionResult(WorkdaySubmissionStatus.sent);
    } catch (error) {
      if (_isNetworkError(error)) {
        try {
          await _queueEnd(coordinates.latitude, coordinates.longitude);
          await _applyEnded();
          return const WorkdaySubmissionResult(WorkdaySubmissionStatus.queued);
        } catch (queueError) {
          state = state.copyWith(
            action: WorkdayAction.idle,
            errorMessage: '$queueError',
          );
          throw WorkdayActionException.from(queueError);
        }
      }
      state = state.copyWith(
        action: WorkdayAction.idle,
        errorMessage: '$error',
      );
      throw WorkdayActionException.from(error);
    }
  }

  Future<void> _queueStart(
    WorkdayDayType type,
    double latitude,
    double longitude,
  ) => _queueEvent(
    action: 'start',
    dayTypeId: type.id,
    dayTypeName: type.name,
    latitude: latitude,
    longitude: longitude,
  );

  Future<void> _queueEnd(double latitude, double longitude) =>
      _queueEvent(action: 'end', latitude: latitude, longitude: longitude);

  Future<void> _queueEvent({
    required String action,
    int? dayTypeId,
    String? dayTypeName,
    required double latitude,
    required double longitude,
  }) async {
    final userId = _userId;
    if (userId == null) {
      throw StateError('Cannot queue workday action without a signed-in user');
    }
    await _db.enqueuePendingWorkdayEvent(
      userId: userId,
      action: action,
      dayTypeId: dayTypeId,
      dayTypeName: dayTypeName,
      latitude: latitude,
      longitude: longitude,
    );
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
    await _persistState();
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
    await _persistState();
  }

  WorkdayActionException _alreadyStartedException() => WorkdayActionException(
    message: _alreadyStartedMessage,
    cause: StateError('A workday has already been started today'),
  );

  static bool _isNetworkError(Object error) {
    if (error is! DioException) return false;
    if (error.response != null) return false;
    return switch (error.type) {
      DioExceptionType.connectionError ||
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout ||
      DioExceptionType.unknown => true,
      _ => false,
    };
  }

  Future<void> _persistState() async {
    final key = _cacheKey;
    if (key == null) return;
    await _prefs.setString(
      key,
      jsonEncode({
        'feature_enabled': state.featureEnabled,
        'workday': state.workday.toJson(),
        'day_types': state.dayTypes.map((type) => type.toJson()).toList(),
      }),
    );
  }
}

final workdayProvider = StateNotifierProvider<WorkdayNotifier, WorkdayState>((
  ref,
) {
  final userId = ref.watch(authProvider.select((state) => state.user?.id));
  return WorkdayNotifier(
    ref.watch(remoteApiServiceProvider),
    ref.watch(sharedPreferencesProvider),
    ref.watch(localDatabaseProvider),
    const WorkdayLocationService(),
    userId,
    () => ref.read(isOfflineProvider),
  );
});

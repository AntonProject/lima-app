import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/db/local_database.dart';
import '../../../../core/network/remote_api_service.dart';
import '../../../../core/services/pending_workday_sync_service.dart';
import '../../../../core/services/workday_location_service.dart';
import '../domain/entities/workday.dart';
import '../domain/repositories/workday_repository.dart';

class WorkdayRepositoryImpl implements WorkdayRepository {
  static const _featureKey = 'feature.workday.checkin.checkout';
  static const _cachePrefix = 'workday_state_v3';

  final RemoteApiService _api;
  final SharedPreferences _prefs;
  final LocalDatabase _db;
  final WorkdayLocationService _locationService;
  final int? _userId;
  final bool Function() _isOffline;

  const WorkdayRepositoryImpl({
    required RemoteApiService api,
    required SharedPreferences prefs,
    required LocalDatabase db,
    required WorkdayLocationService locationService,
    required int? userId,
    required bool Function() isOffline,
  }) : _api = api,
       _prefs = prefs,
       _db = db,
       _locationService = locationService,
       _userId = userId,
       _isOffline = isOffline;

  String? get _cacheKey => _userId == null ? null : '$_cachePrefix::$_userId';

  @override
  Future<WorkdayCachedState> readCached() async {
    final key = _cacheKey;
    if (key == null) return const WorkdayCachedState();
    final raw = _prefs.getString(key);
    if (raw == null || raw.isEmpty) return const WorkdayCachedState();
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return const WorkdayCachedState();
      final map = Map<String, dynamic>.from(decoded);
      final rawTypes = map['day_types'];
      final types = rawTypes is List
          ? rawTypes
                .whereType<Map>()
                .map((row) => DayType.fromMap(Map<String, dynamic>.from(row)))
                .where((type) => type.id > 0 && type.name.isNotEmpty)
                .toList(growable: false)
          : const <DayType>[];
      final rawStatus = map['workday'];
      return WorkdayCachedState(
        featureEnabled: map['feature_enabled'] is bool
            ? map['feature_enabled'] as bool
            : null,
        status: rawStatus is Map
            ? WorkdayStatus.fromMap(Map<String, dynamic>.from(rawStatus))
            : null,
        dayTypes: types,
      );
    } catch (_) {
      return const WorkdayCachedState();
    }
  }

  @override
  Future<bool?> loadFeatureEnabled() async {
    final value = await _api.getGlobalBoolean(_featureKey);
    await _mergeCache(featureEnabled: value);
    return value;
  }

  @override
  Future<WorkdayStatus> loadStatus() async {
    final cached = await readCached();
    final owner = await _db.getCurrentUserOwner();
    final pending = owner.userId == null
        ? const <Map<String, dynamic>>[]
        : await _db.getPendingWorkdayEvents(owner.userId!);
    final hasQueuedOptimisticAction = pending.any(
      (event) => event['status']?.toString() != 'parked',
    );
    if (hasQueuedOptimisticAction && cached.status != null) {
      return cached.status!;
    }
    final value = WorkdayStatus.fromMap(await _api.getWorkdayStatus());
    await _mergeCache(status: value);
    return value;
  }

  @override
  Future<List<DayType>> loadDayTypes() async {
    final value = (await _api.getDayTypes())
        .map(DayType.fromMap)
        .where((type) => type.id > 0 && type.name.isNotEmpty)
        .toList(growable: false);
    await _mergeCache(dayTypes: value);
    return List.unmodifiable(value);
  }

  @override
  Future<void> saveCached(WorkdayCachedState value) async {
    await _mergeCache(
      featureEnabled: value.featureEnabled,
      status: value.status,
      dayTypes: value.dayTypes,
    );
  }

  Future<void> _mergeCache({
    bool? featureEnabled,
    WorkdayStatus? status,
    List<DayType>? dayTypes,
  }) async {
    final key = _cacheKey;
    if (key == null) return;
    final current = await readCached();
    await _prefs.setString(
      key,
      jsonEncode({
        'feature_enabled': featureEnabled ?? current.featureEnabled,
        'workday': (status ?? current.status)?.toJson(),
        'day_types': (dayTypes ?? current.dayTypes)
            .map((type) => type.toJson())
            .toList(),
      }),
    );
  }

  @override
  Future<WorkdayActionResult> start(DayType dayType) async {
    final coordinates = await _locationService.currentOrFallback();
    if (_isOffline()) {
      await _enqueue('start', dayType: dayType, coordinates: coordinates);
      return const WorkdayActionResult(queued: true);
    }
    try {
      await _api.startWorkday(
        dayTypeId: dayType.id,
        latitude: coordinates.latitude,
        longitude: coordinates.longitude,
      );
      return const WorkdayActionResult(queued: false);
    } catch (error) {
      if (!_isNetworkError(error)) rethrow;
      await _enqueue('start', dayType: dayType, coordinates: coordinates);
      return const WorkdayActionResult(queued: true);
    }
  }

  @override
  Future<WorkdayActionResult> end() async {
    final coordinates = await _locationService.currentOrFallback();
    if (_isOffline()) {
      await _enqueue('end', coordinates: coordinates);
      return const WorkdayActionResult(queued: true);
    }
    try {
      await _api.endWorkday(
        latitude: coordinates.latitude,
        longitude: coordinates.longitude,
      );
      return const WorkdayActionResult(queued: false);
    } catch (error) {
      if (!_isNetworkError(error)) rethrow;
      await _enqueue('end', coordinates: coordinates);
      return const WorkdayActionResult(queued: true);
    }
  }

  Future<void> _enqueue(
    String action, {
    DayType? dayType,
    required WorkdayCoordinates coordinates,
  }) async {
    final userId = _userId;
    if (userId == null) {
      throw StateError('Cannot queue workday action without a signed-in user');
    }
    await _db.enqueuePendingWorkdayEvent(
      userId: userId,
      action: action,
      dayTypeId: dayType?.id,
      dayTypeName: dayType?.name,
      latitude: coordinates.latitude,
      longitude: coordinates.longitude,
    );
  }

  @override
  Future<bool> syncPending() => PendingWorkdaySyncService(
    db: _db,
    remoteApi: _api,
    isOffline: _isOffline,
  ).sync();

  static bool _isNetworkError(Object error) {
    if (error is! DioException || error.response != null) return false;
    return switch (error.type) {
      DioExceptionType.connectionError ||
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout ||
      DioExceptionType.unknown => true,
      _ => false,
    };
  }
}

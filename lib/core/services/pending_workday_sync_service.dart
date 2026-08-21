import 'package:dio/dio.dart';

import 'package:lima/core/db/local_database.dart';
import 'package:lima/core/network/remote_api_service.dart';

class WorkdayRetryPolicy {
  static const maxAttempts = 4;
  static const retryBase = Duration(seconds: 30);

  const WorkdayRetryPolicy();

  bool shouldPark({required int attempts, int? statusCode}) {
    if (statusCode != null &&
        statusCode >= 400 &&
        statusCode < 500 &&
        statusCode != 401 &&
        statusCode != 403 &&
        statusCode != 408 &&
        statusCode != 429) {
      return true;
    }
    return attempts >= maxAttempts;
  }

  Duration backoff(int attempts) {
    final multiplier = 1 << (attempts - 1).clamp(0, 3);
    return retryBase * multiplier;
  }
}

/// Sends queued check-in/check-out events before ordinary visit mutations.
///
/// The queue is deliberately FIFO: an end event is meaningless until its
/// preceding start has reached the server. A rejected start can already exist
/// remotely (for example after the app was closed), so the current server
/// status is used to recognise that idempotent case and continue with the
/// following event.
class PendingWorkdaySyncService {
  static const maxAttempts = WorkdayRetryPolicy.maxAttempts;

  final LocalDatabase _db;
  final RemoteApiService _remoteApi;
  final bool Function() _isOffline;
  final DateTime Function() _now;
  static const _retryPolicy = WorkdayRetryPolicy();

  const PendingWorkdaySyncService({
    required LocalDatabase db,
    required RemoteApiService remoteApi,
    required bool Function() isOffline,
    DateTime Function()? now,
  }) : _db = db,
       _remoteApi = remoteApi,
       _isOffline = isOffline,
       _now = now ?? DateTime.now;

  /// Returns `true` when there is no pending event left that must be sent
  /// before an ordinary visit mutation.
  Future<bool> sync() async {
    if (_isOffline()) return false;

    final owner = await _db.getCurrentUserOwner();
    final userId = owner.userId;
    if (userId == null) return true;

    final pending = await _db.getPendingWorkdayEvents(userId, readyOnly: true);
    for (final event in pending) {
      final canContinue = await _syncEvent(event);
      if (!canContinue) return false;
    }
    return true;
  }

  Future<bool> _syncEvent(Map<String, dynamic> event) async {
    final id = (event['id'] as num?)?.toInt();
    final action = event['action']?.toString();
    if (id == null || (action != 'start' && action != 'end')) {
      if (id != null) await _db.deletePendingWorkdayEvent(id);
      return true;
    }

    if (event['status']?.toString() == 'parked') return true;

    final latitude = _asDouble(event['latitude']);
    final longitude = _asDouble(event['longitude']);
    try {
      if (action == 'start') {
        final dayTypeId = (event['day_type_id'] as num?)?.toInt();
        if (dayTypeId == null || dayTypeId <= 0) {
          await _db.deletePendingWorkdayEvent(id);
          return true;
        }
        await _remoteApi.startWorkday(
          dayTypeId: dayTypeId,
          latitude: latitude,
          longitude: longitude,
        );
      } else {
        await _remoteApi.endWorkday(latitude: latitude, longitude: longitude);
      }
      await _db.deletePendingWorkdayEvent(id);
      return true;
    } catch (error) {
      if (_isReconciliationCandidate(error) &&
          await _wasAlreadyApplied(action!)) {
        await _db.deletePendingWorkdayEvent(id);
        return true;
      }
      final attempts = ((event['attempts'] as num?)?.toInt() ?? 0) + 1;
      final permanent = _isPermanent(error);
      final shouldPark =
          permanent || _retryPolicy.shouldPark(attempts: attempts);
      await _db.recordPendingWorkdayEventFailure(
        id: id,
        error: '$error',
        status: shouldPark ? 'parked' : 'retryScheduled',
        nextRetryAt: shouldPark
            ? null
            : _now().add(_retryPolicy.backoff(attempts)),
        parkedAt: shouldPark ? _now() : null,
        httpStatus: _statusCode(error),
      );

      // A parked item is a dead-letter entry and must not block later events.
      return shouldPark;
    }
  }

  static int? _statusCode(Object error) {
    if (error is DioException) return error.response?.statusCode;
    if (error is RemotePushException) return error.statusCode;
    return null;
  }

  static bool _isPermanent(Object error) {
    final code = _statusCode(error);
    if (code == null) return false;
    if (code == 401 || code == 403 || code == 408 || code == 429) return false;
    return code >= 400 && code < 500;
  }

  static bool _isReconciliationCandidate(Object error) {
    final code = _statusCode(error);
    return code == 409 || code == 422;
  }

  Future<bool> _wasAlreadyApplied(String action) async {
    try {
      final status = await _remoteApi.getWorkdayStatus();
      return action == 'start'
          ? _asBool(status['is_started'])
          : _asBool(status['is_completed']);
    } on DioException {
      return false;
    } catch (_) {
      return false;
    }
  }

  static double _asDouble(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse('$value') ?? 0;
  }

  static bool _asBool(Object? value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    return '$value'.toLowerCase() == 'true' || '$value' == '1';
  }
}

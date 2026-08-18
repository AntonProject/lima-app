import 'package:dio/dio.dart';

import 'package:lima/core/db/local_database.dart';
import 'package:lima/core/network/remote_api_service.dart';

/// Sends queued check-in/check-out events before ordinary visit mutations.
///
/// The queue is deliberately FIFO: an end event is meaningless until its
/// preceding start has reached the server. A rejected start can already exist
/// remotely (for example after the app was closed), so the current server
/// status is used to recognise that idempotent case and continue with the
/// following event.
class PendingWorkdaySyncService {
  final LocalDatabase _db;
  final RemoteApiService _remoteApi;
  final bool Function() _isOffline;

  const PendingWorkdaySyncService({
    required LocalDatabase db,
    required RemoteApiService remoteApi,
    required bool Function() isOffline,
  }) : _db = db,
       _remoteApi = remoteApi,
       _isOffline = isOffline;

  /// Returns `true` when there is no pending event left that must be sent
  /// before an ordinary visit mutation.
  Future<bool> sync() async {
    if (_isOffline()) return false;

    final owner = await _db.getCurrentUserOwner();
    final userId = owner.userId;
    if (userId == null) return true;

    final pending = await _db.getPendingWorkdayEvents(userId);
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
      if (await _wasAlreadyApplied(action!)) {
        await _db.deletePendingWorkdayEvent(id);
        return true;
      }
      await _db.recordPendingWorkdayEventFailure(id: id, error: '$error');

      // Keep the event and its successors in order for both server and
      // connectivity failures. Retrying them out of order can finish an
      // unrelated server-side workday.
      return false;
    }
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

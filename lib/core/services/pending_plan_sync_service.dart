import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'package:lima/core/db/local_database.dart';
import 'package:lima/core/network/remote_api_service.dart';
import 'package:lima/core/utils/swallowed.dart';

/// Drains locally queued planned visits without owning sync screen state.
///
/// Retryable failures use backoff; malformed/permanently rejected rows are
/// parked with diagnostics instead of being deleted silently.
class PendingPlanSyncService {
  static const maxAttempts = 10;

  final LocalDatabase _db;
  final RemoteApiService _remoteApi;
  final bool Function() _isOffline;

  const PendingPlanSyncService({
    required LocalDatabase db,
    required RemoteApiService remoteApi,
    required bool Function() isOffline,
  }) : _db = db,
       _remoteApi = remoteApi,
       _isOffline = isOffline;

  Future<void> sync() async {
    final pending = await _db.getPendingPlans(readyOnly: true);
    debugPrint(
      '[PLAN PUSH] pending_plan_sync: offline=${_isOffline()} '
      'pending=${pending.length}',
    );
    if (_isOffline() || pending.isEmpty) return;

    for (final row in pending) {
      await _syncRow(row);
    }
  }

  Future<void> _syncRow(Map<String, dynamic> row) async {
    final pendingId = (row['id'] as num?)?.toInt();
    final localPlanId = (row['local_plan_id'] as num?)?.toInt();
    final orgId = (row['org_id'] as num?)?.toInt();
    final visitFormatId = (row['visit_format_id'] as num?)?.toInt();
    final startDateRaw = row['start_date'] as String?;
    final endDateRaw = row['end_date'] as String?;

    if (pendingId == null ||
        localPlanId == null ||
        orgId == null ||
        visitFormatId == null ||
        startDateRaw == null) {
      if (pendingId != null) {
        await _db.recordPendingPlanFailure(
          id: pendingId,
          error: 'Invalid queued plan payload',
          status: 'parked',
          parkedAt: DateTime.now(),
        );
      }
      return;
    }

    final doctorIds = parseDoctorIds(row['doctor_ids_json'] as String?);

    try {
      final response = await _remoteApi.pushPlannedVisit(
        organizationId: orgId,
        doctorIds: doctorIds,
        visitFormatId: visitFormatId,
        startDate: DateTime.parse(startDateRaw),
        endDate: endDateRaw != null ? DateTime.tryParse(endDateRaw) : null,
        comment: row['comment'] as String?,
      );
      final data = response['response'];
      final remoteId = remoteIdFrom(data);
      if (remoteId != null) {
        final rawJson = data is Map
            ? Map<String, dynamic>.from(data)
            : <String, dynamic>{};
        rawJson.putIfAbsent('doctor_ids', () => doctorIds);
        rawJson.putIfAbsent('visit_format_id', () => visitFormatId);
        await _db.setPlannedVisitRemoteId(
          localId: localPlanId,
          remoteId: remoteId,
          rawJson: rawJson,
        );
      }
      await _db.deletePendingPlan(pendingId);
    } catch (error) {
      final httpStatus = error is RemotePushException
          ? (error.response['status'] as num?)?.toInt()
          : null;
      final retryable4xx =
          httpStatus == 401 ||
          httpStatus == 403 ||
          httpStatus == 408 ||
          httpStatus == 429;
      final permanent =
          httpStatus != null &&
          httpStatus >= 400 &&
          httpStatus < 500 &&
          !retryable4xx;
      final attempts = ((row['attempts'] as num?)?.toInt() ?? 0) + 1;
      final shouldPark = permanent || attempts >= maxAttempts;
      final now = DateTime.now();
      await _db.recordPendingPlanFailure(
        id: pendingId,
        error: '$error',
        status: shouldPark ? 'parked' : 'retryScheduled',
        nextRetryAt: shouldPark ? null : now.add(_backoff(attempts)),
        parkedAt: shouldPark ? now : null,
        httpStatus: httpStatus,
      );
    }
  }

  static Duration _backoff(int attempts) => switch (attempts) {
    1 => const Duration(minutes: 1),
    2 => const Duration(minutes: 5),
    3 => const Duration(minutes: 30),
    _ => const Duration(hours: 1),
  };

  @visibleForTesting
  static List<int> parseDoctorIds(String? raw) {
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded
            .map((item) => item is num ? item.toInt() : int.tryParse('$item'))
            .whereType<int>()
            .toList();
      }
    } catch (error) {
      logSwallowed(error, 'PendingPlanSyncService.parseDoctorIds');
    }
    return const [];
  }

  @visibleForTesting
  static int? remoteIdFrom(Object? data) {
    if (data is num) return data.toInt();
    if (data is String) return int.tryParse(data);
    if (data is! Map) return null;
    return (data['id'] as num?)?.toInt() ??
        (data['plan_id'] as num?)?.toInt() ??
        (data['visit_id'] as num?)?.toInt() ??
        remoteIdFrom(data['data']) ??
        remoteIdFrom(data['result']);
  }
}

import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'package:lima/core/db/local_database.dart';
import 'package:lima/core/network/remote_api_service.dart';
import 'package:lima/core/utils/swallowed.dart';

/// Drains locally queued planned visits without owning sync screen state.
///
/// A malformed or rejected (4xx) queue row is removed because retrying it
/// cannot make the payload valid. Network and 5xx failures stay queued for a
/// later reconcile.
class PendingPlanSyncService {
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
    final pending = await _db.getPendingPlans();
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
      if (pendingId != null) await _db.deletePendingPlan(pendingId);
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
        await _db.setPlannedVisitRemoteId(
          localId: localPlanId,
          remoteId: remoteId,
          rawJson: data is Map ? Map<String, dynamic>.from(data) : null,
        );
      }
      await _db.deletePendingPlan(pendingId);
    } catch (error) {
      if (error is RemotePushException) {
        final status = error.response['status'];
        if (status is int && status >= 400 && status < 500) {
          await _db.deletePendingPlan(pendingId);
        }
      }
      // Network and server failures remain queued for the next reconcile.
    }
  }

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
    if (data is! Map) return null;
    return (data['id'] as num?)?.toInt() ??
        (data['plan_id'] as num?)?.toInt() ??
        (data['visit_id'] as num?)?.toInt();
  }
}

import 'dart:convert';

import 'package:lima/core/db/local_database.dart';
import 'package:lima/core/models/local_visit.dart';
import 'package:lima/core/network/remote_api_service.dart';
import 'package:lima/core/utils/swallowed.dart';

class PendingVisitPushFailure {
  final String type;
  final int? id;
  final String message;
  final bool queueFailure;

  const PendingVisitPushFailure({
    required this.type,
    required this.message,
    this.id,
    this.queueFailure = false,
  });
}

class PendingVisitPushResult {
  final List<int> syncedIds;
  final List<int> parkedIds;
  final List<PendingVisitPushFailure> failures;
  final List<Map<String, dynamic>> responses;
  final int remaining;
  final DateTime pushedAt;

  const PendingVisitPushResult({
    required this.syncedIds,
    required this.parkedIds,
    required this.failures,
    required this.responses,
    required this.remaining,
    required this.pushedAt,
  });

  bool get hasFailures => failures.any((failure) => !failure.queueFailure);
}

/// Sends locally stored visits and owns retry/backoff/parking persistence.
///
/// No UI state or notifications belong here. The caller decides how visit
/// results should be combined with other mutation queues and displayed.
class PendingVisitPushService {
  static const int maxPushAttempts = 8;

  final LocalDatabase _db;
  final RemoteApiService _remoteApi;

  const PendingVisitPushService({
    required LocalDatabase db,
    required RemoteApiService remoteApi,
  }) : _db = db,
       _remoteApi = remoteApi;

  Future<PendingVisitPushResult> sync() async {
    final failures = <PendingVisitPushFailure>[];
    final syncedIds = <int>[];
    final parkedIds = <int>[];
    final responses = <Map<String, dynamic>>[];

    try {
      final repaired = await _db.repairLegacyVisitDrugPayloads();
      if (repaired > 0) {
        logSwallowed(
          'repaired $repaired legacy visit(s)',
          'PendingVisitPushService.repair',
        );
      }
    } catch (error) {
      failures.add(
        PendingVisitPushFailure(
          type: 'repair',
          message: _errorMessage(error),
          queueFailure: true,
        ),
      );
    }

    final unsyncedRows = await _db.getVisits(
      unsyncedOnly: true,
      dueForRetryOnly: true,
    );
    for (final row in unsyncedRows) {
      await _syncRow(
        row,
        syncedIds: syncedIds,
        parkedIds: parkedIds,
        failures: failures,
        responses: responses,
      );
    }

    if (syncedIds.isNotEmpty) {
      await _db.markSynced(syncedIds);
    }
    final pushedAt = DateTime.now();
    await _db.setSyncMeta('last_push_at', pushedAt.toIso8601String());

    return PendingVisitPushResult(
      syncedIds: syncedIds,
      parkedIds: parkedIds,
      failures: failures,
      responses: responses,
      remaining: await _db.unsyncedCount(),
      pushedAt: pushedAt,
    );
  }

  Future<void> _syncRow(
    Map<String, dynamic> row, {
    required List<int> syncedIds,
    required List<int> parkedIds,
    required List<PendingVisitPushFailure> failures,
    required List<Map<String, dynamic>> responses,
  }) async {
    late final LocalVisit visit;
    try {
      visit = LocalVisit.fromMap(row);
    } catch (error) {
      final rawId = row['id'];
      failures.add(
        PendingVisitPushFailure(
          type: 'visit_parse',
          id: rawId is num ? rawId.toInt() : null,
          message: _errorMessage(error),
          queueFailure: true,
        ),
      );
      return;
    }

    try {
      final response = await _remoteApi.pushUnsyncedVisitDebug(visit);
      responses.add({'visit_id': visit.id, ...response});
      if (visit.id != null) {
        await _db.setVisitPushPayload(
          visitId: visit.id!,
          requestJson: jsonEncode(response['request']),
          responseJson: jsonEncode(response['response']),
        );
        syncedIds.add(visit.id!);
      }
    } catch (error) {
      final visitId = visit.id;
      if (visitId != null && isPermanentVisitPushFailure(error)) {
        await _parkVisit(
          visitId,
          error,
          parkedIds: parkedIds,
          failures: failures,
          responses: responses,
          message: 'отклонён сервером, не отправлен — требует внимания',
        );
        return;
      }

      final requestJson = error is RemotePushException
          ? jsonEncode(error.request)
          : null;
      final responseJson = error is RemotePushException
          ? jsonEncode(error.response)
          : jsonEncode({'error': '$error'});
      if (visitId != null) {
        await _db.setVisitPushPayload(
          visitId: visitId,
          requestJson: requestJson,
          responseJson: responseJson,
        );
        final attempts = await _db.recordVisitPushFailure(visitId);
        if (attempts >= maxPushAttempts) {
          await _parkVisit(
            visitId,
            error,
            parkedIds: parkedIds,
            failures: failures,
            responses: responses,
            message: 'не отправлен после $attempts попыток — требует внимания',
          );
          return;
        }
      }

      failures.add(
        PendingVisitPushFailure(
          type: 'visit',
          id: visitId,
          message: 'visit#${visitId ?? '-'}: ${_errorMessage(error)}',
        ),
      );
      responses.add({
        'visit_id': visitId,
        'ok': false,
        if (error is RemotePushException) 'request': error.request,
        if (error is RemotePushException) 'response': error.response,
        'error': '$error',
      });
    }
  }

  Future<void> _parkVisit(
    int visitId,
    Object error, {
    required List<int> parkedIds,
    required List<PendingVisitPushFailure> failures,
    required List<Map<String, dynamic>> responses,
    required String message,
  }) async {
    if (error is RemotePushException) {
      await _db.setVisitPushPayload(
        visitId: visitId,
        requestJson: jsonEncode(error.request),
        responseJson: jsonEncode(error.response),
      );
    } else {
      await _db.setVisitPushPayload(
        visitId: visitId,
        responseJson: jsonEncode({'error': '$error'}),
      );
    }
    await _db.markVisitPushFailedPermanently(visitId);
    parkedIds.add(visitId);
    failures.add(
      PendingVisitPushFailure(
        type: 'visit',
        id: visitId,
        message: 'visit#$visitId: $message',
      ),
    );
    responses.add({
      'visit_id': visitId,
      'ok': false,
      'parked': true,
      'error': _errorMessage(error),
    });
  }

  static String _errorMessage(Object error) {
    if (error is RemotePushException) return error.displayMessage;
    return '$error';
  }
}

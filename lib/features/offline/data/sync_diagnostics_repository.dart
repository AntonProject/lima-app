import 'dart:convert';

import '../../../core/db/local_database.dart';
import '../../../core/models/local_visit.dart';
import '../../../core/utils/swallowed.dart';
import '../domain/entities/sync_data_change.dart';
import '../domain/entities/sync_queue_records.dart';
import '../domain/repositories/sync_diagnostics_repository.dart';

/// Data access for the sync/diagnostics screen: unsynced/failed queues and
/// local table totals. Keeps the raw SQL out of the widget layer.
class SyncDiagnosticsRepositoryImpl implements SyncDiagnosticsRepository {
  final LocalDatabase _db;

  SyncDiagnosticsRepositoryImpl(this._db);

  /// Broadcast of table names touched by local writes — lets screens refresh
  /// without polling (mirrors LocalDatabase.changes).
  @override
  Stream<SyncDataChange> get changes =>
      _db.changes.map(SyncDataChange.fromStorageTables);

  Future<List<Map<String, dynamic>>> _getVisits({
    bool? unsyncedOnly,
    bool dueForRetryOnly = false,
  }) => _db.getVisits(
    unsyncedOnly: unsyncedOnly,
    dueForRetryOnly: dueForRetryOnly,
  );

  /// Typed variant of [getVisits]. Rows that fail to parse are silently
  /// dropped — callers that need the raw shape should use [getVisits].
  @override
  Future<List<LocalVisit>> getVisitModels({
    bool? unsyncedOnly,
    bool dueForRetryOnly = false,
  }) async {
    final rows = await _getVisits(
      unsyncedOnly: unsyncedOnly,
      dueForRetryOnly: dueForRetryOnly,
    );
    return _parseVisits(rows);
  }

  Future<List<Map<String, dynamic>>> _getFailedVisits() =>
      _db.getFailedVisits();

  /// Typed variant of [getFailedVisits].
  @override
  Future<List<LocalVisit>> getFailedVisitModels() async {
    final rows = await _getFailedVisits();
    return _parseVisits(rows);
  }

  /// Converts the persisted API error payload into text suitable for the UI.
  /// The screen should not know that the diagnostics response is stored as
  /// JSON in SQLite.
  @override
  String failedVisitMessage(LocalVisit visit, {required String fallback}) =>
      extractFailureMessage(visit.lastPushResponseJson, fallback: fallback);

  static String extractFailureMessage(String? raw, {required String fallback}) {
    if (raw == null || raw.isEmpty) return fallback;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        final message =
            decoded['error'] ??
            decoded['message'] ??
            decoded['detail'] ??
            decoded['title'];
        if (message != null && message.toString().trim().isNotEmpty) {
          return message.toString();
        }
      }
      return raw;
    } catch (_) {
      return raw;
    }
  }

  static List<LocalVisit> _parseVisits(List<Map<String, dynamic>> rows) {
    final result = <LocalVisit>[];
    for (final row in rows) {
      try {
        result.add(LocalVisit.fromMap(row));
    } catch (error) {
      logSwallowed(error, 'SyncDiagnosticsRepository.parseVisit');
    }
    }
    return result;
  }

  @override
  Future<void> retryFailedVisit(int id) => _db.retryFailedVisit(id);

  @override
  Future<void> deleteVisit(int id) => _db.deleteVisit(id);

  @override
  Future<int> deleteLegacyTestVisits() => _db.deleteLegacyTestVisits();

  @override
  Future<List<PendingOrganisationUpdateRecord>> getPendingOrgUpdates() async {
    final rows = await _db.getPendingOrgUpdates();
    return rows
        .map(PendingOrganisationUpdateRecord.fromMap)
        .toList(growable: false);
  }

  @override
  Future<List<PendingDoctorRecord>> getPendingDoctors() async {
    final rows = await _db.getPendingDoctors();
    return rows.map(PendingDoctorRecord.fromMap).toList(growable: false);
  }

  @override
  Future<List<PendingDoctorRecord>> getFailedPendingDoctors() async {
    final rows = await _db.getFailedPendingDoctors();
    return rows.map(PendingDoctorRecord.fromMap).toList(growable: false);
  }

  @override
  Future<void> deletePendingDoctor(int id) => _db.deletePendingDoctor(id);

  /// Row counts per local table shown as the offline-data summary.
  @override
  Future<SyncLocalTotals> getLocalTotals() async {
    return SyncLocalTotals.fromMap(await _db.getLocalTotals());
  }
}

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/local_database.dart';

/// Data access for the sync/diagnostics screen: unsynced/failed queues and
/// local table totals. Keeps the raw SQL out of the widget layer.
class SyncDiagnosticsRepository {
  final LocalDatabase _db;

  SyncDiagnosticsRepository(this._db);

  /// Broadcast of table names touched by local writes — lets screens refresh
  /// without polling (mirrors LocalDatabase.changes).
  Stream<Set<String>> get changes => _db.changes;

  Future<List<Map<String, dynamic>>> getVisits({
    bool? unsyncedOnly,
    bool dueForRetryOnly = false,
  }) => _db.getVisits(
    unsyncedOnly: unsyncedOnly,
    dueForRetryOnly: dueForRetryOnly,
  );

  Future<List<Map<String, dynamic>>> getFailedVisits() => _db.getFailedVisits();

  Future<void> retryFailedVisit(int id) => _db.retryFailedVisit(id);

  Future<void> deleteVisit(int id) => _db.deleteVisit(id);

  Future<int> deleteLegacyTestVisits() => _db.deleteLegacyTestVisits();

  Future<List<Map<String, dynamic>>> getPendingOrgUpdates() =>
      _db.getPendingOrgUpdates();

  Future<List<Map<String, dynamic>>> getPendingDoctors() =>
      _db.getPendingDoctors();

  Future<List<Map<String, dynamic>>> getFailedPendingDoctors() =>
      _db.getFailedPendingDoctors();

  Future<void> deletePendingDoctor(int id) => _db.deletePendingDoctor(id);

  /// Row counts per local table shown as the offline-data summary.
  Future<Map<String, int>> getLocalTotals() async {
    Future<int> count(String sql) async {
      final rows = await _db.db.rawQuery(sql);
      if (rows.isEmpty) return 0;
      return (rows.first['c'] as num?)?.toInt() ?? 0;
    }

    return {
      'organizations': await count('SELECT COUNT(*) AS c FROM organisations'),
      'lpu': await count(
        "SELECT COUNT(*) AS c FROM organisations WHERE type = 'lpu'",
      ),
      'pharmacy': await count(
        "SELECT COUNT(*) AS c FROM organisations WHERE type = 'pharmacy'",
      ),
      'distributor': await count(
        "SELECT COUNT(*) AS c FROM organisations WHERE type = 'distributor'",
      ),
      'doctors': await count('SELECT COUNT(*) AS c FROM doctors'),
      'visits': await count('SELECT COUNT(*) AS c FROM visits'),
      'drugs': await count('SELECT COUNT(*) AS c FROM drugs'),
      'materials': await count('SELECT COUNT(*) AS c FROM drug_materials'),
    };
  }
}

final syncDiagnosticsRepositoryProvider = Provider<SyncDiagnosticsRepository>((
  ref,
) {
  return SyncDiagnosticsRepository(ref.watch(localDatabaseProvider));
});

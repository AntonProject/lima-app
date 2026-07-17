import 'package:sqflite/sqflite.dart';

import 'package:lima/core/db/local_database.dart';

/// Typed local counts used by sync state and diagnostics UI.
class SyncLocalTotals {
  final int organizations;
  final int lpu;
  final int pharmacy;
  final int distributor;
  final int otherOrganizations;
  final int doctors;
  final int visits;
  final int plannedVisits;
  final int drugs;
  final int materials;

  const SyncLocalTotals({
    required this.organizations,
    required this.lpu,
    required this.pharmacy,
    required this.distributor,
    required this.otherOrganizations,
    required this.doctors,
    required this.visits,
    required this.plannedVisits,
    required this.drugs,
    required this.materials,
  });
}

/// Keeps table names and bootstrap checks out of the sync notifier.
class SyncDiagnosticsService {
  final LocalDatabase _db;

  const SyncDiagnosticsService({required LocalDatabase db}) : _db = db;

  Future<SyncLocalTotals> collectLocalTotals() async {
    final counts = await _db.getLocalTotals();
    final organizations = counts['organizations'] ?? 0;
    final lpu = counts['lpu'] ?? 0;
    final pharmacy = counts['pharmacy'] ?? 0;
    final distributor = counts['distributor'] ?? 0;
    return SyncLocalTotals(
      organizations: organizations,
      lpu: lpu,
      pharmacy: pharmacy,
      distributor: distributor,
      otherOrganizations: organizations - lpu - pharmacy - distributor,
      doctors: counts['doctors'] ?? 0,
      visits: counts['visits'] ?? 0,
      plannedVisits: counts['plannedVisits'] ?? 0,
      drugs: counts['drugs'] ?? 0,
      materials: counts['materials'] ?? 0,
    );
  }

  Future<int> doctorLinksCount() async {
    final rows = await _db.db.rawQuery(
      'SELECT COUNT(*) AS c FROM doctor_organisations',
    );
    return Sqflite.firstIntValue(rows) ?? 0;
  }

  Future<bool> hasBaseDirectory({
    required SyncLocalTotals totals,
    required String bootstrapKey,
    required int minimumLpu,
    required int minimumPharmacy,
  }) async {
    if (totals.lpu < minimumLpu || totals.pharmacy < minimumPharmacy) {
      return false;
    }
    return await _db.getSyncMeta(bootstrapKey) == '1';
  }
}

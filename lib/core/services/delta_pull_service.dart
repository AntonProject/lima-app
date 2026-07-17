import 'package:flutter/foundation.dart';

import 'package:lima/core/db/local_database.dart';
import 'package:lima/core/network/remote_api_service.dart';

class DeltaPullResult {
  final int lastSyncIdBefore;
  final int lastSyncIdAfter;
  final int organizationsCount;
  final List<Map<String, dynamic>> organizations;
  final int doctorsCount;
  final int drugsCount;

  const DeltaPullResult({
    required this.lastSyncIdBefore,
    required this.lastSyncIdAfter,
    required this.organizationsCount,
    required this.organizations,
    required this.doctorsCount,
    required this.drugsCount,
  });
}

/// Pulls dictionary rows after the locally stored sync cursor.
///
/// SQLite is updated and the cursor advances only after all selected layers
/// have been written successfully. A failed remote request returns null so
/// the caller can decide whether to fall back to a full refresh.
class DeltaPullService {
  final LocalDatabase _db;
  final RemoteApiService _remoteApi;

  const DeltaPullService({
    required LocalDatabase db,
    required RemoteApiService remoteApi,
  }) : _db = db,
       _remoteApi = remoteApi;

  Future<DeltaPullResult?> pull({bool includeDoctors = true}) async {
    final syncId = await _effectiveSyncId();
    try {
      final orgs = await _remoteApi.getOrganizationsSync(
        syncId: syncId > 0 ? syncId : null,
      );
      final doctors = includeDoctors
          ? await _remoteApi.getDoctorsSync(syncId: syncId > 0 ? syncId : null)
          : const <Map<String, dynamic>>[];
      final relations = includeDoctors
          ? await _remoteApi.getDoctorOrganisationRelations(syncId: syncId)
          : const <Map<String, dynamic>>[];
      final drugs = await _remoteApi.getDrugsSync(syncId: syncId);

      await _db.upsertOrganisations(orgs);
      await _db.upsertDoctorOrganisationLinks(relations);
      await _db.upsertDoctors(doctors);
      await _db.upsertDrugs(drugs);

      final maxSyncId =
          [
            ...orgs.map((row) => row['sync_id'] as int?),
            ...doctors.map((row) => row['sync_id'] as int?),
            ...relations.map((row) => row['sync_id'] as int?),
            ...drugs.map((row) => row['sync_id'] as int?),
          ].whereType<int>().fold<int>(syncId, (previous, value) {
            return value > previous ? value : previous;
          });
      if (maxSyncId > 0) {
        await _db.setSyncMeta('last_sync_id', '$maxSyncId');
      }

      return DeltaPullResult(
        lastSyncIdBefore: syncId,
        lastSyncIdAfter: maxSyncId > 0 ? maxSyncId : syncId,
        organizationsCount: orgs.length,
        organizations: orgs,
        doctorsCount: doctors.length,
        drugsCount: drugs.length,
      );
    } catch (_) {
      return null;
    }
  }

  Future<int> _effectiveSyncId() async {
    final stored =
        int.tryParse(await _db.getSyncMeta('last_sync_id') ?? '') ?? 0;
    final local = await _db.getMaxLocalSyncId();
    return effectiveSyncId(stored: stored, local: local);
  }

  @visibleForTesting
  static int effectiveSyncId({required int stored, required int local}) {
    return stored > local ? stored : local;
  }
}

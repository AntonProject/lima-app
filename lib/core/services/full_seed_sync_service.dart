import 'package:lima/core/db/local_database.dart';
import 'package:lima/core/i18n/app_i18n.dart';
import 'package:lima/core/network/remote_api_service.dart';

/// Fetches the initial remote snapshot and persists it without touching local
/// rows that still belong to the offline mutation queue.
class FullSeedSyncService {
  final LocalDatabase _db;
  final RemoteApiService _remoteApi;

  const FullSeedSyncService({
    required LocalDatabase db,
    required RemoteApiService remoteApi,
  }) : _db = db,
       _remoteApi = remoteApi;

  Future<RemoteSeedBundle> fetchAndReplace({
    int? regionId,
    int? companyId,
    bool includeDoctors = true,
    void Function(String message, {int? current, int? total})? onProgress,
  }) async {
    final seed = await _remoteApi.fetchOfflineSeed(
      regionId: regionId,
      companyId: companyId,
      includeDoctors: includeDoctors,
      onProgress: onProgress,
    );
    final localTotals = await _db.getLocalTotals();
    if (seed.orgs.isEmpty) {
      throw StateError(
        (localTotals['organizations'] ?? 0) > 0
            ? AppI18n.tr('syncEmptyOrgsKept')
            : AppI18n.tr('syncEmptyOrgsEmpty'),
      );
    }

    await _db.replaceRemoteSnapshotPreservingUnsynced(
      orgs: seed.orgs,
      doctors: seed.doctors,
      doctorOrgLinks: seed.doctorOrgLinks,
      replaceDoctors: includeDoctors,
      drugs: seed.drugs,
      materials: seed.materials,
      visits: seed.visits,
      plannedVisits: seed.plannedVisits,
      favOrgIds: seed.favOrgIds,
      managers: seed.managers,
      dayTypes: seed.dayTypes,
      dailyStats: seed.dailyStats,
    );
    return seed;
  }
}

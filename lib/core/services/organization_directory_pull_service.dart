import 'package:lima/core/db/local_database.dart';
import 'package:lima/core/network/remote_api_service.dart';

/// Pulls the organization directory for the layered sync flow.
///
/// The caller decides whether a full dictionary or cursor-based delta is
/// required. This service owns only the API-to-SQLite write boundary.
class OrganizationDirectoryPullService {
  final LocalDatabase _db;
  final RemoteApiService _remoteApi;

  const OrganizationDirectoryPullService({
    required LocalDatabase db,
    required RemoteApiService remoteApi,
  }) : _db = db,
       _remoteApi = remoteApi;

  Future<List<Map<String, dynamic>>> pull({
    required bool full,
    required int syncId,
  }) async {
    final organizations = full
        ? await _remoteApi.getOrganizationsDictionary()
        : await _remoteApi.getOrganizationsSync(
            syncId: syncId > 0 ? syncId : null,
          );
    if (organizations.isNotEmpty) {
      await _db.upsertOrganisations(organizations);
    }
    return organizations;
  }
}

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/local_database.dart';
import '../../../core/network/api_client.dart';
import '../../../core/services/material_cache_service.dart';

/// Drug catalogue + materials. Owned by the knowledge feature, but visit
/// screens (orders, detailing, фармкружок) read the same local drug list
/// through this repository too.
class DrugsRepository {
  final LocalDatabase _db;
  final ApiClient _apiClient;

  DrugsRepository(this._db, this._apiClient);

  Future<List<Map<String, dynamic>>> getDrugs({
    String? query,
    bool onlyWithPositivePrice = true,
    bool onlyWithDocuments = false,
  }) => _db.getDrugs(
    query: query,
    onlyWithPositivePrice: onlyWithPositivePrice,
    onlyWithDocuments: onlyWithDocuments,
  );

  Future<List<Map<String, dynamic>>> getDrugMaterials(int drugId) =>
      _db.getDrugMaterials(drugId);

  /// Deletes downloaded material files, cached_path pointers and cached
  /// dashboard stats — the "clear cache" action in the profile.
  Future<void> clearMaterialsCache() async {
    final cacheService = MaterialCacheService(
      dio: _apiClient.dio,
      authToken: _apiClient.token,
    );
    await cacheService.clearCache(_db);
    await _db.clearCachedStats();
  }
}

final drugsRepositoryProvider = Provider<DrugsRepository>((ref) {
  return DrugsRepository(
    ref.watch(localDatabaseProvider),
    ref.watch(apiClientProvider),
  );
});

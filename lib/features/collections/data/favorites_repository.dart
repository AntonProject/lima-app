import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/db/local_database.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/remote_api_service.dart';

class FavoritesRepository {
  final LocalDatabase _db;
  final RemoteApiService _api;
  final SharedPreferences _prefs;

  FavoritesRepository(this._db, this._api, this._prefs);

  static const _key = 'favorite_pharmacy_ids';

  Set<int> readLocal() => (_prefs.getStringList(_key) ?? const [])
      .map(int.tryParse)
      .whereType<int>()
      .toSet();

  Future<void> persist(Set<int> ids) =>
      _prefs.setStringList(_key, ids.map((id) => '$id').toList());

  Future<void> setOrgFavoriteLocal(int orgId, bool value) =>
      _db.updateOrgFavorite(orgId, value);

  Future<void> clearOrgFavoritesLocal() => _db.clearOrgFavorites();

  Future<List<Map<String, dynamic>>> getRemote({
    bool allowDictionaryFallback = true,
  }) => _api.getFavoriteOrganizations(
    allowDictionaryFallback: allowDictionaryFallback,
  );

  Future<void> addRemote(int orgId) => _api.addOrganizationToFavorites(orgId);

  Future<void> removeRemote(int orgId) =>
      _api.removeOrganizationFromFavorites(orgId);

  Future<void> enqueuePending({
    required String entityType,
    required int entityId,
    required bool add,
  }) =>
      _db.enqueueFavorite(entityType: entityType, entityId: entityId, add: add);

  Future<List<Map<String, dynamic>>> getFavoriteOrgsLocal({String? type}) =>
      _db.getFavoriteOrgs(type: type);

  // ── Doctor favorites ────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getFavoriteDoctorsLocal() =>
      _db.getFavoriteDoctors();

  Future<int> getFavoriteDoctorsCount() => _db.getFavoriteDoctorsCount();

  Future<int> setDoctorFavoriteLocal(int doctorId, bool value) =>
      _db.updateDoctorFavorite(doctorId, value);

  Future<void> addDoctorRemote(int doctorId) =>
      _api.addDoctorToFavorites(doctorId);

  Future<void> removeDoctorRemote(int doctorId) =>
      _api.removeDoctorFromFavorites(doctorId);
}

final favoritesRepositoryProvider = Provider<FavoritesRepository>((ref) {
  return FavoritesRepository(
    ref.watch(localDatabaseProvider),
    ref.watch(remoteApiServiceProvider),
    ref.watch(sharedPreferencesProvider),
  );
});

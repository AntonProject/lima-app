import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/db/local_database.dart';
import '../../../core/models/models.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/remote_api_service.dart';
import '../domain/repositories/favorites_repository.dart';

class FavoritesRepositoryImpl implements FavoritesRepository {
  final LocalDatabase _db;
  final RemoteApiService _api;
  final SharedPreferences _prefs;

  FavoritesRepositoryImpl(this._db, this._api, this._prefs);

  static const _key = 'favorite_pharmacy_ids';

  @override
  Set<int> readLocal() => (_prefs.getStringList(_key) ?? const [])
      .map(int.tryParse)
      .whereType<int>()
      .toSet();

  @override
  Future<void> persist(Set<int> ids) =>
      _prefs.setStringList(_key, ids.map((id) => '$id').toList());

  @override
  Future<void> setOrgFavoriteLocal(int orgId, bool value) =>
      _db.updateOrgFavorite(orgId, value);

  @override
  Future<void> clearOrgFavoritesLocal() => _db.clearOrgFavorites();

  Future<List<Map<String, dynamic>>> getRemote({
    bool allowDictionaryFallback = true,
  }) => _api.getFavoriteOrganizations(
    allowDictionaryFallback: allowDictionaryFallback,
  );

  @override
  Future<Set<int>> getRemoteFavoriteOrgIds({
    bool allowDictionaryFallback = true,
  }) async {
    final rows = await getRemote(
      allowDictionaryFallback: allowDictionaryFallback,
    );
    return rows.map((row) => row['id']).whereType<int>().toSet();
  }

  @override
  Future<void> addRemote(int orgId) => _api.addOrganizationToFavorites(orgId);

  @override
  Future<void> removeRemote(int orgId) =>
      _api.removeOrganizationFromFavorites(orgId);

  @override
  Future<void> enqueuePending({
    required String entityType,
    required int entityId,
    required bool add,
  }) =>
      _db.enqueueFavorite(entityType: entityType, entityId: entityId, add: add);

  Future<List<Map<String, dynamic>>> getFavoriteOrgsLocal({String? type}) =>
      _db.getFavoriteOrgs(type: type);

  /// Typed variant of [getFavoriteOrgsLocal]. Rows that fail to parse
  /// (missing id) are silently dropped.
  @override
  Future<List<Organisation>> getFavoriteOrgModelsLocal({String? type}) async {
    final rows = await getFavoriteOrgsLocal(type: type);
    return rows.map(Organisation.fromJson).toList();
  }

  // ── Doctor favorites ────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getFavoriteDoctorsLocal() =>
      _db.getFavoriteDoctors();

  @override
  Future<List<Doctor>> getFavoriteDoctorModels() async {
    final rows = await getFavoriteDoctorsLocal();
    return rows.map(Doctor.fromJson).toList(growable: false);
  }

  @override
  Future<int> getFavoriteDoctorsCount() => _db.getFavoriteDoctorsCount();

  @override
  Future<int> setDoctorFavoriteLocal(int doctorId, bool value) =>
      _db.updateDoctorFavorite(doctorId, value);

  @override
  Future<void> addDoctorRemote(int doctorId) =>
      _api.addDoctorToFavorites(doctorId);

  @override
  Future<void> removeDoctorRemote(int doctorId) =>
      _api.removeDoctorFromFavorites(doctorId);
}

final favoritesRepositoryProvider = Provider<FavoritesRepositoryImpl>((ref) {
  return FavoritesRepositoryImpl(
    ref.watch(localDatabaseProvider),
    ref.watch(remoteApiServiceProvider),
    ref.watch(sharedPreferencesProvider),
  );
});

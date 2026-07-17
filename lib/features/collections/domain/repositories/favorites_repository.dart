import '../../../../core/models/models.dart';

abstract interface class FavoritesRepository {
  Set<int> readLocal();

  Future<void> persist(Set<int> ids);

  Future<void> setOrgFavoriteLocal(int orgId, bool value);

  Future<void> clearOrgFavoritesLocal();

  Future<Set<int>> getRemoteFavoriteOrgIds({
    bool allowDictionaryFallback = true,
  });

  Future<void> addRemote(int orgId);

  Future<void> removeRemote(int orgId);

  Future<void> enqueuePending({
    required String entityType,
    required int entityId,
    required bool add,
  });

  Future<List<Organisation>> getFavoriteOrgModelsLocal({String? type});

  Future<List<Doctor>> getFavoriteDoctorModels();

  Future<int> getFavoriteDoctorsCount();

  Future<int> setDoctorFavoriteLocal(int doctorId, bool value);

  Future<void> addDoctorRemote(int doctorId);

  Future<void> removeDoctorRemote(int doctorId);
}

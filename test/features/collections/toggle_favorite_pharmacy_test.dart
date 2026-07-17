import 'package:flutter_test/flutter_test.dart';
import 'package:lima/core/models/models.dart';
import 'package:lima/features/collections/domain/repositories/favorites_repository.dart';
import 'package:lima/features/collections/domain/use_cases/toggle_favorite_pharmacy.dart';

void main() {
  test('applies a favorite mutation when the API accepts it', () async {
    final repository = _FakeFavorites();
    final result = await ToggleFavoritePharmacy(repository)(
      pharmacyId: 10,
      currentlyFavorite: false,
      isOffline: false,
    );

    expect(result.isFavorite, isTrue);
    expect(result.queued, isFalse);
    expect(repository.localValue, isTrue);
    expect(repository.remoteAdds, 1);
  });

  test('queues the local mutation while offline', () async {
    final repository = _FakeFavorites()..remoteError = StateError('offline');
    final result = await ToggleFavoritePharmacy(repository)(
      pharmacyId: 10,
      currentlyFavorite: false,
      isOffline: true,
    );

    expect(result.isFavorite, isTrue);
    expect(result.queued, isTrue);
    expect(repository.queued, isTrue);
  });

  test('rolls back when a reachable API rejects the mutation', () async {
    final repository = _FakeFavorites()..remoteError = StateError('rejected');
    final result = await ToggleFavoritePharmacy(repository)(
      pharmacyId: 10,
      currentlyFavorite: false,
      isOffline: false,
    );

    expect(result.isFavorite, isFalse);
    expect(result.queued, isFalse);
    expect(repository.localValue, isFalse);
  });
}

class _FakeFavorites implements FavoritesRepository {
  bool localValue = false;
  bool queued = false;
  int remoteAdds = 0;
  Object? remoteError;

  @override
  Set<int> readLocal() => const {};

  @override
  Future<void> persist(Set<int> ids) async {}

  @override
  Future<void> setOrgFavoriteLocal(int orgId, bool value) async {
    localValue = value;
  }

  @override
  Future<void> clearOrgFavoritesLocal() async {}

  @override
  Future<Set<int>> getRemoteFavoriteOrgIds({
    bool allowDictionaryFallback = true,
  }) async => const {};

  @override
  Future<void> addRemote(int orgId) async {
    remoteAdds++;
    if (remoteError != null) throw remoteError!;
  }

  @override
  Future<void> removeRemote(int orgId) async {
    if (remoteError != null) throw remoteError!;
  }

  @override
  Future<void> enqueuePending({
    required String entityType,
    required int entityId,
    required bool add,
  }) async {
    queued = true;
  }

  @override
  Future<List<Organisation>> getFavoriteOrgModelsLocal({String? type}) async =>
      const [];

  @override
  Future<List<Doctor>> getFavoriteDoctorModels() async => const [];

  @override
  Future<int> getFavoriteDoctorsCount() async => 0;

  @override
  Future<int> setDoctorFavoriteLocal(int doctorId, bool value) async => 0;

  @override
  Future<void> addDoctorRemote(int doctorId) async {}

  @override
  Future<void> removeDoctorRemote(int doctorId) async {}
}

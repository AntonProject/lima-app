import '../repositories/favorites_repository.dart';

class FavoriteMutationResult {
  final bool isFavorite;
  final bool queued;

  const FavoriteMutationResult({
    required this.isFavorite,
    required this.queued,
  });
}

class ToggleFavoritePharmacy {
  final FavoritesRepository _repository;

  const ToggleFavoritePharmacy(this._repository);

  Future<FavoriteMutationResult> call({
    required int pharmacyId,
    required bool currentlyFavorite,
    required bool isOffline,
  }) async {
    final desired = !currentlyFavorite;
    await _repository.setOrgFavoriteLocal(pharmacyId, desired);
    try {
      if (desired) {
        await _repository.addRemote(pharmacyId);
      } else {
        await _repository.removeRemote(pharmacyId);
      }
      return FavoriteMutationResult(isFavorite: desired, queued: false);
    } catch (error) {
      if (isOffline) {
        try {
          await _repository.enqueuePending(
            entityType: 'pharmacy',
            entityId: pharmacyId,
            add: desired,
          );
          return FavoriteMutationResult(isFavorite: desired, queued: true);
        } catch (_) {
          await _repository.setOrgFavoriteLocal(pharmacyId, currentlyFavorite);
          return FavoriteMutationResult(
            isFavorite: currentlyFavorite,
            queued: false,
          );
        }
      }
      await _repository.setOrgFavoriteLocal(pharmacyId, currentlyFavorite);
      return FavoriteMutationResult(
        isFavorite: currentlyFavorite,
        queued: false,
      );
    }
  }
}

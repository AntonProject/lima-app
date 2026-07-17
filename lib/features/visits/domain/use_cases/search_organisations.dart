import 'package:lima/core/models/models.dart';

import '../repositories/organisations_directory_repository.dart';

/// Searches the remote directory and merges the result into the local source
/// of truth so a result remains available after the search response expires.
class SearchOrganisations {
  final OrganisationsDirectoryRepository _repository;

  const SearchOrganisations(this._repository);

  Future<List<Organisation>> call({
    required String query,
    required bool isLpu,
    required bool allRegions,
  }) async {
    final results = await _repository.searchModels(
      query: query,
      typeIds: isLpu ? const [2] : const [1],
      global: allRegions,
    );
    if (results.isNotEmpty) {
      await _repository.upsertLocalModels(results);
    }
    return results;
  }
}

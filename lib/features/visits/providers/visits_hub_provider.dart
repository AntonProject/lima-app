import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/organisations_repository.dart';
import '../domain/repositories/organisations_directory_repository.dart';
import '../domain/use_cases/search_organisations.dart';
import '../presentation/view_models/visits_hub_view_model.dart';
import '../../auth/providers/auth_provider.dart';

final organisationsDirectoryRepositoryProvider =
    Provider<OrganisationsDirectoryRepository>((ref) {
      return ref.watch(organisationsRepositoryProvider);
    });

final searchOrganisationsProvider = Provider<SearchOrganisations>((ref) {
  return SearchOrganisations(
    ref.watch(organisationsDirectoryRepositoryProvider),
  );
});

final visitsHubViewModelProvider =
    StateNotifierProvider.autoDispose<VisitsHubViewModel, VisitsHubViewState>((
      ref,
    ) {
      final auth = ref.watch(authProvider);
      return VisitsHubViewModel(
        ref.watch(organisationsDirectoryRepositoryProvider),
        auth.user,
        searchOrganisations: ref.watch(searchOrganisationsProvider),
      );
    });

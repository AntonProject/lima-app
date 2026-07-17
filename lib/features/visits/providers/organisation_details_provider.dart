import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../presentation/view_models/organisation_details_view_model.dart';
import 'visits_hub_provider.dart';

final organisationDetailsViewModelProvider = StateNotifierProvider.autoDispose
    .family<OrganisationDetailsViewModel, OrganisationDetailsViewState, int>(
      (ref, organisationId) => OrganisationDetailsViewModel(
        ref.watch(organisationsDirectoryRepositoryProvider),
        organisationId,
      ),
    );

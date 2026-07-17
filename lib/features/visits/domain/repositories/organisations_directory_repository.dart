import 'package:lima/core/models/models.dart';
import 'package:lima/features/offline/domain/entities/sync_data_change.dart';

import '../entities/organisation_draft.dart';

/// Local-first directory contract used by the visits catalogue.
///
/// The presentation layer receives typed organisations and never needs to know
/// whether a search result came from SQLite or the remote directory.
abstract interface class OrganisationsDirectoryRepository {
  Stream<SyncDataChange> get changes;

  Future<List<Organisation>> getLocalModels({String? type});

  Future<Organisation?> getModelById(int id);

  Future<List<Organisation>> searchModels({
    required String query,
    List<int>? typeIds,
    bool global = false,
  });

  Future<void> upsertLocalModels(List<Organisation> organisations);

  Future<List<OrganisationArea>> getAreas(int regionId);

  Future<void> insertLocalOrganisation(Organisation organisation);

  Future<int?> createRemoteOrganisation(OrganisationDraft draft);

  Future<void> replaceOrganisationTempId(int tempId, int remoteId);

  Future<void> enqueueNewOrganisation({
    required int tempLocalId,
    required OrganisationDraft draft,
  });

  Future<void> updateLocalOrganisation(OrganisationUpdateDraft draft);

  Future<void> updateRemoteOrganisation(OrganisationUpdateDraft draft);

  Future<void> enqueueOrganisationUpdate(OrganisationUpdateDraft draft);
}

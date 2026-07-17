import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/local_database.dart';
import '../../../core/models/models.dart';
import '../../../core/network/remote_api_service.dart';
import '../../offline/domain/entities/sync_data_change.dart';
import '../domain/entities/organisation_draft.dart';
import '../domain/repositories/organisations_directory_repository.dart';

class OrganisationsRepositoryImpl implements OrganisationsDirectoryRepository {
  final LocalDatabase _db;
  final RemoteApiService _api;

  OrganisationsRepositoryImpl(this._db, this._api);

  /// Broadcast of table names touched by local writes — lets screens refresh
  /// without polling (mirrors LocalDatabase.changes).
  @override
  Stream<SyncDataChange> get changes =>
      _db.changes.map(SyncDataChange.fromStorageTables);

  @override
  Future<List<Organisation>> getLocalModels({String? type}) async {
    final rows = await _db.getOrganisations(type: type);
    return rows.map(Organisation.fromJson).toList();
  }

  @override
  Future<List<Organisation>> searchModels({
    required String query,
    List<int>? typeIds,
    bool global = false,
  }) async {
    final rows = await _api.searchOrganizations(
      query: query,
      typeIds: typeIds,
      global: global,
    );
    return rows.map(Organisation.fromJson).toList(growable: false);
  }

  @override
  Future<void> upsertLocalModels(List<Organisation> organisations) => _db
      .upsertOrganisations(organisations.map((item) => item.toJson()).toList());

  @override
  Future<void> insertLocalOrganisation(Organisation organisation) =>
      _db.insertLocalOrganisation(organisation.toJson());

  @override
  Future<int?> createRemoteOrganisation(OrganisationDraft draft) =>
      _api.createOrganization(
        name: draft.name,
        inn: draft.inn,
        typeId: draft.typeId,
        regionId: draft.regionId,
        areaId: draft.areaId,
        phone: draft.phone,
        phone2: draft.phone2,
        phone3: draft.phone3,
        address: draft.address,
        categoryId: draft.categoryId,
        healthCareFacilityTypeId: draft.healthCareFacilityTypeId,
        revisionStatus: draft.revisionStatus,
        responsiblePerson: draft.responsible,
        latitude: draft.latitude,
        longitude: draft.longitude,
      );

  @override
  Future<void> replaceOrganisationTempId(int tempId, int remoteId) =>
      _db.replaceOrganizationTempId(tempId, remoteId);

  @override
  Future<void> enqueueNewOrganisation({
    required int tempLocalId,
    required OrganisationDraft draft,
  }) => _db.enqueuePendingOrganization(
    tempLocalId: tempLocalId,
    name: draft.name,
    inn: draft.inn,
    typeId: draft.typeId,
    regionId: draft.regionId,
    areaId: draft.areaId,
    phone: draft.phone,
    phone2: draft.phone2,
    phone3: draft.phone3,
    address: draft.address,
    categoryId: draft.categoryId,
    healthCareFacilityTypeId: draft.healthCareFacilityTypeId,
    revisionStatus: draft.revisionStatus,
    responsible: draft.responsible,
    latitude: draft.latitude,
    longitude: draft.longitude,
  );

  @override
  Future<void> updateLocalOrganisation(OrganisationUpdateDraft draft) =>
      _db.updateOrganisation(
        id: draft.organisationId,
        name: draft.name,
        address: draft.address,
        city: draft.city,
        district: draft.district,
        inn: draft.inn,
        category: draft.category,
        responsible: draft.responsible,
        phone: draft.phone,
        latitude: draft.latitude,
        longitude: draft.longitude,
        updatedAt: DateTime.now().toIso8601String(),
      );

  @override
  Future<void> updateRemoteOrganisation(OrganisationUpdateDraft draft) async {
    await _api.updateOrganization(
      organizationId: draft.organisationId,
      name: draft.name,
      address: draft.address,
      phone: draft.phone,
      city: draft.city,
      district: draft.district,
      inn: draft.inn,
      category: draft.category,
      responsiblePerson: draft.responsible,
      latitude: draft.latitude,
      longitude: draft.longitude,
    );
  }

  @override
  Future<void> enqueueOrganisationUpdate(OrganisationUpdateDraft draft) =>
      _db.enqueuePendingOrgUpdate(
        orgId: draft.organisationId,
        name: draft.name,
        address: draft.address,
        phone: draft.phone,
        city: draft.city,
        district: draft.district,
        inn: draft.inn,
        category: draft.category,
        responsible: draft.responsible,
        latitude: draft.latitude,
        longitude: draft.longitude,
      );

  @override
  Future<Organisation?> getModelById(int id) async {
    final row = await _db.getOrganisationById(id);
    return row == null ? null : Organisation.fromJson(row);
  }

  /// Districts (areas) of a region for the create/edit-organisation forms.
  @override
  Future<List<OrganisationArea>> getAreas(int regionId) async {
    final rows = await _api.getAreas(regionId);
    return rows
        .map(
          (row) => OrganisationArea(
            id: row['id'] as int,
            name: row['name'] as String,
            latitude: (row['latitude'] as num?)?.toDouble(),
            longitude: (row['longitude'] as num?)?.toDouble(),
          ),
        )
        .toList(growable: false);
  }
}

final organisationsRepositoryProvider = Provider<OrganisationsRepositoryImpl>((
  ref,
) {
  return OrganisationsRepositoryImpl(
    ref.watch(localDatabaseProvider),
    ref.watch(remoteApiServiceProvider),
  );
});

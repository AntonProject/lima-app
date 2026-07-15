import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/local_database.dart';
import '../../../core/network/remote_api_service.dart';

class OrganisationsRepository {
  final LocalDatabase _db;
  final RemoteApiService _api;

  OrganisationsRepository(this._db, this._api);

  /// Broadcast of table names touched by local writes — lets screens refresh
  /// without polling (mirrors LocalDatabase.changes).
  Stream<Set<String>> get changes => _db.changes;

  Future<List<Map<String, dynamic>>> getLocal({String? type}) =>
      _db.getOrganisations(type: type);

  Future<Map<String, dynamic>?> getById(int id) => _db.getOrganisationById(id);

  Future<void> upsertLocal(List<Map<String, dynamic>> orgs) =>
      _db.upsertOrganisations(orgs);

  Future<void> updateLocal({
    required int id,
    String? name,
    String? address,
    String? city,
    String? district,
    String? inn,
    String? category,
    String? responsible,
    String? phone,
    double? latitude,
    double? longitude,
    String? updatedAt,
    String? rawJson,
  }) => _db.updateOrganisation(
    id: id,
    name: name,
    address: address,
    city: city,
    district: district,
    inn: inn,
    category: category,
    responsible: responsible,
    phone: phone,
    latitude: latitude,
    longitude: longitude,
    updatedAt: updatedAt,
    rawJson: rawJson,
  );

  Future<void> insertLocal(Map<String, dynamic> row) =>
      _db.insertLocalOrganisation(row);

  Future<void> replaceTempId(int tempId, int remoteId) =>
      _db.replaceOrganizationTempId(tempId, remoteId);

  // ── Offline queues ──────────────────────────────────────────────────────

  Future<void> enqueuePendingOrgUpdate({
    required int orgId,
    required String name,
    required String address,
    String? phone,
    String? city,
    String? district,
    String? inn,
    String? category,
    String? responsible,
    double? latitude,
    double? longitude,
  }) => _db.enqueuePendingOrgUpdate(
    orgId: orgId,
    name: name,
    address: address,
    phone: phone,
    city: city,
    district: district,
    inn: inn,
    category: category,
    responsible: responsible,
    latitude: latitude,
    longitude: longitude,
  );

  Future<void> enqueuePendingOrganization({
    required int tempLocalId,
    required String name,
    required String inn,
    required int typeId,
    required int regionId,
    int? areaId,
    String? phone,
    String? phone2,
    String? phone3,
    String? address,
    int? categoryId,
    int? healthCareFacilityTypeId,
    String? revisionStatus,
    String? responsible,
    double? latitude,
    double? longitude,
  }) => _db.enqueuePendingOrganization(
    tempLocalId: tempLocalId,
    name: name,
    inn: inn,
    typeId: typeId,
    regionId: regionId,
    areaId: areaId,
    phone: phone,
    phone2: phone2,
    phone3: phone3,
    address: address,
    categoryId: categoryId,
    healthCareFacilityTypeId: healthCareFacilityTypeId,
    revisionStatus: revisionStatus,
    responsible: responsible,
    latitude: latitude,
    longitude: longitude,
  );

  // ── Remote ──────────────────────────────────────────────────────────────

  /// Districts (areas) of a region for the create/edit-organisation forms.
  Future<List<Map<String, dynamic>>> getAreas(int regionId) =>
      _api.getAreas(regionId);

  Future<List<Map<String, dynamic>>> search({
    required String query,
    List<int>? typeIds,
    bool global = false,
  }) =>
      _api.searchOrganizations(query: query, typeIds: typeIds, global: global);

  Future<Map<String, dynamic>> updateRemote({
    required int organizationId,
    required String name,
    required String address,
    String? phone,
    String? city,
    String? district,
    String? inn,
    String? category,
    String? responsiblePerson,
    double? latitude,
    double? longitude,
  }) => _api.updateOrganization(
    organizationId: organizationId,
    name: name,
    address: address,
    phone: phone,
    city: city,
    district: district,
    inn: inn,
    category: category,
    responsiblePerson: responsiblePerson,
    latitude: latitude,
    longitude: longitude,
  );

  Future<int?> createRemote({
    required String name,
    required String inn,
    required int typeId,
    required int regionId,
    int? areaId,
    String? phone,
    String? phone2,
    String? phone3,
    String? address,
    int? categoryId,
    int? healthCareFacilityTypeId,
    String? revisionStatus,
    String? responsiblePerson,
    double? latitude,
    double? longitude,
  }) => _api.createOrganization(
    name: name,
    inn: inn,
    typeId: typeId,
    regionId: regionId,
    areaId: areaId,
    phone: phone,
    phone2: phone2,
    phone3: phone3,
    address: address,
    categoryId: categoryId,
    healthCareFacilityTypeId: healthCareFacilityTypeId,
    revisionStatus: revisionStatus,
    responsiblePerson: responsiblePerson,
    latitude: latitude,
    longitude: longitude,
  );
}

final organisationsRepositoryProvider = Provider<OrganisationsRepository>((
  ref,
) {
  return OrganisationsRepository(
    ref.watch(localDatabaseProvider),
    ref.watch(remoteApiServiceProvider),
  );
});

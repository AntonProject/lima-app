import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/local_database.dart';
import '../../../core/network/remote_api_service.dart';

class DoctorsRepository {
  final LocalDatabase _db;
  final RemoteApiService _api;

  DoctorsRepository(this._db, this._api);

  Future<List<Map<String, dynamic>>> getDoctors({
    int? orgId,
    String? query,
    bool includeGlobalFallback = true,
  }) => _db.getDoctors(
    orgId: orgId,
    query: query,
    includeGlobalFallback: includeGlobalFallback,
  );

  Future<Map<String, dynamic>?> getById(int id) => _db.getDoctorById(id);

  Future<int?> getPrimaryOrgId(int doctorId) =>
      _db.getPrimaryOrgIdForDoctor(doctorId);

  Future<Map<int, int>> getVisitCountsByDoctorIds(List<int> doctorIds) =>
      _db.getVisitCountsByDoctorIds(doctorIds);

  Future<int> insertLocal(Map<String, dynamic> doctor) =>
      _db.insertDoctor(doctor);

  Future<void> upsertLocal(List<Map<String, dynamic>> doctors) =>
      _db.upsertDoctors(doctors);

  Future<void> upsertOrganisationLinks(List<Map<String, dynamic>> links) =>
      _db.upsertDoctorOrganisationLinks(links);

  Future<void> replaceTempId(int tempId, int remoteId) =>
      _db.replaceDoctorTempId(tempId, remoteId);

  Future<void> enqueuePending({
    required int tempLocalId,
    required int orgId,
    required String fullName,
    required String specialty,
    int? specializationId,
    String? phone,
    String? hobby,
    String? interests,
    String? birthday,
  }) => _db.enqueuePendingDoctor(
    tempLocalId: tempLocalId,
    orgId: orgId,
    fullName: fullName,
    specialty: specialty,
    specializationId: specializationId,
    phone: phone,
    hobby: hobby,
    interests: interests,
    birthday: birthday,
  );

  // ── Remote ──────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getByOrganizationRemote(int orgId) =>
      _api.getDoctorsByOrganization(orgId);

  Future<int?> addRemote({
    required int organizationId,
    required String fullName,
    required int specializationId,
    String? phone,
    String? hobby,
    String? interests,
    String? birthday,
  }) => _api.addDoctor(
    organizationId: organizationId,
    fullName: fullName,
    specializationId: specializationId,
    phone: phone,
    hobby: hobby,
    interests: interests,
    birthday: birthday,
  );

  Future<void> markVisitedRemote({
    required int doctorId,
    int? organizationId,
    int? visitId,
  }) => _api.markDoctorVisited(
    doctorId: doctorId,
    organizationId: organizationId,
    visitId: visitId,
  );
}

final doctorsRepositoryProvider = Provider<DoctorsRepository>((ref) {
  return DoctorsRepository(
    ref.watch(localDatabaseProvider),
    ref.watch(remoteApiServiceProvider),
  );
});

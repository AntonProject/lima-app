import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/local_database.dart';
import '../../../core/models/models.dart';
import '../../../core/network/remote_api_service.dart';
import '../domain/repositories/doctors_directory_repository.dart';
import '../domain/entities/doctor_draft.dart';

class DoctorsRepositoryImpl implements DoctorsDirectoryRepository {
  final LocalDatabase _db;
  final RemoteApiService _api;

  DoctorsRepositoryImpl(this._db, this._api);

  @override
  Future<List<Doctor>> getDoctorModels({
    int? orgId,
    String? query,
    bool includeGlobalFallback = true,
  }) async {
    final rows = await _db.getDoctors(
      orgId: orgId,
      query: query,
      includeGlobalFallback: includeGlobalFallback,
    );
    return rows.map(Doctor.fromJson).toList();
  }

  @override
  Future<List<Doctor>> getByOrganizationRemoteModels(int orgId) async {
    final rows = await _api.getDoctorsByOrganization(orgId);
    return rows.map(Doctor.fromJson).toList(growable: false);
  }

  @override
  Future<void> upsertDoctorModels(List<Doctor> doctors) =>
      _db.upsertDoctors(doctors.map((doctor) => doctor.toJson()).toList());

  @override
  Future<void> upsertDoctorModel(Doctor doctor) => upsertDoctorModels([doctor]);

  @override
  Future<void> insertLocalDoctor(Doctor doctor) =>
      _db.insertDoctor(doctor.toJson());

  @override
  Future<int?> createRemoteDoctor(DoctorDraft draft) => _api.addDoctor(
    organizationId: draft.organizationId,
    fullName: draft.fullName,
    specializationId: draft.specializationId,
    phone: draft.phone,
    hobby: draft.hobby,
    interests: draft.interests,
    birthday: draft.birthday,
  );

  @override
  Future<void> replaceDoctorTempId(int tempId, int remoteId) =>
      _db.replaceDoctorTempId(tempId, remoteId);

  @override
  Future<void> enqueueNewDoctor({
    required int tempLocalId,
    required DoctorDraft draft,
  }) => _db.enqueuePendingDoctor(
    tempLocalId: tempLocalId,
    orgId: draft.organizationId,
    fullName: draft.fullName,
    specialty: draft.specialty,
    specializationId: draft.specializationId,
    phone: draft.phone,
    hobby: draft.hobby,
    interests: draft.interests,
    birthday: draft.birthday,
  );

  @override
  Future<void> upsertOrganisationLinksFor({
    required int organizationId,
    required List<int> doctorIds,
  }) => _db.upsertDoctorOrganisationLinks(
    doctorIds
        .map(
          (doctorId) => <String, dynamic>{
            'doctor_id': doctorId,
            'organisation_id': organizationId,
          },
        )
        .toList(),
  );

  @override
  Future<void> markVisited({
    required int doctorId,
    int? organizationId,
    int? visitId,
  }) => _api.markDoctorVisited(
    doctorId: doctorId,
    organizationId: organizationId,
    visitId: visitId,
  );

  @override
  Future<Doctor?> getDoctorModel(int id) async {
    final row = await _db.getDoctorById(id);
    return row == null ? null : Doctor.fromJson(row);
  }

  @override
  Future<int?> getPrimaryOrgId(int doctorId) =>
      _db.getPrimaryOrgIdForDoctor(doctorId);

  @override
  Future<Map<int, int>> getVisitCountsByDoctorIds(List<int> doctorIds) =>
      _db.getVisitCountsByDoctorIds(doctorIds);
}

final doctorsRepositoryProvider = Provider<DoctorsRepositoryImpl>((ref) {
  return DoctorsRepositoryImpl(
    ref.watch(localDatabaseProvider),
    ref.watch(remoteApiServiceProvider),
  );
});

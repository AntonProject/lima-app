import 'package:lima/core/models/models.dart';

import '../entities/doctor_draft.dart';

/// Typed doctor-directory contract shared by LPU details and visit creation.
abstract interface class DoctorsDirectoryRepository {
  Future<List<Doctor>> getDoctorModels({
    int? orgId,
    String? query,
    bool includeGlobalFallback = true,
  });

  Future<Doctor?> getDoctorModel(int id);

  Future<int?> getPrimaryOrgId(int doctorId);

  Future<Map<int, int>> getVisitCountsByDoctorIds(List<int> doctorIds);

  Future<List<Doctor>> getByOrganizationRemoteModels(int orgId);

  Future<void> upsertDoctorModels(List<Doctor> doctors);

  Future<void> upsertDoctorModel(Doctor doctor);

  Future<void> insertLocalDoctor(Doctor doctor);

  Future<int?> createRemoteDoctor(DoctorDraft draft);

  Future<void> replaceDoctorTempId(int tempId, int remoteId);

  Future<void> enqueueNewDoctor({
    required int tempLocalId,
    required DoctorDraft draft,
  });

  Future<void> upsertOrganisationLinksFor({
    required int organizationId,
    required List<int> doctorIds,
  });

  Future<void> markVisited({
    required int doctorId,
    int? organizationId,
    int? visitId,
  });
}

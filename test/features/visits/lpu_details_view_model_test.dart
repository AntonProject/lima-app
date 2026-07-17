import 'package:flutter_test/flutter_test.dart';
import 'package:lima/core/models/models.dart';
import 'package:lima/features/visits/domain/entities/doctor_draft.dart';
import 'package:lima/features/visits/domain/repositories/doctors_directory_repository.dart';
import 'package:lima/features/visits/presentation/view_models/lpu_details_view_model.dart';

class _FakeDoctorsDirectoryRepository implements DoctorsDirectoryRepository {
  final List<Doctor> localDoctors;
  final List<Doctor> remoteDoctors;
  final Map<int, int> visitCounts;
  int remoteCalls = 0;

  _FakeDoctorsDirectoryRepository({
    this.localDoctors = const [],
    this.remoteDoctors = const [],
    this.visitCounts = const {},
  });

  @override
  Future<List<Doctor>> getDoctorModels({
    int? orgId,
    String? query,
    bool includeGlobalFallback = true,
  }) async => localDoctors;

  @override
  Future<Doctor?> getDoctorModel(int id) async {
    for (final doctor in [...localDoctors, ...remoteDoctors]) {
      if (doctor.id == id) return doctor;
    }
    return null;
  }

  @override
  Future<int?> getPrimaryOrgId(int doctorId) async => localDoctors
      .followedBy(remoteDoctors)
      .where((doctor) => doctor.id == doctorId)
      .map((doctor) => doctor.organisationId)
      .firstOrNull;

  @override
  Future<Map<int, int>> getVisitCountsByDoctorIds(List<int> doctorIds) async =>
      {
        for (final id in doctorIds)
          if (visitCounts.containsKey(id)) id: visitCounts[id]!,
      };

  @override
  Future<List<Doctor>> getByOrganizationRemoteModels(int orgId) async {
    remoteCalls++;
    return remoteDoctors;
  }

  @override
  Future<void> upsertDoctorModels(List<Doctor> doctors) async {
    localDoctors
      ..clear()
      ..addAll(doctors);
  }

  @override
  Future<void> upsertDoctorModel(Doctor doctor) async {
    await upsertDoctorModels([doctor]);
  }

  @override
  Future<void> insertLocalDoctor(Doctor doctor) async {
    await upsertDoctorModel(doctor);
  }

  @override
  Future<int?> createRemoteDoctor(DoctorDraft draft) async => null;

  @override
  Future<void> replaceDoctorTempId(int tempId, int remoteId) async {}

  @override
  Future<void> enqueueNewDoctor({
    required int tempLocalId,
    required DoctorDraft draft,
  }) async {}

  @override
  Future<void> upsertOrganisationLinksFor({
    required int organizationId,
    required List<int> doctorIds,
  }) async {}

  @override
  Future<void> markVisited({
    required int doctorId,
    int? organizationId,
    int? visitId,
  }) async {}
}

const _localDoctor = Doctor(
  id: 1,
  fullName: 'Local Doctor',
  organisationId: 458,
);

const _remoteDoctor = Doctor(
  id: 2,
  fullName: 'Remote Doctor',
  organisationId: 458,
);

void main() {
  test(
    'shares one repaired doctor list and visit counts across LPU flows',
    () async {
      final repository = _FakeDoctorsDirectoryRepository(
        localDoctors: [_localDoctor],
        remoteDoctors: [_localDoctor, _remoteDoctor],
        visitCounts: const {1: 2},
      );
      final viewModel = LpuDetailsViewModel(repository, 458);
      addTearDown(viewModel.dispose);

      await viewModel.load();
      await viewModel.load();

      expect(repository.remoteCalls, 1);
      expect(viewModel.state.doctors.map((doctor) => doctor.id), [1, 2]);
      expect(viewModel.state.visitCounts[1], 2);
      expect(viewModel.state.visitedDoctorIds, {1});
    },
  );

  test('updates favorite in the shared state without replacing the doctor', () {
    final viewModel = LpuDetailsViewModel(
      _FakeDoctorsDirectoryRepository(localDoctors: [_localDoctor]),
      458,
    );
    addTearDown(viewModel.dispose);

    viewModel.state = const LpuDetailsViewState(doctors: [_localDoctor]);
    viewModel.setDoctorFavorite(1, true);

    expect(viewModel.state.doctors.single.isFavorite, isTrue);
    expect(viewModel.state.doctors.single.fullName, 'Local Doctor');
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:lima/core/models/models.dart';
import 'package:lima/features/knowledge/domain/repositories/knowledge_repository.dart';
import 'package:lima/features/visits/domain/entities/doctor_draft.dart';
import 'package:lima/features/visits/domain/entities/visit_interaction.dart';
import 'package:lima/features/visits/domain/repositories/doctors_directory_repository.dart';
import 'package:lima/features/visits/presentation/view_models/lpu_detailing_view_model.dart';

class _FakeDoctorsRepository implements DoctorsDirectoryRepository {
  _FakeDoctorsRepository(this.doctors);

  final List<Doctor> doctors;

  @override
  Future<List<Doctor>> getDoctorModels({
    int? orgId,
    String? query,
    bool includeGlobalFallback = true,
  }) async => doctors;

  @override
  Future<List<Doctor>> getByOrganizationRemoteModels(int orgId) async =>
      doctors;

  @override
  Future<Doctor?> getDoctorModel(int id) async =>
      doctors.where((doctor) => doctor.id == id).firstOrNull;

  @override
  Future<int?> getPrimaryOrgId(int doctorId) async => null;

  @override
  Future<Map<int, int>> getVisitCountsByDoctorIds(List<int> doctorIds) async =>
      {};

  @override
  Future<void> upsertDoctorModels(List<Doctor> doctors) async {}

  @override
  Future<void> upsertDoctorModel(Doctor doctor) async {}

  @override
  Future<void> insertLocalDoctor(Doctor doctor) async {}

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

class _FakeKnowledgeRepository implements KnowledgeRepository {
  _FakeKnowledgeRepository(this.drugs);

  final List<Drug> drugs;

  @override
  Future<List<Drug>> getKnowledgeDrugs({
    String? query,
    bool onlyWithPositivePrice = true,
    bool onlyWithDocuments = false,
  }) async => drugs;

  @override
  Future<Drug?> getDrugModel(
    int drugId, {
    bool onlyWithPositivePrice = false,
  }) async => drugs.where((drug) => drug.id == drugId).firstOrNull;

  @override
  Future<List<DrugMaterial>> getDrugMaterialModels(int drugId) async => [];

  @override
  Future<void> clearMaterialsCache() async {}
}

const _doctor = Doctor(id: 7, fullName: 'Доктор ЛПУ', organisationId: 458);

const _lpuDrug = Drug(id: 1, name: 'Сириус', manufacturer: 'LIMA', price: 10);
const _otherDrug = Drug(
  id: 2,
  name: 'Адамант',
  manufacturer: 'Other',
  price: 20,
);

void main() {
  test('loads one immutable source for doctors and detailing drugs', () async {
    final viewModel = LpuDetailingViewModel(
      _FakeDoctorsRepository(const [_doctor]),
      _FakeKnowledgeRepository(const [_otherDrug, _lpuDrug]),
    );
    addTearDown(viewModel.dispose);

    await viewModel.load(organizationId: 458, doctorIds: const [7]);

    expect(viewModel.state.doctors, [same(_doctor)]);
    expect(viewModel.state.drugs.map((drug) => drug.name), [
      'Адамант',
      'Сириус',
    ]);
    expect(viewModel.state.drugByName['сириус'], same(_lpuDrug));
    expect(viewModel.state.isLoading, isFalse);
  });

  test(
    'query and status changes create new state without mutating old state',
    () async {
      final viewModel = LpuDetailingViewModel(
        _FakeDoctorsRepository(const [_doctor]),
        _FakeKnowledgeRepository(const [_lpuDrug, _otherDrug]),
      );
      addTearDown(viewModel.dispose);

      await viewModel.load(organizationId: 458, doctorIds: const [7]);
      final initial = viewModel.state;
      viewModel.setQuery('сири');
      viewModel.setStatus('Сириус', DrugStatus.familiarPrescribes);
      viewModel.lockAction();

      expect(initial.query, isEmpty);
      expect(initial.statuses, isEmpty);
      expect(initial.isActionLocked, isFalse);
      expect(viewModel.state.filteredDrugs.map((drug) => drug.name), [
        'Сириус',
      ]);
      expect(viewModel.state.statuses['Сириус'], DrugStatus.familiarPrescribes);
      expect(viewModel.state.isActionLocked, isTrue);
    },
  );
}

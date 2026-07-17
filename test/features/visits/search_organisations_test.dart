import 'package:flutter_test/flutter_test.dart';
import 'package:lima/core/models/models.dart';
import 'package:lima/features/offline/domain/entities/sync_data_change.dart';
import 'package:lima/features/visits/domain/entities/organisation_draft.dart';
import 'package:lima/features/visits/domain/repositories/organisations_directory_repository.dart';
import 'package:lima/features/visits/domain/use_cases/search_organisations.dart';

void main() {
  test(
    'searches the selected organisation type and caches the result',
    () async {
      final repository = _FakeDirectoryRepository();
      final useCase = SearchOrganisations(repository);

      final results = await useCase(
        query: 'hospital',
        isLpu: true,
        allRegions: false,
      );

      expect(results, hasLength(1));
      expect(repository.lastQuery, 'hospital');
      expect(repository.lastTypeIds, [2]);
      expect(repository.lastGlobal, isFalse);
      expect(repository.cached, results);
    },
  );

  test(
    'does not write an empty remote response to the local catalogue',
    () async {
      final repository = _FakeDirectoryRepository(result: const []);
      final useCase = SearchOrganisations(repository);

      await useCase(query: 'missing', isLpu: false, allRegions: true);

      expect(repository.lastTypeIds, [1]);
      expect(repository.lastGlobal, isTrue);
      expect(repository.upsertCalls, 0);
    },
  );
}

class _FakeDirectoryRepository implements OrganisationsDirectoryRepository {
  final List<Organisation> result;
  String? lastQuery;
  List<int>? lastTypeIds;
  bool? lastGlobal;
  List<Organisation> cached = const [];
  int upsertCalls = 0;

  _FakeDirectoryRepository({this.result = const [_result]});

  static const _result = Organisation(
    id: 42,
    name: 'Hospital',
    address: 'Address',
    type: OrgType.lpu,
  );

  @override
  Stream<SyncDataChange> get changes => const Stream.empty();

  @override
  Future<List<Organisation>> getLocalModels({String? type}) async => result;

  @override
  Future<Organisation?> getModelById(int id) async =>
      result.where((organisation) => organisation.id == id).firstOrNull;

  @override
  Future<List<Organisation>> searchModels({
    required String query,
    List<int>? typeIds,
    bool global = false,
  }) async {
    lastQuery = query;
    lastTypeIds = typeIds;
    lastGlobal = global;
    return result;
  }

  @override
  Future<void> upsertLocalModels(List<Organisation> organisations) async {
    upsertCalls++;
    cached = organisations;
  }

  @override
  Future<List<OrganisationArea>> getAreas(int regionId) async => const [];

  @override
  Future<void> insertLocalOrganisation(Organisation organisation) async {}

  @override
  Future<int?> createRemoteOrganisation(OrganisationDraft draft) async => null;

  @override
  Future<void> replaceOrganisationTempId(int tempId, int remoteId) async {}

  @override
  Future<void> enqueueNewOrganisation({
    required int tempLocalId,
    required OrganisationDraft draft,
  }) async {}

  @override
  Future<void> updateLocalOrganisation(OrganisationUpdateDraft draft) async {}

  @override
  Future<void> updateRemoteOrganisation(OrganisationUpdateDraft draft) async {}

  @override
  Future<void> enqueueOrganisationUpdate(OrganisationUpdateDraft draft) async {}
}

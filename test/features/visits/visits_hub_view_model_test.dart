import 'package:flutter_test/flutter_test.dart';
import 'package:lima/core/models/models.dart';
import 'package:lima/features/offline/domain/entities/sync_data_change.dart';
import 'package:lima/features/visits/domain/entities/organisation_draft.dart';
import 'package:lima/features/visits/domain/repositories/organisations_directory_repository.dart';
import 'package:lima/features/visits/presentation/view_models/visits_hub_view_model.dart';

class _FakeOrganisationsDirectoryRepository
    implements OrganisationsDirectoryRepository {
  final List<Organisation> lpu;
  final List<Organisation> pharmacies;

  const _FakeOrganisationsDirectoryRepository({
    this.lpu = const [],
    this.pharmacies = const [],
  });

  @override
  Stream<SyncDataChange> get changes => const Stream.empty();

  @override
  Future<List<Organisation>> getLocalModels({String? type}) async {
    return type == 'pharmacy' ? pharmacies : lpu;
  }

  @override
  Future<Organisation?> getModelById(int id) async => null;

  @override
  Future<List<Organisation>> searchModels({
    required String query,
    List<int>? typeIds,
    bool global = false,
  }) async => const [];

  @override
  Future<void> upsertLocalModels(List<Organisation> organisations) async {}

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

const _user = UserModel(
  id: 1,
  fullName: 'Anton Dev',
  role: 'mp',
  city: 'г. Ташкент',
  regionId: 1,
);

const _nearLpu = Organisation(
  id: 1,
  name: 'Near LPU',
  address: 'Near address',
  type: OrgType.lpu,
  regionId: 1,
  city: 'г. Ташкент',
  latitude: 41.3001,
  longitude: 69.3001,
);

const _farLpu = Organisation(
  id: 2,
  name: 'Far LPU',
  address: 'Far address',
  type: OrgType.lpu,
  regionId: 1,
  city: 'г. Ташкент',
  latitude: 41.32,
  longitude: 69.32,
);

const _otherRegionLpu = Organisation(
  id: 3,
  name: 'Other Region LPU',
  address: 'Other address',
  type: OrgType.lpu,
  regionId: 2,
  city: 'Самаркандская область',
  latitude: 39.65,
  longitude: 66.96,
);

const _pharmacy = Organisation(
  id: 4,
  name: 'Region Pharmacy',
  address: 'Pharmacy address',
  type: OrgType.pharmacy,
  regionId: 1,
  city: 'г. Ташкент',
);

void main() {
  test(
    'loads local directories and applies the region scope by default',
    () async {
      final viewModel = VisitsHubViewModel(
        const _FakeOrganisationsDirectoryRepository(
          lpu: [_farLpu, _otherRegionLpu, _nearLpu],
          pharmacies: [_pharmacy],
        ),
        _user,
        autoLoad: false,
      );
      addTearDown(viewModel.dispose);

      await viewModel.load();

      expect(viewModel.state.localCacheLoaded, isTrue);
      expect(viewModel.state.organisations.map((org) => org.id), [2, 1]);

      viewModel.setAllRegions(true);
      expect(viewModel.state.organisations.map((org) => org.id), [2, 1, 3]);

      viewModel.setTab(false);
      expect(viewModel.state.organisations.map((org) => org.id), [4]);
    },
  );

  test(
    'nearby mode sorts the active region without changing the source cache',
    () async {
      final viewModel = VisitsHubViewModel(
        const _FakeOrganisationsDirectoryRepository(
          lpu: [_farLpu, _otherRegionLpu, _nearLpu],
        ),
        _user,
        autoLoad: false,
      );
      addTearDown(viewModel.dispose);

      await viewModel.load();
      final hasCoordinates = await viewModel.applyNearby(
        const NearbyCoordinates(latitude: 41.3, longitude: 69.3),
      );

      expect(hasCoordinates, isTrue);
      expect(viewModel.state.nearbyMode, isTrue);
      expect(viewModel.state.organisations.map((org) => org.id), [1, 2]);
      expect(viewModel.state.lpuOrganisations, hasLength(3));

      viewModel.resetToDefault();
      expect(viewModel.state.nearbyMode, isFalse);
      expect(viewModel.state.allRegions, isFalse);
      expect(viewModel.state.organisations.map((org) => org.id), [2, 1]);
    },
  );
}

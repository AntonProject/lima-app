// Regression probes created during the 2026-09-17 review. They assert the
// corrected behavior and are included in the normal suite through
// test/regressions/app_review_regressions_test.dart.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lima/core/db/local_database.dart';
import 'package:lima/core/models/models.dart';
import 'package:lima/core/network/remote_api_service.dart';
import 'package:lima/core/providers/app_collections_provider.dart';
import 'package:lima/core/services/pending_plan_sync_service.dart';
import 'package:lima/core/services/pending_workday_sync_service.dart';
import 'package:lima/features/knowledge/domain/repositories/drug_catalogue_repository.dart';
import 'package:lima/features/visits/data/history_records_mapper.dart';
import 'package:lima/features/visits/data/mappers/pharmacy_order_draft_mapper.dart';
import 'package:lima/features/visits/domain/entities/pharmacy_order.dart';
import 'package:lima/features/visits/domain/repositories/pharmacy_order_draft_repository.dart';
import 'package:lima/features/visits/domain/repositories/pharmacy_order_repository.dart';
import 'package:lima/features/visits/domain/use_cases/submit_pharmacy_order.dart';
import 'package:lima/features/visits/presentation/view_models/pharmacy_order_view_model.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _Catalogue implements DrugCatalogueRepository {
  final List<Drug> rows;
  _Catalogue(this.rows);
  @override
  Future<List<Drug>> getOrderDrugs() async => rows;
}

class _Orders implements PharmacyOrderRepository {
  PharmacyOrderLines? sent;
  bool? alreadyCalculated;
  @override
  Future<PharmacyOrderLocation> resolveLocation({
    required bool isOffline,
  }) async => const PharmacyOrderLocation(latitude: 41.3, longitude: 69.2);

  @override
  Future<PharmacyOrderSubmission> submit({
    required int orderUserId,
    required int organizationId,
    int? plannedVisitId,
    required PharmacyOrderPricingTerms pricingTerms,
    required bool isWholesaler,
    required String orderComment,
    required PharmacyOrderLines lines,
    bool pricesAlreadyCalculated = false,
    double latitude = 0,
    double longitude = 0,
  }) async {
    sent = lines;
    alreadyCalculated = pricesAlreadyCalculated;
    return const PharmacyOrderSubmission(
      request: {},
      response: {},
      remoteId: 81,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Drafts implements PharmacyOrderDraftRepository {
  PharmacyOrderDraft? saved;
  @override
  Future<int> saveDraft(PharmacyOrderDraft draft) async {
    saved = draft;
    return 1;
  }

  @override
  Future<void> markSubmitted({
    required int localVisitId,
    required PharmacyOrderSubmission submission,
    required PharmacyOrderPricingTerms pricingTerms,
    required int prepaymentPercent,
    required int buyerType,
    required bool isWholesaler,
  }) async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Remote implements RemoteApiService {
  final List<String> workdayCalls = [];
  int? planFailureStatus;
  @override
  Future<void> startWorkday({
    required int dayTypeId,
    double latitude = 0,
    double longitude = 0,
  }) async => workdayCalls.add('start');
  @override
  Future<void> endWorkday({double latitude = 0, double longitude = 0}) async =>
      workdayCalls.add('end');
  @override
  Future<Map<String, dynamic>> pushPlannedVisit({
    required int organizationId,
    required List<int> doctorIds,
    required int visitFormatId,
    required DateTime startDate,
    DateTime? endDate,
    String? comment,
  }) async {
    if (planFailureStatus != null) {
      throw RemotePushException(
        message: 'auth or rate limit failure',
        response: {'status': planFailureStatus},
      );
    }
    return {
      'response': {'id': 91},
    };
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Drug _drug({
  int id = 5,
  double price = 100,
  int? bindingId = 5,
  int stockId = 90,
}) => Drug(
  id: id,
  name: 'Drug $id',
  manufacturer: 'TEMUR MED',
  price: price,
  stock: 100,
  currentStockId: stockId,
  bindingDrugId: bindingId,
);

PharmacyOrderViewModelConfig _config({
  bool fromCart = false,
  List<CartItemSnapshot> cart = const [],
  Map<int, Drug>? initial,
  Map<int, int> quantities = const {5: 10},
}) => PharmacyOrderViewModelConfig(
  pharmacyId: 8,
  organizationName: 'INTERFARMED',
  fromCart: fromCart,
  checkoutCartId: null,
  prepaymentPercent: 50,
  buyerType: 0,
  marginId: 22,
  contractId: 7,
  initialQuantities: quantities,
  initialDrugs: initial ?? {5: _drug(price: 130)},
  cartItems: cart,
);

const _offline = PharmacyOrderSubmitContext(
  orderUserId: 1,
  medicalRepName: 'Rep',
  userCompanyId: 2,
  organizationInn: 123,
  isOffline: true,
  comment: '',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final db = LocalDatabase();
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });
  // The source lives under docs/ and is imported by a test/ entrypoint.
  // ignore: invalid_use_of_visible_for_testing_member
  setUp(() async => db.initForTesting(inMemoryDatabasePath));
  tearDownAll(() async => db.db.close());

  test(
    'R01 confirmation preserves the calculated price used for submission',
    () async {
      final orders = _Orders();
      final vm = PharmacyOrderViewModel(
        _Catalogue([_drug(price: 100)]),
        SubmitPharmacyOrder(orders),
        _Drafts(),
        _config(),
        autoLoad: false,
      );
      addTearDown(vm.dispose);
      await vm.load();
      await vm.submitOrder(
        const PharmacyOrderSubmitContext(
          orderUserId: 1,
          medicalRepName: 'Rep',
          userCompanyId: 2,
          organizationInn: 123,
          isOffline: false,
          comment: '',
        ),
      );
      expect(orders.alreadyCalculated, isTrue);
      expect(orders.sent!.single.salePrice, 130);
    },
  );

  test(
    'R02 refreshed stock identifiers are used when checking out a cart',
    () async {
      final vm = PharmacyOrderViewModel(
        _Catalogue([_drug(stockId: 999)]),
        SubmitPharmacyOrder(_Orders()),
        _Drafts(),
        _config(
          fromCart: true,
          cart: const [
            CartItemSnapshot(
              drugId: 5,
              name: 'Drug 5',
              manufacturer: 'TEMUR MED',
              price: 100,
              quantity: 10,
              pharmacyId: 8,
              pharmacyName: 'INTERFARMED',
              stock: 100,
              currentStockId: 90,
              bindingDrugId: 5,
              prepaymentPercent: 50,
              buyerType: 0,
              contractId: 7,
            ),
          ],
        ),
        autoLoad: false,
      );
      addTearDown(vm.dispose);
      await vm.load();
      // Test-only state inspection; analyzer does not classify docs/ as tests.
      // ignore: invalid_use_of_visible_for_testing_member, invalid_use_of_protected_member
      expect(vm.state.drugs[5]!.currentStockId, 999);
      expect(vm.buildSelectedLines().lines.single.incomeDetailingId, 999);
    },
  );

  test(
    'R03 offline order preserves the selected contract in persistent payload',
    () async {
      final drafts = _Drafts();
      final vm = PharmacyOrderViewModel(
        _Catalogue([]),
        SubmitPharmacyOrder(_Orders()),
        drafts,
        _config(),
        autoLoad: false,
      );
      addTearDown(vm.dispose);
      final result = await vm.submitOrder(_offline);
      expect(result.status, PharmacyOrderSubmissionStatus.queued);
      final row = PharmacyOrderDraftMapper.toLocalVisitRow(drafts.saved!);
      final raw = jsonDecode(row['raw_json'] as String) as Map;
      expect(raw['contract_id'], 7);
    },
  );

  test('R04 invalid selected line prevents partial order submission', () async {
    final drafts = _Drafts();
    final vm = PharmacyOrderViewModel(
      _Catalogue([]),
      SubmitPharmacyOrder(_Orders()),
      drafts,
      _config(
        initial: {5: _drug(), 6: _drug(id: 6, bindingId: null)},
        quantities: const {5: 10, 6: 20},
      ),
      autoLoad: false,
    );
    addTearDown(vm.dispose);
    final result = await vm.submitOrder(_offline);
    expect(result.status, PharmacyOrderSubmissionStatus.invalidLines);
    expect(drafts.saved, isNull);
  });

  test(
    'R05 workday retry delay blocks the later end event and visit mutations',
    () async {
      await db.setCurrentUserOwner(userId: 1, login: 'a', role: 'mp');
      await db.enqueuePendingWorkdayEvent(
        userId: 1,
        action: 'start',
        dayTypeId: 1,
      );
      final first = (await db.getPendingWorkdayEvents(1)).single;
      await db.recordPendingWorkdayEventFailure(
        id: first['id'] as int,
        error: 'timeout',
        nextRetryAt: DateTime.now().add(const Duration(hours: 1)),
      );
      await db.enqueuePendingWorkdayEvent(userId: 1, action: 'end');
      final remote = _Remote();
      final drained = await PendingWorkdaySyncService(
        db: db,
        remoteApi: remote,
        isOffline: () => false,
      ).sync();
      expect(
        {'calls': remote.workdayCalls, 'drained': drained},
        {'calls': <String>[], 'drained': false},
      );
    },
  );

  for (final status in [401, 429]) {
    test(
      'R06-$status planned visit survives a retryable HTTP failure',
      () async {
        await db.enqueuePendingPlan(
          localPlanId: 1,
          orgId: 8,
          orgType: 'lpu',
          doctorIds: [3],
          visitFormatId: 1,
          visitDate: DateTime(2026, 9, 17),
        );
        await PendingPlanSyncService(
          db: db,
          remoteApi: _Remote()..planFailureStatus = status,
          isOffline: () => false,
        ).sync();
        expect(await db.getPendingPlans(), hasLength(1));
      },
    );
  }

  test('R06-400 parks a permanently rejected plan with diagnostics', () async {
    await db.enqueuePendingPlan(
      localPlanId: 1,
      orgId: 8,
      orgType: 'lpu',
      doctorIds: [3],
      visitFormatId: 1,
      visitDate: DateTime(2026, 9, 17),
    );
    await PendingPlanSyncService(
      db: db,
      remoteApi: _Remote()..planFailureStatus = 400,
      isOffline: () => false,
    ).sync();

    final row = (await db.getPendingPlans()).single;
    expect(row['status'], 'parked');
    expect(row['http_status'], 400);
    expect(row['last_error'], isNotNull);
    expect(await db.getPendingPlans(readyOnly: true), isEmpty);
  });

  test(
    'R07 a new account cannot read the previous account mutation queues',
    () async {
      await db.setCurrentUserOwner(userId: 1, login: 'a', role: 'mp');
      await db.enqueuePendingPlan(
        localPlanId: 1,
        orgId: 8,
        orgType: 'lpu',
        doctorIds: [3],
        visitFormatId: 1,
        visitDate: DateTime(2026, 9, 17),
      );
      await db.enqueuePendingOrganization(
        tempLocalId: -1,
        name: 'Account A pharmacy',
        inn: '123',
        typeId: 1,
        regionId: 2,
      );
      await db.insertVisit({
        'org_id': 8,
        'org_name': 'Account A pharmacy',
        'visit_type': 'order',
        'status': 'pending',
        'created_at': '2026-09-17T16:19:00',
        'updated_at': '2026-09-17T16:19:00',
        'raw_json': '{}',
      });
      await db.clearUserScopedData();
      await db.setCurrentUserOwner(userId: 2, login: 'b', role: 'mp');
      expect(
        {
          'plans': (await db.getPendingPlans()).length,
          'organizations': (await db.getPendingOrganizations()).length,
          'visits': (await db.getVisits()).length,
        },
        {'plans': 0, 'organizations': 0, 'visits': 0},
      );

      await db.clearUserScopedData();
      await db.setCurrentUserOwner(userId: 1, login: 'a', role: 'mp');
      expect(await db.getPendingPlans(), hasLength(1));
      expect(await db.getPendingOrganizations(), hasLength(1));
      expect(await db.getVisits(), hasLength(1));
    },
  );

  test(
    'R08 full seed retains an offline planned visit and its queue link',
    () async {
      final id = await db.insertLocalPlannedVisit({
        'org_id': 8,
        'org_name': 'Clinic',
        'org_type': 'lpu',
        'visit_date': '2026-09-17',
        'status': 'planned',
      });
      await db.enqueuePendingPlan(
        localPlanId: id,
        orgId: 8,
        orgType: 'lpu',
        doctorIds: [3],
        visitFormatId: 1,
        visitDate: DateTime(2026, 9, 17),
      );
      await db.replaceRemoteSnapshotPreservingUnsynced(
        orgs: [
          {'id': 8, 'name': 'Clinic'},
        ],
        doctors: [],
        drugs: [],
        materials: [],
        visits: [],
      );
      final pending = (await db.getPendingPlans()).single;
      expect(
        await db.db.query(
          'planned_visits',
          where: 'id = ?',
          whereArgs: [pending['local_plan_id']],
        ),
        hasLength(1),
      );
    },
  );

  test(
    'R09 full seed retains the path of an already cached material',
    () async {
      await db.upsertDrugMaterials([
        {
          'drug_id': 5,
          'title': 'Video',
          'local_path': '/files/video.mp4',
          'cached_path': '/local/offline/video.mp4',
          'file_type': 'video',
        },
      ]);
      await db.replaceRemoteSnapshotPreservingUnsynced(
        orgs: [
          {'id': 8, 'name': 'Clinic'},
        ],
        doctors: [],
        drugs: [],
        visits: [],
        materials: [
          {
            'drug_id': 5,
            'title': 'Video',
            'local_path': '/files/video.mp4',
            'file_type': 'video',
          },
        ],
      );
      final material = (await db.getDrugMaterials(5)).single;
      expect(material['cached_path'], '/local/offline/video.mp4');
    },
  );

  test('R09b full seed retains an already cached drug image', () async {
    await db.db.insert('drugs', {
      'id': 5,
      'name': 'Drug 5',
      'image_url': '/images/drug-5.png',
      'image_cached_path': '/local/offline/drug-5.png',
    });
    await db.replaceRemoteSnapshotPreservingUnsynced(
      orgs: [
        {'id': 8, 'name': 'Clinic'},
      ],
      doctors: [],
      materials: [],
      visits: [],
      drugs: [
        {'id': 5, 'name': 'Drug 5', 'image_url': '/images/drug-5.png'},
      ],
    );

    final row = (await db.db.query('drugs', where: 'id = 5')).single;
    expect(row['image_cached_path'], '/local/offline/drug-5.png');
  });

  test(
    'R10 distinct offline orders made in the same minute stay in history',
    () {
      final rows = [
        for (final id in [1, 2])
          {
            'id': id,
            'org_id': 8,
            'org_name': 'Clinic',
            'visit_type': 'order',
            'status': 'pending',
            'is_synced': 0,
            'created_at': '2026-09-17T16:19:${id == 1 ? '01' : '40'}',
            'raw_json': jsonEncode({'visit_type': 1, 'total_sum': id * 1000}),
          },
      ];
      expect(HistoryRecordsMapper.fromRows(rows), hasLength(2));
    },
  );
}

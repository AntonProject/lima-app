import 'package:flutter_test/flutter_test.dart';
import 'package:lima/core/models/client_contract.dart';
import 'package:lima/core/models/order_term_option.dart';
import 'package:lima/core/models/models.dart';
import 'package:lima/core/providers/app_collections_provider.dart';
import 'package:lima/features/knowledge/domain/repositories/drug_catalogue_repository.dart';
import 'package:lima/features/visits/domain/entities/pharmacy_order.dart';
import 'package:lima/features/visits/domain/repositories/pharmacy_order_draft_repository.dart';
import 'package:lima/features/visits/domain/repositories/pharmacy_order_repository.dart';
import 'package:lima/features/visits/domain/use_cases/submit_pharmacy_order.dart';
import 'package:lima/features/visits/presentation/view_models/pharmacy_order_view_model.dart';

class _FakeDrugCatalogueRepository implements DrugCatalogueRepository {
  final List<Drug> drugs;

  const _FakeDrugCatalogueRepository(this.drugs);

  @override
  Future<List<Drug>> getOrderDrugs() async => drugs;
}

class _FakePharmacyOrderRepository implements PharmacyOrderRepository {
  PharmacyOrderLocation location = const PharmacyOrderLocation(
    latitude: 41.3,
    longitude: 69.2,
  );
  bool returnNoPriceMatrix = false;
  PharmacyOrderSubmissionFailure? failure;
  PharmacyOrderPricingTerms? submittedTerms;
  bool? submittedWholesale;
  double? calculatedPrice;
  double? submittedLatitude;

  @override
  Future<bool> supportsWholesaleOrders({int? companyId}) async => true;

  @override
  Future<List<OrderTermOption>> getOrderTermOptions({int? companyId}) async =>
      const [
        OrderTermOption(
          marginId: 22,
          prepaymentPercent: 100,
          wholesaler: true,
          retail: true,
        ),
      ];

  @override
  Future<bool?> getPrepaymentFeatureFlag() async => true;

  @override
  Future<List<ClientContract>> getClientContracts(int clientInn) async =>
      const [];

  @override
  Future<PharmacyOrderPricingPreview?> calculatePricing({
    required int prepaymentPercent,
    required bool isWholesaler,
    required PharmacyOrderLines lines,
    int? companyId,
    int paymentVariantId = 1,
    int? contractId,
    double? orderTotal,
  }) async {
    if (returnNoPriceMatrix) return null;
    return PharmacyOrderPricingPreview(
      terms: PharmacyOrderPricingTerms(
        companyId: companyId,
        paymentVariantId: paymentVariantId,
        marginId: prepaymentPercent == 0 ? 8 : 22,
        marginPercent: prepaymentPercent == 0 ? 0 : 20,
        prepaymentPercent: prepaymentPercent,
        isWholesaler: isWholesaler,
      ),
      lines: calculatedPrice == null
          ? lines
          : lines
                .map((line) => line.copyWith(salePrice: calculatedPrice))
                .toList(growable: false),
    );
  }

  @override
  Future<PharmacyOrderPricingTerms?> resolvePricingTerms({
    required int prepaymentPercent,
    required bool isWholesaler,
    required double orderTotal,
    int paymentVariantId = 1,
    int? companyId,
    int? contractId,
  }) async {
    if (returnNoPriceMatrix) return null;
    return PharmacyOrderPricingTerms(
      companyId: companyId,
      paymentVariantId: paymentVariantId,
      marginId: prepaymentPercent == 0 ? 8 : 22,
      marginPercent: prepaymentPercent == 0 ? 0 : 20,
      prepaymentPercent: prepaymentPercent,
      isWholesaler: isWholesaler,
    );
  }

  @override
  Future<PharmacyOrderLocation> resolveLocation({
    required bool isOffline,
  }) async => location;

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
    if (failure != null) throw failure!;
    submittedTerms = pricingTerms;
    submittedWholesale = isWholesaler;
    submittedLatitude = latitude;
    return const PharmacyOrderSubmission(
      request: {'ok': true},
      response: {'visit_id': 123},
      remoteId: 123,
    );
  }
}

class _FakePharmacyOrderDraftRepository
    implements PharmacyOrderDraftRepository {
  PharmacyOrderDraft? savedDraft;
  PharmacyOrderSubmission? markedSubmission;
  PharmacyOrderSubmissionFailure? recordedFailure;

  @override
  Future<int> saveDraft(PharmacyOrderDraft draft) async {
    savedDraft = draft;
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
  }) async {
    markedSubmission = submission;
  }

  @override
  Future<void> recordSubmissionFailure({
    required int localVisitId,
    required PharmacyOrderSubmissionFailure failure,
  }) async {
    recordedFailure = failure;
  }
}

PharmacyOrderViewModel _createViewModel(
  DrugCatalogueRepository repository,
  PharmacyOrderViewModelConfig config,
) {
  return PharmacyOrderViewModel(
    repository,
    SubmitPharmacyOrder(_FakePharmacyOrderRepository()),
    _FakePharmacyOrderDraftRepository(),
    config,
    autoLoad: false,
  );
}

PharmacyOrderViewModelConfig _submissionConfig({
  required int prepaymentPercent,
  required int buyerType,
  int? marginId,
}) {
  return PharmacyOrderViewModelConfig(
    pharmacyId: 458,
    marginId: marginId,
    organizationName: 'Pharmacy',
    fromCart: false,
    checkoutCartId: null,
    prepaymentPercent: prepaymentPercent,
    buyerType: buyerType,
    initialQuantities: const {5: 1},
    initialDrugs: const {
      5: Drug(
        id: 5,
        name: 'Drug',
        manufacturer: 'Manufacturer',
        price: 100,
        stock: 2,
        currentStockId: 2194,
        bindingDrugId: 5,
      ),
    },
    cartItems: const [],
  );
}

void main() {
  test('calculates amount due from the selected prepayment percent', () {
    const state = PharmacyOrderViewState(
      drugs: {
        5: Drug(
          id: 5,
          name: 'Drug',
          manufacturer: 'Manufacturer',
          price: 120000,
        ),
      },
      quantities: {5: 10},
    );

    expect(state.total, 1200000);
    expect(state.payableTotal(50), 600000);
    expect(state.payableTotal(0), 0);
    expect(state.payableTotal(100), 1200000);
    expect(state.payableTotal(120), 1200000);
    expect(state.payableTotal(-5), 0);
  });

  test('loads cart snapshot first and merges the local catalogue', () async {
    const cartItem = CartItemSnapshot(
      drugId: 5,
      name: 'Cart name',
      manufacturer: 'Cart manufacturer',
      price: 90,
      quantity: 1,
      pharmacyId: 458,
      pharmacyName: 'Pharmacy',
      stock: 2,
      currentStockId: 9,
      bindingDrugId: 10,
      prepaymentPercent: 0,
      buyerType: 0,
    );
    final config = PharmacyOrderViewModelConfig(
      pharmacyId: 458,
      fromCart: true,
      checkoutCartId: null,
      prepaymentPercent: 0,
      buyerType: 0,
      initialQuantities: const {5: 1},
      initialDrugs: const {},
      cartItems: const [cartItem],
    );
    final viewModel = _createViewModel(
      const _FakeDrugCatalogueRepository([
        Drug(
          id: 5,
          name: 'Server name',
          manufacturer: 'Server manufacturer',
          price: 100,
          stock: 3,
          currentStockId: 11,
          bindingDrugId: 12,
        ),
      ]),
      config,
    );
    addTearDown(viewModel.dispose);

    await viewModel.load();

    expect(viewModel.state.selectedIds, [5]);
    expect(viewModel.state.drugs[5]?.name, 'Server name');
    expect(viewModel.state.drugs[5]?.currentStockId, 11);
    expect(viewModel.state.quantities[5], 1);
    expect(viewModel.state.hasInvalidQuantities, isFalse);
  });

  test(
    'does not increment above available stock and decrements locally',
    () async {
      final config = PharmacyOrderViewModelConfig(
        pharmacyId: 458,
        fromCart: false,
        checkoutCartId: null,
        prepaymentPercent: 100,
        buyerType: 0,
        initialQuantities: const {5: 1},
        initialDrugs: const {
          5: Drug(
            id: 5,
            name: 'Drug',
            manufacturer: 'Manufacturer',
            price: 100,
            stock: 2,
          ),
        },
        cartItems: const [],
      );
      final viewModel = _createViewModel(
        const _FakeDrugCatalogueRepository([]),
        config,
      );
      addTearDown(viewModel.dispose);

      viewModel.increment(5);
      viewModel.increment(5);
      expect(viewModel.state.quantities[5], 2);
      expect(viewModel.state.canIncrease(5), isFalse);
      expect(viewModel.state.hasInvalidQuantities, isFalse);

      viewModel.decrement(5);
      expect(viewModel.state.quantities[5], 1);
    },
  );

  test('reports sent and preserves selected 0% retail terms', () async {
    final repository = _FakePharmacyOrderRepository();
    final drafts = _FakePharmacyOrderDraftRepository();
    final viewModel = PharmacyOrderViewModel(
      const _FakeDrugCatalogueRepository([]),
      SubmitPharmacyOrder(repository),
      drafts,
      _submissionConfig(prepaymentPercent: 0, buyerType: 0),
      autoLoad: false,
    );
    addTearDown(viewModel.dispose);

    final result = await viewModel.submitOrder(
      const PharmacyOrderSubmitContext(
        orderUserId: 992,
        medicalRepName: 'Anton Dev',
        userCompanyId: 2,
        organizationInn: 123,
        isOffline: false,
        comment: 'test',
      ),
    );

    expect(result.status, PharmacyOrderSubmissionStatus.sent);
    expect(
      viewModel.state.submission.status,
      PharmacyOrderSubmissionStatus.sent,
    );
    expect(repository.submittedTerms?.prepaymentPercent, 0);
    expect(repository.submittedTerms?.marginId, 8);
    expect(repository.submittedWholesale, isFalse);
    expect(drafts.savedDraft?.prepaymentPercent, 0);
    expect(drafts.markedSubmission?.remoteId, 123);
  });

  test('keeps price-list prices and calculates only the others', () async {
    final viewModel = PharmacyOrderViewModel(
      const _FakeDrugCatalogueRepository([]),
      SubmitPharmacyOrder(
        _FakePharmacyOrderRepository()..calculatedPrice = 250,
      ),
      _FakePharmacyOrderDraftRepository(),
      const PharmacyOrderViewModelConfig(
        pharmacyId: 458,
        organizationName: 'Pharmacy',
        fromCart: false,
        checkoutCartId: null,
        prepaymentPercent: 100,
        buyerType: 0,
        marginId: 8,
        initialQuantities: {1: 1, 2: 1},
        initialDrugs: {
          1: Drug(
            id: 1,
            name: 'List priced',
            manufacturer: 'M',
            price: 100,
            stock: 5,
            currentStockId: 11,
            bindingDrugId: 1,
            hasListPrice: true,
          ),
          2: Drug(
            id: 2,
            name: 'Base priced',
            manufacturer: 'M',
            price: 100,
            stock: 5,
            currentStockId: 22,
            bindingDrugId: 2,
          ),
        },
        cartItems: [],
      ),
      autoLoad: false,
    );
    addTearDown(viewModel.dispose);

    await viewModel.refreshCalculatedPrices();

    expect(viewModel.state.drugs[1]?.price, 100);
    expect(viewModel.state.drugs[2]?.price, 250);
    expect(viewModel.state.isActionLocked, isFalse);

    final preview = await viewModel.calculateSelectedPricing();
    expect(preview?.lines.map((line) => line.salePrice), [100, 250]);
  });

  test('skips the calculation when every line has a list price', () async {
    final repository = _FakePharmacyOrderRepository()..calculatedPrice = 250;
    final viewModel = PharmacyOrderViewModel(
      const _FakeDrugCatalogueRepository([]),
      SubmitPharmacyOrder(repository),
      _FakePharmacyOrderDraftRepository(),
      const PharmacyOrderViewModelConfig(
        pharmacyId: 458,
        organizationName: 'Pharmacy',
        fromCart: false,
        checkoutCartId: null,
        prepaymentPercent: 100,
        buyerType: 0,
        marginId: 8,
        initialQuantities: {1: 1},
        initialDrugs: {
          1: Drug(
            id: 1,
            name: 'List priced',
            manufacturer: 'M',
            price: 100,
            stock: 5,
            currentStockId: 11,
            bindingDrugId: 1,
            hasListPrice: true,
          ),
        },
        cartItems: [],
      ),
      autoLoad: false,
    );
    addTearDown(viewModel.dispose);

    await viewModel.refreshCalculatedPrices();

    expect(viewModel.state.drugs[1]?.price, 100);
    expect(viewModel.state.isActionLocked, isFalse);
  });

  test('stops before saving when required location is missing', () async {
    final repository = _FakePharmacyOrderRepository()
      ..location = const PharmacyOrderLocation(
        latitude: 0,
        longitude: 0,
        isRequired: true,
      );
    final drafts = _FakePharmacyOrderDraftRepository();
    final viewModel = PharmacyOrderViewModel(
      const _FakeDrugCatalogueRepository([]),
      SubmitPharmacyOrder(repository),
      drafts,
      _submissionConfig(prepaymentPercent: 100, buyerType: 0, marginId: 22),
      autoLoad: false,
    );
    addTearDown(viewModel.dispose);

    final result = await viewModel.submitOrder(
      const PharmacyOrderSubmitContext(
        orderUserId: 992,
        medicalRepName: 'Anton Dev',
        userCompanyId: 2,
        organizationInn: 123,
        isOffline: false,
        comment: 'test',
      ),
    );

    expect(result.status, PharmacyOrderSubmissionStatus.locationRequired);
    expect(drafts.savedDraft, isNull);
  });

  test('sends the resolved location with the order', () async {
    final repository = _FakePharmacyOrderRepository();
    final drafts = _FakePharmacyOrderDraftRepository();
    final viewModel = PharmacyOrderViewModel(
      const _FakeDrugCatalogueRepository([]),
      SubmitPharmacyOrder(repository),
      drafts,
      _submissionConfig(prepaymentPercent: 100, buyerType: 0, marginId: 22),
      autoLoad: false,
    );
    addTearDown(viewModel.dispose);

    await viewModel.submitOrder(
      const PharmacyOrderSubmitContext(
        orderUserId: 992,
        medicalRepName: 'Anton Dev',
        userCompanyId: 2,
        organizationInn: 123,
        isOffline: false,
        comment: 'test',
      ),
    );

    expect(repository.submittedLatitude, 41.3);
    expect(drafts.savedDraft?.longitude, 69.2);
  });

  test('queues a local draft without pricing lookup while offline', () async {
    final repository = _FakePharmacyOrderRepository()
      ..returnNoPriceMatrix = true;
    final drafts = _FakePharmacyOrderDraftRepository();
    final viewModel = PharmacyOrderViewModel(
      const _FakeDrugCatalogueRepository([]),
      SubmitPharmacyOrder(repository),
      drafts,
      _submissionConfig(prepaymentPercent: 100, buyerType: 0),
      autoLoad: false,
    );
    addTearDown(viewModel.dispose);

    final result = await viewModel.submitOrder(
      const PharmacyOrderSubmitContext(
        orderUserId: 992,
        medicalRepName: 'Anton Dev',
        userCompanyId: 2,
        organizationInn: null,
        isOffline: true,
        comment: '',
      ),
    );

    expect(result.status, PharmacyOrderSubmissionStatus.queued);
    expect(drafts.savedDraft, isNotNull);
    expect(drafts.savedDraft?.pricingTerms, isNull);
    expect(repository.submittedTerms, isNull);
    expect(drafts.markedSubmission, isNull);
  });

  test(
    'reports permanent server rejection and records retry diagnostics',
    () async {
      final repository = _FakePharmacyOrderRepository()
        ..failure = const PharmacyOrderSubmissionFailure(
          message: 'invalid margin',
          response: {'status': 400},
          isPermanent: true,
        );
      final drafts = _FakePharmacyOrderDraftRepository();
      final viewModel = PharmacyOrderViewModel(
        const _FakeDrugCatalogueRepository([]),
        SubmitPharmacyOrder(repository),
        drafts,
        _submissionConfig(prepaymentPercent: 0, buyerType: 0),
        autoLoad: false,
      );
      addTearDown(viewModel.dispose);

      final result = await viewModel.submitOrder(
        const PharmacyOrderSubmitContext(
          orderUserId: 992,
          medicalRepName: 'Anton Dev',
          userCompanyId: 2,
          organizationInn: null,
          isOffline: false,
          comment: '',
        ),
      );

      expect(result.status, PharmacyOrderSubmissionStatus.rejected);
      expect(result.message, 'invalid margin');
      expect(drafts.recordedFailure?.isPermanent, isTrue);
    },
  );
}

import 'package:flutter_test/flutter_test.dart';
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
  bool returnNoPriceMatrix = false;
  PharmacyOrderSubmissionFailure? failure;
  PharmacyOrderPricingTerms? submittedTerms;
  bool? submittedWholesale;

  @override
  Future<bool> supportsWholesaleOrders({int? companyId}) async => true;

  @override
  Future<PharmacyOrderPricingPreview?> calculatePricing({
    required int prepaymentPercent,
    required bool isWholesaler,
    required PharmacyOrderLines lines,
    int? companyId,
    int paymentVariantId = 1,
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
      lines: lines,
    );
  }

  @override
  Future<PharmacyOrderPricingTerms?> resolvePricingTerms({
    required int prepaymentPercent,
    required bool isWholesaler,
    required double orderTotal,
    int paymentVariantId = 1,
    int? companyId,
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
  Future<PharmacyOrderSubmission> submit({
    required int orderUserId,
    required int organizationId,
    required PharmacyOrderPricingTerms pricingTerms,
    required bool isWholesaler,
    required String orderComment,
    required PharmacyOrderLines lines,
    bool pricesAlreadyCalculated = false,
  }) async {
    if (failure != null) throw failure!;
    submittedTerms = pricingTerms;
    submittedWholesale = isWholesaler;
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
}) {
  return PharmacyOrderViewModelConfig(
    pharmacyId: 458,
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

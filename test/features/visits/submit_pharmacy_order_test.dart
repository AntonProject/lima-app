import 'package:flutter_test/flutter_test.dart';
import 'package:lima/features/visits/domain/entities/pharmacy_order.dart';
import 'package:lima/features/visits/domain/repositories/pharmacy_order_repository.dart';
import 'package:lima/features/visits/domain/use_cases/build_pharmacy_order_lines.dart';
import 'package:lima/features/visits/domain/use_cases/submit_pharmacy_order.dart';

class _FakePharmacyOrderRepository implements PharmacyOrderRepository {
  PharmacyOrderPricingTerms? resolvedTerms;
  PharmacyOrderPricingTerms? submittedTerms;
  bool? submittedWholesale;
  PharmacyOrderLines? submittedLines;

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
  }) async => null;

  @override
  Future<PharmacyOrderPricingTerms?> resolvePricingTerms({
    required int prepaymentPercent,
    required bool isWholesaler,
    required double orderTotal,
    int paymentVariantId = 1,
    int? companyId,
  }) async {
    resolvedTerms = PharmacyOrderPricingTerms(
      companyId: companyId,
      paymentVariantId: paymentVariantId,
      marginId: prepaymentPercent == 0 ? 8 : 22,
      marginPercent: prepaymentPercent == 0 ? 0 : 20,
      prepaymentPercent: prepaymentPercent,
      isWholesaler: isWholesaler,
    );
    return resolvedTerms;
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
    submittedTerms = pricingTerms;
    submittedWholesale = isWholesaler;
    submittedLines = lines;
    return const PharmacyOrderSubmission(
      request: {'ok': true},
      response: {'visit_id': 123},
      remoteId: 123,
    );
  }
}

void main() {
  test('resolves and submits selected 0% retail terms unchanged', () async {
    final repository = _FakePharmacyOrderRepository();
    final useCase = SubmitPharmacyOrder(repository);
    const lines = <PharmacyOrderLine>[
      PharmacyOrderLine(
        incomeDetailingId: 2194,
        drugId: 26,
        drugName: 'Препарат',
        quantity: 1,
        salePrice: 64400,
        salePriceWithoutNds: 57500,
      ),
    ];

    final terms = await useCase.resolvePricingTerms(
      prepaymentPercent: 0,
      isWholesaler: false,
      orderTotal: 64400,
      companyId: 2,
    );
    expect(terms?.prepaymentPercent, 0);
    expect(terms?.marginId, 8);

    final result = await useCase(
      orderUserId: 992,
      organizationId: 458,
      pricingTerms: terms!,
      isWholesaler: false,
      orderComment: '',
      lines: lines,
    );

    expect(result.remoteId, 123);
    expect(repository.submittedTerms?.prepaymentPercent, 0);
    expect(repository.submittedTerms?.marginId, 8);
    expect(repository.submittedWholesale, false);
    expect(repository.submittedLines, same(lines));
  });

  test('keeps 100% wholesale selection in the typed contract', () async {
    final repository = _FakePharmacyOrderRepository();
    final useCase = SubmitPharmacyOrder(repository);
    final terms = await useCase.resolvePricingTerms(
      prepaymentPercent: 100,
      isWholesaler: true,
      orderTotal: 100000,
    );

    await useCase(
      orderUserId: 992,
      organizationId: 458,
      pricingTerms: terms!,
      isWholesaler: true,
      orderComment: 'Опт',
      lines: const [],
    );

    expect(repository.submittedTerms?.prepaymentPercent, 100);
    expect(repository.submittedTerms?.marginId, 22);
    expect(repository.submittedWholesale, true);
  });
}

import '../entities/pharmacy_order.dart';
import '../repositories/pharmacy_order_repository.dart';
import '../../../../core/failures/result.dart';

class SubmitPharmacyOrder {
  final PharmacyOrderRepository _repository;

  const SubmitPharmacyOrder(this._repository);

  Future<PharmacyOrderPricingPreview?> calculatePricing({
    required int prepaymentPercent,
    required bool isWholesaler,
    required PharmacyOrderLines lines,
    int? companyId,
    int paymentVariantId = 1,
    double? orderTotal,
  }) => _repository.calculatePricing(
    prepaymentPercent: prepaymentPercent,
    isWholesaler: isWholesaler,
    lines: lines,
    companyId: companyId,
    paymentVariantId: paymentVariantId,
    orderTotal: orderTotal,
  );

  Future<PharmacyOrderPricingTerms?> resolvePricingTerms({
    required int prepaymentPercent,
    required bool isWholesaler,
    required double orderTotal,
    int paymentVariantId = 1,
    int? companyId,
  }) => _repository.resolvePricingTerms(
    prepaymentPercent: prepaymentPercent,
    isWholesaler: isWholesaler,
    orderTotal: orderTotal,
    paymentVariantId: paymentVariantId,
    companyId: companyId,
  );

  Future<PharmacyOrderSubmission> call({
    required int orderUserId,
    required int organizationId,
    required PharmacyOrderPricingTerms pricingTerms,
    required bool isWholesaler,
    required String orderComment,
    required PharmacyOrderLines lines,
    bool pricesAlreadyCalculated = false,
  }) => _repository.submit(
    orderUserId: orderUserId,
    organizationId: organizationId,
    pricingTerms: pricingTerms,
    isWholesaler: isWholesaler,
    orderComment: orderComment,
    lines: lines,
    pricesAlreadyCalculated: pricesAlreadyCalculated,
  );

  Future<Result<PharmacyOrderSubmission>> submitResult({
    required int orderUserId,
    required int organizationId,
    required PharmacyOrderPricingTerms pricingTerms,
    required bool isWholesaler,
    required String orderComment,
    required PharmacyOrderLines lines,
    bool pricesAlreadyCalculated = false,
  }) async {
    try {
      return Result.success(
        await call(
          orderUserId: orderUserId,
          organizationId: organizationId,
          pricingTerms: pricingTerms,
          isWholesaler: isWholesaler,
          orderComment: orderComment,
          lines: lines,
          pricesAlreadyCalculated: pricesAlreadyCalculated,
        ),
      );
    } catch (error) {
      final failure = error is AppFailure
          ? error
          : UnexpectedFailure('$error', cause: error);
      return Result.failure(failure);
    }
  }
}

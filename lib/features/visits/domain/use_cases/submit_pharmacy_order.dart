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
    int? contractId,
    double? orderTotal,
  }) => _repository.calculatePricing(
    prepaymentPercent: prepaymentPercent,
    isWholesaler: isWholesaler,
    lines: lines,
    companyId: companyId,
    paymentVariantId: paymentVariantId,
    contractId: contractId,
    orderTotal: orderTotal,
  );

  Future<PharmacyOrderPricingTerms?> resolvePricingTerms({
    required int prepaymentPercent,
    required bool isWholesaler,
    required double orderTotal,
    int paymentVariantId = 1,
    int? companyId,
    int? contractId,
  }) => _repository.resolvePricingTerms(
    prepaymentPercent: prepaymentPercent,
    isWholesaler: isWholesaler,
    orderTotal: orderTotal,
    paymentVariantId: paymentVariantId,
    companyId: companyId,
    contractId: contractId,
  );

  Future<PharmacyOrderLocation> resolveLocation({required bool isOffline}) =>
      _repository.resolveLocation(isOffline: isOffline);

  Future<PharmacyOrderSubmission> call({
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
  }) => _repository.submit(
    orderUserId: orderUserId,
    organizationId: organizationId,
    plannedVisitId: plannedVisitId,
    pricingTerms: pricingTerms,
    isWholesaler: isWholesaler,
    orderComment: orderComment,
    lines: lines,
    pricesAlreadyCalculated: pricesAlreadyCalculated,
    latitude: latitude,
    longitude: longitude,
  );

  Future<Result<PharmacyOrderSubmission>> submitResult({
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
    try {
      return Result.success(
        await call(
          orderUserId: orderUserId,
          organizationId: organizationId,
          plannedVisitId: plannedVisitId,
          pricingTerms: pricingTerms,
          isWholesaler: isWholesaler,
          orderComment: orderComment,
          lines: lines,
          pricesAlreadyCalculated: pricesAlreadyCalculated,
          latitude: latitude,
          longitude: longitude,
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

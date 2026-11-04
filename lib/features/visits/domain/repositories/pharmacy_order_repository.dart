import '../entities/pharmacy_order.dart';
import '../../../../core/models/client_contract.dart';
import '../../../../core/models/order_term_option.dart';

abstract interface class PharmacyOrderRepository {
  Future<List<OrderTermOption>> getOrderTermOptions({int? companyId});

  Future<bool?> getPrepaymentFeatureFlag();

  Future<List<ClientContract>> getClientContracts(int clientInn);

  Future<bool> supportsWholesaleOrders({int? companyId});

  Future<PharmacyOrderPricingPreview?> calculatePricing({
    required int prepaymentPercent,
    required bool isWholesaler,
    required PharmacyOrderLines lines,
    int? companyId,
    int paymentVariantId = 1,
    int? contractId,
    double? orderTotal,
  });

  Future<PharmacyOrderPricingTerms?> resolvePricingTerms({
    required int prepaymentPercent,
    required bool isWholesaler,
    required double orderTotal,
    int paymentVariantId = 1,
    int? companyId,
    int? contractId,
  });

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
  });

  Future<PharmacyOrderLocation> resolveLocation({required bool isOffline});
}

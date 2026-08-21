import '../use_cases/build_pharmacy_order_lines.dart';
import '../../../../core/failures/result.dart';

class PharmacyOrderPricingTerms {
  final int? companyId;
  final int paymentVariantId;
  final int marginId;
  final int? marginPercent;
  final int? contractId;
  final int prepaymentPercent;
  final bool isWholesaler;

  const PharmacyOrderPricingTerms({
    this.companyId,
    required this.paymentVariantId,
    required this.marginId,
    this.marginPercent,
    this.contractId,
    required this.prepaymentPercent,
    required this.isWholesaler,
  });

  Map<String, dynamic> toMap() => {
    'company_id': companyId,
    'payment_variant_id': paymentVariantId,
    'margin_id': marginId,
    'margin_percent': marginPercent,
    'contract_id': contractId,
    'prepayment_percent': prepaymentPercent,
    'is_wholesaler': isWholesaler,
  };
}

class PharmacyOrderSubmission {
  final Map<String, dynamic> request;
  final Object? response;
  final int? remoteId;

  const PharmacyOrderSubmission({
    required this.request,
    required this.response,
    this.remoteId,
  });
}

class PharmacyOrderPricingPreview {
  final PharmacyOrderPricingTerms terms;
  final PharmacyOrderLines lines;

  const PharmacyOrderPricingPreview({required this.terms, required this.lines});
}

/// Typed payload passed between the catalogue and booking screens.
///
/// It deliberately contains only presentation-neutral order data. API field
/// names and JSON encoding stay in the data layer; GoRouter receives this
/// object through `extra` instead of carrying a serialized API-shaped map in
/// the URL.
class PharmacyOrderRouteLine {
  final int id;
  final String name;
  final String manufacturer;
  final double price;
  final String? serialNumber;
  final String? expiryDate;
  final int? mainStock;
  final int? stock;
  final int? remainsStock;
  final int? currentStockId;
  final int? bindingDrugId;
  final int quantity;
  final String? imageUrl;

  const PharmacyOrderRouteLine({
    required this.id,
    required this.name,
    required this.manufacturer,
    required this.price,
    this.serialNumber,
    this.expiryDate,
    this.mainStock,
    this.stock,
    this.remainsStock,
    this.currentStockId,
    this.bindingDrugId,
    required this.quantity,
    this.imageUrl,
  });
}

class PharmacyOrderRouteData {
  final List<PharmacyOrderRouteLine> lines;
  final int prepaymentPercent;
  final int buyerType;
  final PharmacyOrderPricingTerms? pricingTerms;
  final int? cartId;
  final bool fromCart;
  final int? plannedVisitId;
  final int? contractId;
  final bool isLpuBooking;

  const PharmacyOrderRouteData({
    required this.lines,
    required this.prepaymentPercent,
    required this.buyerType,
    this.pricingTerms,
    this.cartId,
    this.fromCart = false,
    this.plannedVisitId,
    this.contractId,
    this.isLpuBooking = false,
  });
}

class PharmacyOrderSubmissionFailure extends AppFailure {
  final Map<String, dynamic>? request;
  final Map<String, dynamic> response;
  final bool isPermanent;

  const PharmacyOrderSubmissionFailure({
    required String message,
    required this.response,
    required this.isPermanent,
    this.request,
  }) : super(message);
}

typedef PharmacyOrderLines = List<PharmacyOrderLine>;

class PharmacyOrderDraft {
  final int? plannedVisitId;
  final int organizationId;
  final String organizationName;
  final int? organizationInn;
  final int orderUserId;
  final String? medicalRepName;
  final DateTime createdAt;
  final String comment;
  final int prepaymentPercent;
  final int buyerType;
  final bool isWholesaler;
  final PharmacyOrderPricingTerms? pricingTerms;
  final PharmacyOrderLines lines;

  const PharmacyOrderDraft({
    this.plannedVisitId,
    required this.organizationId,
    required this.organizationName,
    this.organizationInn,
    required this.orderUserId,
    this.medicalRepName,
    required this.createdAt,
    required this.comment,
    required this.prepaymentPercent,
    required this.buyerType,
    required this.isWholesaler,
    required this.pricingTerms,
    required this.lines,
  });
}

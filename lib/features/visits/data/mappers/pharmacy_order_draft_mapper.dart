import 'dart:convert';

import '../../domain/entities/pharmacy_order.dart';

class PharmacyOrderDraftMapper {
  const PharmacyOrderDraftMapper._();

  static Map<String, dynamic> toLocalVisitRow(PharmacyOrderDraft draft) {
    final createdAt = draft.createdAt.toIso8601String();
    final terms = draft.pricingTerms?.toMap();
    final lines = draft.lines.map((line) => line.toApiMap()).toList();
    final payload = {
      'organization_id': draft.organizationId,
      'organization_name': draft.organizationName,
      'organization_inn': draft.organizationInn,
      'visit_type': 1,
      'status': 'completed',
      'comment': draft.comment,
      'order_comment': draft.comment,
      'order_user_id': draft.orderUserId,
      'prepayment': draft.prepaymentPercent,
      'prepayment_percent': draft.prepaymentPercent,
      'buyer_type': draft.buyerType,
      'is_wholesaler': draft.isWholesaler,
      if (terms?['company_id'] != null) 'company_id': terms!['company_id'],
      if (terms?['payment_variant_id'] != null)
        'payment_variant_id': terms!['payment_variant_id'],
      if (terms?['margin_id'] != null) 'margin_id': terms!['margin_id'],
      if (terms?['margin_percent'] != null)
        'margin_percent': terms!['margin_percent'],
      'drugs': lines,
      // Keep this legacy alias for old local readers.
      'items': lines,
      'start_date': createdAt,
      'end_date': createdAt,
    };

    return {
      'remote_id': null,
      'org_id': draft.organizationId,
      'org_name': draft.organizationName,
      'doctor_id': null,
      'doctor_name': null,
      'visit_type': 'order',
      'status': 'completed',
      'notes': draft.comment,
      'medical_rep_name': draft.medicalRepName,
      'created_at': createdAt,
      'updated_at': createdAt,
      'raw_json': jsonEncode(payload),
    };
  }

  static String mergeSelectedOrderTerms(
    String rawJson, {
    required int prepayment,
    required int buyerType,
    required bool isWholesaler,
    required PharmacyOrderPricingTerms pricingTerms,
  }) {
    try {
      final decoded = jsonDecode(rawJson);
      if (decoded is Map) {
        final map = Map<String, dynamic>.from(decoded);
        map['prepayment'] = prepayment;
        map['prepayment_percent'] = prepayment;
        map['buyer_type'] = buyerType;
        map['is_wholesaler'] = isWholesaler;
        map['margin_id'] = pricingTerms.marginId;
        if (pricingTerms.marginPercent != null) {
          map['margin_percent'] = pricingTerms.marginPercent;
        }
        map['payment_variant_id'] = pricingTerms.paymentVariantId;
        return jsonEncode(map);
      }
    } catch (_) {
      // Keep the server payload unchanged when its shape is not JSON-map data.
    }
    return rawJson;
  }
}

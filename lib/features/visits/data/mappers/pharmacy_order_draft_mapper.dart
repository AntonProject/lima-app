import 'dart:convert';

import '../../domain/entities/pharmacy_order.dart';

class PharmacyOrderDraftMapper {
  const PharmacyOrderDraftMapper._();

  static Map<String, dynamic> toLocalVisitRow(PharmacyOrderDraft draft) {
    final createdAt = draft.createdAt.toIso8601String();
    final terms = draft.pricingTerms?.toMap();
    final lines = draft.lines.map((line) => line.toApiMap()).toList();
    final payload = {
      if (draft.plannedVisitId != null) 'visit_id': draft.plannedVisitId,
      'organization_id': draft.organizationId,
      'organization_name': draft.organizationName,
      'organization_inn': draft.organizationInn,
      'visit_type': 1,
      'latitude': draft.latitude,
      'longitude': draft.longitude,
      'status': 'pending',
      'sync_status': 'pending',
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
      if (terms?['contract_id'] != null) 'contract_id': terms!['contract_id'],
      'drugs': lines,
      // Keep this legacy alias for old local readers.
      'items': lines,
      'start_date': createdAt,
      'end_date': createdAt,
    };

    return {
      'remote_id': draft.plannedVisitId,
      'org_id': draft.organizationId,
      'org_name': draft.organizationName,
      'doctor_id': null,
      'doctor_name': null,
      'visit_type': 'order',
      'status': 'pending',
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
    int? plannedVisitId,
  }) {
    try {
      final decoded = jsonDecode(rawJson);
      if (decoded is Map) {
        final map = Map<String, dynamic>.from(decoded);
        map['prepayment'] = prepayment;
        map['prepayment_percent'] = prepayment;
        map['buyer_type'] = buyerType;
        map['is_wholesaler'] = isWholesaler;
        if (plannedVisitId != null) map['visit_id'] = plannedVisitId;
        map['margin_id'] = pricingTerms.marginId;
        if (pricingTerms.marginPercent != null) {
          map['margin_percent'] = pricingTerms.marginPercent;
        }
        map['payment_variant_id'] = pricingTerms.paymentVariantId;
        map['contract_id'] = pricingTerms.contractId;
        map['sync_status'] = 'pending';
        return jsonEncode(map);
      }
    } catch (_) {
      // Keep the server payload unchanged when its shape is not JSON-map data.
    }
    return rawJson;
  }
}

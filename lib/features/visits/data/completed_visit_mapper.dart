import 'dart:convert';

import '../domain/entities/completed_visit.dart';

class CompletedVisitMapper {
  const CompletedVisitMapper._();

  static String toJson(
    CompletedVisitDraft draft, {
    required String comment,
    required DateTime timestamp,
  }) => jsonEncode(toMap(draft, comment: comment, timestamp: timestamp));

  static Map<String, dynamic> toMap(
    CompletedVisitDraft draft, {
    required String comment,
    required DateTime timestamp,
  }) {
    final start = timestamp.toIso8601String();
    final end = draft.updatedAt.toIso8601String();
    return switch (draft.payload) {
      LpuCompletedVisitPayload payload => _lpu(
        draft,
        payload,
        comment: comment,
        start: start,
        end: end,
      ),
      PharmaCircleCompletedVisitPayload payload => _circle(
        draft,
        payload,
        comment: comment,
        start: start,
        end: end,
      ),
      StockCompletedVisitPayload payload => _stock(
        draft,
        payload,
        comment: comment,
        start: start,
        end: end,
      ),
    };
  }

  static Map<String, dynamic> _lpu(
    CompletedVisitDraft draft,
    LpuCompletedVisitPayload payload, {
    required String comment,
    required String start,
    required String end,
  }) {
    final presentations = payload.presentations
        .map(
          (item) => {
            'drug_id': item.drugId,
            'status_id': item.statusId,
            'ball': null,
            'comment': '',
            'document_ids': const <int>[],
            'drug_name': item.drugName,
            'manufacturer': item.manufacturer,
            'status': item.status,
          },
        )
        .toList(growable: false);
    return {
      'organization_id': draft.organizationId,
      'organization_name': draft.organizationName,
      'visit_type': 2,
      if (payload.groupVisit) 'visit_format': 3,
      if (payload.groupVisit) 'visit_format_id': 3,
      if (payload.groupVisit)
        'visit_format_name': payload.groupVisitName ?? 'group',
      'doctor_ids': payload.doctorIds,
      'doctor_name': payload.doctorName,
      'medical_representative_name': draft.medicalRepName,
      'presentations': presentations,
      'talked_about_drugs': presentations,
      'status': 'completed',
      'comment': comment,
      'start_date': start,
      'end_date': end,
    };
  }

  static Map<String, dynamic> _circle(
    CompletedVisitDraft draft,
    PharmaCircleCompletedVisitPayload payload, {
    required String comment,
    required String start,
    required String end,
  }) {
    final talkedAboutDrugs = payload.discussedDrugs
        .map(
          (item) => {
            'drug_id': item.drugId,
            'document_ids': List<int>.from(item.documentIds)..sort(),
          },
        )
        .toList(growable: false);
    return {
      'organization_id': draft.organizationId,
      'organization_name': draft.organizationName,
      'visit_type': 1,
      'visit_format': 1,
      'visit_format_name': payload.visitFormatName,
      'status': 'completed',
      'pharmacists_fio': payload.pharmacistName,
      'participants_count': payload.participantsCount,
      'discussed_drugs_count': talkedAboutDrugs.length,
      'materials_shown_count': payload.materialsShownCount,
      'visit_pharm_circle': {
        'pharmacist_names': payload.pharmacistName,
        'start': start,
        'end': end,
        'number_of_participants': payload.participantsCount,
      },
      'talked_about_drugs': talkedAboutDrugs,
      'comment': comment,
      'start_date': start,
      'end_date': end,
    };
  }

  static Map<String, dynamic> _stock(
    CompletedVisitDraft draft,
    StockCompletedVisitPayload payload, {
    required String comment,
    required String start,
    required String end,
  }) {
    final stockItems = payload.stockItems
        .map(
          (item) => {
            'drug_id': item.drugId,
            'drug_name': item.drugName,
            'manufacturer': item.manufacturer,
            'serial_number': item.serialNumber,
            'expiry_date': item.expiryDate,
            'quantity': item.quantity,
            'stock': item.stock,
          },
        )
        .toList(growable: false);
    final drugs = payload.drugs
        .map(
          (item) => {
            'income_detailing_id': item.incomeDetailingId,
            'drug_id': item.drugId,
            'package': item.package,
            'sale_price': item.salePrice,
            'sale_price_without_nds': item.salePriceWithoutNds,
            'serial_no': item.serialNumber,
            'expire_date': item.expiryDate,
          },
        )
        .toList(growable: false);
    return {
      'organization_id': draft.organizationId,
      'organization_name': draft.organizationName,
      'visit_type': 4,
      'status': 'completed',
      'comment': comment,
      'stock_items': stockItems,
      'drugs': drugs,
      'start_date': start,
      'end_date': end,
    };
  }
}

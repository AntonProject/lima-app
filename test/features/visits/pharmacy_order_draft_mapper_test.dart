import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lima/features/visits/data/mappers/pharmacy_order_draft_mapper.dart';
import 'package:lima/features/visits/domain/entities/pharmacy_order.dart';
import 'package:lima/features/visits/domain/use_cases/build_pharmacy_order_lines.dart';

void main() {
  test('maps a typed draft to the local visit row without changing terms', () {
    const line = PharmacyOrderLine(
      incomeDetailingId: 2194,
      drugId: 109,
      drugName: 'Test drug',
      quantity: 2,
      salePrice: 64400,
      salePriceWithoutNds: 57500,
      serialNumber: 'S-1',
      expiryDate: '2027-01-01',
    );
    final draft = PharmacyOrderDraft(
      organizationId: 458,
      organizationName: 'Test pharmacy',
      organizationInn: 123,
      orderUserId: 7,
      medicalRepName: 'Anton Dev',
      createdAt: DateTime.utc(2026, 7, 15, 10),
      comment: 'offline order',
      prepaymentPercent: 0,
      buyerType: 0,
      isWholesaler: false,
      pricingTerms: const PharmacyOrderPricingTerms(
        companyId: 2,
        paymentVariantId: 1,
        marginId: 22,
        marginPercent: 0,
        prepaymentPercent: 0,
        isWholesaler: false,
      ),
      lines: const [line],
    );

    final row = PharmacyOrderDraftMapper.toLocalVisitRow(draft);
    final payload = jsonDecode(row['raw_json'] as String) as Map;

    expect(row['org_id'], 458);
    expect(row['medical_rep_name'], 'Anton Dev');
    expect(payload['prepayment_percent'], 0);
    expect(payload['is_wholesaler'], isFalse);
    expect(payload['margin_id'], 22);
    expect((payload['drugs'] as List).single['income_detailing_id'], 2194);
    expect((payload['drugs'] as List).single['package'], 2);
  });

  test('merges selected terms into canonical server history JSON', () {
    const terms = PharmacyOrderPricingTerms(
      companyId: 2,
      paymentVariantId: 1,
      marginId: 8,
      marginPercent: 0,
      prepaymentPercent: 0,
      isWholesaler: false,
    );

    final merged =
        jsonDecode(
              PharmacyOrderDraftMapper.mergeSelectedOrderTerms(
                '{"visit_id": 123, "prepayment_percent": 100, "margin_id": 22}',
                prepayment: 0,
                buyerType: 0,
                isWholesaler: false,
                pricingTerms: terms,
              ),
            )
            as Map;

    expect(merged['visit_id'], 123);
    expect(merged['prepayment_percent'], 0);
    expect(merged['buyer_type'], 0);
    expect(merged['margin_id'], 8);
    expect(merged['margin_percent'], 0);
  });
}

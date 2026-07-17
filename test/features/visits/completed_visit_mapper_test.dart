import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lima/features/visits/data/completed_visit_mapper.dart';
import 'package:lima/features/visits/domain/entities/completed_visit.dart';

CompletedVisitDraft _draft(CompletedVisitPayload payload) =>
    CompletedVisitDraft(
      organizationId: 458,
      organizationName: 'Test organisation',
      doctorId: null,
      doctorName: null,
      localVisitType: 'test',
      notes: 'comment',
      medicalRepName: 'Rep',
      createdAt: DateTime.utc(2026, 7, 16, 10),
      updatedAt: DateTime.utc(2026, 7, 16, 11),
      payload: payload,
    );

void main() {
  test('maps LPU presentations to the server payload', () {
    final raw = CompletedVisitMapper.toMap(
      _draft(
        const LpuCompletedVisitPayload(
          doctorIds: [12, 13],
          doctorName: 'Doctor group',
          groupVisit: true,
          groupVisitName: 'Групповая презентация',
          presentations: [
            LpuPresentationRecord(
              drugId: 77,
              statusId: 4,
              drugName: 'Drug',
              manufacturer: 'Factory',
              status: 'familiar_prescribes',
            ),
          ],
        ),
      ),
      comment: '2 drugs',
      timestamp: DateTime.utc(2026, 7, 16, 10),
    );

    expect(raw['visit_type'], 2);
    expect(raw['doctor_ids'], [12, 13]);
    expect(raw['visit_format_id'], 3);
    expect(raw['presentations'], raw['talked_about_drugs']);
    expect(raw['presentations'][0]['status_id'], 4);
  });

  test('maps circle materials with stable document ordering', () {
    final raw = CompletedVisitMapper.toMap(
      _draft(
        const PharmaCircleCompletedVisitPayload(
          pharmacistName: 'Pharmacist',
          participantsCount: 3,
          materialsShownCount: 2,
          visitFormatName: 'Фарм кружок',
          discussedDrugs: [
            DiscussedDrugRecord(drugId: 21, documentIds: [9, 2]),
          ],
        ),
      ),
      comment: '',
      timestamp: DateTime.utc(2026, 7, 16, 10),
    );

    expect(raw['visit_type'], 1);
    expect(raw['visit_format'], 1);
    expect(raw['participants_count'], 3);
    expect(raw['talked_about_drugs'][0]['document_ids'], [2, 9]);
  });

  test('maps stock removal to VisitRequest drugs and local stock details', () {
    final raw = CompletedVisitMapper.toMap(
      _draft(
        const StockCompletedVisitPayload(
          stockItems: [
            StockItemRecord(
              drugId: 10,
              drugName: 'Drug',
              manufacturer: 'Factory',
              serialNumber: 'SN',
              expiryDate: '2027-01-01',
              quantity: 2,
              stock: 5,
            ),
          ],
          drugs: [
            StockDrugRecord(
              incomeDetailingId: 100,
              drugId: 10,
              package: 2,
              salePrice: 120,
              salePriceWithoutNds: 107.14,
              serialNumber: 'SN',
              expiryDate: '2027-01-01',
            ),
          ],
        ),
      ),
      comment: 'stock',
      timestamp: DateTime.utc(2026, 7, 16, 10),
    );

    expect(raw['visit_type'], 4);
    expect(raw['stock_items'][0]['quantity'], 2);
    expect(raw['drugs'][0]['income_detailing_id'], 100);
    expect(
      jsonDecode(
        CompletedVisitMapper.toJson(
          _draft(const StockCompletedVisitPayload(stockItems: [], drugs: [])),
          comment: '',
          timestamp: DateTime.utc(2026, 7, 16, 10),
        ),
      ),
      isA<Map<String, dynamic>>(),
    );
  });
}

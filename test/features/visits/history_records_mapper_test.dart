import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lima/features/visits/data/history_records_mapper.dart';

void main() {
  test('deduplicates a remote visit and keeps the richer local row', () {
    final records = HistoryRecordsMapper.fromRows([
      {
        'remote_id': 321,
        'org_id': 8,
        'org_name': 'Clinic',
        'visit_type': 'lpu',
        'status': 'planned',
        'created_at': '2026-07-15T10:00:00',
        'updated_at': '2026-07-15T10:00:00',
        'raw_json': jsonEncode({
          'visit_type': 2,
          'organization_name': 'Clinic',
        }),
      },
      {
        'remote_id': 321,
        'org_id': 8,
        'org_name': 'Clinic',
        'visit_type': 'lpu',
        'status': 'completed',
        'doctor_name': 'Dr. Test',
        'created_at': '2026-07-15T10:00:00',
        'updated_at': '2026-07-15T10:30:00',
        'raw_json': jsonEncode({
          'visit_type': 2,
          'organization_name': 'Clinic',
          'doctor_name': 'Dr. Test',
        }),
      },
    ]);

    expect(records, hasLength(1));
    expect(records.single.id, '321');
    expect(records.single.status, 'completed');
    expect(records.single.doctor, 'Dr. Test');
  });

  test('keeps a locally completed order pending until it is synced', () {
    final records = HistoryRecordsMapper.fromRows([
      {
        'id': 9,
        'org_id': 8,
        'org_name': 'Clinic',
        'visit_type': 'order',
        'status': 'completed',
        'is_synced': 0,
        'created_at': '2026-07-15T10:00:00',
        'updated_at': '2026-07-15T10:00:00',
        'raw_json': jsonEncode({'complete': true}),
      },
    ]);

    expect(records.single.syncStatus, 'pending');
    expect(records.single.status, 'pending');
  });

  test('keeps order quantities, totals and product metadata for export', () {
    final records = HistoryRecordsMapper.fromRows([
      {
        'remote_id': 42,
        'org_id': 8,
        'org_name': 'INTERFARMED',
        'visit_type': 'order',
        'status': 'completed',
        'is_synced': 1,
        'created_at': '2026-09-17T10:00:00',
        'updated_at': '2026-09-17T10:00:00',
        'raw_json': jsonEncode({
          'visit_type': 1,
          'total_sum': 1200000,
          'drugs': [
            {
              'drug': {
                'name': 'ЭССЕНИКС',
                'producer': {'name': 'TEMUR MED'},
              },
              'package': 10,
              'sale_price': 120000,
              'margin_percent': 12,
              'serial_no': 'S-10',
              'expire_date': '2027-09-17',
            },
          ],
        }),
      },
    ]);

    final item = records.single.orderItems.single;
    expect(item.name, 'ЭССЕНИКС');
    expect(item.manufacturer, 'TEMUR MED');
    expect(item.quantity, 10);
    expect(item.total, 1200000);
    expect(item.marginPercent, 12);
    expect(records.single.markupPercent, isNull);
    expect(item.serialNumber, 'S-10');
    expect(item.expiryDate, '2027-09-17');
  });
}

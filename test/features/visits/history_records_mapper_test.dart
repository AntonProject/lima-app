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
}

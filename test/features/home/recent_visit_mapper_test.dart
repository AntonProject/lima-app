import 'package:flutter_test/flutter_test.dart';
import 'package:lima/features/home/data/recent_visit_mapper.dart';

void main() {
  test('deduplicates the same remote visit and keeps the newest row', () {
    final visits = RecentVisitMapper.fromRows([
      {
        'remote_id': 100,
        'visit_type': 'order',
        'organization_type_id': 1,
        'organization_name': 'Old name',
        'created_at': '2026-05-12T10:00:00',
        'raw_json': '{}',
      },
      {
        'remote_id': 100,
        'visit_type': 'order',
        'organization_type_id': 1,
        'organization_name': 'New name',
        'created_at': '2026-05-13T10:00:00',
        'raw_json': '{}',
      },
    ]);

    expect(visits, hasLength(1));
    expect(visits.single.id, '100');
    expect(visits.single.name, 'New name');
    expect(visits.single.type, 'pharmacy');
  });
}

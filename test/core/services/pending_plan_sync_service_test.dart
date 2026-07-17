import 'package:flutter_test/flutter_test.dart';
import 'package:lima/core/services/pending_plan_sync_service.dart';

void main() {
  test('parses numeric and string doctor ids from a queued plan', () {
    expect(PendingPlanSyncService.parseDoctorIds('[12,"13","bad",null]'), [
      12,
      13,
    ]);
    expect(PendingPlanSyncService.parseDoctorIds(null), isEmpty);
    expect(PendingPlanSyncService.parseDoctorIds('not-json'), isEmpty);
  });

  test('extracts the supported remote plan id fields', () {
    expect(PendingPlanSyncService.remoteIdFrom({'id': 101}), 101);
    expect(PendingPlanSyncService.remoteIdFrom({'plan_id': 102}), 102);
    expect(PendingPlanSyncService.remoteIdFrom({'visit_id': 103}), 103);
    expect(PendingPlanSyncService.remoteIdFrom({'message': 'ok'}), isNull);
    expect(PendingPlanSyncService.remoteIdFrom(null), isNull);
  });
}

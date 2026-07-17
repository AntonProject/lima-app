import 'package:flutter_test/flutter_test.dart';
import 'package:lima/features/offline/domain/entities/sync_data_change.dart';

void main() {
  test('maps storage table names to typed data changes', () {
    final change = SyncDataChange.fromStorageTables([
      'doctors',
      'planned_visits',
      'future_table',
    ]);

    expect(
      change.tables,
      containsAll([
        SyncDataTable.doctors,
        SyncDataTable.plannedVisits,
        SyncDataTable.other,
      ]),
    );
    expect(change.containsAny([SyncDataTable.doctors]), isTrue);
    expect(change.containsAny([SyncDataTable.drugs]), isFalse);
  });
}

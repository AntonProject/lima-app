import 'package:flutter_test/flutter_test.dart';
import 'package:lima/features/offline/domain/entities/sync_queue_records.dart';

void main() {
  test('maps pending sync records without exposing storage rows to UI', () {
    final doctor = PendingDoctorRecord.fromMap({
      'id': 12,
      'full_name': 'Doctor Name',
      'created_at': '2026-07-15T10:00:00',
    });
    final organisation = PendingOrganisationUpdateRecord.fromMap({
      'id': '13',
      'name': 'LPU Name',
    });
    final totals = SyncLocalTotals.fromMap({
      'lpu': 4,
      'pharmacy': 8,
      'doctors': 2,
    });

    expect(doctor.id, 12);
    expect(doctor.fullName, 'Doctor Name');
    expect(organisation.id, 13);
    expect(organisation.name, 'LPU Name');
    expect(totals.lpu, 4);
    expect(totals.pharmacy, 8);
    expect(totals.doctors, 2);
    expect(totals.visits, 0);
  });
}

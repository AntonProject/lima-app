import 'package:flutter_test/flutter_test.dart';
import 'package:lima/core/models/models.dart';
import 'package:lima/features/plan/domain/entities/planned_visit_record.dart';
import 'package:lima/features/plan/domain/use_cases/merge_planned_visits.dart';

void main() {
  test('removes an unstamped local plan when its server twin exists', () {
    final date = DateTime(2026, 7, 15);
    final useCase = const MergePlannedVisits();

    final merged = useCase(
      planned: [
        PlannedVisitRecord(
          localId: 10,
          remoteId: 500,
          organisationName: 'Hospital',
          organisationId: 42,
          organisationType: 'lpu',
          assignedBy: 'Server',
          date: date,
          status: VisitStatus.planned,
        ),
        PlannedVisitRecord(
          localId: 11,
          organisationName: 'Hospital',
          organisationId: 42,
          organisationType: 'lpu',
          assignedBy: 'Local',
          date: date,
          status: VisitStatus.planned,
        ),
      ],
      local: const [],
    );

    expect(merged, hasLength(1));
    expect(merged.single.remoteId, 500);
  });

  test('keeps different organisation/day plans and sorts newest first', () {
    final useCase = const MergePlannedVisits();
    final older = PlannedVisitRecord(
      localId: 1,
      organisationName: 'A',
      organisationId: 1,
      organisationType: 'lpu',
      assignedBy: 'Local',
      date: DateTime(2026, 7, 1),
      status: VisitStatus.planned,
    );
    final newer = PlannedVisitRecord(
      localId: 2,
      organisationName: 'B',
      organisationId: 2,
      organisationType: 'pharmacy',
      assignedBy: 'Local',
      date: DateTime(2026, 7, 2),
      status: VisitStatus.planned,
    );

    final merged = useCase(planned: [older], local: [newer]);

    expect(merged.map((item) => item.organisationName), ['B', 'A']);
  });

  test('removes a server plan completed through its original visit id', () {
    final date = DateTime(2026, 7, 30);
    final planned = PlannedVisitRecord(
      localId: 12,
      remoteId: 38479,
      organisationName: '57-son dorixona mchj',
      organisationId: 841,
      organisationType: 'pharmacy',
      assignedBy: 'Server',
      date: date,
      status: VisitStatus.planned,
    );
    final completed = PlannedVisitRecord(
      localId: 44,
      remoteId: 38479,
      organisationName: '57-son dorixona mchj',
      organisationId: 841,
      organisationType: 'pharmacy',
      assignedBy: 'Local',
      date: date,
      status: VisitStatus.completed,
    );

    final merged = const MergePlannedVisits().call(
      planned: [planned],
      local: [completed],
    );

    expect(merged, isEmpty);
  });

  test('removes an unstamped local plan completed by its local id', () {
    final date = DateTime(2026, 7, 30);
    final planned = PlannedVisitRecord(
      localId: 287,
      organisationName: 'ASH-SHAFI',
      organisationId: 14461,
      organisationType: 'lpu',
      assignedBy: 'Local',
      date: date,
      status: VisitStatus.planned,
    );
    final completed = PlannedVisitRecord(
      localId: 5844,
      remoteId: 287,
      organisationName: 'ASH-SHAFI',
      organisationId: 14461,
      organisationType: 'lpu',
      assignedBy: 'Local',
      date: date,
      status: VisitStatus.completed,
    );

    final merged = const MergePlannedVisits().call(
      planned: [planned],
      local: [completed],
    );

    expect(merged, isEmpty);
  });
}

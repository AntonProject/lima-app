import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:lima/core/models/models.dart';
import 'package:lima/features/offline/domain/entities/sync_data_change.dart';
import 'package:lima/features/plan/domain/entities/planned_visit_draft.dart';
import 'package:lima/features/plan/domain/entities/planned_visit_record.dart';
import 'package:lima/features/plan/domain/repositories/planned_visits_repository.dart';
import 'package:lima/features/plan/providers/planned_visits_provider.dart';

void main() {
  test('reloads plans after background sync changes local storage', () async {
    final repository = _FakePlannedVisitsRepository();
    final notifier = PlannedVisitsNotifier(repository);
    addTearDown(() async {
      notifier.dispose();
      await repository.dispose();
    });

    await _waitUntil(() => repository.plannedReads == 1);
    expect(notifier.state, isEmpty);

    repository.planned = [
      PlannedVisitRecord(
        localId: 1,
        remoteId: 78820,
        organisationName: 'Тестовый ЛПУ',
        organisationId: 4201,
        organisationType: 'lpu',
        doctorIds: const [30500, 27617],
        doctorName: 'Акбарова Дилдора, Алиджанов Сарвар',
        assignedBy: 'Anton Dev',
        date: DateTime(2026, 7, 29),
        status: VisitStatus.planned,
        visitFormat: 'double',
      ),
    ];
    repository.emit(SyncDataTable.plannedVisits);

    await _waitUntil(() => notifier.state.length == 1);
    expect(notifier.state.single.id, 78820);
    expect(notifier.state.single.doctorIds, [30500, 27617]);
  });
}

Future<void> _waitUntil(bool Function() predicate) async {
  for (var attempt = 0; attempt < 50; attempt++) {
    if (predicate()) return;
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  fail('Condition was not met in time');
}

class _FakePlannedVisitsRepository implements PlannedVisitsRepository {
  final _changes = StreamController<SyncDataChange>.broadcast();
  List<PlannedVisitRecord> planned = const [];
  int plannedReads = 0;

  @override
  Stream<SyncDataChange> get changes => _changes.stream;

  void emit(SyncDataTable table) => _changes.add(SyncDataChange({table}));

  Future<void> dispose() => _changes.close();

  @override
  Future<List<PlannedVisitRecord>> getPlannedVisitRecords() async {
    plannedReads++;
    return planned;
  }

  @override
  Future<List<PlannedVisitRecord>> getLocalVisitRecords() async => const [];

  @override
  Future<List<VisitFormatOption>> getVisitFormats() async => const [];

  @override
  Future<int> savePlannedVisit(PlannedVisitDraft draft) async => 1;

  @override
  Future<void> enqueuePlannedVisit({
    required int localPlanId,
    required PlannedVisitDraft draft,
  }) async {}
}

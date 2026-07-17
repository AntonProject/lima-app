import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/models.dart';
import '../domain/entities/planned_visit_record.dart';
import '../domain/repositories/planned_visits_repository.dart';
import '../domain/use_cases/merge_planned_visits.dart';
import '../../visits/data/visits_repository.dart';
import '../../../core/utils/swallowed.dart';

final plannedVisitsRepositoryProvider = Provider<PlannedVisitsRepository>(
  (ref) => ref.watch(visitsRepositoryProvider),
);

class PlannedVisitsNotifier extends StateNotifier<List<PlannedVisit>> {
  final PlannedVisitsRepository _repo;

  PlannedVisitsNotifier(this._repo) : super(const []) {
    load();
  }

  Future<void> load() async {
    var planned = const <PlannedVisitRecord>[];
    var local = const <PlannedVisitRecord>[];
    try {
      planned = await _repo.getPlannedVisitRecords();
    } catch (error) {
      logSwallowed(error, 'PlannedVisitsNotifier.loadRemote');
    }

    try {
      local = await _repo.getLocalVisitRecords();
    } catch (error) {
      logSwallowed(error, 'PlannedVisitsNotifier.loadLocal');
    }

    final records = const MergePlannedVisits().call(
      planned: planned,
      local: local,
    );
    state = records.map((record) => record.toModel()).toList(growable: false);
  }

  void addPlannedVisit(PlannedVisit visit) {
    state = [...state, visit];
  }
}

final plannedVisitsProvider =
    StateNotifierProvider<PlannedVisitsNotifier, List<PlannedVisit>>((ref) {
      return PlannedVisitsNotifier(ref.watch(plannedVisitsRepositoryProvider));
    });

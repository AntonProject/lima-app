import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/models.dart';
import '../../offline/domain/entities/sync_data_change.dart';
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
  StreamSubscription<SyncDataChange>? _changesSubscription;
  bool _isLoading = false;
  bool _reloadRequested = false;

  PlannedVisitsNotifier(this._repo) : super(const []) {
    _changesSubscription = _repo.changes.listen((change) {
      if (change.containsAny(const [
        SyncDataTable.plannedVisits,
        SyncDataTable.visits,
      ])) {
        unawaited(load());
      }
    });
    unawaited(load());
  }

  Future<void> load() async {
    if (_isLoading) {
      _reloadRequested = true;
      return;
    }

    _isLoading = true;
    try {
      do {
        _reloadRequested = false;
        await _loadOnce();
      } while (mounted && _reloadRequested);
    } finally {
      _isLoading = false;
    }
  }

  Future<void> _loadOnce() async {
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
    if (!mounted) return;
    state = records.map((record) => record.toModel()).toList(growable: false);
  }

  void addPlannedVisit(PlannedVisit visit) {
    state = [...state, visit];
  }

  @override
  void dispose() {
    _changesSubscription?.cancel();
    super.dispose();
  }
}

final plannedVisitsProvider =
    StateNotifierProvider<PlannedVisitsNotifier, List<PlannedVisit>>((ref) {
      return PlannedVisitsNotifier(ref.watch(plannedVisitsRepositoryProvider));
    });

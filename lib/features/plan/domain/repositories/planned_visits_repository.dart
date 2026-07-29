import '../entities/planned_visit_record.dart';
import '../entities/planned_visit_draft.dart';
import '../../../offline/domain/entities/sync_data_change.dart';

abstract interface class PlannedVisitsRepository {
  Stream<SyncDataChange> get changes;

  Future<List<PlannedVisitRecord>> getPlannedVisitRecords();

  Future<List<PlannedVisitRecord>> getLocalVisitRecords();

  Future<List<VisitFormatOption>> getVisitFormats();

  Future<int> savePlannedVisit(PlannedVisitDraft draft);

  Future<void> enqueuePlannedVisit({
    required int localPlanId,
    required PlannedVisitDraft draft,
  });
}

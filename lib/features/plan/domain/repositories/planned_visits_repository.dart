import '../entities/planned_visit_record.dart';
import '../entities/planned_visit_draft.dart';

abstract interface class PlannedVisitsRepository {
  Future<List<PlannedVisitRecord>> getPlannedVisitRecords();

  Future<List<PlannedVisitRecord>> getLocalVisitRecords();

  Future<List<VisitFormatOption>> getVisitFormats();

  Future<int> savePlannedVisit(PlannedVisitDraft draft);

  Future<void> enqueuePlannedVisit({
    required int localPlanId,
    required PlannedVisitDraft draft,
  });
}

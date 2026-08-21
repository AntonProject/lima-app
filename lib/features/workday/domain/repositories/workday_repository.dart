import '../entities/workday.dart';

abstract interface class WorkdayRepository {
  Future<WorkdayCachedState> readCached();
  Future<bool?> loadFeatureEnabled();
  Future<WorkdayStatus> loadStatus();
  Future<List<DayType>> loadDayTypes();
  Future<void> saveCached(WorkdayCachedState value);
  Future<WorkdayActionResult> start(DayType dayType);
  Future<WorkdayActionResult> end();
  Future<bool> syncPending();
}

import '../../../offline/domain/entities/sync_data_change.dart';
import '../entities/recent_visit.dart';

abstract interface class HomeRepository {
  Stream<SyncDataChange> get changes;

  Future<int?> getCurrentUserId();

  Future<List<RecentVisit>> getRecentVisits();
}

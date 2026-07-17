import '../../models/history_records.dart';
import '../../../offline/domain/entities/sync_data_change.dart';

abstract interface class HistoryRepository {
  Stream<SyncDataChange> get changes;

  Future<List<HistoryVisitRecord>> getHistoryRecords();
}

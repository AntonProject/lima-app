import '../../../../core/models/local_visit.dart';
import '../entities/sync_data_change.dart';
import '../entities/sync_queue_records.dart';

abstract interface class SyncDiagnosticsRepository {
  Stream<SyncDataChange> get changes;

  Future<List<LocalVisit>> getVisitModels({
    bool? unsyncedOnly,
    bool dueForRetryOnly = false,
  });

  Future<List<LocalVisit>> getFailedVisitModels();

  String failedVisitMessage(LocalVisit visit, {required String fallback});

  Future<void> retryFailedVisit(int id);

  Future<void> deleteVisit(int id);

  Future<int> deleteLegacyTestVisits();

  Future<List<PendingDoctorRecord>> getPendingDoctors();

  Future<List<PendingDoctorRecord>> getFailedPendingDoctors();

  Future<List<PendingOrganisationUpdateRecord>> getPendingOrgUpdates();

  Future<void> deletePendingDoctor(int id);

  Future<SyncLocalTotals> getLocalTotals();
}

import '../entities/completed_visit.dart';

abstract interface class VisitWriteRepository {
  /// Saves first, then optionally attempts the remote push.
  ///
  /// A remote failure is returned as a queued result so the local visit stays
  /// available for the normal retry worker.
  Future<VisitWriteResult> complete(
    CompletedVisitDraft draft, {
    required bool tryRemote,
  });
}

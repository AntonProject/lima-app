import '../../../../core/models/local_visit.dart';
import '../entities/visit_interaction.dart';

abstract interface class VisitInteractionRepository {
  Future<LocalVisit?> getLocalVisitById(int id);

  Future<List<LocalVisit>> getLocalVisitModels();

  Future<void> completeRemoteVisit(VisitCompletionDraft draft);

  Future<void> rateRemoteVisit(VisitRatingDraft draft);
}

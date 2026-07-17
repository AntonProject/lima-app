enum DrugStatus { familiarPrescribes, familiarNotPrescribes, unfamiliar, other }

class VisitCompletionDraft {
  final int visitId;
  final String comment;
  final DateTime endedAt;

  const VisitCompletionDraft({
    required this.visitId,
    required this.comment,
    required this.endedAt,
  });
}

class VisitRatingDraft {
  final int visitId;
  final int rating;
  final String comment;

  const VisitRatingDraft({
    required this.visitId,
    required this.rating,
    required this.comment,
  });
}

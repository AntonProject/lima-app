import '../entities/pharmacy_order.dart';

abstract interface class PharmacyOrderDraftRepository {
  Future<int> saveDraft(PharmacyOrderDraft draft);

  Future<void> markSubmitted({
    required int localVisitId,
    required PharmacyOrderSubmission submission,
    required PharmacyOrderPricingTerms pricingTerms,
    required int prepaymentPercent,
    required int buyerType,
    required bool isWholesaler,
  });

  Future<void> recordSubmissionFailure({
    required int localVisitId,
    required PharmacyOrderSubmissionFailure failure,
  });
}

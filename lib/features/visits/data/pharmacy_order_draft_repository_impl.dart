import 'dart:convert';

import '../../../core/db/local_database.dart';
import '../../../core/network/remote_api_service.dart';
import '../../../core/utils/swallowed.dart';
import 'mappers/pharmacy_order_draft_mapper.dart';
import '../domain/entities/pharmacy_order.dart';
import '../domain/repositories/pharmacy_order_draft_repository.dart';

class PharmacyOrderDraftRepositoryImpl implements PharmacyOrderDraftRepository {
  final LocalDatabase _db;
  final RemoteApiService _api;

  const PharmacyOrderDraftRepositoryImpl(this._db, this._api);

  @override
  Future<int> saveDraft(PharmacyOrderDraft draft) =>
      _db.insertVisit(PharmacyOrderDraftMapper.toLocalVisitRow(draft));

  @override
  Future<void> markSubmitted({
    required int localVisitId,
    required PharmacyOrderSubmission submission,
    required PharmacyOrderPricingTerms pricingTerms,
    required int prepaymentPercent,
    required int buyerType,
    required bool isWholesaler,
  }) async {
    await _db.markSynced([localVisitId]);

    final remoteId = submission.remoteId;
    if (remoteId != null) {
      await _db.updateVisitRemoteId(
        localVisitId: localVisitId,
        remoteId: remoteId,
      );

      // Keep local history aligned with the canonical server response while
      // preserving the selected order terms in the local detail view.
      try {
        final remoteRow = await _api.getVisitHistoryOrderById(remoteId);
        if (remoteRow != null) {
          final remoteRaw = remoteRow['raw_json'] is String
              ? remoteRow['raw_json'] as String
              : jsonEncode(remoteRow);
          final serverRaw = PharmacyOrderDraftMapper.mergeSelectedOrderTerms(
            remoteRaw,
            prepayment: prepaymentPercent,
            buyerType: buyerType,
            isWholesaler: isWholesaler,
            pricingTerms: pricingTerms,
          );
          await _db.updateVisitRawJson(
            localVisitId: localVisitId,
            rawJson: serverRaw,
          );
        }
      } catch (error) {
        // The submitted visit remains synced if history refresh is delayed.
        logSwallowed(error, 'PharmacyOrderDraftRepositoryImpl.refreshHistory');
      }
    }

    await _db.setVisitPushPayload(
      visitId: localVisitId,
      requestJson: jsonEncode(submission.request),
      responseJson: jsonEncode(submission.response),
    );
  }

  @override
  Future<void> recordSubmissionFailure({
    required int localVisitId,
    required PharmacyOrderSubmissionFailure failure,
  }) async {
    await _db.setVisitPushPayload(
      visitId: localVisitId,
      requestJson: failure.request == null ? null : jsonEncode(failure.request),
      responseJson: jsonEncode(failure.response),
    );
    if (failure.isPermanent) {
      await _db.markVisitPushFailedPermanently(localVisitId);
    }
  }
}

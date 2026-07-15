import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/local_database.dart';
import '../../../core/models/local_visit.dart';
import '../../../core/network/remote_api_service.dart';

class VisitsRepository {
  final LocalDatabase _db;
  final RemoteApiService _api;

  VisitsRepository(this._db, this._api);

  /// Broadcast of table names touched by local writes — lets screens refresh
  /// without polling (mirrors LocalDatabase.changes).
  Stream<Set<String>> get changes => _db.changes;

  Future<List<Map<String, dynamic>>> getPlannedVisits({bool? completedOnly}) =>
      _db.getPlannedVisits(completedOnly: completedOnly);

  Future<List<Map<String, dynamic>>> getVisits({
    bool? unsyncedOnly,
    bool dueForRetryOnly = false,
  }) => _db.getVisits(
    unsyncedOnly: unsyncedOnly,
    dueForRetryOnly: dueForRetryOnly,
  );

  Future<List<Map<String, dynamic>>> getVisitFormats() => _db.getVisitFormats();

  Future<int> insertVisit(Map<String, dynamic> visit) => _db.insertVisit(visit);

  Future<void> markSynced(List<int> ids) => _db.markSynced(ids);

  Future<void> markVisitPushFailedPermanently(int id) =>
      _db.markVisitPushFailedPermanently(id);

  Future<void> setVisitPushPayload({
    required int visitId,
    String? requestJson,
    String? responseJson,
  }) => _db.setVisitPushPayload(
    visitId: visitId,
    requestJson: requestJson,
    responseJson: responseJson,
  );

  Future<void> updateVisitRemoteId({
    required int localVisitId,
    required int remoteId,
  }) =>
      _db.updateVisitRemoteId(localVisitId: localVisitId, remoteId: remoteId);

  Future<void> updateVisitRawJson({
    required int localVisitId,
    required String rawJson,
  }) => _db.updateVisitRawJson(localVisitId: localVisitId, rawJson: rawJson);

  Future<void> updateVisitStatusByRemoteId(
    int remoteId,
    String status, {
    String? notes,
  }) => _db.updateVisitStatusByRemoteId(remoteId, status, notes: notes);

  Future<int> insertLocalPlannedVisit(Map<String, dynamic> row) =>
      _db.insertLocalPlannedVisit(row);

  Future<void> enqueuePendingPlan({
    required int localPlanId,
    required int orgId,
    required String orgType,
    required List<int> doctorIds,
    required int visitFormatId,
    required DateTime visitDate,
    String? comment,
  }) => _db.enqueuePendingPlan(
    localPlanId: localPlanId,
    orgId: orgId,
    orgType: orgType,
    doctorIds: doctorIds,
    visitFormatId: visitFormatId,
    visitDate: visitDate,
    comment: comment,
  );

  // ── Order (Бронь) API ───────────────────────────────────────────────────

  Future<bool> supportsWholesaleOrders({int? companyId}) =>
      _api.supportsWholesaleOrders(companyId: companyId);

  Future<Map<String, dynamic>?> resolveOrderPricingTerms({
    required int prepaymentPercent,
    required bool isWholesaler,
    double orderTotal = 0,
    int paymentVariantId = 1,
    int? companyId,
  }) => _api.resolveOrderPricingTerms(
    prepaymentPercent: prepaymentPercent,
    isWholesaler: isWholesaler,
    orderTotal: orderTotal,
    paymentVariantId: paymentVariantId,
    companyId: companyId,
  );

  Future<Map<String, dynamic>> createOrderVisitDebug({
    required int orderUserId,
    required int organizationId,
    int? companyId,
    int? paymentVariantId,
    int? marginId,
    int? marginPercent,
    int? prepaymentPercent,
    required bool isWholesaler,
    String? orderComment,
    String? orderExpireDate,
    required List<Map<String, dynamic>> drugs,
    bool pricesAlreadyCalculated = false,
  }) => _api.createOrderVisitDebug(
    orderUserId: orderUserId,
    organizationId: organizationId,
    companyId: companyId,
    paymentVariantId: paymentVariantId,
    marginId: marginId,
    marginPercent: marginPercent,
    prepaymentPercent: prepaymentPercent,
    isWholesaler: isWholesaler,
    orderComment: orderComment,
    orderExpireDate: orderExpireDate,
    drugs: drugs,
    pricesAlreadyCalculated: pricesAlreadyCalculated,
  );

  Future<Map<String, dynamic>?> getVisitHistoryOrderById(int visitId) =>
      _api.getVisitHistoryOrderById(visitId);

  Future<Map<String, dynamic>?> getVisitHistoryRemnantById(int visitId) =>
      _api.getVisitHistoryRemnantById(visitId);

  Future<Map<String, dynamic>> pushUnsyncedVisitDebug(LocalVisit visit) =>
      _api.pushUnsyncedVisitDebug(visit);

  Future<void> updateVisit(int visitId, {required Map<String, dynamic> data}) =>
      _api.updateVisit(visitId, data: data);

  Future<void> rateVisit({
    required int visitId,
    required int rating,
    String? comment,
  }) => _api.rateVisit(visitId: visitId, rating: rating, comment: comment);

  Future<Map<String, dynamic>?> prepareOrderVisitDraft({
    required int prepaymentPercent,
    required bool isWholesaler,
    required List<Map<String, dynamic>> drugs,
    int? companyId,
    int paymentVariantId = 1,
    double? orderTotal,
  }) => _api.prepareOrderVisitDraft(
    prepaymentPercent: prepaymentPercent,
    isWholesaler: isWholesaler,
    drugs: drugs,
    companyId: companyId,
    paymentVariantId: paymentVariantId,
    orderTotal: orderTotal,
  );
}

final visitsRepositoryProvider = Provider<VisitsRepository>((ref) {
  return VisitsRepository(
    ref.watch(localDatabaseProvider),
    ref.watch(remoteApiServiceProvider),
  );
});

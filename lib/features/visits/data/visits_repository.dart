import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/local_database.dart';
import '../../../core/models/local_visit.dart';
import '../../../core/models/models.dart';
import '../../../core/network/remote_api_service.dart';
import '../models/history_records.dart';
import '../../offline/domain/entities/sync_data_change.dart';
import '../domain/entities/pharmacy_order.dart';
import '../domain/entities/visit_interaction.dart';
import '../domain/repositories/pharmacy_order_repository.dart';
import '../domain/repositories/history_repository.dart';
import '../domain/repositories/visit_interaction_repository.dart';
import '../../plan/domain/repositories/planned_visits_repository.dart';
import '../../plan/domain/entities/planned_visit_record.dart';
import '../../plan/domain/entities/planned_visit_draft.dart';
import '../../../core/utils/swallowed.dart';
import 'history_records_mapper.dart';
import 'planned_visit_mapper.dart';

class VisitsRepositoryImpl
    implements
        PharmacyOrderRepository,
        PlannedVisitsRepository,
        HistoryRepository,
        VisitInteractionRepository {
  final LocalDatabase _db;
  final RemoteApiService _api;

  VisitsRepositoryImpl(this._db, this._api);

  /// Broadcast of table names touched by local writes — lets screens refresh
  /// without polling (mirrors LocalDatabase.changes).
  @override
  Stream<SyncDataChange> get changes =>
      _db.changes.map(SyncDataChange.fromStorageTables);

  @override
  Future<List<HistoryVisitRecord>> getHistoryRecords() async {
    return HistoryRecordsMapper.fromRows(await _db.getVisits());
  }

  /// User scope used by presentation warm caches. The database owner metadata
  /// stays behind the repository boundary.
  Future<int?> getCurrentUserId() async =>
      (await _db.getCurrentUserOwner()).userId;

  @override
  Future<List<PlannedVisitRecord>> getPlannedVisitRecords() async {
    final rows = await _db.getPlannedVisits();
    return rows
        .map(_mapPlannedVisitRecord)
        .whereType<PlannedVisitRecord>()
        .toList(growable: false);
  }

  @override
  Future<List<PlannedVisitRecord>> getLocalVisitRecords() async {
    final rows = await _db.getVisits();
    return rows
        .map(_mapLocalVisitRecord)
        .whereType<PlannedVisitRecord>()
        .toList(growable: false);
  }

  @override
  Future<List<VisitFormatOption>> getVisitFormats() async {
    final rows = await _db.getVisitFormats();
    return rows
        .map(
          (row) => VisitFormatOption(
            id: _toInt(row['id']) ?? 0,
            name: '${row['name'] ?? ''}'.trim(),
          ),
        )
        .where((format) => format.id > 0 && format.name.isNotEmpty)
        .toList(growable: false);
  }

  @override
  Future<int> savePlannedVisit(PlannedVisitDraft draft) =>
      _db.insertLocalPlannedVisit(PlannedVisitMapper.toLocalRow(draft));

  @override
  Future<void> enqueuePlannedVisit({
    required int localPlanId,
    required PlannedVisitDraft draft,
  }) => _db.enqueuePendingPlan(
    localPlanId: localPlanId,
    orgId: draft.organisationId,
    orgType: draft.organisationType,
    doctorIds: draft.doctorIds,
    visitFormatId: draft.visitFormatId,
    visitDate: draft.visitDate,
    comment: draft.comment,
  );

  static PlannedVisitRecord? _mapPlannedVisitRecord(Map<String, dynamic> row) {
    final localId = _toIntForPlan(row['id']);
    if (localId == null) return null;
    final date = DateTime.tryParse('${row['visit_date'] ?? ''}');
    if (date == null) return null;
    final remoteId = _toIntForPlan(row['remote_id']);
    return PlannedVisitRecord(
      localId: localId,
      remoteId: remoteId,
      organisationName: '${row['org_name'] ?? ''}',
      organisationId: _toIntForPlan(row['org_id']),
      organisationType: '${row['org_type'] ?? 'lpu'}'.toLowerCase(),
      doctorName: _nullableString(row['doctor_name']),
      assignedBy: '${row['assigned_by'] ?? ''}',
      city: _nullableString(row['city']),
      district: _nullableString(row['district']),
      date: date,
      status: VisitStatus.planned,
      visitFormat: _nullableString(row['visit_format']),
    );
  }

  static PlannedVisitRecord? _mapLocalVisitRecord(Map<String, dynamic> row) {
    final localId = _toIntForPlan(row['id']);
    final created = DateTime.tryParse('${row['created_at'] ?? ''}');
    final organisationName = '${row['org_name'] ?? ''}'.trim();
    if (localId == null || created == null || organisationName.isEmpty) {
      return null;
    }
    final status = '${row['status'] ?? 'planned'}'.toLowerCase();
    if (status == 'completed') return null;
    final visitType = '${row['visit_type'] ?? 'lpu'}'.toLowerCase();
    return PlannedVisitRecord(
      localId: localId,
      remoteId: _toIntForPlan(row['remote_id']),
      organisationName: organisationName,
      organisationId: _toIntForPlan(row['org_id']),
      organisationType:
          visitType == 'pharmacy' ||
              visitType == 'order' ||
              visitType == 'circle'
          ? 'pharmacy'
          : 'lpu',
      doctorName: _nullableString(row['doctor_name']),
      assignedBy: 'Локально',
      date: created,
      status: VisitStatus.planned,
      visitFormat: _nullableString(row['visit_format']),
    );
  }

  static int? _toIntForPlan(Object? value) {
    if (value is num) return value.toInt();
    return int.tryParse('$value');
  }

  static String? _nullableString(Object? value) {
    final valueString = '$value'.trim();
    return value == null || valueString.isEmpty || valueString == 'null'
        ? null
        : valueString;
  }

  /// Rows that fail to parse (missing required org_id/org_name/created_at/
  /// updated_at) are silently dropped.
  Future<List<LocalVisit>> getVisitModels({
    bool? unsyncedOnly,
    bool dueForRetryOnly = false,
  }) async {
    final rows = await _db.getVisits(
      unsyncedOnly: unsyncedOnly,
      dueForRetryOnly: dueForRetryOnly,
    );
    return _parseVisits(rows);
  }

  @override
  Future<List<LocalVisit>> getLocalVisitModels() => getVisitModels();

  @override
  Future<LocalVisit?> getLocalVisitById(int id) async {
    final visits = await getVisitModels();
    for (final visit in visits) {
      if (visit.id == id || visit.remoteId == id) return visit;
    }
    return null;
  }

  @override
  Future<void> completeRemoteVisit(VisitCompletionDraft draft) async {
    await _api.updateVisit(
      draft.visitId,
      data: {
        'complete': true,
        'comment': draft.comment,
        'end_date': draft.endedAt.toIso8601String(),
      },
    );
    await _db.updateVisitStatusByRemoteId(
      draft.visitId,
      'completed',
      notes: draft.comment,
    );
  }

  @override
  Future<void> rateRemoteVisit(VisitRatingDraft draft) => _api.rateVisit(
    visitId: draft.visitId,
    rating: draft.rating,
    comment: draft.comment,
  );

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
  }) => _db.updateVisitRemoteId(localVisitId: localVisitId, remoteId: remoteId);

  Future<void> updateVisitRawJson({
    required int localVisitId,
    required String rawJson,
  }) => _db.updateVisitRawJson(localVisitId: localVisitId, rawJson: rawJson);

  Future<void> updateVisitStatusByRemoteId(
    int remoteId,
    String status, {
    String? notes,
  }) => _db.updateVisitStatusByRemoteId(remoteId, status, notes: notes);

  // ── Order (Бронь) API ───────────────────────────────────────────────────

  @override
  Future<PharmacyOrderPricingPreview?> calculatePricing({
    required int prepaymentPercent,
    required bool isWholesaler,
    required PharmacyOrderLines lines,
    int? companyId,
    int paymentVariantId = 1,
    double? orderTotal,
  }) async {
    if (lines.isEmpty) return null;
    final draft = await _api.prepareOrderVisitDraft(
      prepaymentPercent: prepaymentPercent,
      isWholesaler: isWholesaler,
      drugs: lines.map((line) => line.toApiMap()).toList(),
      companyId: companyId,
      paymentVariantId: paymentVariantId,
      orderTotal: orderTotal,
    );
    if (draft == null) return null;

    final marginId = _toInt(draft['margin_id']);
    if (marginId == null) return null;
    final terms = PharmacyOrderPricingTerms(
      companyId: _toInt(draft['company_id']) ?? companyId,
      paymentVariantId: _toInt(draft['payment_variant_id']) ?? paymentVariantId,
      marginId: marginId,
      marginPercent: _toInt(draft['margin_percent']),
      prepaymentPercent: prepaymentPercent,
      isWholesaler: isWholesaler,
    );

    final pricedRows =
        (draft['drugs'] as List?)
            ?.whereType<Map>()
            .map(Map<String, dynamic>.from)
            .toList() ??
        const <Map<String, dynamic>>[];
    final byIncomeDetailingId = <int, Map<String, dynamic>>{
      for (final row in pricedRows)
        if (_toInt(row['income_detailing_id'] ?? row['current_stock_id']) !=
            null)
          _toInt(row['income_detailing_id'] ?? row['current_stock_id'])!: row,
    };
    final pricedLines = lines
        .map((line) {
          final priced = byIncomeDetailingId[line.incomeDetailingId];
          return line.copyWith(
            salePrice: _toDouble(priced?['sale_price']),
            salePriceWithoutNds: _toDouble(priced?['sale_price_without_nds']),
          );
        })
        .toList(growable: false);

    return PharmacyOrderPricingPreview(
      terms: terms,
      lines: List.unmodifiable(pricedLines),
    );
  }

  @override
  Future<bool> supportsWholesaleOrders({int? companyId}) =>
      _api.supportsWholesaleOrders(companyId: companyId);

  Future<Map<String, dynamic>?> _resolveOrderPricingTerms({
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

  @override
  Future<PharmacyOrderPricingTerms?> resolvePricingTerms({
    required int prepaymentPercent,
    required bool isWholesaler,
    required double orderTotal,
    int paymentVariantId = 1,
    int? companyId,
  }) async {
    final terms = await _resolveOrderPricingTerms(
      prepaymentPercent: prepaymentPercent,
      isWholesaler: isWholesaler,
      orderTotal: orderTotal,
      paymentVariantId: paymentVariantId,
      companyId: companyId,
    );
    if (terms == null) return null;
    final marginId = _toInt(terms['margin_id']);
    if (marginId == null) return null;
    return PharmacyOrderPricingTerms(
      companyId: _toInt(terms['company_id']),
      paymentVariantId: _toInt(terms['payment_variant_id']) ?? paymentVariantId,
      marginId: marginId,
      marginPercent: _toInt(terms['margin_percent']),
      prepaymentPercent:
          _toInt(terms['prepayment_percent']) ?? prepaymentPercent,
      isWholesaler: terms['is_wholesaler'] is bool
          ? terms['is_wholesaler'] as bool
          : isWholesaler,
    );
  }

  Future<Map<String, dynamic>> _createOrderVisit({
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

  @override
  Future<PharmacyOrderSubmission> submit({
    required int orderUserId,
    required int organizationId,
    required PharmacyOrderPricingTerms pricingTerms,
    required bool isWholesaler,
    required String orderComment,
    required PharmacyOrderLines lines,
    bool pricesAlreadyCalculated = false,
  }) async {
    try {
      final result = await _createOrderVisit(
        orderUserId: orderUserId,
        organizationId: organizationId,
        companyId: pricingTerms.companyId,
        paymentVariantId: pricingTerms.paymentVariantId,
        marginId: pricingTerms.marginId,
        marginPercent: pricingTerms.marginPercent,
        prepaymentPercent: pricingTerms.prepaymentPercent,
        isWholesaler: isWholesaler,
        orderComment: orderComment,
        drugs: lines.map((line) => line.toApiMap()).toList(),
        pricesAlreadyCalculated: pricesAlreadyCalculated,
      );
      final response = result['response'];
      return PharmacyOrderSubmission(
        request: _asMap(result['request']),
        response: response,
        remoteId: _extractRemoteId(response),
      );
    } catch (error) {
      if (error is PharmacyOrderSubmissionFailure) rethrow;
      final remoteError = error is RemotePushException ? error : null;
      throw PharmacyOrderSubmissionFailure(
        message: remoteError?.displayMessage ?? '$error',
        request: remoteError?.request,
        response: remoteError?.response ?? {'error': '$error'},
        isPermanent: isPermanentVisitPushFailure(error),
      );
    }
  }

  static List<LocalVisit> _parseVisits(List<Map<String, dynamic>> rows) {
    final result = <LocalVisit>[];
    for (final row in rows) {
      try {
        result.add(LocalVisit.fromMap(row));
      } catch (error) {
        // Missing required field (org_id/org_name/created_at/updated_at) —
        // skip rather than crash the list.
        logSwallowed(error, 'VisitsRepositoryImpl.parseVisit');
      }
    }
    return result;
  }

  static int? _toInt(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse('$value');
  }

  static double? _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value == null) return null;
    return double.tryParse('$value');
  }

  static Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map) return Map<String, dynamic>.from(value);
    return const <String, dynamic>{};
  }

  static int? _extractRemoteId(dynamic response) {
    final map = _asMap(response);
    return _toInt(
      map['visit_id'] ??
          map['id'] ??
          (_asMap(map['data'])['visit_id'] ?? _asMap(map['data'])['id']),
    );
  }
}

final visitsRepositoryProvider = Provider<VisitsRepositoryImpl>((ref) {
  return VisitsRepositoryImpl(
    ref.watch(localDatabaseProvider),
    ref.watch(remoteApiServiceProvider),
  );
});

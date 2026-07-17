import 'dart:convert';

import '../../../core/db/local_database.dart';
import '../../../core/models/local_visit.dart';
import '../../../core/network/remote_api_service.dart';
import '../domain/entities/completed_visit.dart';
import '../domain/repositories/visit_write_repository.dart';
import 'completed_visit_mapper.dart';

class VisitWriteRepositoryImpl implements VisitWriteRepository {
  final LocalDatabase _db;
  final RemoteApiService _api;

  VisitWriteRepositoryImpl(this._db, this._api);

  @override
  Future<VisitWriteResult> complete(
    CompletedVisitDraft draft, {
    required bool tryRemote,
  }) async {
    final rawJson = CompletedVisitMapper.toJson(
      draft,
      comment: draft.notes,
      timestamp: draft.createdAt,
    );
    final localId = await _db.insertVisit({
      'remote_id': null,
      'org_id': draft.organizationId,
      'org_name': draft.organizationName,
      'doctor_id': draft.doctorId,
      'doctor_name': draft.doctorName,
      'visit_type': draft.localVisitType,
      'status': 'completed',
      'notes': draft.notes,
      'medical_rep_name': draft.medicalRepName,
      'created_at': draft.createdAt.toIso8601String(),
      'updated_at': draft.updatedAt.toIso8601String(),
      'raw_json': rawJson,
    });

    if (!tryRemote) {
      return VisitWriteResult(
        localId: localId,
        remoteId: null,
        remoteAccepted: false,
        queuedForSync: true,
        remoteError: null,
      );
    }

    final visit = LocalVisit(
      id: localId,
      remoteId: null,
      orgId: draft.organizationId,
      orgName: draft.organizationName,
      doctorId: draft.doctorId,
      doctorName: draft.doctorName,
      visitType: draft.localVisitType,
      status: 'completed',
      notes: draft.notes,
      createdAt: draft.createdAt,
      updatedAt: draft.updatedAt,
      isSynced: false,
      rawJson: rawJson,
      medicalRepName: draft.medicalRepName,
    );

    try {
      final pushResult = await _api.pushUnsyncedVisitDebug(visit);
      final response = pushResult['response'];
      final remoteId = _extractRemoteId(response);
      await _db.markSynced([localId]);
      if (remoteId != null) {
        await _db.updateVisitRemoteId(
          localVisitId: localId,
          remoteId: remoteId,
        );
        if (draft.payload is StockCompletedVisitPayload) {
          await _mergeStockHistory(
            localId: localId,
            remoteId: remoteId,
            fallback: jsonDecode(rawJson),
          );
        }
      }
      await _db.setVisitPushPayload(
        visitId: localId,
        requestJson: jsonEncode(pushResult['request']),
        responseJson: jsonEncode(pushResult['response']),
      );
      return VisitWriteResult(
        localId: localId,
        remoteId: remoteId,
        remoteAccepted: true,
        queuedForSync: false,
        remoteError: null,
      );
    } catch (error) {
      await _db.setVisitPushPayload(
        visitId: localId,
        responseJson: jsonEncode({'error': '$error'}),
      );
      return VisitWriteResult(
        localId: localId,
        remoteId: null,
        remoteAccepted: false,
        queuedForSync: true,
        remoteError: '$error',
      );
    }
  }

  Future<void> _mergeStockHistory({
    required int localId,
    required int remoteId,
    required dynamic fallback,
  }) async {
    final remoteRow = await _api.getVisitHistoryRemnantById(remoteId);
    if (remoteRow == null) return;
    final serverRaw = remoteRow['raw_json'];
    final fallbackMap = fallback is Map
        ? Map<String, dynamic>.from(fallback)
        : const <String, dynamic>{};
    final merged = <String, dynamic>{...fallbackMap};
    if (serverRaw is String && serverRaw.isNotEmpty) {
      final decoded = jsonDecode(serverRaw);
      if (decoded is Map) merged.addAll(Map<String, dynamic>.from(decoded));
    } else {
      merged.addAll(remoteRow);
    }
    final fallbackStockItems = fallbackMap['stock_items'];
    final fallbackDrugs = fallbackMap['drugs'];
    if (fallbackStockItems is List && fallbackStockItems.isNotEmpty) {
      final serverStockItems = merged['stock_items'];
      if (serverStockItems is! List || serverStockItems.isEmpty) {
        merged['stock_items'] = fallbackStockItems;
      }
    }
    if (fallbackDrugs is List && fallbackDrugs.isNotEmpty) {
      final serverDrugs = merged['drugs'];
      if (serverDrugs is! List || serverDrugs.isEmpty) {
        merged['drugs'] = fallbackDrugs;
      }
    }
    await _db.updateVisitRawJson(
      localVisitId: localId,
      rawJson: jsonEncode(merged),
    );
  }

  static int? _extractRemoteId(dynamic response) {
    if (response is num) return response.toInt();
    if (response is String) return int.tryParse(response);
    if (response is! Map) return null;
    final map = Map<String, dynamic>.from(response);
    final data = map['data'];
    if (data is Map) {
      final nested = _extractRemoteId(data);
      if (nested != null) return nested;
    }
    final value = map['visit_id'] ?? map['id'];
    if (value is num) return value.toInt();
    return int.tryParse('$value');
  }
}

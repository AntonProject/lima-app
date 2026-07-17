import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import 'package:lima/core/db/local_database.dart';
import 'package:lima/core/i18n/app_i18n.dart';
import 'package:lima/core/models/models.dart';
import 'package:lima/core/network/api_client.dart';
import 'package:lima/core/network/remote_api_service.dart';
import 'package:lima/core/services/material_cache_service.dart';
import 'package:lima/core/utils/swallowed.dart';

class LiveSyncResult {
  final int visitsCount;
  final int plannedVisitsCount;
  final int materialsCount;
  final int cachedFilesCount;

  const LiveSyncResult({
    required this.visitsCount,
    required this.plannedVisitsCount,
    required this.materialsCount,
    required this.cachedFilesCount,
  });

  const LiveSyncResult.empty()
    : visitsCount = 0,
      plannedVisitsCount = 0,
      materialsCount = 0,
      cachedFilesCount = 0;
}

/// Refreshes mutable server data and writes it to the local database.
///
/// It intentionally owns no sync state, cursor or UI notifications. Each
/// endpoint remains best-effort, so a failure in one live layer does not erase
/// data successfully cached by another layer.
class LiveDataRefreshService {
  final LocalDatabase _db;
  final RemoteApiService _remoteApi;
  final ApiClient _apiClient;
  final int? Function() _currentCompanyId;
  final Future<void> Function() _repairDoctors;

  const LiveDataRefreshService({
    required LocalDatabase db,
    required RemoteApiService remoteApi,
    required ApiClient apiClient,
    required int? Function() currentCompanyId,
    required Future<void> Function() repairDoctors,
  }) : _db = db,
       _remoteApi = remoteApi,
       _apiClient = apiClient,
       _currentCompanyId = currentCompanyId,
       _repairDoctors = repairDoctors;

  Future<LiveSyncResult> refresh({
    bool repairDoctors = true,
    bool quickOnly = false,
  }) async {
    var visitsCount = 0;
    var plannedVisitsCount = 0;
    var materialsCount = 0;
    var cachedFilesCount = 0;

    if (!quickOnly) {
      try {
        final catalogueDrugs = await _remoteApi.getDrugsBindings();
        if (catalogueDrugs.isNotEmpty) {
          final now = DateTime.now().toIso8601String();
          await _db.upsertDrugs(
            catalogueDrugs
                .map(
                  (drug) => <String, dynamic>{
                    'id': drug.id,
                    'name': drug.name,
                    'manufacturer': drug.manufacturer,
                    'binding_drug_id': drug.bindingDrugId,
                    'updated_at': now,
                  },
                )
                .toList(),
          );
        }
      } catch (error) {
        logSwallowed(error, 'LiveDataRefreshService.bindings');
      }

      try {
        final stockDrugs = await _remoteApi.getStockPriceListDrugs();
        if (stockDrugs.isNotEmpty) {
          final now = DateTime.now().toIso8601String();
          await _db.upsertDrugs(
            stockDrugs
                .map(
                  (drug) => <String, dynamic>{
                    'id': drug.id,
                    'name': drug.name,
                    'manufacturer': drug.manufacturer,
                    'price': drug.price,
                    'serial_number': drug.serialNumber ?? '',
                    'expiry_date': drug.expiryDate ?? '',
                    'main_stock': drug.mainStock ?? drug.stock ?? 0,
                    'stock': drug.stock ?? 0,
                    'remains_stock': drug.remainsStock ?? drug.stock ?? 0,
                    'current_stock_id': drug.currentStockId,
                    'binding_drug_id': drug.bindingDrugId,
                    'updated_at': now,
                  },
                )
                .toList(),
          );
        }
      } catch (error) {
        logSwallowed(error, 'LiveDataRefreshService.stock');
      }
    }

    try {
      final favorites = await _remoteApi.getFavoriteDoctors(
        allowDictionaryFallback: !quickOnly,
      );
      if (favorites.isNotEmpty) {
        await _db.clearDoctorFavorites();
        await _db.upsertDoctors(favorites);
        for (final doctor in favorites) {
          final id = doctor['id'] as int?;
          if (id != null) await _db.updateDoctorFavorite(id, true);
        }
      }
    } catch (error) {
      logSwallowed(error, 'LiveDataRefreshService.favoriteDoctors');
    }

    try {
      final favorites = await _remoteApi.getFavoriteOrganizations(
        allowDictionaryFallback: !quickOnly,
      );
      if (favorites.isNotEmpty) {
        await _db.upsertOrganisations(favorites);
        await _db.clearOrgFavorites();
        for (final organization in favorites) {
          final id = (organization['id'] as num?)?.toInt();
          if (id != null) await _db.updateOrgFavorite(id, true);
        }
      }
    } catch (error) {
      logSwallowed(error, 'LiveDataRefreshService.favoriteOrganizations');
    }

    visitsCount = await _refreshHistory();
    plannedVisitsCount = await _refreshPlannedVisits();

    if (!quickOnly) {
      try {
        final docs = await _remoteApi.getDrugDocuments(
          companyId: _currentCompanyId(),
        );
        if (docs.materials.isNotEmpty) {
          await _db.upsertDrugMaterials(docs.materials);
          materialsCount = docs.materials.length;
        }
        await _db.resetAllDrugDocumentsCount();
        for (final entry in docs.counts.entries) {
          await _db.updateDrugDocumentsCount(entry.key, entry.value);
        }
        for (final entry in docs.drugNames.entries) {
          await _db.updateDrugName(entry.key, entry.value);
        }
        final existing = await _db.getDrugs(onlyWithPositivePrice: false);
        final existingIds = existing
            .map((row) => (row['id'] as num?)?.toInt())
            .whereType<int>()
            .toSet();
        final now = DateTime.now().toIso8601String();
        final documentOnly = docs.counts.entries
            .where((entry) => !existingIds.contains(entry.key))
            .map(
              (entry) => <String, dynamic>{
                'id': entry.key,
                'name':
                    docs.drugNames[entry.key] ??
                    AppI18n.tr('drugNumbered', args: {'n': '${entry.key}'}),
                'manufacturer': '',
                'price': 0,
                'serial_number': '',
                'expiry_date': '',
                'main_stock': 0,
                'stock': 0,
                'remains_stock': 0,
                'current_stock_id': null,
                'binding_drug_id': entry.key,
                'documents_count': entry.value,
                'updated_at': now,
              },
            )
            .toList();
        if (documentOnly.isNotEmpty) await _db.upsertDrugs(documentOnly);
      } catch (error) {
        logSwallowed(error, 'LiveDataRefreshService.documents');
      }
    }

    try {
      await _db.setCachedStat(
        'daily_stats',
        await _remoteApi.getDailyVisitStatistics(),
      );
    } catch (error) {
      logSwallowed(error, 'LiveDataRefreshService.dailyStats');
    }

    try {
      final managers = await _remoteApi.getManagers();
      if (managers.isNotEmpty) {
        await _db.upsertManagers(
          managers
              .map(
                (manager) => {
                  'full_name': manager.name,
                  'role': manager.role,
                  'initials': manager.initials,
                  'raw_json': jsonEncode({
                    'name': manager.name,
                    'role': manager.role,
                  }),
                },
              )
              .toList(),
        );
      }
    } catch (error) {
      logSwallowed(error, 'LiveDataRefreshService.managers');
    }

    await _refreshSimpleDictionary(
      label: 'dayTypes',
      load: _remoteApi.getDayTypes,
      save: _db.upsertDayTypes,
    );
    await _refreshSimpleDictionary(
      label: 'visitFormats',
      load: _remoteApi.getVisitFormats,
      save: _db.upsertVisitFormats,
    );

    if (!quickOnly) {
      try {
        final cacheService = MaterialCacheService(
          dio: _apiClient.dio,
          authToken: _apiClient.token,
        );
        cachedFilesCount = await cacheService.downloadPending(_db);
      } catch (error) {
        logSwallowed(error, 'LiveDataRefreshService.materialCache');
      }
    }

    if (repairDoctors) {
      try {
        await _repairDoctors();
      } catch (error) {
        logSwallowed(error, 'LiveDataRefreshService.doctorRepair');
      }
    }

    return LiveSyncResult(
      visitsCount: visitsCount,
      plannedVisitsCount: plannedVisitsCount,
      materialsCount: materialsCount,
      cachedFilesCount: cachedFilesCount,
    );
  }

  Future<int> _refreshHistory() async {
    try {
      final allVisits = <Map<String, dynamic>>[];
      for (final fetch in [
        _remoteApi.getVisitHistoryGeneral,
        _remoteApi.getVisitHistoryOrders,
        _remoteApi.getVisitHistoryRemnant,
      ]) {
        try {
          allVisits.addAll(await fetch());
        } catch (error) {
          logSwallowed(error, 'LiveDataRefreshService.historyEndpoint');
        }
      }
      if (allVisits.isEmpty) return 0;

      final seen = <int>{};
      final deduped = <Map<String, dynamic>>[];
      for (final visit in allVisits.reversed) {
        final remoteId = visit['remote_id'] as int?;
        if (remoteId == null || seen.add(remoteId)) deduped.add(visit);
      }
      final fetchedIds = deduped
          .map((visit) => (visit['remote_id'] as num?)?.toInt())
          .whereType<int>()
          .toSet();
      final pushedRows = await _db.db.query(
        'visits',
        where:
            'is_synced = ? AND remote_id IS NOT NULL AND last_push_response_json IS NOT NULL',
        whereArgs: const [1],
      );
      final pushedByRemoteId = {
        for (final row in pushedRows)
          if ((row['remote_id'] as num?)?.toInt() != null)
            (row['remote_id'] as num).toInt(): row,
      };
      const columns = {
        'remote_id',
        'org_id',
        'org_name',
        'doctor_id',
        'doctor_name',
        'visit_type',
        'status',
        'notes',
        'created_at',
        'updated_at',
        'is_synced',
        'raw_json',
        'last_push_request_json',
        'last_push_response_json',
        'medical_rep_name',
      };
      await _db.db.transaction((txn) async {
        await txn.delete('visits', where: 'is_synced = ?', whereArgs: [1]);
        final batch = txn.batch();
        for (final visit in deduped) {
          final remoteId = (visit['remote_id'] as num?)?.toInt();
          final row = Map<String, dynamic>.from(visit)
            ..['is_synced'] = 1
            ..removeWhere((key, _) => !columns.contains(key));
          final localRow = remoteId == null ? null : pushedByRemoteId[remoteId];
          if (localRow != null) _mergeLocalOrderPushState(row, localRow);
          batch.insert(
            'visits',
            row,
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
        for (final localRow in pushedRows) {
          final remoteId = (localRow['remote_id'] as num?)?.toInt();
          if (remoteId == null || fetchedIds.contains(remoteId)) continue;
          final row = Map<String, dynamic>.from(localRow)
            ..removeWhere((key, _) => !columns.contains(key));
          batch.insert(
            'visits',
            row,
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
        await batch.commit(noResult: true);
      });
      return deduped.length +
          pushedRows.where((row) {
            final remoteId = (row['remote_id'] as num?)?.toInt();
            return remoteId != null && !fetchedIds.contains(remoteId);
          }).length;
    } catch (error) {
      logSwallowed(error, 'LiveDataRefreshService.history');
      return 0;
    }
  }

  Future<int> _refreshPlannedVisits() async {
    try {
      final owner = await _db.getCurrentUserOwner();
      final planned = <Map<String, dynamic>>[];
      var anyFetchSucceeded = false;
      for (final fetch in [
        _remoteApi.getCurrentVisitPlans(null, owner.userId),
        _remoteApi.getVisitPlans(owner.userId),
      ]) {
        try {
          final items = await fetch;
          anyFetchSucceeded = true;
          for (final visit in items) {
            final row = _plannedVisitToRow(visit);
            final remoteId = row['remote_id'];
            if (remoteId == null ||
                !planned.any((item) => item['remote_id'] == remoteId)) {
              planned.add(row);
            }
          }
        } catch (error) {
          logSwallowed(error, 'LiveDataRefreshService.plansEndpoint');
        }
      }
      if (planned.isNotEmpty) await _db.upsertPlannedVisits(planned);
      if (anyFetchSucceeded) {
        await _db.reconcileServerPlannedVisits(
          planned
              .map((row) => (row['remote_id'] as num?)?.toInt())
              .whereType<int>()
              .toSet(),
        );
      }
      return planned.length;
    } catch (error) {
      logSwallowed(error, 'LiveDataRefreshService.plans');
      return 0;
    }
  }

  Future<void> _refreshSimpleDictionary({
    required String label,
    required Future<List<Map<String, dynamic>>> Function() load,
    required Future<void> Function(List<Map<String, dynamic>>) save,
  }) async {
    try {
      final values = await load();
      if (values.isEmpty) return;
      await save(
        values
            .map(
              (value) => {
                'id': value['id'],
                'name': value['name'] ?? value['title'] ?? '${value['id']}',
                'raw_json': jsonEncode(value),
              },
            )
            .toList(),
      );
    } catch (error) {
      logSwallowed(error, 'LiveDataRefreshService.$label');
    }
  }

  static Map<String, dynamic> _plannedVisitToRow(PlannedVisit visit) {
    return {
      'remote_id': visit.id,
      'org_id': visit.organisationId,
      'org_name': visit.organisationName,
      'org_type': visit.organisationType == OrgType.pharmacy
          ? 'pharmacy'
          : 'lpu',
      'doctor_name': visit.doctorName,
      'assigned_by': visit.assignedBy,
      'city': visit.city,
      'visit_date': visit.date.toIso8601String(),
      'status': visit.status == VisitStatus.completed ? 'completed' : 'planned',
    };
  }

  static void _mergeLocalOrderPushState(
    Map<String, dynamic> remoteRow,
    Map<String, dynamic> localRow,
  ) {
    final requestJson = localRow['last_push_request_json'] as String?;
    final responseJson = localRow['last_push_response_json'] as String?;
    if (requestJson != null && requestJson.isNotEmpty) {
      remoteRow['last_push_request_json'] = requestJson;
    }
    if (responseJson != null && responseJson.isNotEmpty) {
      remoteRow['last_push_response_json'] = responseJson;
    }
    final localRaw = _decodeJsonMap(localRow['raw_json'] as String?);
    final request = _decodeJsonMap(requestJson);
    if (localRaw == null && request == null) return;
    final raw =
        _decodeJsonMap(remoteRow['raw_json'] as String?) ?? <String, dynamic>{};

    void copyTerms(Map<String, dynamic>? source) {
      if (source == null) return;
      for (final key in [
        'prepayment',
        'prepayment_percent',
        'buyer_type',
        'is_wholesaler',
        'margin_id',
        'margin_percent',
        'payment_variant_id',
        'company_id',
      ]) {
        if (source.containsKey(key) && source[key] != null) {
          raw[key] = source[key];
        }
      }
      if (source['prepayment_percent'] != null) {
        raw['prepayment'] = source['prepayment_percent'];
      }
      if (!source.containsKey('buyer_type') &&
          source['is_wholesaler'] != null) {
        raw['buyer_type'] = source['is_wholesaler'] == true ? 1 : 0;
      }
    }

    copyTerms(localRaw);
    copyTerms(request);
    if (raw.isNotEmpty) remoteRow['raw_json'] = jsonEncode(raw);
  }

  static Map<String, dynamic>? _decodeJsonMap(String? rawJson) {
    if (rawJson == null || rawJson.isEmpty) return null;
    try {
      final decoded = jsonDecode(rawJson);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (error) {
      logSwallowed(error, 'LiveDataRefreshService.decodeJson');
    }
    return null;
  }
}

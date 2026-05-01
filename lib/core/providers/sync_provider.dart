import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';
import 'package:lima/core/db/local_database.dart';
import 'package:lima/core/models/local_visit.dart';
import 'package:lima/core/models/models.dart';
import 'package:lima/core/network/api_client.dart';
import 'package:lima/core/network/remote_api_service.dart';
import 'package:lima/core/services/in_app_notifications_service.dart';
import 'package:lima/core/services/material_cache_service.dart';
import 'package:lima/core/providers/connectivity_provider.dart';
import 'package:lima/features/auth/providers/auth_provider.dart';

// ─── SyncStatus ───────────────────────────────────────────────────────────────

enum SyncStatus { idle, loading, success, error }

const _fullPullBootstrapKey = 'full_pull_bootstrap_v3_done';

// ─── SyncState ────────────────────────────────────────────────────────────────

class SyncState {
  final SyncStatus status;
  final int unsyncedCount;
  final String? message;
  final DateTime? lastSyncAt;
  final Map<String, dynamic>? lastGetDebug;
  final Map<String, dynamic>? lastPostDebug;

  const SyncState({
    this.status = SyncStatus.idle,
    this.unsyncedCount = 0,
    this.message,
    this.lastSyncAt,
    this.lastGetDebug,
    this.lastPostDebug,
  });

  SyncState copyWith({
    SyncStatus? status,
    int? unsyncedCount,
    String? message,
    DateTime? lastSyncAt,
    Map<String, dynamic>? lastGetDebug,
    Map<String, dynamic>? lastPostDebug,
  }) {
    return SyncState(
      status: status ?? this.status,
      unsyncedCount: unsyncedCount ?? this.unsyncedCount,
      message: message ?? this.message,
      lastSyncAt: lastSyncAt ?? this.lastSyncAt,
      lastGetDebug: lastGetDebug ?? this.lastGetDebug,
      lastPostDebug: lastPostDebug ?? this.lastPostDebug,
    );
  }
}

// ─── SyncNotifier ─────────────────────────────────────────────────────────────

class SyncNotifier extends StateNotifier<SyncState> {
  final LocalDatabase _db;
  final RemoteApiService _remoteApi;
  final ApiClient _apiClient;
  final bool Function() _isOffline;
  final Future<bool> Function() _silentReauth;
  bool _isReconciling = false;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  final InAppNotificationsService _notificationsService =
      InAppNotificationsService();

  SyncNotifier(
    this._db,
    this._remoteApi,
    this._apiClient,
    this._isOffline,
    this._silentReauth,
  ) : super(const SyncState()) {
    _startConnectivityWatcher();
  }

  void _startConnectivityWatcher() {
    _connectivitySub = Connectivity().onConnectivityChanged.listen((results) {
      final online =
          results.isNotEmpty &&
          results.any(
            (r) =>
                r != ConnectivityResult.none &&
                r != ConnectivityResult.bluetooth,
          );
      // Use raw `online` value — don't rely on Riverpod provider which may lag
      if (online && !_isReconciling) {
        // Small delay so the network stack is ready before API calls
        Future.delayed(const Duration(seconds: 2), () {
          if (!_isReconciling) reconcileInBackground();
        });
      }
    });
  }

  @override
  void dispose() {
    _connectivitySub?.cancel();
    super.dispose();
  }

  // ── pullFromRemote ─────────────────────────────────────────────────────────

  /// Fetches the full dataset from the mock remote, seeds the local DB, and
  /// records the sync timestamp in sync_meta.
  Future<void> pullFromRemote({bool fullRefresh = false}) async {
    if (_isOffline()) {
      state = state.copyWith(
        status: SyncStatus.idle,
        message: 'Офлайн режим: загрузка с сервера пропущена',
      );
      return;
    }
    state = state.copyWith(
      status: SyncStatus.loading,
      message: 'Загрузка данных…',
    );

    try {
      if (!fullRefresh) {
        final delta = await _tryDeltaPull();
        if (delta != null) {
          final live = await _syncAllLiveDataFromRemote();
          final now = DateTime.now();
          await _db.setSyncMeta('last_pull_at', now.toIso8601String());
          final unsynced = await _db.unsyncedCount();
          final totals = await _collectLocalTotals();
          state = state.copyWith(
            status: SyncStatus.success,
            unsyncedCount: unsynced,
            message: 'Дельта-синхронизация выполнена',
            lastSyncAt: now,
            lastGetDebug: {
              'ok': true,
              'mode': 'delta',
              'last_sync_id_before': delta.lastSyncIdBefore,
              'last_sync_id_after': delta.lastSyncIdAfter,
              'delta_organizations_count': delta.organizationsCount,
              'delta_doctors_count': delta.doctorsCount,
              'delta_drugs_count': delta.drugsCount,
              'delta_visits_count': live.visitsCount,
              'delta_planned_visits_count': live.plannedVisitsCount,
              'delta_materials_count': live.materialsCount,
              'delta_cached_files_count': live.cachedFilesCount,
              'local_organizations_total': totals.organizations,
              'local_doctors_total': totals.doctors,
              'local_drugs_total': totals.drugs,
              'message': 'Delta sync success',
            },
          );
          await _notificationsService.add(
            title: 'Синхронизация завершена',
            body:
                'Дельта: ЛПУ ${delta.organizationsCount}, врачи ${delta.doctorsCount}, препараты ${delta.drugsCount}.',
            kind: 'sync',
          );
          return;
        }
      }

      final seed = await _remoteApi.fetchOfflineSeed();
      if (fullRefresh) {
        await _db.replaceRemoteSnapshotPreservingUnsynced(
          orgs: seed.orgs,
          doctors: seed.doctors,
          drugs: seed.drugs,
          materials: seed.materials,
          visits: seed.visits,
          plannedVisits: seed.plannedVisits,
          favOrgIds: seed.favOrgIds,
          managers: seed.managers,
          dayTypes: seed.dayTypes,
          dailyStats: seed.dailyStats,
        );
      } else {
        await _db.seedFromRemote(
          orgs: seed.orgs,
          doctors: seed.doctors,
          drugs: seed.drugs,
          materials: seed.materials,
          visits: seed.visits,
          plannedVisits: seed.plannedVisits,
          favOrgIds: seed.favOrgIds,
          managers: seed.managers,
          dayTypes: seed.dayTypes,
          dailyStats: seed.dailyStats,
        );
      }

      final live = await _syncAllLiveDataFromRemote();

      final now = DateTime.now();
      await _db.setSyncMeta('last_pull_at', now.toIso8601String());

      final unsynced = await _db.unsyncedCount();
      final totals = await _collectLocalTotals();

      state = state.copyWith(
        status: SyncStatus.success,
        unsyncedCount: unsynced,
        message:
            '${fullRefresh ? 'Полное обновление' : 'Загружено'}: ${seed.orgs.length} организаций, ${seed.drugs.length} препаратов',
        lastSyncAt: now,
        lastGetDebug: {
          'ok': true,
          'mode': fullRefresh ? 'full_refresh' : 'seed_pull',
          'fetched_organizations_count': seed.orgs.length,
          'fetched_doctors_count': seed.doctors.length,
          'fetched_drugs_count': seed.drugs.length,
          'fetched_materials_count': seed.materials.length,
          'fetched_visits_count': seed.visits.length,
          'live_visits_count': live.visitsCount,
          'live_planned_visits_count': live.plannedVisitsCount,
          'live_materials_count': live.materialsCount,
          'cached_files_count': live.cachedFilesCount,
          'local_organizations_total': totals.organizations,
          'local_doctors_total': totals.doctors,
          'local_drugs_total': totals.drugs,
          'message': 'GET sync success',
        },
      );
      await _notificationsService.add(
        title: fullRefresh
            ? 'Полная синхронизация завершена'
            : 'Синхронизация завершена',
        body:
            'Изменения: ЛПУ ${seed.orgs.length}, врачи ${seed.doctors.length}, препараты ${seed.drugs.length}, визиты ${seed.visits.length}.',
        kind: 'sync',
      );
    } catch (e, st) {
      state = state.copyWith(
        status: SyncStatus.error,
        message: 'Ошибка загрузки: $e',
        lastGetDebug: {'ok': false, 'error': '$e'},
      );
      await _notificationsService.add(
        title: 'Синхронизация с ошибкой',
        body: 'Ошибка синхронизации: $e',
        kind: 'sync',
      );
      // Re-throw so callers can handle if needed.
      Error.throwWithStackTrace(e, st);
    }
  }

  Future<_DeltaPullResult?> _tryDeltaPull() async {
    final syncCursor = await _db.getSyncMeta('last_sync_id');
    final syncId = int.tryParse(syncCursor ?? '');
    try {
      final orgs = await _remoteApi.getOrganizationsSync(syncId: syncId);
      final doctors = await _remoteApi.getDoctorsSync(syncId: syncId);
      final drugs = await _remoteApi.getDrugsSync(syncId: syncId);

      await _db.upsertOrganisations(orgs);
      await _db.upsertDoctors(doctors);
      await _db.upsertDrugs(drugs);
      final maxSyncId = [
        ...orgs.map((e) => e['sync_id'] as int?),
        ...doctors.map((e) => e['sync_id'] as int?),
        ...drugs.map((e) => e['sync_id'] as int?),
      ].whereType<int>().fold<int>(syncId ?? 0, (p, e) => e > p ? e : p);
      if (maxSyncId > 0) {
        await _db.setSyncMeta('last_sync_id', '$maxSyncId');
      }

      return _DeltaPullResult(
        lastSyncIdBefore: syncId,
        lastSyncIdAfter: maxSyncId > 0 ? maxSyncId : syncId,
        organizationsCount: orgs.length,
        doctorsCount: doctors.length,
        drugsCount: drugs.length,
      );
    } catch (_) {
      return null;
    }
  }

  Future<_LocalTotals> _collectLocalTotals() async {
    final db = _db.db;
    final orgs = await db.rawQuery('SELECT COUNT(*) AS c FROM organisations');
    final doctors = await db.rawQuery('SELECT COUNT(*) AS c FROM doctors');
    final drugs = await db.rawQuery('SELECT COUNT(*) AS c FROM drugs');
    return _LocalTotals(
      organizations: (orgs.first['c'] as int?) ?? 0,
      doctors: (doctors.first['c'] as int?) ?? 0,
      drugs: (drugs.first['c'] as int?) ?? 0,
    );
  }

  /// Refreshes all live data that changes frequently: visits, planned visits,
  /// favourite doctors/orgs, daily stats, managers, day types, and materials.
  Future<_LiveSyncResult> _syncAllLiveDataFromRemote() async {
    var visitsCount = 0;
    var plannedVisitsCount = 0;
    var materialsCount = 0;
    var cachedFilesCount = 0;
    // Ensure base directories are present even if user runs only incremental sync.
    try {
      final totals = await _collectLocalTotals();
      if (totals.organizations == 0) {
        final orgs = await _remoteApi.getOrganizationsSync(syncId: null);
        if (orgs.isNotEmpty) {
          await _db.upsertOrganisations(orgs);
        }
      }
      if (totals.doctors == 0) {
        final doctors = await _remoteApi.getDoctorsSync(syncId: null);
        if (doctors.isNotEmpty) {
          await _db.upsertDoctors(doctors);
        }
      }
    } catch (_) {}

    // Price-list drugs — refreshes current_stock_id / binding_drug_id needed for Бронь
    try {
      final stockDrugs = await _remoteApi.getStockPriceListDrugs();
      if (stockDrugs.isNotEmpty) {
        final now = DateTime.now().toIso8601String();
        final rows = stockDrugs
            .map(
              (d) => <String, dynamic>{
                'id': d.id,
                'name': d.name,
                'manufacturer': d.manufacturer,
                'price': d.price,
                'serial_number': d.serialNumber ?? '',
                'expiry_date': d.expiryDate ?? '',
                'stock': d.stock ?? 0,
                'current_stock_id': d.currentStockId,
                'binding_drug_id': d.bindingDrugId,
                'updated_at': now,
              },
            )
            .toList();
        await _db.upsertDrugs(rows);
      }
    } catch (_) {}

    // Favourite doctors
    try {
      final favDoctors = await _remoteApi.getFavoriteDoctors();
      if (favDoctors.isNotEmpty) {
        await _db.clearDoctorFavorites();
        await _db.upsertDoctors(favDoctors);
        for (final d in favDoctors) {
          final id = d['id'] as int?;
          if (id != null) await _db.updateDoctorFavorite(id, true);
        }
      }
    } catch (_) {}

    // Favourite organisations
    try {
      final favOrgs = await _remoteApi.getFavoriteOrganizations();
      if (favOrgs.isNotEmpty) {
        await _db.clearOrgFavorites();
        for (final o in favOrgs) {
          final id = (o['id'] as num?)?.toInt();
          if (id != null) await _db.updateOrgFavorite(id, true);
        }
      }
    } catch (_) {}

    // All visit history
    try {
      final allVisits = <Map<String, dynamic>>[];
      for (final fn in [
        _remoteApi.getVisitHistoryGeneral,
        _remoteApi.getVisitHistoryOrders,
        _remoteApi.getVisitHistoryRemnant,
      ]) {
        try {
          allVisits.addAll(await fn());
        } catch (_) {}
      }
      if (allVisits.isNotEmpty) {
        // Deduplicate by remote_id — last endpoint wins (more specific type)
        final seen = <int>{};
        final deduped = <Map<String, dynamic>>[];
        for (final v in allVisits.reversed) {
          final rid = v['remote_id'] as int?;
          if (rid == null || seen.add(rid)) {
            deduped.add(v);
          }
        }

        const visitColumns = {
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
        await _db.db.delete('visits', where: 'is_synced = ?', whereArgs: [1]);
        final batch = _db.db.batch();
        for (final v in deduped) {
          final row = Map<String, dynamic>.from(v)
            ..['is_synced'] = 1
            ..removeWhere((k, _) => !visitColumns.contains(k));
          batch.insert(
            'visits',
            row,
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
        await batch.commit(noResult: true);
        visitsCount = deduped.length;
      }
    } catch (_) {}

    // Planned visits — convert PlannedVisit model → DB row
    try {
      final planned = <Map<String, dynamic>>[];
      for (final fn in [
        _remoteApi.getCurrentVisitPlans,
        _remoteApi.getVisitPlans,
      ]) {
        try {
          final items = await fn();
          for (final pv in items) {
            final row = _plannedVisitToRow(pv);
            final key = row['remote_id'];
            if (key == null || !planned.any((e) => e['remote_id'] == key)) {
              planned.add(row);
            }
          }
        } catch (_) {}
      }
      if (planned.isNotEmpty) {
        await _db.upsertPlannedVisits(planned);
        plannedVisitsCount = planned.length;
      }
    } catch (_) {}

    // Drug documents/materials + per-drug documents count.
    try {
      final docs = await _remoteApi.getDrugDocuments();
      if (docs.materials.isNotEmpty) {
        await _db.upsertDrugMaterials(docs.materials);
        materialsCount = docs.materials.length;
      }
      for (final e in docs.counts.entries) {
        await _db.updateDrugDocumentsCount(e.key, e.value);
      }
      // Update drug names from documents API (may differ from sync API names)
      for (final e in docs.drugNames.entries) {
        await _db.updateDrugName(e.key, e.value);
      }
    } catch (_) {}

    // Daily stats
    try {
      final stats = await _remoteApi.getDailyVisitStatistics();
      await _db.setCachedStat('daily_stats', stats);
    } catch (_) {}

    // Managers
    try {
      final managers = await _remoteApi.getManagers();
      if (managers.isNotEmpty) {
        final rows = managers
            .map(
              (m) => {
                'full_name': m.name,
                'role': m.role,
                'initials': m.initials,
                'raw_json': '{"name":"${m.name}","role":"${m.role}"}',
              },
            )
            .toList();
        await _db.upsertManagers(rows);
      }
    } catch (_) {}

    // Day types
    try {
      final dayTypes = await _remoteApi.getDayTypes();
      if (dayTypes.isNotEmpty) {
        final rows = dayTypes
            .map(
              (e) => {
                'id': e['id'],
                'name': e['name'] ?? e['title'] ?? '${e['id']}',
                'raw_json': jsonEncode(e),
              },
            )
            .toList();
        await _db.upsertDayTypes(rows);
      }
    } catch (_) {}

    // Download material files for offline access
    try {
      final cacheService = MaterialCacheService(
        dio: _apiClient.dio,
        authToken: _apiClient.token,
      );
      cachedFilesCount = await cacheService.downloadPending(_db);
    } catch (_) {}

    return _LiveSyncResult(
      visitsCount: visitsCount,
      plannedVisitsCount: plannedVisitsCount,
      materialsCount: materialsCount,
      cachedFilesCount: cachedFilesCount,
    );
  }

  // ── pushToRemote ───────────────────────────────────────────────────────────

  static Map<String, dynamic> _plannedVisitToRow(PlannedVisit pv) {
    final orgType = pv.organisationType == OrgType.pharmacy
        ? 'pharmacy'
        : 'lpu';
    return {
      'remote_id': pv.id,
      'org_id': pv.organisationId,
      'org_name': pv.organisationName,
      'org_type': orgType,
      'doctor_name': pv.doctorName,
      'assigned_by': pv.assignedBy,
      'city': pv.city,
      'visit_date': pv.date.toIso8601String(),
      'status': pv.status == VisitStatus.completed ? 'completed' : 'planned',
    };
  }

  /// Pushes all unsynced local visits to the mock remote, then marks them as
  /// synced in the local DB.
  Future<void> pushToRemote() async {
    if (_isOffline()) {
      final count = await _db.unsyncedCount();
      state = state.copyWith(
        status: SyncStatus.idle,
        unsyncedCount: count,
        message: 'Офлайн режим: отправка пропущена',
      );
      return;
    }
    state = state.copyWith(
      status: SyncStatus.loading,
      message: 'Отправка данных…',
    );

    try {
      final unsyncedRows = await _db.getVisits(unsyncedOnly: true);

      final syncedIds = <int>[];
      final failed = <String>[];
      final responses = <Map<String, dynamic>>[];

      for (final row in unsyncedRows) {
        final visit = LocalVisit.fromMap(row);
        try {
          final response = await _remoteApi.pushUnsyncedVisitDebug(visit);
          responses.add({'visit_id': visit.id, ...response});
          if (visit.id != null) {
            await _db.setVisitPushPayload(
              visitId: visit.id!,
              requestJson: jsonEncode(response['request']),
              responseJson: jsonEncode(response['response']),
            );
          }
          if (visit.id != null) syncedIds.add(visit.id!);
        } catch (e) {
          failed.add('visit#${visit.id ?? '-'}: $e');
          responses.add({'visit_id': visit.id, 'ok': false, 'error': '$e'});
          if (visit.id != null) {
            await _db.setVisitPushPayload(
              visitId: visit.id!,
              responseJson: jsonEncode({'error': '$e'}),
            );
          }
        }
      }

      if (syncedIds.isNotEmpty) {
        await _db.markSynced(syncedIds);
      }

      final now = DateTime.now();
      await _db.setSyncMeta('last_push_at', now.toIso8601String());

      final remaining = await _db.unsyncedCount();

      state = state.copyWith(
        status: failed.isEmpty ? SyncStatus.success : SyncStatus.error,
        unsyncedCount: remaining,
        message: failed.isEmpty
            ? (syncedIds.isEmpty
                  ? 'Данные очереди отправлены'
                  : 'Отправлено ${syncedIds.length} визитов')
            : 'Отправлено ${syncedIds.length}, ошибок: ${failed.length}. ${failed.first}',
        lastSyncAt: now,
        lastPostDebug: {
          'ok': failed.isEmpty,
          'synced_count': syncedIds.length,
          'failed_count': failed.length,
          'remaining_unsynced': remaining,
          'responses': responses,
          'message': failed.isEmpty
              ? 'POST sync success'
              : 'POST sync has errors',
        },
      );
      await _notificationsService.add(
        title: failed.isEmpty
            ? (syncedIds.isEmpty
                  ? 'Фоновая синхронизация завершена'
                  : 'Отправка визитов завершена')
            : 'Отправка визитов с ошибками',
        body: failed.isEmpty
            ? (syncedIds.isEmpty
                  ? 'Очередь изменений обработана, осталось: $remaining.'
                  : 'Отправлено: ${syncedIds.length}, осталось: $remaining.')
            : 'Отправлено: ${syncedIds.length}, ошибок: ${failed.length}, осталось: $remaining.',
        kind: 'sync',
      );

      // Flush pending favorites queue
      try {
        final pendingFavs = await _db.getPendingFavorites();
        for (final row in pendingFavs) {
          final id = row['id'] as int;
          final entityType = row['entity_type'] as String;
          final entityId = row['entity_id'] as int;
          final add = row['action'] == 'add';
          try {
            if (entityType == 'doctor') {
              if (add) {
                await _remoteApi.addDoctorToFavorites(entityId);
              } else {
                await _remoteApi.removeDoctorFromFavorites(entityId);
              }
            } else {
              if (add) {
                await _remoteApi.addOrganizationToFavorites(entityId);
              } else {
                await _remoteApi.removeOrganizationFromFavorites(entityId);
              }
            }
            await _db.deletePendingFavorite(id);
          } catch (_) {
            // Keep in queue for next sync attempt
          }
        }
      } catch (_) {}

      // Flush pending feedback queue
      try {
        final pendingFeedback = await _db.getPendingFeedback();
        for (final row in pendingFeedback) {
          final id = row['id'] as int;
          final message = row['message'] as String;
          final rawPaths = row['photo_paths'] as String? ?? '[]';
          final photoPaths = (jsonDecode(rawPaths) as List).cast<String>();
          try {
            await _remoteApi.sendFeedback(
              message: message,
              photoPaths: photoPaths,
            );
            await _db.deletePendingFeedback(id);
            for (final p in photoPaths) {
              try {
                File(p).deleteSync();
              } catch (_) {}
            }
          } catch (_) {
            // Keep in queue for next sync attempt
          }
        }
      } catch (_) {}

      // Flush pending new doctors queue
      try {
        final pendingDoctors = await _db.getPendingDoctors();
        for (final row in pendingDoctors) {
          final id = row['id'] as int;
          final tempLocalId = row['temp_local_id'] as int;
          final orgId = row['org_id'] as int;
          final fullName = row['full_name'] as String;
          final specialty = row['specialty'] as String;
          final phone = row['phone'] as String?;
          try {
            final remoteId = await _remoteApi.addDoctor(
              organizationId: orgId,
              fullName: fullName,
              specialty: specialty,
              phone: phone,
            );
            if (remoteId != null) {
              await _db.replaceDoctorTempId(tempLocalId, remoteId);
              await _db.deletePendingDoctor(id);
            }
          } catch (_) {
            // Keep in queue for next sync attempt
          }
        }
      } catch (_) {}

      // Flush pending organization updates queue
      try {
        final pendingOrgUpdates = await _db.getPendingOrgUpdates();
        for (final row in pendingOrgUpdates) {
          final id = row['id'] as int;
          final orgId = row['org_id'] as int;
          try {
            await _remoteApi.updateOrganization(
              organizationId: orgId,
              name: row['name'] as String,
              address: row['address'] as String,
              phone: row['phone'] as String?,
              city: row['city'] as String?,
              district: row['district'] as String?,
              inn: row['inn'] as String?,
              category: row['category'] as String?,
              responsiblePerson: row['responsible'] as String?,
              latitude: (row['latitude'] as num?)?.toDouble(),
              longitude: (row['longitude'] as num?)?.toDouble(),
            );
            await _db.deletePendingOrgUpdate(id);
          } catch (_) {
            // Keep in queue for next sync attempt
          }
        }
      } catch (_) {}
    } catch (e, st) {
      state = state.copyWith(
        status: SyncStatus.error,
        message: 'Ошибка отправки: $e',
        lastPostDebug: {'ok': false, 'error': '$e'},
      );
      await _notificationsService.add(
        title: 'Ошибка отправки визитов',
        body: '$e',
        kind: 'sync',
      );
      Error.throwWithStackTrace(e, st);
    }
  }

  // ── checkSync ─────────────────────────────────────────────────────────────

  /// Reads the unsynced count from the DB and updates the state.
  Future<void> checkSync() async {
    final count = await _db.unsyncedCount();
    state = state.copyWith(unsyncedCount: count);
  }

  // ── refreshUnsyncedCount ──────────────────────────────────────────────────

  /// Alias for [checkSync] — call after any local write to keep the badge
  /// in the UI up to date.
  Future<void> refreshUnsyncedCount() => checkSync();

  Future<void> ensureBootstrapFullPull() async {
    final done = await _db.getSyncMeta(_fullPullBootstrapKey);
    if (done == '1') return;
    await pullFromRemote(fullRefresh: true);
    await _db.setSyncMeta(_fullPullBootstrapKey, '1');
  }

  Future<void> reconcileInBackground() async {
    if (_isReconciling) return;
    if (_isOffline()) return;
    _isReconciling = true;
    try {
      // If no token (e.g. offline login via cache), re-auth first
      if (!_apiClient.hasToken) {
        final ok = await _silentReauth();
        if (!ok) return;
      }
      await pushToRemote();
      await pullFromRemote();
    } catch (_) {
      // Keep silent: background reconcile should not break UX.
    } finally {
      _isReconciling = false;
    }
  }
}

class _DeltaPullResult {
  final int? lastSyncIdBefore;
  final int? lastSyncIdAfter;
  final int organizationsCount;
  final int doctorsCount;
  final int drugsCount;

  const _DeltaPullResult({
    required this.lastSyncIdBefore,
    required this.lastSyncIdAfter,
    required this.organizationsCount,
    required this.doctorsCount,
    required this.drugsCount,
  });
}

class _LocalTotals {
  final int organizations;
  final int doctors;
  final int drugs;

  const _LocalTotals({
    required this.organizations,
    required this.doctors,
    required this.drugs,
  });
}

class _LiveSyncResult {
  final int visitsCount;
  final int plannedVisitsCount;
  final int materialsCount;
  final int cachedFilesCount;

  const _LiveSyncResult({
    required this.visitsCount,
    required this.plannedVisitsCount,
    required this.materialsCount,
    required this.cachedFilesCount,
  });
}

// ─── Provider ────────────────────────────────────────────────────────────────

final syncProvider = StateNotifierProvider<SyncNotifier, SyncState>((ref) {
  return SyncNotifier(
    ref.watch(localDatabaseProvider),
    ref.watch(remoteApiServiceProvider),
    ref.watch(apiClientProvider),
    () => ref.read(isOfflineProvider),
    () => ref.read(authProvider.notifier).silentReauth(),
  );
});

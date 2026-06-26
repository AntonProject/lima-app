import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';
import 'package:lima/core/config/env_config.dart';
import 'package:lima/core/i18n/app_i18n.dart';
import 'package:lima/core/db/local_database.dart';
import 'package:lima/core/models/local_visit.dart';
import 'package:lima/core/models/models.dart';
import 'package:lima/core/network/api_client.dart';
import 'package:lima/core/network/remote_api_service.dart';
import 'package:lima/core/services/in_app_notifications_service.dart';
import 'package:lima/core/services/material_cache_service.dart';
import 'package:lima/core/utils/swallowed.dart';
import 'package:lima/core/providers/connectivity_provider.dart';
import 'package:lima/features/auth/providers/auth_provider.dart';

// ─── SyncStatus ───────────────────────────────────────────────────────────────

enum SyncStatus { idle, loading, success, error }

enum SyncOperation { pull, fullRefresh, push }

const _fullPullBootstrapKey = 'full_pull_bootstrap_v4_all_regions_done';
const _organizationDirectoryBootstrapKey =
    'organization_directory_bootstrap_v1_all_regions_done';
// Timestamp of the last full organisation dictionary pull, and how often to
// force one so orgs with sync_id = null (which the delta sync skips) still land.
const _organizationDirectoryFullPullAtKey = 'organization_directory_full_pull_at';
const _organizationDirectoryFullPullInterval = Duration(hours: 24);
const _doctorDirectoryBootstrapKey = 'doctor_directory_bootstrap_v1_done';
const _doctorDirectoryExpectedTotalKey = 'doctor_directory_expected_total';
const _doctorDirectoryCursorKey = 'doctor_directory_sync_id';
const _lastAppActivityKey = 'last_app_activity_at';
const _lastDeltaPullKey = 'last_delta_pull_at';
const _minimumUsableLpuDirectorySize = 100;
const _minimumUsablePharmacyDirectorySize = 100;

// ─── SyncState ────────────────────────────────────────────────────────────────

class SyncState {
  final SyncStatus status;
  final int unsyncedCount;
  final String? message;
  final DateTime? lastSyncAt;
  final Map<String, dynamic>? lastGetDebug;
  final Map<String, dynamic>? lastPostDebug;
  final int? progressCurrent;
  final int? progressTotal;
  final SyncOperation? activeOperation;

  const SyncState({
    this.status = SyncStatus.idle,
    this.unsyncedCount = 0,
    this.message,
    this.lastSyncAt,
    this.lastGetDebug,
    this.lastPostDebug,
    this.progressCurrent,
    this.progressTotal,
    this.activeOperation,
  });

  SyncState copyWith({
    SyncStatus? status,
    int? unsyncedCount,
    String? message,
    DateTime? lastSyncAt,
    Map<String, dynamic>? lastGetDebug,
    Map<String, dynamic>? lastPostDebug,
    int? progressCurrent,
    int? progressTotal,
    SyncOperation? activeOperation,
    bool clearProgress = false,
    bool clearActiveOperation = false,
  }) {
    return SyncState(
      status: status ?? this.status,
      unsyncedCount: unsyncedCount ?? this.unsyncedCount,
      message: message ?? this.message,
      lastSyncAt: lastSyncAt ?? this.lastSyncAt,
      lastGetDebug: lastGetDebug ?? this.lastGetDebug,
      lastPostDebug: lastPostDebug ?? this.lastPostDebug,
      progressCurrent: clearProgress
          ? null
          : progressCurrent ?? this.progressCurrent,
      progressTotal: clearProgress ? null : progressTotal ?? this.progressTotal,
      activeOperation: clearActiveOperation
          ? null
          : activeOperation ?? this.activeOperation,
    );
  }
}

// ─── SyncNotifier ─────────────────────────────────────────────────────────────

class SyncNotifier extends StateNotifier<SyncState> {
  /// After this many failed push attempts a visit is treated as permanently
  /// stuck: it is removed from the queue and surfaced in the sync report
  /// instead of being retried forever.
  static const int _maxPushAttempts = 8;

  final LocalDatabase _db;
  final RemoteApiService _remoteApi;
  final ApiClient _apiClient;
  final bool Function() _isOffline;
  final Future<bool> Function() _silentReauth;
  final int? Function() _currentRegionId;
  final int? Function() _currentCompanyId;
  bool _isReconciling = false;
  bool _reconcilePending = false;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  final InAppNotificationsService _notificationsService =
      InAppNotificationsService();

  SyncNotifier(
    this._db,
    this._remoteApi,
    this._apiClient,
    this._isOffline,
    this._silentReauth,
    this._currentRegionId,
    this._currentCompanyId,
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
        // Small delay so the network stack is ready before API calls.
        Future.delayed(const Duration(seconds: 2), () async {
          if (_isReconciling) return;
          // A connectivity transition (e.g. Wi-Fi without internet) does not
          // guarantee real reachability — verify before kicking off a sync.
          if (await _hasRealInternet()) {
            reconcileInBackground();
          }
        });
      }
    });
  }

  /// Verifies actual internet reachability via a DNS lookup, not just the
  /// connectivity layer (which reports "connected" for Wi-Fi without internet).
  Future<bool> _hasRealInternet() async {
    try {
      final result = await InternetAddress.lookup(
        EnvConfig.connectivityHost,
      ).timeout(const Duration(seconds: 5));
      return result.isNotEmpty && result.first.rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  @override
  void dispose() {
    _connectivitySub?.cancel();
    super.dispose();
  }

  // ── pullFromRemote ─────────────────────────────────────────────────────────

  /// Fetches the full dataset from the mock remote, seeds the local DB, and
  /// records the sync timestamp in sync_meta.
  Future<void> pullFromRemote({
    bool fullRefresh = false,
    bool includeDoctors = true,
    bool repairDoctors = true,
    bool pushPendingFirst = true,
    bool deltaOnly = false,
  }) async {
    if (state.activeOperation != null) return;
    if (_isOffline()) {
      state = state.copyWith(
        status: SyncStatus.idle,
        message: AppI18n.tr('syncOfflineSkipped'),
        clearActiveOperation: true,
      );
      return;
    }
    if (pushPendingFirst) {
      final canPull = await _pushPendingBeforePull(fullRefresh: fullRefresh);
      if (!canPull) return;
    }
    final startingTotals = await _collectLocalTotals();
    if (!await _hasBaseDirectory(startingTotals)) {
      fullRefresh = true;
      deltaOnly = false;
      includeDoctors = true;
      repairDoctors = true;
    }
    state = state.copyWith(
      status: SyncStatus.loading,
      activeOperation: fullRefresh
          ? SyncOperation.fullRefresh
          : SyncOperation.pull,
      message: fullRefresh
          ? AppI18n.tr('syncFullPrep')
          : AppI18n.tr('syncCheckDelta'),
      clearProgress: true,
    );

    try {
      final companyId = _currentCompanyId();
      if (!fullRefresh) {
        final delta = await _tryDeltaPull(
          includeDoctors: includeDoctors,
        ).timeout(const Duration(seconds: 25), onTimeout: () => null);
        if (delta != null) {
          // Cooldown: skip the (heavy) live-data refresh if it ran < 30s ago.
          // Avoids re-downloading the visit/plan/material set on every hot
          // reload or quick app restart.
          final lastPullRaw = await _db.getSyncMeta('last_pull_at');
          final lastPullAt = DateTime.tryParse(lastPullRaw ?? '');
          final liveStale =
              lastPullAt == null ||
              DateTime.now().difference(lastPullAt) >
                  const Duration(seconds: 30);
          state = state.copyWith(
            status: SyncStatus.loading,
            message: liveStale
                ? AppI18n.tr('syncDeltaGotUpdating')
                : AppI18n.tr('syncDeltaGotFresh'),
            clearProgress: true,
          );
          final live = liveStale
              ? await _syncAllLiveDataFromRemote(repairDoctors: repairDoctors)
              : _LiveSyncResult.empty();
          final now = DateTime.now();
          await _db.setSyncMeta('last_pull_at', now.toIso8601String());
          await _db.setSyncMeta('last_delta_pull_at', now.toIso8601String());
          final unsynced = await _db.unsyncedCount();
          final totals = await _collectLocalTotals();
          final deltaOrgCounts = _countOrgTypes(delta.organizations);
          state = state.copyWith(
            status: SyncStatus.success,
            clearProgress: true,
            clearActiveOperation: true,
            unsyncedCount: unsynced,
            message: AppI18n.tr('syncDeltaDone'),
            lastSyncAt: now,
            lastGetDebug: {
              'ok': true,
              'mode': 'delta',
              'company_id': companyId,
              'include_doctors': includeDoctors,
              'last_sync_id_before': delta.lastSyncIdBefore,
              'last_sync_id_after': delta.lastSyncIdAfter,
              'delta_organizations_count': delta.organizationsCount,
              'delta_lpu_count': deltaOrgCounts.lpu,
              'delta_pharmacy_count': deltaOrgCounts.pharmacy,
              'delta_distributor_count': deltaOrgCounts.distributor,
              'delta_other_organizations_count': deltaOrgCounts.other,
              'delta_doctors_count': delta.doctorsCount,
              'delta_drugs_count': delta.drugsCount,
              'delta_visits_count': live.visitsCount,
              'delta_planned_visits_count': live.plannedVisitsCount,
              'delta_materials_count': live.materialsCount,
              'delta_cached_files_count': live.cachedFilesCount,
              'local_organizations_total': totals.organizations,
              'local_lpu_total': totals.lpu,
              'local_pharmacy_total': totals.pharmacy,
              'local_distributor_total': totals.distributor,
              'local_other_organizations_total': totals.otherOrganizations,
              'local_doctors_total': totals.doctors,
              'local_drugs_total': totals.drugs,
              'local_materials_total': totals.materials,
              'local_visits_total': totals.visits,
              'local_planned_visits_total': totals.plannedVisits,
              'message': 'Delta sync success',
            },
          );
          _drainPendingReconcile();
          return;
        }
        if (deltaOnly) {
          final now = DateTime.now();
          final unsynced = await _db.unsyncedCount();
          final totals = await _collectLocalTotals();
          state = state.copyWith(
            status: SyncStatus.success,
            clearProgress: true,
            clearActiveOperation: true,
            unsyncedCount: unsynced,
            message: AppI18n.tr('syncDeltaUnavailNoFull'),
            lastSyncAt: now,
            lastGetDebug: {
              'ok': false,
              'mode': 'delta_unavailable',
              'company_id': companyId,
              'include_doctors': includeDoctors,
              'local_organizations_total': totals.organizations,
              'local_lpu_total': totals.lpu,
              'local_pharmacy_total': totals.pharmacy,
              'local_distributor_total': totals.distributor,
              'local_other_organizations_total': totals.otherOrganizations,
              'local_doctors_total': totals.doctors,
              'local_drugs_total': totals.drugs,
              'local_materials_total': totals.materials,
              'local_visits_total': totals.visits,
              'local_planned_visits_total': totals.plannedVisits,
              'message': 'Delta unavailable; seed skipped',
            },
          );
          return;
        }
        state = state.copyWith(
          status: SyncStatus.loading,
          message: AppI18n.tr('syncDeltaUnavailLoadingFull'),
          clearProgress: true,
        );
      }

      final regionId = _currentRegionId();
      final seed = await _remoteApi.fetchOfflineSeed(
        regionId: regionId,
        companyId: companyId,
        includeDoctors: includeDoctors,
        onProgress: _setPullProgress,
      );
      final localTotalsBeforeReplace = await _collectLocalTotals();
      if (seed.orgs.isEmpty) {
        throw StateError(
          localTotalsBeforeReplace.organizations > 0
              ? AppI18n.tr('syncEmptyOrgsKept')
              : AppI18n.tr('syncEmptyOrgsEmpty'),
        );
      }
      state = state.copyWith(
        status: SyncStatus.loading,
        message: fullRefresh
            ? AppI18n.tr('syncWritingFull')
            : AppI18n.tr('syncWriting'),
        clearProgress: true,
      );
      await _db.replaceRemoteSnapshotPreservingUnsynced(
        orgs: seed.orgs,
        doctors: seed.doctors,
        doctorOrgLinks: seed.doctorOrgLinks,
        replaceDoctors: includeDoctors,
        drugs: seed.drugs,
        materials: seed.materials,
        visits: seed.visits,
        plannedVisits: seed.plannedVisits,
        favOrgIds: seed.favOrgIds,
        managers: seed.managers,
        dayTypes: seed.dayTypes,
        dailyStats: seed.dailyStats,
      );

      final live = await _syncAllLiveDataFromRemote(
        repairDoctors: repairDoctors,
      );

      final now = DateTime.now();
      await _db.setSyncMeta('last_pull_at', now.toIso8601String());
      await _db.setSyncMeta('last_delta_pull_at', now.toIso8601String());
      final currentSyncId =
          int.tryParse(await _db.getSyncMeta('last_sync_id') ?? '') ?? 0;
      final seedSyncId = _maxSyncId(
        seed.orgs,
        seed.doctors,
        seed.doctorOrgLinks,
        seed.drugs,
      );
      final localSyncId = await _db.getMaxLocalSyncId();
      final nextSyncId = [
        currentSyncId,
        seedSyncId,
        localSyncId,
      ].fold<int>(0, (max, value) => value > max ? value : max);
      if (nextSyncId > 0) {
        await _db.setSyncMeta('last_sync_id', '$nextSyncId');
      }

      final unsynced = await _db.unsyncedCount();
      final totals = await _collectLocalTotals();
      final fetchedOrgCounts = _countOrgTypes(seed.orgs);
      if (totals.lpu > 0 && totals.pharmacy > 0) {
        await _db.setSyncMeta(_organizationDirectoryBootstrapKey, '1');
      }
      if (totals.doctors > 0 && await _doctorLinksCount() > 0) {
        await _db.setSyncMeta(_doctorDirectoryBootstrapKey, '1');
      }

      state = state.copyWith(
        status: SyncStatus.success,
        clearProgress: true,
        clearActiveOperation: true,
        unsyncedCount: unsynced,
        message: AppI18n.tr('syncCountsSummary', args: {
          'mode': fullRefresh
              ? AppI18n.tr('syncModeFull')
              : AppI18n.tr('syncModeLoaded'),
          'lpu': '${fetchedOrgCounts.lpu}',
          'pharmacy': '${fetchedOrgCounts.pharmacy}',
          'drugs': '${seed.drugs.length}',
        }),
        lastSyncAt: now,
        lastGetDebug: {
          'ok': true,
          'mode': fullRefresh ? 'full_refresh' : 'seed_pull',
          'region_id': regionId,
          'company_id': companyId,
          'include_doctors': includeDoctors,
          'last_sync_id_after': nextSyncId > 0 ? nextSyncId : null,
          'fetched_organizations_count': seed.orgs.length,
          'fetched_lpu_count': fetchedOrgCounts.lpu,
          'fetched_pharmacy_count': fetchedOrgCounts.pharmacy,
          'fetched_distributor_count': fetchedOrgCounts.distributor,
          'fetched_other_organizations_count': fetchedOrgCounts.other,
          'fetched_doctors_count': seed.doctors.length,
          'fetched_drugs_count': seed.drugs.length,
          'fetched_materials_count': seed.materials.length,
          'fetched_visits_count': seed.visits.length,
          'live_visits_count': live.visitsCount,
          'live_planned_visits_count': live.plannedVisitsCount,
          'live_materials_count': live.materialsCount,
          'cached_files_count': live.cachedFilesCount,
          'local_organizations_total': totals.organizations,
          'local_lpu_total': totals.lpu,
          'local_pharmacy_total': totals.pharmacy,
          'local_distributor_total': totals.distributor,
          'local_other_organizations_total': totals.otherOrganizations,
          'local_doctors_total': totals.doctors,
          'local_drugs_total': totals.drugs,
          'local_materials_total': totals.materials,
          'local_visits_total': totals.visits,
          'local_planned_visits_total': totals.plannedVisits,
          'message': 'GET sync success',
        },
      );
      _drainPendingReconcile();
    } catch (e, st) {
      state = state.copyWith(
        status: SyncStatus.error,
        message: AppI18n.tr('syncLoadError', args: {'e': '$e'}),
        lastGetDebug: {'ok': false, 'error': '$e'},
        clearProgress: true,
        clearActiveOperation: true,
      );
      _drainPendingReconcile();
      // Re-throw so callers can handle if needed.
      Error.throwWithStackTrace(e, st);
    }
  }

  void startLayeredSyncInBackground({bool fullRefresh = false}) {
    if (_isOffline() || state.activeOperation != null) return;
    if (fullRefresh) {
      unawaited(
        syncLayeredFromRemote(fullRefresh: true, pushPendingFirst: false),
      );
      return;
    }
    unawaited(syncLaunchDeltaIfNeeded());
  }

  /// Starts the doctors-only sync in the background (fire-and-forget).
  /// Silent — does not update sync state, so it can run in parallel with the
  /// main critical sync without causing UI flicker or state conflicts.
  void syncDoctorsInBackground() {
    unawaited(_syncDoctorsBackground());
  }

  /// When true, [_publishLayerProgress] calls coming from the doctors
  /// background path are suppressed so the main sync's state stays clean.
  bool _doctorsSilent = false;

  Future<void> _syncDoctorsBackground() async {
    _doctorsSilent = true;
    try {
      final syncId = await _currentSyncId();
      final initialTotals = await _collectLocalTotals();
      final needsRepair = await _doctorDirectoryNeedsRepair(
        totals: initialTotals,
      );
      final doctorBootstrapped = await _isDoctorDirectoryBootstrapped();
      final hasLegacyComplete =
          !doctorBootstrapped && initialTotals.doctors > 5000;
      if (hasLegacyComplete) await _markDoctorDirectoryBootstrapped();

      await _syncDoctorsLayer(
        syncId: needsRepair ? null : (syncId > 0 ? syncId : null),
        forceFull: needsRepair,
      );

      final nextSyncId = [
        syncId,
        await _db.getMaxLocalSyncId(),
      ].fold<int>(0, (max, value) => value > max ? value : max);
      if (nextSyncId > 0) {
        await _db.setSyncMeta('last_sync_id', '$nextSyncId');
      }
      // Finalize the sync UI. The layered main sync (skipDoctors:true) leaves
      // the pull/fullRefresh operation active on purpose so the loading card
      // stays up until doctors — the last layer — finish here. Clear it now so
      // the spinner/progress card stops and the status reads "done".
      // A concurrent push must not be clobbered, so only finalize when the
      // active operation is a pull/fullRefresh (or already idle).
      final op = state.activeOperation;
      if (op == null ||
          op == SyncOperation.pull ||
          op == SyncOperation.fullRefresh) {
        final unsynced = await _db.unsyncedCount();
        state = state.copyWith(
          status: SyncStatus.success,
          clearProgress: true,
          clearActiveOperation: true,
          unsyncedCount: unsynced,
          lastSyncAt: DateTime.now(),
          message: AppI18n.tr('syncDataUpdated'),
        );
      }
      _drainPendingReconcile();
    } catch (_) {
      _drainPendingReconcile();
    } finally {
      _doctorsSilent = false;
    }
  }

  Future<void> syncLayeredFromRemote({
    bool fullRefresh = false,
    bool pushPendingFirst = true,
    bool skipDoctors = false,
    // When true (used on the splash for a fast launch) only the live/home layer
    // (visits + planned visits) is awaited; the heavier organisation directory
    // and full drug catalogue continue loading in the background after the user
    // is already on /home. Ignored on a first run (empty DB) where that data is
    // needed up front to create visits.
    bool homeOnly = false,
  }) async {
    if (state.activeOperation != null) return;
    if (_isOffline()) {
      await refreshUnsyncedCount();
      state = state.copyWith(
        status: SyncStatus.idle,
        message: AppI18n.tr('syncOfflineSkipped'),
        clearActiveOperation: true,
      );
      return;
    }
    if (pushPendingFirst) {
      final canPull = await _pushPendingBeforePull(fullRefresh: fullRefresh);
      if (!canPull) return;
    }

    final companyId = _currentCompanyId();
    final initialTotals = await _collectLocalTotals();
    final isFirstRun =
        initialTotals.organizations == 0 &&
        initialTotals.doctors == 0 &&
        initialTotals.drugs == 0;
    final initialMessage = isFirstRun
        ? AppI18n.tr('syncLoadingData')
        : AppI18n.tr('syncUpdatingDataEllipsis');

    state = state.copyWith(
      status: SyncStatus.loading,
      activeOperation: fullRefresh
          ? SyncOperation.fullRefresh
          : SyncOperation.pull,
      message: initialMessage,
      clearProgress: true,
    );

    try {
      final syncId = await _currentSyncId();

      // ── Parallel layers: live + orgs + drugs ───────────────────────────────
      final orgBootstrapped =
          await _db.getSyncMeta(_organizationDirectoryBootstrapKey) == '1';
      // The delta sync only returns rows with a sync_id greater than the cursor;
      // server-side orgs that have sync_id = null (e.g. freshly created) are
      // never delivered by it. Periodically force a full dictionary pull so such
      // organisations still land locally even without a first run.
      final lastFullOrgPull = DateTime.tryParse(
        await _db.getSyncMeta(_organizationDirectoryFullPullAtKey) ?? '',
      );
      final fullOrgPullStale =
          lastFullOrgPull == null ||
          DateTime.now().difference(lastFullOrgPull) >
              _organizationDirectoryFullPullInterval;
      final forceFullOrganizations =
          fullRefresh ||
          !orgBootstrapped ||
          fullOrgPullStale ||
          initialTotals.lpu < _minimumUsableLpuDirectorySize ||
          initialTotals.pharmacy < _minimumUsablePharmacyDirectorySize;

      final liveFuture = _syncAllLiveDataFromRemote(
        repairDoctors: false,
        quickOnly: true,
      );
      final orgsFuture =
          (forceFullOrganizations
                  ? _remoteApi.getOrganizationsDictionary()
                  : _remoteApi.getOrganizationsSync(
                      syncId: syncId > 0 ? syncId : null,
                    ))
              .then((orgs) async {
                if (orgs.isNotEmpty) await _db.upsertOrganisations(orgs);
                return orgs;
              });
      final drugsFuture = _syncDrugsAndMaterialsLayer(companyId: companyId);

      // ── Fast home-only path (splash, warm start) ────────────────────────────
      // Await only the live/home layer and let the heavy directory + catalogue
      // layers finish in the background so the user reaches /home in ~5–10s.
      // On a first run (empty DB) we skip this and load everything up front.
      if (homeOnly && !isFirstRun) {
        final live = await liveFuture;
        // Don't drop the directory/catalogue work — keep it running and persist
        // metadata once it lands, without blocking the splash.
        unawaited(() async {
          try {
            final orgs = await orgsFuture;
            final drugs = await drugsFuture;
            if (forceFullOrganizations) {
              final orgTotalsCheck = await _collectLocalTotals();
              if (orgTotalsCheck.lpu > 0 && orgTotalsCheck.pharmacy > 0) {
                await _db.setSyncMeta(_organizationDirectoryBootstrapKey, '1');
                await _db.setSyncMeta(
                  _organizationDirectoryFullPullAtKey,
                  DateTime.now().toIso8601String(),
                );
              }
            }
            final maxSyncId = _maxSyncId(orgs, const [], const [], drugs.$3);
            final nextSyncId = [
              syncId,
              maxSyncId,
              await _db.getMaxLocalSyncId(),
            ].fold<int>(0, (max, value) => value > max ? value : max);
            if (nextSyncId > 0) {
              await _db.setSyncMeta('last_sync_id', '$nextSyncId');
            }
            final now = DateTime.now();
            await _db.setSyncMeta('last_pull_at', now.toIso8601String());
            await _db.setSyncMeta('last_delta_pull_at', now.toIso8601String());
            await refreshUnsyncedCount();
          } catch (e) {
            logSwallowed(e, 'Sync.syncLayeredFromRemote.homeOnlyBackground');
          }
        }());

        final unsynced = await _db.unsyncedCount();
        state = state.copyWith(
          // skipDoctors is true on the splash → keep the loading label honest
          // while doctors + directory finish in the background.
          status: skipDoctors ? SyncStatus.loading : SyncStatus.success,
          clearProgress: true,
          clearActiveOperation: !skipDoctors,
          unsyncedCount: unsynced,
          message: skipDoctors
              ? AppI18n.tr('syncLoadingDoctorsRef')
              : AppI18n.tr('syncDone'),
          lastGetDebug: {
            'ok': true,
            'mode': 'layered_home_only',
            'live_visits_count': live.visitsCount,
            'live_planned_visits_count': live.plannedVisitsCount,
          },
        );
        _drainPendingReconcile();
        return;
      }

      final live = await liveFuture;
      final orgs = await orgsFuture;
      final drugs = await drugsFuture;

      if (forceFullOrganizations) {
        final orgTotalsCheck = await _collectLocalTotals();
        if (orgTotalsCheck.lpu > 0 && orgTotalsCheck.pharmacy > 0) {
          await _db.setSyncMeta(_organizationDirectoryBootstrapKey, '1');
          await _db.setSyncMeta(
            _organizationDirectoryFullPullAtKey,
            DateTime.now().toIso8601String(),
          );
        }
      }

      // ── Doctors layer (skipped when skipDoctors=true — loaded in background) ─
      (int, List<Map>, List<Map>) doctorCounts;
      if (skipDoctors) {
        doctorCounts = (
          0,
          const <Map<String, dynamic>>[],
          const <Map<String, dynamic>>[],
        );
      } else {
        state = state.copyWith(
          status: SyncStatus.loading,
          message: AppI18n.tr('syncLoadingDoctors'),
          clearProgress: true,
        );
        final doctorBootstrapped = await _isDoctorDirectoryBootstrapped();
        final needsDoctorRepair = await _doctorDirectoryNeedsRepair(
          totals: initialTotals,
        );
        final hasLegacyCompleteDoctors =
            !doctorBootstrapped && initialTotals.doctors > 5000;
        if (hasLegacyCompleteDoctors) {
          await _markDoctorDirectoryBootstrapped();
        }
        final forceFullDoctors = fullRefresh || needsDoctorRepair;
        final doctorSyncId = forceFullDoctors
            ? null
            : (syncId > 0 ? syncId : null);
        doctorCounts = await _syncDoctorsLayer(
          syncId: doctorSyncId,
          forceFull: forceFullDoctors,
        );
      }

      final maxSyncId = _maxSyncId(
        orgs,
        doctorCounts.$3,
        doctorCounts.$2,
        drugs.$3,
      );
      final nextSyncId = [
        syncId,
        maxSyncId,
        await _db.getMaxLocalSyncId(),
      ].fold<int>(0, (max, value) => value > max ? value : max);
      if (nextSyncId > 0) {
        await _db.setSyncMeta('last_sync_id', '$nextSyncId');
      }

      final now = DateTime.now();
      await _db.setSyncMeta('last_pull_at', now.toIso8601String());
      await _db.setSyncMeta('last_delta_pull_at', now.toIso8601String());
      final totals = await _collectLocalTotals();
      final unsynced = await _db.unsyncedCount();
      state = state.copyWith(
        status: skipDoctors ? SyncStatus.loading : SyncStatus.success,
        clearProgress: true,
        clearActiveOperation: skipDoctors ? false : true,
        unsyncedCount: unsynced,
        lastSyncAt: skipDoctors ? null : now,
        // While doctors still load in the background keep an honest "in
        // progress" label — the loading card/spinner is still visible.
        message: skipDoctors
            ? AppI18n.tr('syncLoadingDoctorsRef')
            : AppI18n.tr('syncDone'),
        lastGetDebug: {
          'ok': true,
          'mode': fullRefresh ? 'layered_full' : 'layered_delta',
          'skip_doctors': skipDoctors,
          'company_id': companyId,
          'last_sync_id_after': nextSyncId > 0 ? nextSyncId : null,
          'local_organizations_total': totals.organizations,
          'local_lpu_total': totals.lpu,
          'local_pharmacy_total': totals.pharmacy,
          'local_distributor_total': totals.distributor,
          'local_doctors_total': totals.doctors,
          'local_drugs_total': totals.drugs,
          'local_materials_total': totals.materials,
          'local_visits_total': totals.visits,
          'local_planned_visits_total': totals.plannedVisits,
          'live_visits_count': live.visitsCount,
          'live_planned_visits_count': live.plannedVisitsCount,
          'fetched_doctors_count': doctorCounts.$1,
          'message': 'Layered sync success',
        },
      );
      _drainPendingReconcile();
    } catch (e, st) {
      state = state.copyWith(
        status: SyncStatus.error,
        message: AppI18n.tr('syncLoadError', args: {'e': '$e'}),
        lastGetDebug: {'ok': false, 'error': '$e'},
        clearProgress: true,
        clearActiveOperation: true,
      );
      _drainPendingReconcile();
      Error.throwWithStackTrace(e, st);
    }
  }

  Future<int> _currentSyncId() async {
    final syncCursor = await _db.getSyncMeta('last_sync_id');
    final storedSyncId = int.tryParse(syncCursor ?? '') ?? 0;
    final localSyncId = await _db.getMaxLocalSyncId();
    return storedSyncId > localSyncId ? storedSyncId : localSyncId;
  }

  Future<void> _publishLayerProgress(
    String message, {
    Map<String, dynamic>? debug,
    int? progressCurrent,
    int? progressTotal,
  }) async {
    // Silent doctors sync running in parallel with the main sync — don't
    // overwrite the user-facing message that the main sync is showing.
    if (_doctorsSilent && state.activeOperation != null) return;

    final now = DateTime.now();
    final totals = await _collectLocalTotals();
    final unsynced = await _db.unsyncedCount();
    state = state.copyWith(
      status: SyncStatus.loading,
      message: message,
      unsyncedCount: unsynced,
      lastSyncAt: now,
      lastGetDebug: {
        'ok': true,
        if (debug != null) ...debug,
        ..._localTotalsDebug(totals),
      },
      progressCurrent: progressCurrent,
      progressTotal: progressTotal,
      clearProgress: progressCurrent == null && progressTotal == null,
    );
  }

  Map<String, dynamic> _localTotalsDebug(_LocalTotals totals) {
    return {
      'local_organizations_total': totals.organizations,
      'local_lpu_total': totals.lpu,
      'local_pharmacy_total': totals.pharmacy,
      'local_distributor_total': totals.distributor,
      'local_other_organizations_total': totals.otherOrganizations,
      'local_doctors_total': totals.doctors,
      'local_drugs_total': totals.drugs,
      'local_materials_total': totals.materials,
      'local_visits_total': totals.visits,
      'local_planned_visits_total': totals.plannedVisits,
    };
  }

  Future<(int, int, List<Map>)> _syncDrugsAndMaterialsLayer({
    int? companyId,
  }) async {
    var drugsCount = 0;
    var materialsCount = 0;
    final changedDrugRows = <Map>[];

    // 1) Full catalogue from /dict/drugs/bindings — this is the complete drug
    //    list the web uses for ЛПУ-detailing and the pharmacy фармкружок. It
    //    has no price/stock, so it only seeds names/manufacturers. Stored first
    //    so the price-list pass below can enrich the matching rows.
    try {
      final catalogueDrugs = await _remoteApi.getDrugsBindings();
      if (catalogueDrugs.isNotEmpty) {
        final now = DateTime.now().toIso8601String();
        final rows = catalogueDrugs
            .map(
              (d) => <String, dynamic>{
                'id': d.id,
                'name': d.name,
                'manufacturer': d.manufacturer,
                'binding_drug_id': d.bindingDrugId,
                'updated_at': now,
              },
            )
            .toList();
        changedDrugRows.addAll(rows);
        await _db.upsertDrugs(rows);
        drugsCount = rows.length;
      }
    } catch (e) {
      logSwallowed(e, 'Sync._syncDrugsAndMaterialsLayer.bindings');
    }

    // 2) Price-list (warehouse stock) — enriches the catalogue rows with real
    //    price/остатки/current_stock_id needed for брони/заказы. If the
    //    bindings call above failed (offline/edge), this still populates the
    //    list on its own, preserving the previous behaviour.
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
                'main_stock': d.mainStock ?? d.stock ?? 0,
                'stock': d.stock ?? 0,
                'remains_stock': d.remainsStock ?? d.stock ?? 0,
                'current_stock_id': d.currentStockId,
                'binding_drug_id': d.bindingDrugId,
                'updated_at': now,
              },
            )
            .toList();
        changedDrugRows.addAll(rows);
        await _db.upsertDrugs(rows);
        drugsCount = drugsCount == 0 ? rows.length : drugsCount;
      }
    } catch (e) {
      logSwallowed(e, 'Sync._syncDrugsAndMaterialsLayer');
    }

    try {
      final docs = await _remoteApi.getDrugDocuments(companyId: companyId);
      if (docs.materials.isNotEmpty) {
        await _db.upsertDrugMaterials(docs.materials);
        materialsCount = docs.materials.length;
      }
      // The /api/Documents fetch above completed, so docs.counts is the full,
      // authoritative set of drugs that have documents. Clear stale counts
      // first so drugs that lost their documents drop out of the knowledge base
      // (which lists drugs with documents_count > 0).
      await _db.resetAllDrugDocumentsCount();
      for (final e in docs.counts.entries) {
        await _db.updateDrugDocumentsCount(e.key, e.value);
      }
      for (final e in docs.drugNames.entries) {
        await _db.updateDrugName(e.key, e.value);
      }
    } catch (e) {
      logSwallowed(e, 'Sync._syncDrugsAndMaterialsLayer');
    }

    return (drugsCount, materialsCount, changedDrugRows);
  }

  Future<(int, List<Map>, List<Map>)> _syncDoctorsLayer({
    int? syncId,
    bool forceFull = false,
  }) async {
    final totals = await _collectLocalTotals();
    final linksCount = await _doctorLinksCount();
    if (forceFull || totals.doctors == 0 || linksCount == 0) {
      final count = await _repairDoctorDirectoryIfNeeded();
      return (count, const <Map>[], const <Map>[]);
    }

    if (syncId == null || syncId <= 0) {
      return (0, const <Map>[], const <Map>[]);
    }

    var doctors = const <Map<String, dynamic>>[];
    var relations = const <Map<String, dynamic>>[];
    try {
      doctors = await _remoteApi.getDoctorsSync(syncId: syncId);
    } catch (_) {
      doctors = const <Map<String, dynamic>>[];
    }
    try {
      relations = await _remoteApi.getDoctorOrganisationRelations(
        syncId: syncId,
      );
    } catch (_) {
      relations = const <Map<String, dynamic>>[];
    }
    if (relations.isNotEmpty) {
      await _db.upsertDoctorOrganisationLinks(relations);
    }
    if (doctors.isNotEmpty) {
      await _db.upsertDoctors(doctors);
    }
    return (doctors.length, relations, doctors);
  }

  Future<bool> _pushPendingBeforePull({required bool fullRefresh}) async {
    // Drain pending plan submissions first — they're cheap and unrelated to
    // visit-push pipeline. Errors here are non-fatal: rows stay in queue.
    await _pushPendingPlans();

    final pending = await _db.unsyncedCount();
    if (pending <= 0) return true;

    state = state.copyWith(
      status: SyncStatus.loading,
      unsyncedCount: pending,
      message: AppI18n.tr('syncPushFirst', args: {'n': '$pending'}),
      clearProgress: true,
    );

    try {
      await pushToRemote();
    } catch (_) {
      final remaining = await _db.unsyncedCount();
      state = state.copyWith(
        status: SyncStatus.error,
        unsyncedCount: remaining,
        message:
            AppI18n.tr('syncPushFailedDeferred'),
        clearProgress: true,
        clearActiveOperation: true,
      );
      return false;
    }

    final remaining = await _db.unsyncedCount();
    // Allow pull to continue even if transient (non-permanent) failures left
    // some records unsynced — they will be retried on the next reconcile.
    // Permanent failures are already deleted by pushToRemote(), so remaining > 0
    // means server-side 5xx or network errors, not invalid data.
    state = state.copyWith(
      status: SyncStatus.loading,
      unsyncedCount: remaining,
      message: remaining > 0
          ? (fullRefresh
                ? AppI18n.tr('syncSomeUnsentFull', args: {'n': '$remaining'})
                : AppI18n.tr('syncSomeUnsentDelta', args: {'n': '$remaining'}))
          : (fullRefresh
                ? AppI18n.tr('syncQueueSentFull')
                : AppI18n.tr('syncQueueSentDelta')),
      clearProgress: true,
    );
    return true;
  }

  /// Drains the [pending_plans] queue: POSTs each row to `/api/visits/plans`
  /// and on success removes it + stamps the new `remote_id` on the local
  /// [planned_visits] row. Network/server errors leave the row in queue.
  /// Safe to call whenever — no-op when offline or queue empty.
  Future<void> pushPendingPlans() => _pushPendingPlans();

  Future<void> _pushPendingPlans() async {
    final offline = _isOffline();
    final pending = await _db.getPendingPlans();
    debugPrint(
      '[PLAN PUSH] _pushPendingPlans: offline=$offline pending=${pending.length}',
    );
    if (offline) return;
    if (pending.isEmpty) return;

    for (final row in pending) {
      final pendingId = (row['id'] as num?)?.toInt();
      final localPlanId = (row['local_plan_id'] as num?)?.toInt();
      final orgId = (row['org_id'] as num?)?.toInt();
      final visitFormatId = (row['visit_format_id'] as num?)?.toInt();
      final startDateRaw = row['start_date'] as String?;
      final endDateRaw = row['end_date'] as String?;
      if (pendingId == null ||
          localPlanId == null ||
          orgId == null ||
          visitFormatId == null ||
          startDateRaw == null) {
        // Malformed row — drop it to avoid permanent stuckness.
        if (pendingId != null) await _db.deletePendingPlan(pendingId);
        continue;
      }
      List<int> doctorIds = const [];
      final doctorIdsJson = row['doctor_ids_json'] as String?;
      if (doctorIdsJson != null && doctorIdsJson.isNotEmpty) {
        try {
          final decoded = jsonDecode(doctorIdsJson);
          if (decoded is List) {
            doctorIds = decoded
                .map((e) => (e is num) ? e.toInt() : int.tryParse('$e'))
                .whereType<int>()
                .toList();
          }
        } catch (e) {
          logSwallowed(e, 'Sync._pushPendingPlans');
        }
      }

      try {
        final response = await _remoteApi.pushPlannedVisit(
          organizationId: orgId,
          doctorIds: doctorIds,
          visitFormatId: visitFormatId,
          startDate: DateTime.parse(startDateRaw),
          endDate: endDateRaw != null ? DateTime.tryParse(endDateRaw) : null,
          comment: row['comment'] as String?,
        );
        final data = response['response'];
        int? remoteId;
        if (data is Map) {
          remoteId =
              (data['id'] as num?)?.toInt() ??
              (data['plan_id'] as num?)?.toInt() ??
              (data['visit_id'] as num?)?.toInt();
        }
        if (remoteId != null) {
          await _db.setPlannedVisitRemoteId(
            localId: localPlanId,
            remoteId: remoteId,
            rawJson: data is Map ? Map<String, dynamic>.from(data) : null,
          );
        }
        await _db.deletePendingPlan(pendingId);
      } catch (e) {
        // 4xx validation failure — drop the queue entry to avoid spinning on
        // bad input. Server-side / network errors keep the row for retry.
        if (e is RemotePushException) {
          final status = e.response['status'];
          if (status is int && status >= 400 && status < 500) {
            await _db.deletePendingPlan(pendingId);
          }
        }
        // Continue with the next pending row regardless.
      }
    }
  }

  void _setPullProgress(String message, {int? current, int? total}) {
    if (!mounted) return;
    state = state.copyWith(
      status: SyncStatus.loading,
      message: message,
      progressCurrent: current,
      progressTotal: total,
    );
  }

  static int? _progressPercent(int current, int? total) {
    if (total == null || total <= 0) return null;
    final normalized = current.clamp(0, total);
    return ((normalized / total) * 100).round().clamp(0, 100);
  }

  int _maxSyncId(List<Map> a, List<Map> b, List<Map> c, List<Map> d) {
    return [
      ...a.map((e) => e['sync_id']),
      ...b.map((e) => e['sync_id']),
      ...c.map((e) => e['sync_id']),
      ...d.map((e) => e['sync_id']),
    ].whereType<int>().fold<int>(0, (prev, id) => id > prev ? id : prev);
  }

  Future<_DeltaPullResult?> _tryDeltaPull({bool includeDoctors = true}) async {
    final syncCursor = await _db.getSyncMeta('last_sync_id');
    final storedSyncId = int.tryParse(syncCursor ?? '') ?? 0;
    final localSyncId = await _db.getMaxLocalSyncId();
    final syncId = storedSyncId > localSyncId ? storedSyncId : localSyncId;
    try {
      final orgs = await _remoteApi.getOrganizationsSync(
        syncId: syncId > 0 ? syncId : null,
      );
      final doctors = includeDoctors
          ? await _remoteApi.getDoctorsSync(syncId: syncId > 0 ? syncId : null)
          : const <Map<String, dynamic>>[];
      final relations = includeDoctors
          ? await _remoteApi.getDoctorOrganisationRelations(syncId: syncId)
          : const <Map<String, dynamic>>[];
      final drugs = await _remoteApi.getDrugsSync(syncId: syncId);

      await _db.upsertOrganisations(orgs);
      await _db.upsertDoctorOrganisationLinks(relations);
      await _db.upsertDoctors(doctors);
      await _db.upsertDrugs(drugs);
      final maxSyncId = [
        ...orgs.map((e) => e['sync_id'] as int?),
        ...doctors.map((e) => e['sync_id'] as int?),
        ...relations.map((e) => e['sync_id'] as int?),
        ...drugs.map((e) => e['sync_id'] as int?),
      ].whereType<int>().fold<int>(syncId, (p, e) => e > p ? e : p);
      if (maxSyncId > 0) {
        await _db.setSyncMeta('last_sync_id', '$maxSyncId');
      }

      return _DeltaPullResult(
        lastSyncIdBefore: syncId,
        lastSyncIdAfter: maxSyncId > 0 ? maxSyncId : syncId,
        organizationsCount: orgs.length,
        organizations: orgs,
        doctorsCount: doctors.length,
        drugsCount: drugs.length,
      );
    } catch (_) {
      return null;
    }
  }

  /// Reads the single scalar of a COUNT(*) query, tolerating an empty result
  /// set (e.g. a cleared or corrupted table) instead of crashing on `.first`.
  static int _scalarCount(List<Map<String, dynamic>> rows) {
    if (rows.isEmpty) return 0;
    return (rows.first['c'] as num?)?.toInt() ?? 0;
  }

  Future<_LocalTotals> _collectLocalTotals() async {
    final db = _db.db;
    final orgs = await db.rawQuery('SELECT COUNT(*) AS c FROM organisations');
    final lpu = await db.rawQuery(
      "SELECT COUNT(*) AS c FROM organisations WHERE type = 'lpu'",
    );
    final pharmacies = await db.rawQuery(
      "SELECT COUNT(*) AS c FROM organisations WHERE type = 'pharmacy'",
    );
    final distributors = await db.rawQuery(
      "SELECT COUNT(*) AS c FROM organisations WHERE type = 'distributor'",
    );
    final doctors = await db.rawQuery('SELECT COUNT(*) AS c FROM doctors');
    final visits = await db.rawQuery('SELECT COUNT(*) AS c FROM visits');
    final plannedVisits = await db.rawQuery(
      'SELECT COUNT(*) AS c FROM planned_visits',
    );
    final drugs = await db.rawQuery('SELECT COUNT(*) AS c FROM drugs');
    final materials = await db.rawQuery(
      'SELECT COUNT(*) AS c FROM drug_materials',
    );
    final orgTotal = _scalarCount(orgs);
    final lpuTotal = _scalarCount(lpu);
    final pharmacyTotal = _scalarCount(pharmacies);
    final distributorTotal = _scalarCount(distributors);
    return _LocalTotals(
      organizations: orgTotal,
      lpu: lpuTotal,
      pharmacy: pharmacyTotal,
      distributor: distributorTotal,
      otherOrganizations:
          orgTotal - lpuTotal - pharmacyTotal - distributorTotal,
      doctors: _scalarCount(doctors),
      visits: _scalarCount(visits),
      plannedVisits: _scalarCount(plannedVisits),
      drugs: _scalarCount(drugs),
      materials: _scalarCount(materials),
    );
  }

  _OrgTypeCounts _countOrgTypes(List<Map<String, dynamic>> orgs) {
    var lpu = 0;
    var pharmacy = 0;
    var distributor = 0;
    var other = 0;
    for (final org in orgs) {
      switch ((org['type'] ?? '').toString()) {
        case 'lpu':
          lpu++;
        case 'pharmacy':
          pharmacy++;
        case 'distributor':
          distributor++;
        default:
          other++;
      }
    }
    return _OrgTypeCounts(
      lpu: lpu,
      pharmacy: pharmacy,
      distributor: distributor,
      other: other,
    );
  }

  /// Refreshes all live data that changes frequently: visits, planned visits,
  /// favourite doctors/orgs, daily stats, managers, day types, and materials.
  Future<_LiveSyncResult> _syncAllLiveDataFromRemote({
    bool repairDoctors = true,
    bool quickOnly = false,
  }) async {
    var visitsCount = 0;
    var plannedVisitsCount = 0;
    var materialsCount = 0;
    var cachedFilesCount = 0;

    // Full catalogue (bindings) — keeps the detailing/фармкружок list complete,
    // not just warehouse stock. Skipped in the lightweight quick refresh.
    if (!quickOnly) {
      try {
        final catalogueDrugs = await _remoteApi.getDrugsBindings();
        if (catalogueDrugs.isNotEmpty) {
          final now = DateTime.now().toIso8601String();
          final rows = catalogueDrugs
              .map(
                (d) => <String, dynamic>{
                  'id': d.id,
                  'name': d.name,
                  'manufacturer': d.manufacturer,
                  'binding_drug_id': d.bindingDrugId,
                  'updated_at': now,
                },
              )
              .toList();
          await _db.upsertDrugs(rows);
        }
      } catch (e) {
        logSwallowed(e, 'Sync._syncAllLiveDataFromRemote.bindings');
      }
    }

    // Price-list drugs — refreshes current_stock_id / binding_drug_id needed for Бронь
    if (!quickOnly) {
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
                  'main_stock': d.mainStock ?? d.stock ?? 0,
                  'stock': d.stock ?? 0,
                  'remains_stock': d.remainsStock ?? d.stock ?? 0,
                  'current_stock_id': d.currentStockId,
                  'binding_drug_id': d.bindingDrugId,
                  'updated_at': now,
                },
              )
              .toList();
          await _db.upsertDrugs(rows);
        }
      } catch (e) {
        logSwallowed(e, 'Sync._syncAllLiveDataFromRemote');
      }
    }

    // Favourite doctors
    try {
      final favDoctors = await _remoteApi.getFavoriteDoctors(
        allowDictionaryFallback: !quickOnly,
      );
      if (favDoctors.isNotEmpty) {
        await _db.clearDoctorFavorites();
        await _db.upsertDoctors(favDoctors);
        for (final d in favDoctors) {
          final id = d['id'] as int?;
          if (id != null) await _db.updateDoctorFavorite(id, true);
        }
      }
    } catch (e) {
      logSwallowed(e, 'Sync._syncAllLiveDataFromRemote');
    }

    // Favourite organisations
    try {
      final favOrgs = await _remoteApi.getFavoriteOrganizations(
        allowDictionaryFallback: !quickOnly,
      );
      if (favOrgs.isNotEmpty) {
        await _db.upsertOrganisations(favOrgs);
        await _db.clearOrgFavorites();
        for (final o in favOrgs) {
          final id = (o['id'] as num?)?.toInt();
          if (id != null) await _db.updateOrgFavorite(id, true);
        }
      }
    } catch (e) {
      logSwallowed(e, 'Sync._syncAllLiveDataFromRemote');
    }

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
        } catch (e) {
          logSwallowed(e, 'Sync._syncAllLiveDataFromRemote');
        }
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
        final fetchedRemoteIds = deduped
            .map((v) => (v['remote_id'] as num?)?.toInt())
            .whereType<int>()
            .toSet();
        final locallyPushedRows = await _db.db.query(
          'visits',
          where:
              'is_synced = ? AND remote_id IS NOT NULL AND last_push_response_json IS NOT NULL',
          whereArgs: const [1],
        );
        final locallyPushedByRemoteId = {
          for (final row in locallyPushedRows)
            if ((row['remote_id'] as num?)?.toInt() != null)
              (row['remote_id'] as num).toInt(): row,
        };

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
          final remoteId = (v['remote_id'] as num?)?.toInt();
          final row = Map<String, dynamic>.from(v)
            ..['is_synced'] = 1
            ..removeWhere((k, _) => !visitColumns.contains(k));
          final localRow = remoteId == null
              ? null
              : locallyPushedByRemoteId[remoteId];
          if (localRow != null) {
            _mergeLocalOrderPushState(row, localRow);
          }
          batch.insert(
            'visits',
            row,
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
        for (final localRow in locallyPushedRows) {
          final remoteId = (localRow['remote_id'] as num?)?.toInt();
          if (remoteId == null || fetchedRemoteIds.contains(remoteId)) {
            continue;
          }
          final row = Map<String, dynamic>.from(localRow)
            ..removeWhere((k, _) => !visitColumns.contains(k));
          batch.insert(
            'visits',
            row,
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
        await batch.commit(noResult: true);
        visitsCount =
            deduped.length +
            locallyPushedRows.where((row) {
              final remoteId = (row['remote_id'] as num?)?.toInt();
              return remoteId != null && !fetchedRemoteIds.contains(remoteId);
            }).length;
      }
    } catch (e) {
      logSwallowed(e, 'Sync._syncAllLiveDataFromRemote');
    }

    // Planned visits — convert PlannedVisit model → DB row.
    // Filter by the logged-in medrep: /visits/plans returns OTHER reps' plans
    // too (the web hides them), so pass the owner id to drop foreign plans.
    try {
      final owner = await _db.getCurrentUserOwner();
      final ownerId = owner.userId;
      final planned = <Map<String, dynamic>>[];
      var anyPlanFetchOk = false;
      final fetches = <Future<List<PlannedVisit>>>[
        _remoteApi.getCurrentVisitPlans(null, ownerId),
        _remoteApi.getVisitPlans(ownerId),
      ];
      for (final f in fetches) {
        try {
          final items = await f;
          anyPlanFetchOk = true;
          for (final pv in items) {
            final row = _plannedVisitToRow(pv);
            final key = row['remote_id'];
            if (key == null || !planned.any((e) => e['remote_id'] == key)) {
              planned.add(row);
            }
          }
        } catch (e) {
          logSwallowed(e, 'Sync._syncAllLiveDataFromRemote');
        }
      }
      if (planned.isNotEmpty) {
        await _db.upsertPlannedVisits(planned);
        plannedVisitsCount = planned.length;
      }
      // Reconcile: drop server-origin local plans the API no longer returns
      // (deleted/expired server-side). Only when a fetch actually succeeded —
      // a network failure must not wipe the local cache. Locally-created
      // (un-pushed) plans have no remote_id and are preserved.
      if (anyPlanFetchOk) {
        final serverIds = planned
            .map((e) => (e['remote_id'] as num?)?.toInt())
            .whereType<int>()
            .toSet();
        await _db.reconcileServerPlannedVisits(serverIds);
      }
    } catch (e) {
      logSwallowed(e, 'Sync._syncAllLiveDataFromRemote');
    }

    if (!quickOnly) {
      // Drug documents/materials + per-drug documents count.
      try {
        final docs = await _remoteApi.getDrugDocuments(
          companyId: _currentCompanyId(),
        );
        if (docs.materials.isNotEmpty) {
          await _db.upsertDrugMaterials(docs.materials);
          materialsCount = docs.materials.length;
        }
        // Reset stale counts before re-applying the authoritative set so drugs
        // without documents drop out of the knowledge base.
        await _db.resetAllDrugDocumentsCount();
        for (final e in docs.counts.entries) {
          await _db.updateDrugDocumentsCount(e.key, e.value);
        }
        // Update drug names from documents API (may differ from sync API names)
        for (final e in docs.drugNames.entries) {
          await _db.updateDrugName(e.key, e.value);
        }
        final existingDrugRows = await _db.getDrugs(
          onlyWithPositivePrice: false,
        );
        final existingDrugIds = existingDrugRows
            .map((e) => (e['id'] as num?)?.toInt())
            .whereType<int>()
            .toSet();
        final now = DateTime.now().toIso8601String();
        final documentOnlyDrugs = docs.counts.entries
            .where((e) => !existingDrugIds.contains(e.key))
            .map(
              (e) => {
                'id': e.key,
                'name':
                    docs.drugNames[e.key] ??
                    AppI18n.tr('drugNumbered', args: {'n': '${e.key}'}),
                'manufacturer': '',
                'price': 0,
                'serial_number': '',
                'expiry_date': '',
                'main_stock': 0,
                'stock': 0,
                'remains_stock': 0,
                'current_stock_id': null,
                'binding_drug_id': e.key,
                'documents_count': e.value,
                'updated_at': now,
              },
            )
            .toList();
        if (documentOnlyDrugs.isNotEmpty) {
          await _db.upsertDrugs(documentOnlyDrugs);
        }
      } catch (e) {
        logSwallowed(e, 'Sync._syncAllLiveDataFromRemote');
      }
    }

    // Daily stats
    try {
      final stats = await _remoteApi.getDailyVisitStatistics();
      await _db.setCachedStat('daily_stats', stats);
    } catch (e) {
      logSwallowed(e, 'Sync._syncAllLiveDataFromRemote');
    }

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
    } catch (e) {
      logSwallowed(e, 'Sync._syncAllLiveDataFromRemote');
    }

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
    } catch (e) {
      logSwallowed(e, 'Sync._syncAllLiveDataFromRemote');
    }

    // Visit formats (used by plan-screen format picker).
    try {
      final formats = await _remoteApi.getVisitFormats();
      if (formats.isNotEmpty) {
        final rows = formats
            .map(
              (e) => {
                'id': e['id'],
                'name': e['name'] ?? e['title'] ?? '${e['id']}',
                'raw_json': jsonEncode(e),
              },
            )
            .toList();
        await _db.upsertVisitFormats(rows);
      }
    } catch (e) {
      logSwallowed(e, 'Sync._syncAllLiveDataFromRemote');
    }

    if (!quickOnly) {
      // Download material files for offline access
      try {
        final cacheService = MaterialCacheService(
          dio: _apiClient.dio,
          authToken: _apiClient.token,
        );
        cachedFilesCount = await cacheService.downloadPending(_db);
      } catch (e) {
        logSwallowed(e, 'Sync._syncAllLiveDataFromRemote');
      }
    }

    if (repairDoctors) {
      try {
        await _repairDoctorDirectoryIfNeeded();
      } catch (e) {
        logSwallowed(e, 'Sync._syncAllLiveDataFromRemote');
      }
    }

    return _LiveSyncResult(
      visitsCount: visitsCount,
      plannedVisitsCount: plannedVisitsCount,
      materialsCount: materialsCount,
      cachedFilesCount: cachedFilesCount,
    );
  }

  void _mergeLocalOrderPushState(
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

    void copyOrderTerms(Map<String, dynamic>? source) {
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
      if (source.containsKey('prepayment_percent') &&
          source['prepayment_percent'] != null) {
        raw['prepayment'] = source['prepayment_percent'];
      }
      if (!source.containsKey('buyer_type') &&
          source.containsKey('is_wholesaler') &&
          source['is_wholesaler'] != null) {
        raw['buyer_type'] = source['is_wholesaler'] == true ? 1 : 0;
      }
    }

    copyOrderTerms(localRaw);
    copyOrderTerms(request);
    if (raw.isNotEmpty) {
      remoteRow['raw_json'] = jsonEncode(raw);
    }
  }

  Map<String, dynamic>? _decodeJsonMap(String? rawJson) {
    if (rawJson == null || rawJson.isEmpty) return null;
    try {
      final decoded = jsonDecode(rawJson);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (e) {
      logSwallowed(e, 'Sync._decodeJsonMap');
    }
    return null;
  }

  Future<int> _doctorLinksCount() async {
    final rows = await _db.db.rawQuery(
      'SELECT COUNT(*) AS c FROM doctor_organisations',
    );
    return Sqflite.firstIntValue(rows) ?? 0;
  }

  Future<bool> _doctorDirectoryNeedsRepair({_LocalTotals? totals}) async {
    final currentTotals = totals ?? await _collectLocalTotals();
    if (currentTotals.lpu == 0) return false;
    final bootstrapped = await _isDoctorDirectoryBootstrapped();
    var expectedTotal = await _doctorDirectoryExpectedTotal();
    if (expectedTotal == null && !_isOffline()) {
      try {
        final remoteTotal = await _remoteApi.getDoctorsDictionaryTotal();
        if (remoteTotal != null && remoteTotal > 0) {
          expectedTotal = remoteTotal;
          await _setDoctorDirectoryExpectedTotal(remoteTotal);
        }
      } catch (e) {
        logSwallowed(e, 'Sync._doctorDirectoryNeedsRepair');
      }
    }
    if (expectedTotal != null &&
        expectedTotal > 0 &&
        currentTotals.doctors < expectedTotal) {
      return true;
    }
    if (!bootstrapped && expectedTotal == null) return true;
    if (!bootstrapped && currentTotals.doctors <= 5000) return true;
    if (currentTotals.doctors == 0) return true;
    if (_currentRegionId() != null && currentTotals.doctors < 100) return true;
    return await _doctorLinksCount() == 0;
  }

  String _doctorDirectoryBootstrapMetaKey() {
    return _doctorDirectoryBootstrapKey;
  }

  String _doctorDirectoryExpectedTotalMetaKey() {
    return _doctorDirectoryExpectedTotalKey;
  }

  Future<bool> _isDoctorDirectoryBootstrapped() async {
    return await _db.getSyncMeta(_doctorDirectoryBootstrapMetaKey()) == '1';
  }

  Future<void> _markDoctorDirectoryBootstrapped() async {
    await _db.setSyncMeta(_doctorDirectoryBootstrapMetaKey(), '1');
  }

  Future<int?> _doctorDirectoryExpectedTotal() async {
    return int.tryParse(
      await _db.getSyncMeta(_doctorDirectoryExpectedTotalMetaKey()) ?? '',
    );
  }

  Future<void> _setDoctorDirectoryExpectedTotal(int total) async {
    if (total <= 0) return;
    await _db.setSyncMeta(_doctorDirectoryExpectedTotalMetaKey(), '$total');
  }

  Future<int> _doctorDirectoryCursor() async {
    return int.tryParse(
          await _db.getSyncMeta(_doctorDirectoryCursorKey) ?? '',
        ) ??
        0;
  }

  Future<void> _setDoctorDirectoryCursor(int cursor) async {
    if (cursor < 0) return;
    await _db.setSyncMeta(_doctorDirectoryCursorKey, '$cursor');
  }

  Future<int> _repairDoctorDirectoryIfNeeded() async {
    final totals = await _collectLocalTotals();
    if (!await _doctorDirectoryNeedsRepair(totals: totals)) return 0;

    final relations = await _remoteApi.getDoctorOrganisationRelations(
      syncId: 0,
    );
    await _db.upsertDoctorOrganisationLinks(relations);
    await _publishLayerProgress(
      AppI18n.tr('syncUpdatingDataEllipsis'),
      debug: {
        'mode': 'layered',
        'layer': 'doctor_relations',
        'fetched_doctor_relations_count': relations.length,
      },
    );

    var fetchedCount = 0;
    // Always fetch expected_total from API so a stale cached value doesn't
    // prevent repair when the server adds new doctors. Fall back to stored
    // value only if the API call fails.
    final freshTotal = await _remoteApi.getDoctorsDictionaryTotal();
    final expectedTotal = (freshTotal != null && freshTotal > 0)
        ? freshTotal
        : await _doctorDirectoryExpectedTotal();
    if (expectedTotal != null && expectedTotal > 0) {
      await _setDoctorDirectoryExpectedTotal(expectedTotal);
    }
    var cursor = await _doctorDirectoryCursor();
    if (expectedTotal != null &&
        expectedTotal > 0 &&
        cursor >= expectedTotal &&
        totals.doctors < expectedTotal) {
      cursor = 0;
      await _setDoctorDirectoryCursor(0);
    }

    await _remoteApi.getDoctorsSyncBatched(
      syncId: cursor,
      batchSize: 1000,
      collectRows: false,
      onBatch: (pageDoctors, loaded, nextCursor) async {
        fetchedCount = loaded;
        await _db.upsertDoctors(pageDoctors);
        await _setDoctorDirectoryCursor(nextCursor);
        final progressCurrent = expectedTotal == null || expectedTotal <= 0
            ? nextCursor
            : nextCursor.clamp(0, expectedTotal);
        final progressTotal = expectedTotal;
        final percent = _progressPercent(progressCurrent, progressTotal);
        await _publishLayerProgress(
          percent == null
              ? AppI18n.tr('syncUpdatingDataEllipsis')
              : AppI18n.tr('syncUpdatingDataPct', args: {'percent': '$percent'}),
          debug: {
            'mode': 'layered',
            'layer': 'doctors',
            'fetched_doctors_count': loaded,
            'doctor_sync_id': nextCursor,
            'expected_doctors_total': ?expectedTotal,
          },
          progressCurrent: progressCurrent,
          progressTotal: progressTotal,
        );
      },
    );
    final afterTotals = await _collectLocalTotals();
    final latestExpectedTotal = await _doctorDirectoryExpectedTotal();
    final latestCursor = await _doctorDirectoryCursor();
    final hasExpectedDoctors =
        latestExpectedTotal == null ||
        latestExpectedTotal <= 0 ||
        afterTotals.doctors >= latestExpectedTotal ||
        latestCursor >= latestExpectedTotal;
    if (hasExpectedDoctors &&
        afterTotals.doctors > 0 &&
        await _doctorLinksCount() > 0) {
      await _markDoctorDirectoryBootstrapped();
    }
    return fetchedCount;
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
    if (state.activeOperation != null) return;
    if (_isOffline()) {
      final count = await _db.unsyncedCount();
      state = state.copyWith(
        status: SyncStatus.idle,
        unsyncedCount: count,
        message: AppI18n.tr('syncOfflinePushSkipped'),
        clearActiveOperation: true,
      );
      return;
    }
    state = state.copyWith(
      status: SyncStatus.loading,
      activeOperation: SyncOperation.push,
      message: AppI18n.tr('syncPushingData'),
      clearProgress: true,
    );

    try {
      // Repair & re-queue visits saved by older builds in the legacy
      // talked_about_drugs format (drug_name/status string) that the server
      // rejected and parked. Must run before collecting the push queue so the
      // recovered visits are included in this cycle.
      try {
        final repaired = await _db.repairLegacyVisitDrugPayloads();
        if (repaired > 0) {
          logSwallowed(
            'repaired $repaired legacy visit(s)',
            'Sync.pushToRemote.repair',
          );
        }
      } catch (e) {
        logSwallowed(e, 'Sync.pushToRemote.repair');
      }

      // Skip visits whose backoff window has not elapsed yet so we don't hammer
      // the server on every reconcile after a transient failure.
      final unsyncedRows = await _db.getVisits(
        unsyncedOnly: true,
        dueForRetryOnly: true,
      );

      final syncedIds = <int>[];
      final parkedIds = <int>[];
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
          if (visit.id != null && isPermanentVisitPushFailure(e)) {
            // Server rejected the payload: keep the row (field data must never
            // be lost), park it and let the user retry/delete from sync screen.
            if (e is RemotePushException) {
              await _db.setVisitPushPayload(
                visitId: visit.id!,
                requestJson: jsonEncode(e.request),
                responseJson: jsonEncode(e.response),
              );
            } else {
              await _db.setVisitPushPayload(
                visitId: visit.id!,
                responseJson: jsonEncode({'error': '$e'}),
              );
            }
            await _db.markVisitPushFailedPermanently(visit.id!);
            parkedIds.add(visit.id!);
            responses.add({
              'visit_id': visit.id,
              'ok': false,
              'parked': true,
              'error': _pushErrorMessage(e),
            });
            failed.add(
              'visit#${visit.id ?? '-'}: отклонён сервером, не отправлен — требует внимания',
            );
            continue;
          }
          final requestJson = e is RemotePushException
              ? jsonEncode(e.request)
              : null;
          final responseJson = e is RemotePushException
              ? jsonEncode(e.response)
              : jsonEncode({'error': '$e'});
          if (visit.id != null) {
            await _db.setVisitPushPayload(
              visitId: visit.id!,
              requestJson: requestJson,
              responseJson: responseJson,
            );
            // Transient failure: bump attempt count + schedule backoff. After
            // too many tries, park the visit (keep the row) so the queue does
            // not spin forever but no field data is lost.
            final attempts = await _db.recordVisitPushFailure(visit.id!);
            if (attempts >= _maxPushAttempts) {
              await _db.markVisitPushFailedPermanently(visit.id!);
              parkedIds.add(visit.id!);
              responses.add({
                'visit_id': visit.id,
                'ok': false,
                'parked': true,
                'error': _pushErrorMessage(e),
              });
              failed.add(
                'visit#${visit.id}: не отправлен после $attempts попыток — требует внимания',
              );
              continue;
            }
          }
          failed.add('visit#${visit.id ?? '-'}: ${_pushErrorMessage(e)}');
          responses.add({
            'visit_id': visit.id,
            'ok': false,
            if (e is RemotePushException) 'request': e.request,
            if (e is RemotePushException) 'response': e.response,
            'error': '$e',
          });
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
                  ? AppI18n.tr('syncQueueSent')
                  : AppI18n.tr('syncSentVisits', args: {
                      'n': '${syncedIds.length}',
                    }))
            : AppI18n.tr('syncSentWithAttention', args: {
                'sent': '${syncedIds.length}',
                'parked': '${parkedIds.length}',
                'failed': '${failed.length}',
                'first': failed.first,
              }),
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
      // Only notify when something real happened for the user (visits actually
      // sent, or there were errors). A silent background reconcile that pushed
      // nothing must not spam the notification list.
      if (syncedIds.isNotEmpty || failed.isNotEmpty) {
        await _notificationsService.add(
          title: failed.isEmpty
              ? AppI18n.tr('syncPushVisitsDone')
              : AppI18n.tr('syncPushVisitsErrors'),
          body: failed.isEmpty
              ? AppI18n.tr('syncSentRemaining', args: {
                  'sent': '${syncedIds.length}',
                  'remaining': '$remaining',
                })
              : AppI18n.tr('syncSentErrorsRemaining', args: {
                  'sent': '${syncedIds.length}',
                  'failed': '${failed.length}',
                  'remaining': '$remaining',
                }),
          kind: 'sync',
        );
      }

      final pushCompleted = failed.isEmpty && remaining == 0;

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
            // Keep in queue for next sync attempt; after too many tries the
            // row is parked (failed=1) and surfaced on the sync screen.
            await _db.recordPendingFavoriteFailure(id);
          }
        }
      } catch (e) {
        logSwallowed(e, 'Sync.pushToRemote');
      }

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
              } catch (e) {
                logSwallowed(e, 'Sync.pushToRemote');
              }
            }
          } catch (_) {
            // Keep in queue for next sync attempt; after too many tries the
            // row is parked (failed=1) and surfaced on the sync screen.
            await _db.recordPendingFeedbackFailure(id);
          }
        }
      } catch (e) {
        logSwallowed(e, 'Sync.pushToRemote');
      }

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
          } catch (e) {
            // Keep in queue for next sync attempt
            logSwallowed(e, 'Sync.pushPendingDoctor#$id');
          }
        }
      } catch (e) {
        logSwallowed(e, 'Sync.pushToRemote');
      }

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
          } catch (e) {
            // Keep in queue for next sync attempt
            logSwallowed(e, 'Sync.pushPendingOrgUpdate#$id');
          }
        }
      } catch (e) {
        logSwallowed(e, 'Sync.pushToRemote');
      }

      // Flush pending new organizations queue (offline-created pharmacies).
      try {
        final pendingOrgs = await _db.getPendingOrganizations();
        for (final row in pendingOrgs) {
          final id = row['id'] as int;
          final tempLocalId = row['temp_local_id'] as int;
          try {
            final remoteId = await _remoteApi.createOrganization(
              name: row['name'] as String,
              inn: row['inn'] as String,
              typeId: row['type_id'] as int,
              regionId: row['region_id'] as int,
              areaId: (row['area_id'] as num?)?.toInt(),
              phone: row['phone'] as String?,
              phone2: row['phone2'] as String?,
              phone3: row['phone3'] as String?,
              address: row['address'] as String?,
              categoryId: (row['category_id'] as num?)?.toInt(),
              healthCareFacilityTypeId: (row['hcf_type_id'] as num?)?.toInt(),
              revisionStatus: row['revision_status'] as String?,
              responsiblePerson: row['responsible'] as String?,
              latitude: (row['latitude'] as num?)?.toDouble(),
              longitude: (row['longitude'] as num?)?.toDouble(),
            );
            if (remoteId != null) {
              await _db.replaceOrganizationTempId(tempLocalId, remoteId);
            }
            // Drop the queue row on success even if the server didn't echo an
            // id — the org was created; the next pull reconciles real data.
            await _db.deletePendingOrganization(id);
          } catch (e) {
            // Keep in queue for next sync attempt.
            logSwallowed(e, 'Sync.pushPendingOrganization#$id');
          }
        }
      } catch (e) {
        logSwallowed(e, 'Sync.pushToRemote');
      }

      // Flush pending planned-visit submissions. Rows survive transient
      // failures (network, 5xx) and get retried on the next push/reconcile.
      // 4xx validation errors drop the row inside _pushPendingPlans().
      try {
        await _pushPendingPlans();
      } catch (e) {
        logSwallowed(e, 'Sync.pushToRemote');
      }

      state = state.copyWith(clearActiveOperation: true);
      if (pushCompleted) {
        _drainPendingReconcile();
      } else {
        _reconcilePending = false;
      }
    } catch (e, st) {
      final message = _pushErrorMessage(e);
      state = state.copyWith(
        status: SyncStatus.error,
        message: AppI18n.tr('syncSendError', args: {'message': message}),
        lastPostDebug: {'ok': false, 'error': '$e'},
        clearActiveOperation: true,
      );
      await _notificationsService.add(
        title: AppI18n.tr('syncSendVisitsErrorTitle'),
        body: message,
        kind: 'sync',
      );
      _reconcilePending = false;
      Error.throwWithStackTrace(e, st);
    }
  }

  // ── checkSync ─────────────────────────────────────────────────────────────

  /// Reads the unsynced count from the DB and updates the state.
  Future<void> checkSync() async {
    final count = await _db.unsyncedCount();
    state = state.copyWith(unsyncedCount: count);
    if (count > 0 && !_isOffline()) {
      if (state.activeOperation != null || _isReconciling) {
        _reconcilePending = true;
      } else {
        unawaited(reconcileInBackground());
      }
    }
  }

  // ── refreshUnsyncedCount ──────────────────────────────────────────────────

  /// Alias for [checkSync] — call after any local write to keep the badge
  /// in the UI up to date.
  Future<void> refreshUnsyncedCount() => checkSync();

  Future<void> syncLaunchDeltaIfNeeded({
    Duration minInterval = const Duration(minutes: 5),
  }) async {
    final now = DateTime.now();
    final totals = await _collectLocalTotals();
    final hasBaseDirectory = await _hasBaseDirectory(totals);
    if (!hasBaseDirectory) {
      await _db.setSyncMeta(_lastAppActivityKey, now.toIso8601String());
      if (_isOffline()) {
        await refreshUnsyncedCount();
        return;
      }
      await syncLayeredFromRemote(fullRefresh: true, pushPendingFirst: false);
      return;
    }
    final previousActivity = _parseMetaDate(
      await _db.getSyncMeta(_lastAppActivityKey),
    );
    final lastDelta =
        _parseMetaDate(await _db.getSyncMeta(_lastDeltaPullKey)) ??
        _parseMetaDate(await _db.getSyncMeta('last_pull_at'));

    await _db.setSyncMeta(_lastAppActivityKey, now.toIso8601String());
    if (_isOffline()) {
      await refreshUnsyncedCount();
      return;
    }

    final needsDoctorRepair = await _doctorDirectoryNeedsRepair();
    final activityAfterDelta =
        previousActivity != null &&
        (lastDelta == null || previousActivity.isAfter(lastDelta));
    final staleDelta =
        lastDelta == null || now.difference(lastDelta).abs() >= minInterval;
    if (!activityAfterDelta && !staleDelta && !needsDoctorRepair) {
      await refreshUnsyncedCount();
      return;
    }

    await syncLayeredFromRemote(pushPendingFirst: false);
  }

  Future<void> ensureBootstrapFullPull() async {
    final done = await _db.getSyncMeta(_fullPullBootstrapKey);
    final totals = await _collectLocalTotals();
    final needsDoctorRepair = await _doctorDirectoryNeedsRepair();
    final hasBaseDirectory = await _hasBaseDirectory(totals);
    if (done == '1' && hasBaseDirectory && !needsDoctorRepair) return;
    await syncLayeredFromRemote(
      fullRefresh: done != '1' || !hasBaseDirectory,
      pushPendingFirst: false,
    );
    final afterTotals = await _collectLocalTotals();
    if (state.status == SyncStatus.success && afterTotals.organizations > 0) {
      await _db.setSyncMeta(_fullPullBootstrapKey, '1');
    }
  }

  Future<void> reconcileInBackground() async {
    if (_isReconciling) return;
    if (_isOffline()) return;
    if (state.activeOperation != null) {
      _reconcilePending = true;
      return;
    }
    _isReconciling = true;
    try {
      // Guard against "connected but no internet": skip silently if the host
      // is not actually reachable. Pending data stays queued for next time.
      if (!await _hasRealInternet()) return;
      // If no token (e.g. offline login via cache), re-auth first
      if (!_apiClient.hasToken) {
        final ok = await _silentReauth();
        if (!ok) return;
      }
      try {
        await pushToRemote();
      } catch (e) {
        // Pull must continue: old invalid pending records should not block
        // completing local reference tables such as doctors and pharmacies.
        logSwallowed(e, 'Sync.reconcile.push');
      }
      await syncLaunchDeltaIfNeeded();
    } catch (e) {
      // Keep silent: background reconcile should not break UX.
      logSwallowed(e, 'Sync.reconcile');
    } finally {
      _isReconciling = false;
      _drainPendingReconcile();
    }
  }

  void _drainPendingReconcile() {
    if (!_reconcilePending) return;
    if (_isReconciling || _isOffline() || state.activeOperation != null) return;
    _reconcilePending = false;
    unawaited(Future<void>.microtask(reconcileInBackground));
  }

  Future<bool> _hasBaseDirectory(_LocalTotals totals) async {
    if (totals.lpu < _minimumUsableLpuDirectorySize ||
        totals.pharmacy < _minimumUsablePharmacyDirectorySize) {
      return false;
    }
    return await _db.getSyncMeta(_organizationDirectoryBootstrapKey) == '1';
  }
}

DateTime? _parseMetaDate(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  return DateTime.tryParse(raw);
}

class _DeltaPullResult {
  final int? lastSyncIdBefore;
  final int? lastSyncIdAfter;
  final int organizationsCount;
  final List<Map<String, dynamic>> organizations;
  final int doctorsCount;
  final int drugsCount;

  const _DeltaPullResult({
    required this.lastSyncIdBefore,
    required this.lastSyncIdAfter,
    required this.organizationsCount,
    required this.organizations,
    required this.doctorsCount,
    required this.drugsCount,
  });
}

class _LocalTotals {
  final int organizations;
  final int lpu;
  final int pharmacy;
  final int distributor;
  final int otherOrganizations;
  final int doctors;
  final int visits;
  final int plannedVisits;
  final int drugs;
  final int materials;

  const _LocalTotals({
    required this.organizations,
    required this.lpu,
    required this.pharmacy,
    required this.distributor,
    required this.otherOrganizations,
    required this.doctors,
    required this.visits,
    required this.plannedVisits,
    required this.drugs,
    required this.materials,
  });
}

class _OrgTypeCounts {
  final int lpu;
  final int pharmacy;
  final int distributor;
  final int other;

  const _OrgTypeCounts({
    required this.lpu,
    required this.pharmacy,
    required this.distributor,
    required this.other,
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

  const _LiveSyncResult.empty()
    : visitsCount = 0,
      plannedVisitsCount = 0,
      materialsCount = 0,
      cachedFilesCount = 0;
}

String _pushErrorMessage(Object error) {
  if (error is RemotePushException) {
    return error.displayMessage;
  }
  return '$error';
}

// ─── Provider ────────────────────────────────────────────────────────────────

final syncProvider = StateNotifierProvider<SyncNotifier, SyncState>((ref) {
  return SyncNotifier(
    ref.watch(localDatabaseProvider),
    ref.watch(remoteApiServiceProvider),
    ref.watch(apiClientProvider),
    () => ref.read(isOfflineProvider),
    () => ref.read(authProvider.notifier).silentReauth(),
    () => ref.read(authProvider).user?.regionId,
    () => ref.read(authProvider).user?.companyId,
  );
});

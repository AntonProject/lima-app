import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lima/core/config/env_config.dart';
import 'package:lima/core/i18n/app_i18n.dart';
import 'package:lima/core/db/local_database.dart';
import 'package:lima/core/network/api_client.dart';
import 'package:lima/core/network/remote_api_service.dart';
import 'package:lima/core/services/in_app_notifications_service.dart';
import 'package:lima/core/services/doctor_directory_sync_service.dart';
import 'package:lima/core/services/pending_plan_sync_service.dart';
import 'package:lima/core/services/pending_mutation_sync_service.dart';
import 'package:lima/core/services/pending_visit_push_service.dart';
import 'package:lima/core/services/delta_pull_service.dart';
import 'package:lima/core/services/organization_directory_pull_service.dart';
import 'package:lima/core/services/live_data_refresh_service.dart';
import 'package:lima/core/services/full_seed_sync_service.dart';
import 'package:lima/core/services/sync_diagnostics_service.dart';
import 'package:lima/core/services/background_reconcile_service.dart';
import 'package:lima/core/services/sync_operation_gate.dart';
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
const _organizationDirectoryFullPullAtKey =
    'organization_directory_full_pull_at';
const _organizationDirectoryFullPullInterval = Duration(hours: 24);
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
  final LocalDatabase _db;
  final RemoteApiService _remoteApi;
  final ApiClient _apiClient;
  final bool Function() _isOffline;
  final Future<bool> Function() _silentReauth;
  final int? Function() _currentRegionId;
  final int? Function() _currentCompanyId;
  late final DoctorDirectorySyncService _doctorDirectorySync;
  late final PendingPlanSyncService _pendingPlanSync;
  late final PendingMutationSyncService _pendingMutationSync;
  late final PendingVisitPushService _pendingVisitPush;
  late final DeltaPullService _deltaPull;
  late final OrganizationDirectoryPullService _organizationDirectoryPull;
  late final LiveDataRefreshService _liveDataRefresh;
  late final FullSeedSyncService _fullSeedSync;
  late final SyncDiagnosticsService _diagnostics;
  late final BackgroundReconcileService _backgroundReconcile;
  bool _isReconciling = false;
  bool _reconcilePending = false;
  final _operationGate = SyncOperationGate();
  final _doctorOperationGate = SyncOperationGate();
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
    _doctorDirectorySync = DoctorDirectorySyncService(
      db: _db,
      remoteApi: _remoteApi,
      isOffline: _isOffline,
      currentRegionId: _currentRegionId,
      onProgress: _publishDoctorDirectoryProgress,
    );
    _pendingPlanSync = PendingPlanSyncService(
      db: _db,
      remoteApi: _remoteApi,
      isOffline: _isOffline,
    );
    _pendingMutationSync = PendingMutationSyncService(
      db: _db,
      remoteApi: _remoteApi,
      isOffline: _isOffline,
    );
    _pendingVisitPush = PendingVisitPushService(db: _db, remoteApi: _remoteApi);
    _deltaPull = DeltaPullService(db: _db, remoteApi: _remoteApi);
    _organizationDirectoryPull = OrganizationDirectoryPullService(
      db: _db,
      remoteApi: _remoteApi,
    );
    _fullSeedSync = FullSeedSyncService(db: _db, remoteApi: _remoteApi);
    _diagnostics = SyncDiagnosticsService(db: _db);
    _backgroundReconcile = BackgroundReconcileService(
      apiClient: _apiClient,
      isOffline: _isOffline,
      hasRealInternet: _hasRealInternet,
      silentReauth: _silentReauth,
    );
    _liveDataRefresh = LiveDataRefreshService(
      db: _db,
      remoteApi: _remoteApi,
      apiClient: _apiClient,
      currentCompanyId: _currentCompanyId,
      repairDoctors: _repairDoctorDirectoryIfNeeded,
    );
    _startConnectivityWatcher();
  }

  /// Read-only snapshot for feature adapters that expose sync state to UI.
  SyncState get currentState => state;

  /// Shares one in-flight operation with concurrent callers instead of
  /// starting a second pull/push against the same local cursor.
  Future<void> _runSingleFlight(Future<void> Function() operation) {
    return _operationGate.run(operation, onComplete: _drainPendingReconcile);
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
  }) => _runSingleFlight(
    () => _pullFromRemote(
      fullRefresh: fullRefresh,
      includeDoctors: includeDoctors,
      repairDoctors: repairDoctors,
      pushPendingFirst: pushPendingFirst,
      deltaOnly: deltaOnly,
    ),
  );

  Future<void> _pullFromRemote({
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
        final delta = await _deltaPull
            .pull(includeDoctors: includeDoctors)
            .timeout(const Duration(seconds: 25), onTimeout: () => null);
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
              ? await _liveDataRefresh.refresh(repairDoctors: repairDoctors)
              : const LiveSyncResult.empty();
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
      state = state.copyWith(
        status: SyncStatus.loading,
        message: fullRefresh
            ? AppI18n.tr('syncWritingFull')
            : AppI18n.tr('syncWriting'),
        clearProgress: true,
      );
      final seed = await _fullSeedSync.fetchAndReplace(
        regionId: regionId,
        companyId: companyId,
        includeDoctors: includeDoctors,
        onProgress: _setPullProgress,
      );

      final live = await _liveDataRefresh.refresh(repairDoctors: repairDoctors);

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
        await _db.setSyncMeta(DoctorDirectorySyncService.bootstrapMetaKey, '1');
      }

      state = state.copyWith(
        status: SyncStatus.success,
        clearProgress: true,
        clearActiveOperation: true,
        unsyncedCount: unsynced,
        message: AppI18n.tr(
          'syncCountsSummary',
          args: {
            'mode': fullRefresh
                ? AppI18n.tr('syncModeFull')
                : AppI18n.tr('syncModeLoaded'),
            'lpu': '${fetchedOrgCounts.lpu}',
            'pharmacy': '${fetchedOrgCounts.pharmacy}',
            'drugs': '${seed.drugs.length}',
          },
        ),
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
    if (_isOffline() ||
        state.activeOperation != null ||
        _operationGate.isRunning) {
      return;
    }
    if (fullRefresh) {
      unawaited(
        syncLayeredFromRemote(fullRefresh: true, pushPendingFirst: true),
      );
      return;
    }
    unawaited(syncLaunchDeltaIfNeeded());
  }

  /// Starts the doctors-only sync in the background (fire-and-forget).
  /// Silent — does not update sync state, so it can run in parallel with the
  /// main critical sync without causing UI flicker or state conflicts.
  void syncDoctorsInBackground() {
    unawaited(_doctorOperationGate.run(_syncDoctorsBackground));
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
  }) => _runSingleFlight(
    () => _syncLayeredFromRemote(
      fullRefresh: fullRefresh,
      pushPendingFirst: pushPendingFirst,
      skipDoctors: skipDoctors,
      homeOnly: homeOnly,
    ),
  );

  Future<void> _syncLayeredFromRemote({
    bool fullRefresh = false,
    bool pushPendingFirst = true,
    bool skipDoctors = false,
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

      final liveFuture = _liveDataRefresh.refresh(
        repairDoctors: false,
        quickOnly: true,
      );
      final orgsFuture = _organizationDirectoryPull.pull(
        full: forceFullOrganizations,
        syncId: syncId,
      );
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

  Future<void> _publishDoctorDirectoryProgress({
    required int loaded,
    required int cursor,
    required int? expectedTotal,
  }) async {
    final progressCurrent = expectedTotal == null || expectedTotal <= 0
        ? cursor
        : cursor.clamp(0, expectedTotal);
    final percent = _progressPercent(progressCurrent, expectedTotal);
    await _publishLayerProgress(
      percent == null
          ? AppI18n.tr('syncUpdatingDataEllipsis')
          : AppI18n.tr('syncUpdatingDataPct', args: {'percent': '$percent'}),
      debug: {
        'mode': 'layered',
        'layer': 'doctors',
        'fetched_doctors_count': loaded,
        'doctor_sync_id': cursor,
        'expected_doctors_total': ?expectedTotal,
      },
      progressCurrent: progressCurrent,
      progressTotal: expectedTotal,
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
      await _pushToRemote();
    } catch (_) {
      final remaining = await _db.unsyncedCount();
      state = state.copyWith(
        status: SyncStatus.error,
        unsyncedCount: remaining,
        message: AppI18n.tr('syncPushFailedDeferred'),
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

  /// Drains the [pending_plans] queue. The service owns row parsing and
  /// retry/delete policy; this notifier only exposes the sync entrypoint.
  Future<void> pushPendingPlans() => _pendingPlanSync.sync();

  Future<void> _pushPendingPlans() => _pendingPlanSync.sync();

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

  Future<_LocalTotals> _collectLocalTotals() async {
    return _diagnostics.collectLocalTotals();
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
  Future<int> _doctorLinksCount() async {
    return _diagnostics.doctorLinksCount();
  }

  Future<bool> _doctorDirectoryNeedsRepair({_LocalTotals? totals}) async {
    final currentTotals = totals ?? await _collectLocalTotals();
    return _doctorDirectorySync.needsRepair(
      localLpuCount: currentTotals.lpu,
      localDoctorCount: currentTotals.doctors,
    );
  }

  Future<bool> _isDoctorDirectoryBootstrapped() =>
      _doctorDirectorySync.isBootstrapped();

  Future<void> _markDoctorDirectoryBootstrapped() =>
      _doctorDirectorySync.markBootstrapped();

  Future<int> _repairDoctorDirectoryIfNeeded() => _doctorDirectorySync.repair();

  // ── pushToRemote ───────────────────────────────────────────────────────────

  /// Pushes all unsynced local visits to the mock remote, then marks them as
  /// synced in the local DB.
  Future<void> pushToRemote() => _runSingleFlight(_pushToRemote);

  Future<void> _pushToRemote() async {
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

    final queueFailures = <Map<String, dynamic>>[];
    final failed = <String>[];

    void recordQueueFailure(String type, Object error, {int? id}) {
      final detail = _pushErrorMessage(error);
      queueFailures.add({'type': type, 'id': ?id, 'error': detail});
      failed.add('$type${id == null ? '' : '#$id'}: $detail');
    }

    try {
      final visitResult = await _pendingVisitPush.sync();
      final syncedIds = visitResult.syncedIds;
      final parkedIds = visitResult.parkedIds;
      final responses = visitResult.responses;
      final remaining = visitResult.remaining;
      for (final failure in visitResult.failures) {
        if (failure.queueFailure) {
          recordQueueFailure(failure.type, failure.message, id: failure.id);
        } else {
          failed.add(failure.message);
        }
      }

      state = state.copyWith(
        status: failed.isEmpty ? SyncStatus.success : SyncStatus.error,
        unsyncedCount: remaining,
        message: failed.isEmpty
            ? (syncedIds.isEmpty
                  ? AppI18n.tr('syncQueueSent')
                  : AppI18n.tr(
                      'syncSentVisits',
                      args: {'n': '${syncedIds.length}'},
                    ))
            : AppI18n.tr(
                'syncSentWithAttention',
                args: {
                  'sent': '${syncedIds.length}',
                  'parked': '${parkedIds.length}',
                  'failed': '${failed.length}',
                  'first': failed.first,
                },
              ),
        lastSyncAt: visitResult.pushedAt,
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
              ? AppI18n.tr(
                  'syncSentRemaining',
                  args: {
                    'sent': '${syncedIds.length}',
                    'remaining': '$remaining',
                  },
                )
              : AppI18n.tr(
                  'syncSentErrorsRemaining',
                  args: {
                    'sent': '${syncedIds.length}',
                    'failed': '${failed.length}',
                    'remaining': '$remaining',
                  },
                ),
          kind: 'sync',
        );
      }

      // Flush non-visit mutation queues after visit submission.
      final mutationResult = await _pendingMutationSync.sync();
      for (final failure in mutationResult.failures) {
        recordQueueFailure(failure.type, failure.message, id: failure.id);
      }

      // Flush pending planned-visit submissions. Rows survive transient
      // failures (network, 5xx) and get retried on the next push/reconcile.
      // 4xx validation errors drop the row inside _pushPendingPlans().
      try {
        await _pushPendingPlans();
      } catch (e) {
        recordQueueFailure('plans', e);
      }

      if (queueFailures.isNotEmpty) {
        final first = queueFailures.first['error']?.toString() ?? 'unknown';
        state = state.copyWith(
          status: SyncStatus.error,
          message: AppI18n.tr('syncSendError', args: {'message': first}),
          lastPostDebug: {
            ...?state.lastPostDebug,
            'ok': false,
            'queue_failed_count': queueFailures.length,
            'queue_failures': queueFailures,
            'message': 'POST sync has errors',
          },
        );
        await _notificationsService.add(
          title: AppI18n.tr('syncSendVisitsErrorTitle'),
          body: first,
          kind: 'sync',
        );
      }

      state = state.copyWith(clearActiveOperation: true);
      final pushCompleted =
          failed.isEmpty && queueFailures.isEmpty && remaining == 0;
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
      if (state.activeOperation != null ||
          _operationGate.isRunning ||
          _isReconciling) {
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
  }) => _runSingleFlight(
    () => _syncLaunchDeltaIfNeeded(minInterval: minInterval),
  );

  Future<void> _syncLaunchDeltaIfNeeded({
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
      await _syncLayeredFromRemote(fullRefresh: true, pushPendingFirst: true);
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

    // Pending local writes have priority over a remote read, including when
    // this launch path decides that the catalogue itself is still fresh.
    // This keeps connectivity-driven/background entrypoints consistent with
    // the explicit sync screen commands.
    if (!await _pushPendingBeforePull(fullRefresh: false)) return;

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

    await _syncLayeredFromRemote(pushPendingFirst: false);
  }

  Future<void> ensureBootstrapFullPull() =>
      _runSingleFlight(_ensureBootstrapFullPull);

  Future<void> _ensureBootstrapFullPull() async {
    final done = await _db.getSyncMeta(_fullPullBootstrapKey);
    final totals = await _collectLocalTotals();
    final needsDoctorRepair = await _doctorDirectoryNeedsRepair();
    final hasBaseDirectory = await _hasBaseDirectory(totals);
    if (done == '1' && hasBaseDirectory && !needsDoctorRepair) {
      // Bootstrap may already be complete while a visit was created offline
      // afterwards. Keep this entrypoint useful for that case too.
      if (!_isOffline()) {
        await _pushPendingBeforePull(fullRefresh: false);
      }
      return;
    }
    await _syncLayeredFromRemote(
      fullRefresh: done != '1' || !hasBaseDirectory,
      pushPendingFirst: true,
    );
    final afterTotals = await _collectLocalTotals();
    if (state.status == SyncStatus.success && afterTotals.organizations > 0) {
      await _db.setSyncMeta(_fullPullBootstrapKey, '1');
    }
  }

  Future<void> reconcileInBackground() {
    if (_operationGate.isRunning) _reconcilePending = true;
    return _runSingleFlight(_reconcileInBackground);
  }

  Future<void> _reconcileInBackground() async {
    if (_isReconciling) return;
    if (_isOffline()) return;
    if (state.activeOperation != null) {
      _reconcilePending = true;
      return;
    }
    _isReconciling = true;
    try {
      await _backgroundReconcile.run(syncLaunchDelta: _syncLaunchDeltaIfNeeded);
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
    if (_isReconciling ||
        _isOffline() ||
        state.activeOperation != null ||
        _operationGate.isRunning) {
      return;
    }
    _reconcilePending = false;
    unawaited(Future<void>.microtask(reconcileInBackground));
  }

  Future<bool> _hasBaseDirectory(_LocalTotals totals) async {
    return _diagnostics.hasBaseDirectory(
      totals: totals,
      bootstrapKey: _organizationDirectoryBootstrapKey,
      minimumLpu: _minimumUsableLpuDirectorySize,
      minimumPharmacy: _minimumUsablePharmacyDirectorySize,
    );
  }
}

DateTime? _parseMetaDate(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  return DateTime.tryParse(raw);
}

typedef _LocalTotals = SyncLocalTotals;

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

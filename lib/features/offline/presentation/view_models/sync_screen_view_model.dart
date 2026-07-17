import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/models/local_visit.dart';
import '../../domain/entities/sync_data_change.dart';
import '../../domain/entities/sync_queue_records.dart';
import '../../domain/repositories/sync_diagnostics_repository.dart';

class SyncScreenViewState {
  final List<LocalVisit> unsyncedVisits;
  final List<LocalVisit> failedVisits;
  final List<PendingDoctorRecord> pendingDoctors;
  final List<PendingDoctorRecord> failedPendingDoctors;
  final List<PendingOrganisationUpdateRecord> pendingOrgUpdates;
  final SyncLocalTotals localTotals;
  final bool hasLocalTotals;
  final bool isLoadingVisits;
  final bool isLoadingData;
  final int unsyncedPage;
  final String? error;

  const SyncScreenViewState({
    this.unsyncedVisits = const [],
    this.failedVisits = const [],
    this.pendingDoctors = const [],
    this.failedPendingDoctors = const [],
    this.pendingOrgUpdates = const [],
    this.localTotals = const SyncLocalTotals(),
    this.hasLocalTotals = false,
    this.isLoadingVisits = true,
    this.isLoadingData = false,
    this.unsyncedPage = 0,
    this.error,
  });

  SyncScreenViewState copyWith({
    List<LocalVisit>? unsyncedVisits,
    List<LocalVisit>? failedVisits,
    List<PendingDoctorRecord>? pendingDoctors,
    List<PendingDoctorRecord>? failedPendingDoctors,
    List<PendingOrganisationUpdateRecord>? pendingOrgUpdates,
    SyncLocalTotals? localTotals,
    bool? hasLocalTotals,
    bool? isLoadingVisits,
    bool? isLoadingData,
    int? unsyncedPage,
    String? error,
    bool clearError = false,
  }) {
    return SyncScreenViewState(
      unsyncedVisits: unsyncedVisits ?? this.unsyncedVisits,
      failedVisits: failedVisits ?? this.failedVisits,
      pendingDoctors: pendingDoctors ?? this.pendingDoctors,
      failedPendingDoctors: failedPendingDoctors ?? this.failedPendingDoctors,
      pendingOrgUpdates: pendingOrgUpdates ?? this.pendingOrgUpdates,
      localTotals: localTotals ?? this.localTotals,
      hasLocalTotals: hasLocalTotals ?? this.hasLocalTotals,
      isLoadingVisits: isLoadingVisits ?? this.isLoadingVisits,
      isLoadingData: isLoadingData ?? this.isLoadingData,
      unsyncedPage: unsyncedPage ?? this.unsyncedPage,
      error: clearError ? null : (error ?? this.error),
    );
  }

  int get totalUnsyncedPages =>
      unsyncedVisits.isEmpty ? 1 : ((unsyncedVisits.length - 1) ~/ 10) + 1;

  List<LocalVisit> get visibleUnsyncedVisits {
    final start = unsyncedPage * 10;
    return unsyncedVisits.skip(start).take(10).toList(growable: false);
  }
}

class SyncScreenViewModel extends StateNotifier<SyncScreenViewState> {
  static const _localDataTables = {
    SyncDataTable.organisations,
    SyncDataTable.doctors,
    SyncDataTable.doctorOrganisations,
    SyncDataTable.drugs,
    SyncDataTable.drugMaterials,
    SyncDataTable.visits,
    SyncDataTable.plannedVisits,
    SyncDataTable.pendingDoctors,
    SyncDataTable.pendingOrganisationUpdates,
  };

  final SyncDiagnosticsRepository _repository;
  StreamSubscription<SyncDataChange>? _changesSubscription;
  Future<void>? _activeLoad;

  SyncScreenViewModel(this._repository) : super(const SyncScreenViewState()) {
    _changesSubscription = _repository.changes.listen((change) {
      if (change.containsAny(_localDataTables)) unawaited(load());
    });
  }

  Future<void> load() {
    final active = _activeLoad;
    if (active != null) return active;
    final future = _loadInternal();
    _activeLoad = future;
    unawaited(
      future.whenComplete(() {
        if (identical(_activeLoad, future)) _activeLoad = null;
      }),
    );
    return future;
  }

  Future<void> _loadInternal() async {
    if (!mounted) return;
    state = state.copyWith(isLoadingData: true, clearError: true);
    try {
      await _repository.deleteLegacyTestVisits();
      final unsynced = await _repository.getVisitModels(unsyncedOnly: true);
      final failedVisits = await _repository.getFailedVisitModels();
      final pendingDoctors = await _repository.getPendingDoctors();
      final failedPendingDoctors = await _repository.getFailedPendingDoctors();
      final pendingOrgUpdates = await _repository.getPendingOrgUpdates();
      final localTotals = await _repository.getLocalTotals();
      if (!mounted) return;
      final lastPage = unsynced.isEmpty ? 0 : (unsynced.length - 1) ~/ 10;
      state = state.copyWith(
        unsyncedVisits: List.unmodifiable(unsynced),
        failedVisits: List.unmodifiable(failedVisits),
        pendingDoctors: List.unmodifiable(pendingDoctors),
        failedPendingDoctors: List.unmodifiable(failedPendingDoctors),
        pendingOrgUpdates: List.unmodifiable(pendingOrgUpdates),
        localTotals: localTotals,
        hasLocalTotals: true,
        isLoadingVisits: false,
        isLoadingData: false,
        unsyncedPage: state.unsyncedPage.clamp(0, lastPage),
      );
    } catch (error) {
      if (!mounted) return;
      state = state.copyWith(
        isLoadingVisits: false,
        isLoadingData: false,
        error: '$error',
      );
    }
  }

  void setUnsyncedPage(int page) {
    state = state.copyWith(
      unsyncedPage: page.clamp(0, state.totalUnsyncedPages - 1),
    );
  }

  @override
  void dispose() {
    _changesSubscription?.cancel();
    super.dispose();
  }
}

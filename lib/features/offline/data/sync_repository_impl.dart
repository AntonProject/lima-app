import 'dart:async';

import 'package:lima/core/providers/sync_provider.dart';

import '../domain/entities/sync_state.dart';
import '../domain/repositories/sync_repository.dart';

class SyncRepositoryImpl implements SyncRepository {
  final SyncNotifier _notifier;
  final StreamController<SyncViewState> _stateController =
      StreamController<SyncViewState>.broadcast();
  late final void Function() _removeListener;
  bool _disposed = false;

  SyncRepositoryImpl(this._notifier) {
    _removeListener = _notifier.addListener(
      _onCoreStateChanged,
      fireImmediately: false,
    );
  }

  @override
  SyncViewState get currentState => _mapState(_notifier.currentState);

  @override
  Stream<SyncViewState> watchState() => _stateController.stream;

  @override
  Future<void> pullDelta() =>
      _notifier.syncLayeredFromRemote(pushPendingFirst: false);

  @override
  Future<void> fullRefresh() => _notifier.syncLayeredFromRemote(
    fullRefresh: true,
    pushPendingFirst: false,
  );

  @override
  Future<void> pushPending() => _notifier.pushToRemote();

  @override
  Future<void> run(SyncOperationType operation) {
    switch (operation) {
      case SyncOperationType.deltaPull:
        return pullDelta();
      case SyncOperationType.fullRefresh:
        return fullRefresh();
      case SyncOperationType.push:
        return pushPending();
    }
  }

  @override
  Future<void> refreshUnsyncedCount() => _notifier.refreshUnsyncedCount();

  void _onCoreStateChanged(SyncState state) {
    if (_disposed || _stateController.isClosed) return;
    _stateController.add(_mapState(state));
  }

  static SyncViewState _mapState(SyncState state) {
    return SyncViewState(
      status: switch (state.status) {
        SyncStatus.idle => SyncRunStatus.idle,
        SyncStatus.loading => SyncRunStatus.running,
        SyncStatus.success => SyncRunStatus.success,
        SyncStatus.error =>
          _isPartialFailure(state)
              ? SyncRunStatus.partialFailure
              : SyncRunStatus.failure,
      },
      unsyncedCount: state.unsyncedCount,
      message: state.message,
      lastSyncAt: state.lastSyncAt,
      lastGetDebug: state.lastGetDebug,
      lastPostDebug: state.lastPostDebug,
      progressCurrent: state.progressCurrent,
      progressTotal: state.progressTotal,
      activeOperation: switch (state.activeOperation) {
        SyncOperation.pull => SyncOperationType.deltaPull,
        SyncOperation.fullRefresh => SyncOperationType.fullRefresh,
        SyncOperation.push => SyncOperationType.push,
        null => null,
      },
    );
  }

  static bool _isPartialFailure(SyncState state) {
    final debug = state.lastPostDebug;
    final failed = debug?['failed_count'];
    final synced = debug?['synced_count'];
    return failed is num && failed > 0 && synced is num && synced > 0;
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _removeListener();
    _stateController.close();
  }
}

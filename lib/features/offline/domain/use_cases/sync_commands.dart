import '../repositories/sync_repository.dart';

class PullSyncDelta {
  final SyncRepository _repository;

  const PullSyncDelta(this._repository);

  /// Reconcile local writes before reading the next remote revision window.
  ///
  /// Keeping this ordering in the application command prevents screens and
  /// background callers from accidentally pulling stale data first.
  Future<void> call() async {
    await _repository.pushPending();
    await _repository.pullDelta();
  }
}

class RunFullSyncRefresh {
  final SyncRepository _repository;

  const RunFullSyncRefresh(this._repository);

  Future<void> call() async {
    await _repository.pushPending();
    await _repository.fullRefresh();
  }
}

class PushPendingSync {
  final SyncRepository _repository;

  const PushPendingSync(this._repository);

  Future<void> call() => _repository.pushPending();
}

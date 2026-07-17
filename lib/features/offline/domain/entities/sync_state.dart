enum SyncRunStatus { idle, running, success, partialFailure, failure }

enum SyncOperationType { deltaPull, fullRefresh, push }

class SyncViewState {
  final SyncRunStatus status;
  final int unsyncedCount;
  final String? message;
  final DateTime? lastSyncAt;
  final Map<String, dynamic>? lastGetDebug;
  final Map<String, dynamic>? lastPostDebug;
  final int? progressCurrent;
  final int? progressTotal;
  final SyncOperationType? activeOperation;

  const SyncViewState({
    this.status = SyncRunStatus.idle,
    this.unsyncedCount = 0,
    this.message,
    this.lastSyncAt,
    this.lastGetDebug,
    this.lastPostDebug,
    this.progressCurrent,
    this.progressTotal,
    this.activeOperation,
  });
}

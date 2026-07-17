import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/sync_repository_impl.dart';
import '../../domain/entities/sync_state.dart';
import '../../domain/repositories/sync_repository.dart';
import '../../domain/use_cases/sync_commands.dart';
import '../../../../core/providers/sync_provider.dart';

class SyncViewModel extends StateNotifier<SyncViewState> {
  final SyncRepository _repository;
  final PullSyncDelta _pullSyncDelta;
  final RunFullSyncRefresh _runFullSyncRefresh;
  final PushPendingSync _pushPendingSync;
  late final StreamSubscription<SyncViewState> _stateSubscription;
  bool _commandInFlight = false;

  SyncViewModel(this._repository)
    : _pullSyncDelta = PullSyncDelta(_repository),
      _runFullSyncRefresh = RunFullSyncRefresh(_repository),
      _pushPendingSync = PushPendingSync(_repository),
      super(_repository.currentState) {
    _stateSubscription = _repository.watchState().listen((next) {
      if (!mounted) return;
      state = next;
    });
  }

  Future<void> runDelta() =>
      _run(SyncOperationType.deltaPull, _pullSyncDelta.call);

  Future<void> runFullRefresh() =>
      _run(SyncOperationType.fullRefresh, _runFullSyncRefresh.call);

  Future<void> pushPending() =>
      _run(SyncOperationType.push, _pushPendingSync.call);

  Future<void> refreshUnsyncedCount() => _repository.refreshUnsyncedCount();

  Future<void> _run(
    SyncOperationType operation,
    Future<void> Function() command,
  ) async {
    if (_commandInFlight || state.activeOperation != null) return;
    _commandInFlight = true;
    try {
      await command();
    } finally {
      _commandInFlight = false;
    }
  }

  @override
  void dispose() {
    _stateSubscription.cancel();
    super.dispose();
  }
}

final syncRepositoryProvider = Provider<SyncRepository>((ref) {
  final repository = SyncRepositoryImpl(ref.watch(syncProvider.notifier));
  ref.onDispose(repository.dispose);
  return repository;
});

final syncViewModelProvider =
    StateNotifierProvider<SyncViewModel, SyncViewState>((ref) {
      return SyncViewModel(ref.watch(syncRepositoryProvider));
    });

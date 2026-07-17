import '../entities/sync_state.dart';

abstract interface class SyncRepository {
  SyncViewState get currentState;

  Stream<SyncViewState> watchState();

  Future<void> pullDelta();

  Future<void> fullRefresh();

  Future<void> pushPending();

  Future<void> run(SyncOperationType operation);

  Future<void> refreshUnsyncedCount();

  void dispose();
}

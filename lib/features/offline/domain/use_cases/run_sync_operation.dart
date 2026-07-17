import '../entities/sync_state.dart';
import '../repositories/sync_repository.dart';

class RunSyncOperation {
  final SyncRepository _repository;

  const RunSyncOperation(this._repository);

  Future<void> call(SyncOperationType operation) => _repository.run(operation);
}

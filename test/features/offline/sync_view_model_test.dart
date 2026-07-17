import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:lima/features/offline/domain/entities/sync_state.dart';
import 'package:lima/features/offline/domain/repositories/sync_repository.dart';
import 'package:lima/features/offline/presentation/view_models/sync_view_model.dart';

void main() {
  test(
    'ignores a second sync command while the first one is running',
    () async {
      final repository = _FakeSyncRepository();
      final viewModel = SyncViewModel(repository);
      addTearDown(viewModel.dispose);

      final first = viewModel.runDelta();
      await Future<void>.delayed(Duration.zero);
      final second = viewModel.runFullRefresh();

      expect(repository.operations, [SyncOperationType.push]);

      repository.completeCurrentOperation();
      await Future<void>.delayed(Duration.zero);
      expect(repository.operations, [
        SyncOperationType.push,
        SyncOperationType.deltaPull,
      ]);
      repository.completeCurrentOperation();
      await Future.wait([first, second]);
      expect(repository.operations, [
        SyncOperationType.push,
        SyncOperationType.deltaPull,
      ]);
    },
  );

  test(
    'full refresh pushes pending data before pulling the catalogue',
    () async {
      final repository = _FakeSyncRepository();
      final viewModel = SyncViewModel(repository);
      addTearDown(viewModel.dispose);

      final refresh = viewModel.runFullRefresh();
      await Future<void>.delayed(Duration.zero);
      expect(repository.operations, [SyncOperationType.push]);

      repository.completeCurrentOperation();
      await Future<void>.delayed(Duration.zero);
      expect(repository.operations, [
        SyncOperationType.push,
        SyncOperationType.fullRefresh,
      ]);

      repository.completeCurrentOperation();
      await refresh;
    },
  );

  test('does not pull when pushing pending data fails', () async {
    final repository = _FakeSyncRepository(
      pushError: StateError('push failed'),
    );
    final viewModel = SyncViewModel(repository);
    addTearDown(viewModel.dispose);

    await expectLater(viewModel.runDelta(), throwsStateError);
    expect(repository.operations, [SyncOperationType.push]);
  });

  test('forwards repository state changes to the UI state', () async {
    final repository = _FakeSyncRepository();
    final viewModel = SyncViewModel(repository);
    addTearDown(viewModel.dispose);

    repository.emit(
      const SyncViewState(
        status: SyncRunStatus.running,
        activeOperation: SyncOperationType.deltaPull,
        message: 'Проверяем дельту',
        progressCurrent: 25,
        progressTotal: 100,
      ),
    );
    await Future<void>.delayed(Duration.zero);

    expect(viewModel.state.status, SyncRunStatus.running);
    expect(viewModel.state.activeOperation, SyncOperationType.deltaPull);
    expect(viewModel.state.progressCurrent, 25);
    expect(viewModel.state.progressTotal, 100);
  });
}

class _FakeSyncRepository implements SyncRepository {
  final StreamController<SyncViewState> _states =
      StreamController<SyncViewState>.broadcast();
  final List<SyncOperationType> operations = [];
  final _operationCompleted = <Completer<void>>[];
  final Object? pushError;
  SyncViewState _state = const SyncViewState();

  _FakeSyncRepository({this.pushError});

  @override
  SyncViewState get currentState => _state;

  @override
  Stream<SyncViewState> watchState() => _states.stream;

  @override
  Future<void> pullDelta() => _run(SyncOperationType.deltaPull);

  @override
  Future<void> fullRefresh() => _run(SyncOperationType.fullRefresh);

  @override
  Future<void> pushPending() => _run(SyncOperationType.push, error: pushError);

  @override
  Future<void> run(SyncOperationType operation) => _run(operation);

  Future<void> _run(SyncOperationType operation, {Object? error}) async {
    operations.add(operation);
    if (error != null) {
      throw error;
    }
    final completer = Completer<void>();
    _operationCompleted.add(completer);
    await completer.future;
  }

  void completeCurrentOperation() {
    final completer = _operationCompleted.removeAt(0);
    completer.complete();
  }

  void emit(SyncViewState state) {
    _state = state;
    _states.add(state);
  }

  @override
  Future<void> refreshUnsyncedCount() async {}

  @override
  void dispose() {
    _states.close();
  }
}

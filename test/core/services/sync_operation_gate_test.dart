import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:lima/core/services/sync_operation_gate.dart';

void main() {
  test('shares the active operation with concurrent callers', () async {
    final gate = SyncOperationGate();
    final completed = Completer<void>();
    var calls = 0;
    var completions = 0;

    final first = gate.run(() async {
      calls++;
      await completed.future;
    }, onComplete: () => completions++);
    final second = gate.run(() async {
      calls++;
    });

    expect(identical(first, second), isTrue);
    expect(gate.isRunning, isTrue);
    expect(calls, 1);

    completed.complete();
    await Future.wait([first, second]);

    expect(gate.isRunning, isFalse);
    expect(completions, 1);
  });

  test('releases the gate after a failed operation', () async {
    final gate = SyncOperationGate();
    final first = gate.run(() async {
      throw StateError('failed');
    });

    await expectLater(first, throwsStateError);
    expect(gate.isRunning, isFalse);

    var called = false;
    await gate.run(() async {
      called = true;
    });
    expect(called, isTrue);
  });
}

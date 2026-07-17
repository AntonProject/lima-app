import 'package:flutter_test/flutter_test.dart';
import 'package:lima/core/services/pending_visit_push_service.dart';

void main() {
  test('distinguishes visit failures from queue diagnostics', () {
    final visitFailure = PendingVisitPushFailure(
      type: 'visit',
      id: 12,
      message: 'visit#12: server rejected the payload',
    );
    final queueFailure = PendingVisitPushFailure(
      type: 'visit_parse',
      id: 13,
      message: 'invalid local row',
      queueFailure: true,
    );

    final result = PendingVisitPushResult(
      syncedIds: const [],
      parkedIds: const [12],
      failures: [visitFailure, queueFailure],
      responses: const [],
      remaining: 2,
      pushedAt: DateTime(2026, 7, 16),
    );

    expect(result.hasFailures, isTrue);
    expect(result.parkedIds, [12]);
    expect(result.failures.where((failure) => failure.queueFailure).toList(), [
      queueFailure,
    ]);
  });

  test('a queue-only diagnostic does not count as a server visit failure', () {
    final result = PendingVisitPushResult(
      syncedIds: const [],
      parkedIds: const [],
      failures: const [
        PendingVisitPushFailure(
          type: 'repair',
          message: 'repair failed',
          queueFailure: true,
        ),
      ],
      responses: const [],
      remaining: 0,
      pushedAt: DateTime(2026, 7, 16),
    );

    expect(result.hasFailures, isFalse);
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:lima/core/services/pending_mutation_sync_service.dart';

void main() {
  test('serializes a queue failure for sync diagnostics', () {
    const failure = PendingMutationFailure(
      type: 'favorite',
      id: 7,
      message: 'server rejected the mutation',
    );

    expect(failure.toJson(), {
      'type': 'favorite',
      'id': 7,
      'error': 'server rejected the mutation',
    });
  });

  test('reports whether mutation queues contain failures', () {
    expect(const PendingMutationSyncResult().hasFailures, isFalse);
    expect(
      const PendingMutationSyncResult(
        failures: [PendingMutationFailure(type: 'feedback', message: 'failed')],
      ).hasFailures,
      isTrue,
    );
  });
}

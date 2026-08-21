import 'package:flutter_test/flutter_test.dart';
import 'package:lima/core/services/pending_workday_sync_service.dart';

void main() {
  const policy = WorkdayRetryPolicy();

  test('parks validation 4xx immediately but retries auth/rate-limit errors', () {
    expect(policy.shouldPark(attempts: 1, statusCode: 400), isTrue);
    expect(policy.shouldPark(attempts: 1, statusCode: 401), isFalse);
    expect(policy.shouldPark(attempts: 1, statusCode: 429), isFalse);
    expect(policy.shouldPark(attempts: 1, statusCode: 500), isFalse);
  });

  test('parks transient failures at the fourth attempt with exponential backoff', () {
    expect(policy.shouldPark(attempts: 3, statusCode: 503), isFalse);
    expect(policy.shouldPark(attempts: 4, statusCode: 503), isTrue);
    expect(policy.backoff(1), const Duration(seconds: 30));
    expect(policy.backoff(2), const Duration(seconds: 60));
    expect(policy.backoff(4), const Duration(seconds: 240));
  });
}

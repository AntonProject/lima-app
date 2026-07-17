import 'package:flutter_test/flutter_test.dart';
import 'package:lima/core/failures/result.dart';

void main() {
  test('success exposes its value and no failure', () {
    const result = Result<int>.success(42);

    expect(result.isSuccess, isTrue);
    expect(result.isFailure, isFalse);
    expect(result.requireValue, 42);
    expect(result.failure, isNull);
  });

  test('failure preserves the typed error', () {
    const failure = UnexpectedFailure('network unavailable');
    const result = Result<int>.failure(failure);

    expect(result.isFailure, isTrue);
    expect(result.failure, same(failure));
    expect(() => result.requireValue, throwsA(same(failure)));
  });
}

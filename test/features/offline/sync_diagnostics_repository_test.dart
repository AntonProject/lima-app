import 'package:flutter_test/flutter_test.dart';
import 'package:lima/features/offline/data/sync_diagnostics_repository.dart';

void main() {
  test('extracts the first useful message from an API error object', () {
    expect(
      SyncDiagnosticsRepositoryImpl.extractFailureMessage(
        '{"error":"Не указан процент предоплаты"}',
        fallback: 'fallback',
      ),
      'Не указан процент предоплаты',
    );
    expect(
      SyncDiagnosticsRepositoryImpl.extractFailureMessage(
        '{"detail":"Bad request"}',
        fallback: 'fallback',
      ),
      'Bad request',
    );
  });

  test(
    'keeps raw and fallback error text when the payload is not an object',
    () {
      expect(
        SyncDiagnosticsRepositoryImpl.extractFailureMessage(
          'server unavailable',
          fallback: 'fallback',
        ),
        'server unavailable',
      );
      expect(
        SyncDiagnosticsRepositoryImpl.extractFailureMessage(
          null,
          fallback: 'fallback',
        ),
        'fallback',
      );
    },
  );
}

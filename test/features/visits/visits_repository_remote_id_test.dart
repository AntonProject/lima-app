import 'package:flutter_test/flutter_test.dart';
import 'package:lima/features/visits/data/visits_repository.dart';

void main() {
  test('reads the visit id from a bare or wrapped add response', () {
    expect(VisitsRepositoryImpl.remoteIdFromResponse(100933), 100933);
    expect(VisitsRepositoryImpl.remoteIdFromResponse('100933'), 100933);
    expect(VisitsRepositoryImpl.remoteIdFromResponse({'visit_id': 7}), 7);
    expect(
      VisitsRepositoryImpl.remoteIdFromResponse({
        'data': {'id': 8},
      }),
      8,
    );
    expect(VisitsRepositoryImpl.remoteIdFromResponse(null), isNull);
  });
}

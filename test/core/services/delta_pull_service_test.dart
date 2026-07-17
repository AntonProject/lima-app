import 'package:flutter_test/flutter_test.dart';
import 'package:lima/core/services/delta_pull_service.dart';

void main() {
  test('uses the furthest cursor from metadata and local rows', () {
    expect(
      DeltaPullService.effectiveSyncId(stored: 58490, local: 58487),
      58490,
    );
    expect(
      DeltaPullService.effectiveSyncId(stored: 58487, local: 58490),
      58490,
    );
    expect(DeltaPullService.effectiveSyncId(stored: 0, local: 0), 0);
  });
}

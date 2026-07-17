import 'package:flutter_test/flutter_test.dart';

/// Documents the invariants used by DoctorDirectorySyncService when deciding
/// whether a cached doctor directory is complete enough to skip repair.
void main() {
  test('a cached directory is incomplete when below server total', () {
    const localDoctors = 2130;
    const expectedDoctors = 12810;

    expect(localDoctors < expectedDoctors, isTrue);
  });

  test('cursor progress is bounded by the expected total', () {
    const cursor = 14000;
    const expectedDoctors = 12810;
    final progress = cursor.clamp(0, expectedDoctors);

    expect(progress, expectedDoctors);
  });
}

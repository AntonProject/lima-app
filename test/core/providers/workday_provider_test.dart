import 'package:flutter_test/flutter_test.dart';
import 'package:lima/core/providers/workday_provider.dart';

void main() {
  test('keeps a completed workday record without changing the start UI', () {
    const state = WorkdayState(
      featureEnabled: true,
      workday: WorkdaySnapshot(
        isCompleted: true,
        endTime: '2026-08-17T22:10:00',
      ),
    );

    expect(state.workday.phase, WorkdayPhase.notStarted);
    expect(state.isVisible, isTrue);
    expect(state.hasStartedWorkday, isTrue);
  });

  test('allows the first offline start only when no workday was recorded', () {
    const state = WorkdayState();

    expect(state.hasStartedWorkday, isFalse);
  });
}

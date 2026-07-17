import 'package:flutter_test/flutter_test.dart';
import 'package:lima/core/models/local_visit.dart';

void main() {
  group('LocalVisit.fromMap', () {
    test('parses a full row from the local SQLite visits table', () {
      final visit = LocalVisit.fromMap({
        'id': 1,
        'remote_id': 100,
        'org_id': 7,
        'org_name': 'ARZON DORIXONA',
        'doctor_id': 42,
        'doctor_name': 'Иванов Иван',
        'visit_type': 'order',
        'status': 'completed',
        'notes': 'ok',
        'created_at': '2026-01-01T10:00:00.000',
        'updated_at': '2026-01-01T10:05:00.000',
        'is_synced': 1,
        'sync_failed': 0,
        'push_attempts': 2,
        'next_retry_at': '2026-01-01T10:10:00.000',
        'medical_rep_name': 'Петров Пётр',
      });

      expect(visit.id, 1);
      expect(visit.remoteId, 100);
      expect(visit.orgId, 7);
      expect(visit.orgName, 'ARZON DORIXONA');
      expect(visit.doctorId, 42);
      expect(visit.visitType, 'order');
      expect(visit.status, 'completed');
      expect(visit.isSynced, true);
      expect(visit.syncFailed, false);
      expect(visit.pushAttempts, 2);
      expect(visit.nextRetryAt, DateTime.parse('2026-01-01T10:10:00.000'));
      expect(visit.medicalRepName, 'Петров Пётр');
    });

    test('sync bookkeeping fields default to unsynced/not-parked/zero '
        'attempts when absent (freshly-created offline visit)', () {
      final visit = LocalVisit.fromMap({
        'org_id': 1,
        'org_name': 'X',
        'created_at': '2026-01-01T00:00:00.000',
        'updated_at': '2026-01-01T00:00:00.000',
      });

      expect(visit.isSynced, false);
      expect(visit.syncFailed, false);
      expect(visit.pushAttempts, 0);
      expect(visit.nextRetryAt, isNull);
    });

    test('visit_type/status fall back to lpu/planned when absent', () {
      final visit = LocalVisit.fromMap({
        'org_id': 1,
        'org_name': 'X',
        'created_at': '2026-01-01T00:00:00.000',
        'updated_at': '2026-01-01T00:00:00.000',
      });

      expect(visit.visitType, 'lpu');
      expect(visit.status, 'planned');
    });

    test('a malformed next_retry_at does not throw — parses to null', () {
      final visit = LocalVisit.fromMap({
        'org_id': 1,
        'org_name': 'X',
        'created_at': '2026-01-01T00:00:00.000',
        'updated_at': '2026-01-01T00:00:00.000',
        'next_retry_at': 'not a date',
      });

      expect(visit.nextRetryAt, isNull);
    });

    test('toMap/fromMap round-trip preserves sync bookkeeping fields', () {
      final original = LocalVisit(
        id: 5,
        orgId: 1,
        orgName: 'X',
        createdAt: DateTime.parse('2026-01-01T00:00:00.000'),
        updatedAt: DateTime.parse('2026-01-01T00:00:00.000'),
        syncFailed: true,
        pushAttempts: 3,
        nextRetryAt: DateTime.parse('2026-01-02T00:00:00.000'),
        medicalRepName: 'Rep',
        lastPushRequestJson: '{"a":1}',
        lastPushResponseJson: '{"b":2}',
      );

      final roundTripped = LocalVisit.fromMap(original.toMap());

      expect(roundTripped.syncFailed, true);
      expect(roundTripped.pushAttempts, 3);
      expect(roundTripped.nextRetryAt, original.nextRetryAt);
      expect(roundTripped.medicalRepName, 'Rep');
      expect(roundTripped.lastPushRequestJson, '{"a":1}');
      expect(roundTripped.lastPushResponseJson, '{"b":2}');
    });

    test('copyWith updates only the given fields', () {
      final original = LocalVisit(
        orgId: 1,
        orgName: 'X',
        createdAt: DateTime.parse('2026-01-01T00:00:00.000'),
        updatedAt: DateTime.parse('2026-01-01T00:00:00.000'),
      );

      final parked = original.copyWith(syncFailed: true, pushAttempts: 8);

      expect(parked.syncFailed, true);
      expect(parked.pushAttempts, 8);
      // Untouched fields survive.
      expect(parked.orgId, original.orgId);
      expect(parked.orgName, original.orgName);
    });
  });
}

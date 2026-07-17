import 'package:flutter_test/flutter_test.dart';
import 'package:lima/core/models/models.dart';

void main() {
  group('Doctor.fromJson', () {
    test('parses a full row from the local SQLite doctors table', () {
      final doctor = Doctor.fromJson({
        'id': 42,
        'full_name': 'Иванов Иван',
        'specialty': 'Кардиолог',
        'organisation_id': 7,
        'is_favorite': 1, // SQLite stores booleans as INTEGER 0/1
        'category': 'A',
        'last_visit_label': '3 визита',
        'updated_at': '2026-01-01T00:00:00.000',
      });

      expect(doctor.id, 42);
      expect(doctor.fullName, 'Иванов Иван');
      expect(doctor.specialty, 'Кардиолог');
      expect(doctor.organisationId, 7);
      expect(doctor.isFavorite, true);
      expect(doctor.category, 'A');
      expect(doctor.lastVisitLabel, '3 визита');
    });

    test('accepts organization_id (API spelling) as a fallback for '
        'organisation_id (local DB spelling)', () {
      final doctor = Doctor.fromJson({
        'id': 1,
        'full_name': 'Петров Пётр',
        'organization_id': 9,
      });

      expect(doctor.organisationId, 9);
    });

    test('prefers organisation_id over organization_id when both are '
        'present', () {
      final doctor = Doctor.fromJson({
        'id': 1,
        'full_name': 'Петров Пётр',
        'organisation_id': 5,
        'organization_id': 9,
      });

      expect(doctor.organisationId, 5);
    });

    test('accepts name/position as fallbacks for full_name/specialty', () {
      final doctor = Doctor.fromJson({
        'id': 2,
        'name': 'Сидоров Сидор',
        'position': 'Терапевт',
        'organisation_id': 1,
      });

      expect(doctor.fullName, 'Сидоров Сидор');
      expect(doctor.specialty, 'Терапевт');
    });

    test('is_favorite: interprets bool, int and string forms the same '
        'way (mixed sources: API JSON vs SQLite)', () {
      for (final rawValue in [true, 1, '1', 'true']) {
        final doctor = Doctor.fromJson({
          'id': 1,
          'full_name': 'X',
          'organisation_id': 1,
          'is_favorite': rawValue,
        });
        expect(doctor.isFavorite, true, reason: 'failed for $rawValue');
      }
      for (final rawValue in [false, 0, '0', null]) {
        final doctor = Doctor.fromJson({
          'id': 1,
          'full_name': 'X',
          'organisation_id': 1,
          'is_favorite': rawValue,
        });
        expect(doctor.isFavorite, false, reason: 'failed for $rawValue');
      }
    });

    test('missing id/organisation_id default to 0 rather than throwing', () {
      final doctor = Doctor.fromJson({'full_name': 'Безымянный'});

      expect(doctor.id, 0);
      expect(doctor.organisationId, 0);
    });

    test('missing full_name defaults to empty string rather than throwing', () {
      final doctor = Doctor.fromJson({'id': 1, 'organisation_id': 1});

      expect(doctor.fullName, '');
    });

    test('blank/"null"-string optional fields normalize to null', () {
      final doctor = Doctor.fromJson({
        'id': 1,
        'full_name': 'X',
        'organisation_id': 1,
        'specialty': '',
        'phone': 'null',
        'hobby': '   ',
      });

      expect(doctor.specialty, isNull);
      expect(doctor.phone, isNull);
      expect(doctor.hobby, isNull);
    });

    test('add-doctor extras (specialization/hobby/interests/birthday) '
        'round-trip through toJson', () {
      final doctor = Doctor.fromJson({
        'id': 1,
        'full_name': 'X',
        'organisation_id': 1,
        'specialization_id': 21,
        'hobby': 'Шахматы',
        'interests': 'Медицина',
        'birthday': '1990-01-01',
      });

      final json = doctor.toJson();
      expect(json['specialization_id'], 21);
      expect(json['hobby'], 'Шахматы');
      expect(json['interests'], 'Медицина');
      expect(json['birthday'], '1990-01-01');
    });

    test('toJson round-trips through fromJson without loss', () {
      final original = Doctor.fromJson({
        'id': 1,
        'full_name': 'Иванов Иван',
        'specialty': 'Кардиолог',
        'organisation_id': 7,
        'is_favorite': 1,
      });

      final roundTripped = Doctor.fromJson(original.toJson());

      expect(roundTripped.id, original.id);
      expect(roundTripped.fullName, original.fullName);
      expect(roundTripped.specialty, original.specialty);
      expect(roundTripped.organisationId, original.organisationId);
      expect(roundTripped.isFavorite, original.isFavorite);
    });
  });
}

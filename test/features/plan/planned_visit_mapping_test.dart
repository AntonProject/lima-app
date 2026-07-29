import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lima/core/models/models.dart';
import 'package:lima/core/network/remote_api_service.dart';
import 'package:lima/features/plan/domain/entities/planned_visit_draft.dart';
import 'package:lima/features/plan/domain/entities/planned_visit_record.dart';
import 'package:lima/features/visits/data/planned_visit_mapper.dart';

void main() {
  test('API plan keeps every nested doctor id and name', () {
    final raw = <String, dynamic>{
      'id': 78820,
      'start_date': '2026-07-29T00:00:00',
      'visit_format_id': 2,
      'organization': {
        'organization_id': 4201,
        'organization_name': 'Тестовый ЛПУ',
        'type_id': 2,
        'region_name': 'г. Ташкент',
      },
      'medrep': {'id': 992, 'name': 'Anton Dev'},
      'doctors': [
        {'id': 30500, 'full_name': 'Акбарова Дилдора Дарвиновна'},
        {'id': 27617, 'full_name': 'Алиджанов Сарвар Кашипович'},
      ],
    };

    final row = RemoteApiService.mapPlannedVisitToLocal(raw);

    expect(row, isNotNull);
    expect(row!['org_id'], 4201);
    expect(row['org_type'], 'lpu');
    expect(row['doctor_id'], 30500);
    expect(
      row['doctor_name'],
      'Акбарова Дилдора Дарвиновна, Алиджанов Сарвар Кашипович',
    );
    expect(row['visit_format'], 'double');
    final persistedRaw = jsonDecode(row['raw_json'] as String) as Map;
    expect((persistedRaw['doctors'] as List).map((doctor) => doctor['id']), [
      30500,
      27617,
    ]);
  });

  test('locally created plan persists all selected doctors', () {
    final draft = PlannedVisitDraft(
      organisationId: 4201,
      organisationName: 'Тестовый ЛПУ',
      organisationType: 'lpu',
      doctorId: null,
      doctorIds: const [30500, 27617],
      doctorName: 'Акбарова Дилдора Дарвиновна, Алиджанов Сарвар Кашипович',
      assignedBy: 'Anton Dev',
      city: 'г. Ташкент',
      district: null,
      visitDate: DateTime(2026, 7, 29),
      comment: '',
      visitFormat: 'double',
      visitFormatId: 2,
    );

    final row = PlannedVisitMapper.toLocalRow(draft);
    final raw = jsonDecode(row['raw_json'] as String) as Map;

    expect(raw['doctor_ids'], [30500, 27617]);
    expect(raw['visit_format_id'], 2);
  });

  test('presentation model keeps doctor ids used to start the visit', () {
    final record = PlannedVisitRecord(
      localId: 1,
      remoteId: 78820,
      organisationName: 'Тестовый ЛПУ',
      organisationId: 4201,
      organisationType: 'lpu',
      doctorIds: const [30500, 27617],
      doctorName: 'Акбарова Дилдора Дарвиновна, Алиджанов Сарвар Кашипович',
      assignedBy: 'Anton Dev',
      date: DateTime(2026, 7, 29),
      status: VisitStatus.planned,
      visitFormat: 'double',
    );

    expect(record.toModel().doctorIds, [30500, 27617]);
  });
}

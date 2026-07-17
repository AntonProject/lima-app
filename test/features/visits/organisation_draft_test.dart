import 'package:flutter_test/flutter_test.dart';
import 'package:lima/core/models/models.dart';
import 'package:lima/features/visits/domain/entities/organisation_draft.dart';

void main() {
  test('organisation draft keeps the typed local model contract', () {
    const draft = OrganisationDraft(
      name: 'Test pharmacy',
      inn: '123456789',
      type: OrgType.pharmacy,
      typeId: 1,
      regionId: 1,
      regionName: 'г. Ташкент',
      areaId: 5,
      areaName: 'Яшнабадский район',
      phone: '+998900000000',
      address: 'Test address',
      categoryId: 3,
      categoryName: 'C',
    );

    final local = draft.toLocalModel(id: -10, updatedAt: '2026-07-16');

    expect(local.id, -10);
    expect(local.name, 'Test pharmacy');
    expect(local.type, OrgType.pharmacy);
    expect(local.regionId, 1);
    expect(local.areaId, 5);
    expect(local.phone, '+998900000000');
    expect(local.updatedAt, '2026-07-16');
  });

  test('organisation update draft carries only editable fields', () {
    const draft = OrganisationUpdateDraft(
      organisationId: 42,
      name: 'Updated LPU',
      address: 'New address',
      phone: '+998901234567',
      category: 'A',
    );

    expect(draft.organisationId, 42);
    expect(draft.name, 'Updated LPU');
    expect(draft.address, 'New address');
    expect(draft.phone, '+998901234567');
    expect(draft.category, 'A');
    expect(draft.latitude, isNull);
  });
}

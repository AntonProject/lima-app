import 'package:flutter_test/flutter_test.dart';
import 'package:lima/features/visits/domain/use_cases/build_pharmacy_order_lines.dart';

void main() {
  const builder = BuildPharmacyOrderLines();

  test('maps a valid line using stock and binding identifiers', () {
    final result = builder([
      const PharmacyOrderLineInput(
        drugId: 109,
        drugName: 'Тестовый препарат',
        quantity: 2,
        salePrice: 67200,
        incomeDetailingId: 2194,
        bindingDrugId: 26,
      ),
    ]);

    expect(result.skippedInvalidItems, 0);
    expect(result.lines, hasLength(1));
    expect(result.lines.single.incomeDetailingId, 2194);
    expect(result.lines.single.drugId, 26);
    expect(result.lines.single.salePriceWithoutNds, 60000);
    expect(result.lines.single.toApiMap(), {
      'income_detailing_id': 2194,
      'drug_id': 26,
      'drug_name': 'Тестовый препарат',
      'package': 2,
      'quantity': 2,
      'sale_price': 67200,
      'sale_price_without_nds': 60000,
      'price': 67200,
      'serial_no': null,
      'expire_date': null,
    });
  });

  test('falls back to dictionary drug id when binding id is absent', () {
    final result = builder([
      const PharmacyOrderLineInput(
        drugId: 109,
        drugName: 'Тестовый препарат',
        quantity: 1,
        salePrice: 64400,
        incomeDetailingId: 2194,
      ),
    ]);

    expect(result.lines.single.drugId, 109);
  });

  test('skips a line without stock binding and reports it', () {
    final result = builder([
      const PharmacyOrderLineInput(
        drugId: 109,
        drugName: 'Без остатка',
        quantity: 1,
        salePrice: 64400,
      ),
    ]);

    expect(result.lines, isEmpty);
    expect(result.skippedInvalidItems, 1);
  });

  test('does not create a line for a zero quantity', () {
    final result = builder([
      const PharmacyOrderLineInput(
        drugId: 109,
        drugName: 'Нулевое количество',
        quantity: 0,
        salePrice: 64400,
        incomeDetailingId: 2194,
      ),
    ]);

    expect(result.lines, isEmpty);
    expect(result.skippedInvalidItems, 0);
  });
}

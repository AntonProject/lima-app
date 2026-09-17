import 'package:flutter_test/flutter_test.dart';
import 'package:lima/core/services/specification_export_service.dart';

void main() {
  test('derives base price without applying markup and VAT twice', () {
    final basePrice = SpecificationExportService.basePriceFromGross(
      grossPrice: 120000,
      markupPercent: 20,
    );

    final recomposedGross = basePrice * 1.2 * 1.12;
    expect(recomposedGross, closeTo(120000, 0.001));
  });

  test('returns zero for a non-positive gross price', () {
    expect(
      SpecificationExportService.basePriceFromGross(
        grossPrice: 0,
        markupPercent: 20,
      ),
      0,
    );
  });

  test('grows a PNG row so long product metadata is not clipped', () {
    const short = SpecificationItem(
      name: 'ЭССЕНИКС',
      manufacturer: 'TEMUR MED',
      quantity: 1,
      serialNumber: 'S-1',
      expiryDate: '2027-09-17',
      basePrice: 100,
    );
    const long = SpecificationItem(
      name:
          'Очень длинное наименование лекарственного препарата для '
          'внутривенного введения во флаконах большого объёма',
      manufacturer: 'TEMUR MED',
      quantity: 1,
      serialNumber: 'SERIAL-2026-09',
      expiryDate: '2027-09-17',
      basePrice: 100,
    );

    final shortHeight = SpecificationExportService.pngRowHeightForItem(short);
    expect(shortHeight, greaterThanOrEqualTo(79));
    expect(
      SpecificationExportService.pngRowHeightForItem(long),
      greaterThan(shortHeight),
    );
  });
}

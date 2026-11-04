import 'dart:convert';
import 'dart:typed_data';

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

  test('recovers the real base price from a server-priced line', () {
    // "гепатопротем" from a field report: 81 536 UZS gross at a 12% markup.
    final basePrice = SpecificationExportService.basePriceFromGross(
      grossPrice: 81536,
      markupPercent: 12,
    );

    expect(basePrice, closeTo(65000, 0.001));
  });

  test('an unknown markup only strips VAT instead of assuming a percent', () {
    final basePrice = SpecificationExportService.basePriceFromGross(
      grossPrice: 112000,
      markupPercent: null,
    );

    expect(basePrice, closeTo(100000, 0.001));
  });

  test('accepts only a real document from the server', () {
    final png = Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 0x0D]);
    final errorBody = Uint8List.fromList(utf8.encode('{"error":"bad"}'));

    expect(
      SpecificationExportService.isDocumentOfFormat(
        png,
        SpecificationFormat.png,
      ),
      isTrue,
    );
    expect(
      SpecificationExportService.isDocumentOfFormat(
        errorBody,
        SpecificationFormat.png,
      ),
      isFalse,
    );
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

/// Input for one selected pharmacy-order line.
///
/// This type deliberately contains no Flutter, SQLite or API dependencies.
class PharmacyOrderLineInput {
  final int drugId;
  final String drugName;
  final int quantity;
  final double salePrice;
  final int? incomeDetailingId;
  final int? bindingDrugId;
  final String? serialNumber;
  final String? expiryDate;

  const PharmacyOrderLineInput({
    required this.drugId,
    required this.drugName,
    required this.quantity,
    required this.salePrice,
    this.incomeDetailingId,
    this.bindingDrugId,
    this.serialNumber,
    this.expiryDate,
  });
}

/// A validated order line ready for the data layer to serialize.
class PharmacyOrderLine {
  final int incomeDetailingId;
  final int drugId;
  final String drugName;
  final int quantity;
  final double salePrice;
  final double salePriceWithoutNds;
  final String? serialNumber;
  final String? expiryDate;

  const PharmacyOrderLine({
    required this.incomeDetailingId,
    required this.drugId,
    required this.drugName,
    required this.quantity,
    required this.salePrice,
    required this.salePriceWithoutNds,
    this.serialNumber,
    this.expiryDate,
  });

  PharmacyOrderLine copyWith({
    double? salePrice,
    double? salePriceWithoutNds,
  }) => PharmacyOrderLine(
    incomeDetailingId: incomeDetailingId,
    drugId: drugId,
    drugName: drugName,
    quantity: quantity,
    salePrice: salePrice ?? this.salePrice,
    salePriceWithoutNds: salePriceWithoutNds ?? this.salePriceWithoutNds,
    serialNumber: serialNumber,
    expiryDate: expiryDate,
  );

  /// Keeps the existing web/API payload contract stable while the screen no
  /// longer owns the mapping rules.
  Map<String, dynamic> toApiMap() => {
    'income_detailing_id': incomeDetailingId,
    'drug_id': drugId,
    'drug_name': drugName,
    'package': quantity,
    'quantity': quantity,
    'sale_price': salePrice,
    'sale_price_without_nds': salePriceWithoutNds,
    'price': salePrice,
    'serial_no': serialNumber,
    'expire_date': expiryDate,
  };
}

class PharmacyOrderLinesResult {
  final List<PharmacyOrderLine> lines;
  final int skippedInvalidItems;

  const PharmacyOrderLinesResult({
    required this.lines,
    required this.skippedInvalidItems,
  });
}

/// Validates and maps selected products into pharmacy-order lines.
class BuildPharmacyOrderLines {
  const BuildPharmacyOrderLines();

  PharmacyOrderLinesResult call(Iterable<PharmacyOrderLineInput> inputs) {
    final lines = <PharmacyOrderLine>[];
    var skippedInvalidItems = 0;

    for (final input in inputs) {
      if (input.quantity <= 0) continue;

      final incomeDetailingId = input.incomeDetailingId;
      final bindingDrugId = input.bindingDrugId ?? input.drugId;
      if (incomeDetailingId == null || bindingDrugId <= 0) {
        skippedInvalidItems++;
        continue;
      }

      lines.add(
        PharmacyOrderLine(
          incomeDetailingId: incomeDetailingId,
          drugId: bindingDrugId,
          drugName: input.drugName,
          quantity: input.quantity,
          salePrice: input.salePrice,
          salePriceWithoutNds: _priceWithoutNds(input.salePrice),
          serialNumber: input.serialNumber,
          expiryDate: input.expiryDate,
        ),
      );
    }

    return PharmacyOrderLinesResult(
      lines: List.unmodifiable(lines),
      skippedInvalidItems: skippedInvalidItems,
    );
  }

  static double _priceWithoutNds(double value) =>
      double.parse((value / 1.12).toStringAsFixed(2));
}

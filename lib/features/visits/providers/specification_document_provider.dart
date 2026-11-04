import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/remote_api_service.dart';
import '../../../core/services/specification_export_service.dart';
import '../domain/use_cases/build_pharmacy_order_lines.dart';

final specificationDocumentSourceProvider =
    Provider<SpecificationDocumentSource>(
      (ref) => SpecificationDocumentSource(ref.read(remoteApiServiceProvider)),
    );

/// Server-rendered specifications, requested the same way as the web client.
class SpecificationDocumentSource {
  final RemoteApiService _api;

  const SpecificationDocumentSource(this._api);

  Future<Uint8List> forVisit(int visitId, SpecificationFormat format) =>
      _api.fetchVisitSpecification(visitId, format: format.name);

  Future<Uint8List> forDraft({
    required int organizationId,
    required String organizationName,
    required int marginId,
    required int paymentVariantId,
    required bool isWholesaler,
    required List<PharmacyOrderLine> lines,
    required SpecificationFormat format,
    int? contractId,
  }) => _api.buildVisitSpecification({
    'organization_id': organizationId,
    'margin_id': marginId,
    'payment_variant_id': paymentVariantId,
    'contract_id': contractId,
    'is_wholesaler': isWholesaler,
    'name': organizationName,
    'drugs': lines
        .map(
          (line) => {
            'income_detailing_id': line.incomeDetailingId,
            'drug_id': line.drugId,
            'package': line.quantity,
            'sale_price': line.salePrice,
          },
        )
        .toList(growable: false),
  }, format: format.name);
}

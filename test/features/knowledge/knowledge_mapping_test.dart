import 'package:flutter_test/flutter_test.dart';
import 'package:lima/core/models/models.dart';
import 'package:lima/features/collections/domain/entities/cart_server_item.dart';

void main() {
  test('maps material API fields and local cache metadata', () {
    final material = DrugMaterial.fromJson({
      'id': '7',
      'drug_id': 109,
      'document_id': '7001',
      'title': 'Product sheet',
      'file_type': 'pdf',
      'document_type_name': 'Презентация',
      'local_path': '/Documents/7',
      'file_name': 'product-sheet.pdf',
      'cached_path': '/tmp/product-sheet.pdf',
      'uploaded_at': '2026-05-13T10:17:52',
      'is_mandatory': 1,
    });

    expect(material.id, 7);
    expect(material.drugId, 109);
    expect(material.documentId, 7001);
    expect(material.documentTypeName, 'Презентация');
    expect(material.url, '/Documents/7');
    expect(material.fileName, 'product-sheet.pdf');
    expect(material.cachedPath, '/tmp/product-sheet.pdf');
    expect(material.isMandatory, isTrue);
  });

  test('maps server cart terms without losing 0% or buyer type', () {
    final item = CartServerItem.fromMap({
      'drug_id': 109,
      'name': 'Drug',
      'manufacturer': 'Company',
      'price': 64400,
      'quantity': 2,
      'cart_id': 42,
      'prepayment_percent': 0,
      'buyer_type': 1,
      'current_stock_id': 2194,
    });

    expect(item.cartId, 42);
    expect(item.prepaymentPercent, 0);
    expect(item.buyerType, 1);
    expect(item.currentStockId, 2194);
    expect(item.quantity, 2);
  });
}

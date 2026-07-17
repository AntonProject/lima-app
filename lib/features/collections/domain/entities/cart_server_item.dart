class CartServerItem {
  final int drugId;
  final String name;
  final String manufacturer;
  final double price;
  final String? serialNumber;
  final String? expiryDate;
  final int? stock;
  final int quantity;
  final int? pharmacyId;
  final String? pharmacyName;
  final String? addedAt;
  final int? cartId;
  final int? prepaymentPercent;
  final int? buyerType;
  final int? currentStockId;
  final int? bindingDrugId;

  const CartServerItem({
    required this.drugId,
    required this.name,
    required this.manufacturer,
    required this.price,
    this.serialNumber,
    this.expiryDate,
    this.stock,
    required this.quantity,
    this.pharmacyId,
    this.pharmacyName,
    this.addedAt,
    this.cartId,
    this.prepaymentPercent,
    this.buyerType,
    this.currentStockId,
    this.bindingDrugId,
  });

  factory CartServerItem.fromMap(Map<String, dynamic> json) {
    final isWholesaler = _toBool(json['is_wholesaler']);
    return CartServerItem(
      drugId: _toInt(json['drug_id']) ?? 0,
      name: json['name']?.toString() ?? '',
      manufacturer: json['manufacturer']?.toString() ?? '',
      price: _toDouble(json['price']),
      serialNumber: json['serial_number']?.toString(),
      expiryDate: json['expiry_date']?.toString(),
      stock: _toInt(json['stock']),
      quantity: _toInt(json['quantity']) ?? 1,
      pharmacyId: _toInt(json['pharmacy_id']),
      pharmacyName: json['pharmacy_name']?.toString(),
      addedAt: json['added_at']?.toString(),
      cartId: _toInt(json['cart_id']),
      prepaymentPercent:
          _toInt(json['prepayment_percent']) ?? _toInt(json['prepayment']),
      buyerType:
          _toInt(json['buyer_type']) ??
          (isWholesaler == null ? null : (isWholesaler ? 1 : 0)),
      currentStockId: _toInt(json['current_stock_id']),
      bindingDrugId: _toInt(json['binding_drug_id']),
    );
  }

  Map<String, dynamic> toMap() => {
    'drug_id': drugId,
    'name': name,
    'manufacturer': manufacturer,
    'price': price,
    'serial_number': serialNumber,
    'expiry_date': expiryDate,
    'stock': stock,
    'quantity': quantity,
    'pharmacy_id': pharmacyId,
    'pharmacy_name': pharmacyName,
    'added_at': addedAt,
    if (cartId != null) 'cart_id': cartId,
    if (prepaymentPercent != null) 'prepayment_percent': prepaymentPercent,
    if (buyerType != null) 'buyer_type': buyerType,
    if (currentStockId != null) 'current_stock_id': currentStockId,
    if (bindingDrugId != null) 'binding_drug_id': bindingDrugId,
  };

  static int? _toInt(Object? value) {
    if (value is num) return value.toInt();
    return int.tryParse('$value');
  }

  static double _toDouble(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse('$value') ?? 0;
  }

  static bool? _toBool(Object? value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value == null) return null;
    final normalized = value.toString().toLowerCase();
    if (normalized == 'true' || normalized == '1') return true;
    if (normalized == 'false' || normalized == '0') return false;
    return null;
  }
}

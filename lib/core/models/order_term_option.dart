/// A booking payment/buyer combination explicitly allowed by the API.
///
/// The mobile client must not invent a margin for a combination which is not
/// present in this list. `marginId` is the value sent to `/visits/add`.
class OrderTermOption {
  final int marginId;
  final int prepaymentPercent;
  final bool wholesaler;
  final bool retail;

  const OrderTermOption({
    required this.marginId,
    required this.prepaymentPercent,
    required this.wholesaler,
    required this.retail,
  });

  bool supportsBuyer(bool isWholesaler) => isWholesaler ? wholesaler : retail;

  String get cacheKey => '$prepaymentPercent:${wholesaler ? 1 : 0}';

  factory OrderTermOption.fromMap(Map<String, dynamic> map) {
    final marginId = _toInt(map['id'] ?? map['margin_id']);
    final prepaymentPercent = _toInt(map['prepayment_percent']);
    if (marginId == null || prepaymentPercent == null) {
      throw const FormatException('Invalid order term option');
    }
    return OrderTermOption(
      marginId: marginId,
      prepaymentPercent: prepaymentPercent,
      wholesaler: _toBool(map['wholesaler'] ?? map['is_wholesaler']) ?? false,
      retail: _toBool(map['retail'] ?? map['is_retail']) ?? false,
    );
  }

  /// Accepts both the direct `/Markups/short` array item and the common
  /// wrapped `{result: [...]}` response shape. Keeping this parser here makes
  /// the API contract testable without constructing a Dio client.
  static List<OrderTermOption> fromResponse(Object? response) {
    final rows = _extractRows(response);
    final result = <OrderTermOption>[];
    for (final row in rows) {
      if (row is! Map) continue;
      try {
        result.add(OrderTermOption.fromMap(Map<String, dynamic>.from(row)));
      } on FormatException {
        // Ignore malformed server rows; never invent a usable combination.
      }
    }
    return List.unmodifiable(result);
  }

  Map<String, dynamic> toMap() => {
    'id': marginId,
    'margin_id': marginId,
    'prepayment_percent': prepaymentPercent,
    'wholesaler': wholesaler,
    'retail': retail,
  };

  static int? _toInt(Object? value) {
    if (value is num) return value.toInt();
    return int.tryParse('$value');
  }

  static bool? _toBool(Object? value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value == null) return null;
    switch (value.toString().toLowerCase()) {
      case 'true':
      case '1':
      case 'yes':
        return true;
      case 'false':
      case '0':
      case 'no':
        return false;
    }
    return null;
  }

  static List<Object?> _extractRows(Object? response) {
    if (response is List) return response.cast<Object?>();
    if (response is! Map) return const [];
    for (final key in const ['result', 'data', 'items', 'results', 'rows']) {
      final value = response[key];
      if (value is List) return value.cast<Object?>();
      if (value is Map) {
        final nested = _extractRows(value);
        if (nested.isNotEmpty) return nested;
      }
    }
    return const [];
  }
}

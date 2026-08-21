/// A client contract selectable for an LPU booking.
class ClientContract {
  final int id;
  final String name;
  final String? number;
  final String? guid;

  const ClientContract({
    required this.id,
    required this.name,
    this.number,
    this.guid,
  });

  factory ClientContract.fromMap(Map<String, dynamic> map) {
    final id = _toInt(map['id'] ?? map['contract_id']);
    if (id == null) {
      throw const FormatException('Invalid client contract');
    }
    final number = _string(map['number'] ?? map['contract_number']);
    final name =
        _string(map['name'] ?? map['contract_name']) ??
        number ??
        'Договор №$id';
    return ClientContract(
      id: id,
      name: name,
      number: number,
      guid: _string(map['guid'] ?? map['contract_guid']),
    );
  }

  static List<ClientContract> fromResponse(Object? response) {
    final rows = _extractRows(response);
    final result = <ClientContract>[];
    for (final row in rows) {
      if (row is! Map) continue;
      try {
        result.add(ClientContract.fromMap(Map<String, dynamic>.from(row)));
      } on FormatException {
        // A malformed contract is not a selectable contract.
      }
    }
    return List.unmodifiable(result);
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    if (number != null) 'number': number,
    if (guid != null) 'guid': guid,
  };

  static int? _toInt(Object? value) {
    if (value is num) return value.toInt();
    return int.tryParse('$value');
  }

  static String? _string(Object? value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
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

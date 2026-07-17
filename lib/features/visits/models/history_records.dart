import 'dart:convert';

class HistoryVisitRecord {
  final String id;
  final int? orgId;
  final String org;
  final String date;
  final String dateTime;
  final String type;
  final String subType;
  final String drug;
  final String drugStatus;
  final String status;
  final String duration;
  final String medicalRep;
  final String doctor;
  final List<HistoryPresentationRecord> presentations;
  final List<HistoryStockItemRecord> stockItems;
  final List<HistoryOrderItemRecord> orderItems;
  final String pharmacistsFio;
  final int participantsCount;
  final int discussedDrugsCount;
  final int materialsShownCount;
  final double orderTotal;
  final int? prepaymentPercent;
  final int? buyerType;
  final double? markupPercent;
  final String orderStatus;
  final String serialNumber;
  final int quantity;
  final String rawJson;

  const HistoryVisitRecord({
    required this.id,
    this.orgId,
    required this.org,
    required this.date,
    this.dateTime = '—',
    required this.type,
    this.subType = 'lpu',
    this.drug = '—',
    this.drugStatus = '—',
    this.status = 'planned',
    this.duration = '—',
    this.medicalRep = '—',
    this.doctor = '—',
    this.presentations = const <HistoryPresentationRecord>[],
    this.stockItems = const <HistoryStockItemRecord>[],
    this.orderItems = const <HistoryOrderItemRecord>[],
    this.pharmacistsFio = '—',
    this.participantsCount = 0,
    this.discussedDrugsCount = 0,
    this.materialsShownCount = 0,
    this.orderTotal = 0,
    this.prepaymentPercent,
    this.buyerType,
    this.markupPercent,
    this.orderStatus = 'Новая заявка',
    this.serialNumber = '',
    this.quantity = 1,
    this.rawJson = '{}',
  });

  bool get hasServerId => id.trim().isNotEmpty;

  factory HistoryVisitRecord.fromVisitMap(Map<String, dynamic> row) {
    final raw = _decodeRaw(row['raw_json']);
    final pushRequest = _decodeRaw(row['last_push_request_json']);
    final createdAt = _firstDate([
      row['created_at'],
      row['date'],
      row['visit_date'],
      raw['date_create'],
      raw['start_date'],
      raw['created_at'],
      raw['date'],
      raw['visit_date'],
      raw['datetime'],
    ]);
    final updatedAt = _firstDate([
      row['updated_at'],
      raw['end_date'],
      raw['updated_at'],
      raw['finish_date'],
      raw['closed_at'],
      row['created_at'],
    ]);
    final durationMin = (createdAt != null && updatedAt != null)
        ? updatedAt.difference(createdAt).inMinutes
        : 0;
    final typeRaw = _asLower(
      raw['visit_type'] ?? raw['type'] ?? row['visit_type'] ?? row['type'],
    );
    final mappedType = _resolveType(row: row, raw: raw, typeRaw: typeRaw);
    final normalizedType = mappedType.$1;
    final subType = mappedType.$2;

    final doctorNames = _extractDoctorNames(raw);
    final doctorFromRaw = doctorNames.isEmpty ? '—' : doctorNames.join(', ');
    final doctor = doctorFromRaw == '—'
        ? ('${row['doctor_name'] ?? ''}'.trim().isEmpty
              ? '—'
              : '${row['doctor_name']}'.trim())
        : doctorFromRaw;
    final medRepRaw = _pick(raw, const [
      'medical_rep_name',
      'medrep_name',
      'medical_representative_name',
      'medical_rep_name',
      'medical_rep',
      'manager_name',
      'assigned_by',
      'user_name',
    ]);
    final medRepFromRaw = medRepRaw == '—' && raw['medrep'] is Map
        ? _pick(Map<String, dynamic>.from(raw['medrep'] as Map), const [
            'name',
            'full_name',
          ])
        : medRepRaw;
    // Fall back to the dedicated DB column for locally-created visits where the
    // medical rep (= current user) is stored on the row, not inside raw_json.
    final medRepFromRow = '${row['medical_rep_name'] ?? ''}'.trim();
    final medicalRep = medRepFromRaw != '—'
        ? medRepFromRaw
        : (medRepFromRow.isEmpty ? '—' : medRepFromRow);

    final statusRaw = _asLower(
      raw['visit_status_name'] ??
          raw['order_status_name'] ??
          raw['status'] ??
          raw['status_name'] ??
          raw['visit_status'] ??
          row['status'] ??
          row['status_name'] ??
          row['visit_status'],
    );
    final isCompletedByFlag = _toBool(raw['complete']) ?? false;
    final presentations = _extractPresentations(raw);
    final firstDrug = presentations.isEmpty ? '—' : presentations.first.name;
    final firstDrugStatus = presentations.isEmpty
        ? _statusKey(statusRaw)
        : presentations.first.statusKey;
    final stockItems = _extractStockItems(raw);
    final orderItems = _extractOrderItems(raw);
    final firstStock = stockItems.isEmpty ? null : stockItems.first;
    final itemsTotal = _extractItemsTotal(raw);
    final totalSum = _toDouble(raw['total_sum']);
    final price = _toDouble(
      raw['price'] ??
          raw['sum'] ??
          raw['amount'] ??
          raw['total'] ??
          row['price'] ??
          row['sum'] ??
          row['amount'] ??
          row['total'],
    );
    final qty = _toInt(
      firstStock?.quantity ??
          raw['quantity'] ??
          raw['qty'] ??
          row['quantity'] ??
          row['qty'],
    );
    // Some backend rows can contain total_sum=0 while line items contain
    // valid sale_price/package. Prefer computed items total in that case.
    final orderTotal =
        ((totalSum != null && totalSum > 0) ? totalSum : null) ??
        itemsTotal ??
        price ??
        totalSum ??
        0;

    final orgId = _toInt(
      row['org_id'] ??
          row['organization_id'] ??
          raw['organization_id'] ??
          raw['org_id'] ??
          (raw['organization'] is Map
              ? (raw['organization'] as Map)['organization_id']
              : null),
    );
    final org = _firstNonEmptyString([
      row['org_name'],
      row['organization_name'],
      row['organisation_name'],
      (raw['organization'] is Map
          ? (raw['organization'] as Map)['organization_name']
          : null),
      raw['organization_name'],
      raw['organisation_name'],
      raw['org_name'],
      raw['pharmacy_name'],
      raw['lpu_name'],
    ]);
    final pharmCircle = raw['visit_pharm_circle'] is Map
        ? Map<String, dynamic>.from(raw['visit_pharm_circle'] as Map)
        : const <String, dynamic>{};
    return HistoryVisitRecord(
      id: () {
        final remoteId =
            _toInt(row['remote_id']) ??
            _extractRemoteId(row['last_push_response_json']);
        return remoteId?.toString() ?? '';
      }(),
      orgId: orgId,
      org: org,
      date: _formatDate(createdAt),
      dateTime: _formatDateTime(createdAt),
      type: normalizedType,
      subType: subType,
      drug: firstDrug,
      drugStatus: firstDrugStatus,
      status: _statusKey(
        isCompletedByFlag && statusRaw.isEmpty ? 'completed' : statusRaw,
      ),
      duration: durationMin > 0 ? '$durationMin мин' : '—',
      medicalRep: medicalRep,
      doctor: doctor,
      presentations: presentations,
      stockItems: stockItems,
      orderItems: orderItems,
      pharmacistsFio:
          _pick(raw, const [
                'pharmacists_fio',
                'pharmacists',
                'pharmacist_names',
                'participants_fio',
              ]) ==
              '—'
          ? _pick(pharmCircle, const ['pharmacist_names', 'name'])
          : _pick(raw, const [
              'pharmacists_fio',
              'pharmacists',
              'pharmacist_names',
              'participants_fio',
            ]),
      participantsCount:
          _toInt(
            raw['participants_count'] ??
                raw['participants'] ??
                pharmCircle['number_of_participants'],
          ) ??
          0,
      discussedDrugsCount:
          _toInt(raw['discussed_drugs_count'] ?? raw['discussed_count']) ??
          presentations.length,
      materialsShownCount:
          _toInt(
            raw['materials_shown_count'] ?? raw['shown_materials_count'],
          ) ??
          0,
      orderTotal: orderTotal,
      prepaymentPercent:
          _toInt(
            pushRequest['prepayment_percent'] ?? pushRequest['prepayment'],
          ) ??
          _toInt(
            raw['prepayment'] ?? raw['prepayment_percent'] ?? row['prepayment'],
          ),
      buyerType:
          _buyerTypeFrom(pushRequest) ??
          _buyerTypeFrom(raw) ??
          _toInt(row['buyer_type']) ??
          (_toBool(row['is_wholesaler']) == true ? 1 : null),
      markupPercent: _toDouble(
        raw['markup'] ??
            raw['markup_percent'] ??
            raw['margin_percent'] ??
            row['markup'],
      ),
      orderStatus:
          _pick(raw, const ['order_status', 'status_name']).trim() == '—'
          ? (_pick(raw, const [
                      'order_status_name',
                      'visit_status_name',
                    ]).trim() ==
                    '—'
                ? 'Новая заявка'
                : _pick(raw, const [
                    'order_status_name',
                    'visit_status_name',
                  ]).trim())
          : _pick(raw, const ['order_status', 'status_name']).trim(),
      serialNumber: () {
        final direct = _pick(raw, const [
          'serial_number',
          'series',
          'series_number',
          'serial_no',
        ]);
        if (direct != '—') return direct;
        final stockSerial = firstStock?.serialNumber ?? '';
        return stockSerial.isEmpty || stockSerial == '—' ? '' : stockSerial;
      }(),
      quantity: qty ?? (firstStock?.quantity ?? 1),
      rawJson: row['raw_json'] is String
          ? row['raw_json'] as String
          : jsonEncode(raw),
    );
  }

  static (String, String) _resolveType({
    required Map<String, dynamic> row,
    required Map<String, dynamic> raw,
    required String typeRaw,
  }) {
    // Use visit_format_name from API directly — most reliable signal.
    // Must be checked before any heuristics that look at order_status/total_sum,
    // because the server always includes those fields even for circle visits.
    final fmtName = _asLower(raw['visit_format_name'] ?? '');
    if (fmtName.contains('фармкруж') || fmtName.contains('pharm')) {
      return ('pharmacy', 'circle');
    }
    if (fmtName.contains('груп') || fmtName.contains('group')) {
      return ('lpu', 'group');
    }
    if (fmtName.contains('двойн') || fmtName.contains('double')) {
      return ('lpu', 'double');
    }

    // visit_pharm_circle object presence is a reliable circle signal.
    final pharmCircle = raw['visit_pharm_circle'];
    final hasPharmCircle = pharmCircle is Map && pharmCircle.isNotEmpty;

    final hasOrderItems =
        raw['items'] is List && (raw['items'] as List).isNotEmpty;
    final hasOrderFields =
        raw.containsKey('prepayment') ||
        raw.containsKey('buyer_type') ||
        raw.containsKey('order_status') ||
        raw.containsKey('order_status_name') ||
        raw.containsKey('total_sum');
    final hasDoctorSignals =
        _pick(raw, const ['doctor_name', 'doctor_full_name', 'doctor_fio']) !=
            '—' ||
        _extractDoctorNames(raw).isNotEmpty;
    final hasCirclePayload =
        hasPharmCircle ||
        _toInt(raw['participants_count'] ?? raw['participants']) != null ||
        _pick(raw, const [
              'pharmacists_fio',
              'pharmacists',
              'pharmacist_names',
            ]) !=
            '—';
    if (typeRaw == 'stock' || typeRaw == '4' || typeRaw == 'remnant') {
      return ('stock', 'stock');
    }
    if (typeRaw == 'circle' || typeRaw == 'pharmcircle') {
      return ('pharmacy', 'circle');
    }
    // Defensive rule: visit_type says pharmacy but no circle payload → order.
    // Safe here because format_name was already checked above.
    if ((hasOrderItems || hasOrderFields) &&
        !hasDoctorSignals &&
        !hasCirclePayload) {
      return ('pharmacy', 'order');
    }
    if (typeRaw == 'order' || typeRaw == '1' || typeRaw == 'pharmacy') {
      return hasCirclePayload ? ('pharmacy', 'circle') : ('pharmacy', 'order');
    }
    if (typeRaw == '2' || typeRaw == 'lpu' || typeRaw == 'presentation') {
      final doctors = _extractDoctorNames(raw);
      final isGroup =
          _toBool(raw['is_group']) == true ||
          _asLower(raw['visit_subtype']).contains('group') ||
          _asLower(raw['presentation_type']).contains('group') ||
          _asLower(raw['visit_type_name']).contains('груп') ||
          doctors.length > 1;
      return ('lpu', isGroup ? 'group' : 'lpu');
    }

    final rowType = _asLower(row['type']);
    if (rowType == 'stock') return ('stock', 'stock');
    if (rowType == 'order' || rowType == 'pharmacy') {
      return ('pharmacy', 'order');
    }
    final doctors = _extractDoctorNames(raw);
    final isGroup = doctors.length > 1;
    return ('lpu', isGroup ? 'group' : 'lpu');
  }

  ColorSpec get statusColor {
    switch (status) {
      case 'completed':
        return const ColorSpec(bgHex: 0xFFDDF5E6, fgHex: 0xFF2AA65A);
      case 'planned':
        return const ColorSpec(bgHex: 0xFFEAF0FF, fgHex: 0xFF4B84F0);
      case 'cancelled':
        return const ColorSpec(bgHex: 0xFFFFE8E8, fgHex: 0xFFE05050);
      default:
        return const ColorSpec(bgHex: 0xFFEFF2F7, fgHex: 0xFF7A848A);
    }
  }

  static Map<String, dynamic> _decodeRaw(dynamic raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is String && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) return decoded;
      } catch (_) {
        return const <String, dynamic>{};
      }
    }
    return const <String, dynamic>{};
  }

  static int? _extractRemoteId(dynamic raw) {
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    if (raw is String && int.tryParse(raw.trim()) != null) {
      return int.tryParse(raw.trim());
    }
    final decoded = _decodeRaw(raw);
    return _toInt(decoded['id'] ?? decoded['visit_id']);
  }

  static String _pick(Map<String, dynamic> raw, List<String> keys) {
    for (final key in keys) {
      final value = raw[key];
      if (value is String && value.trim().isNotEmpty) return value.trim();
    }
    return '—';
  }

  static List<String> _extractDoctorNames(Map<String, dynamic> raw) {
    final out = <String>{};
    final single = _pick(raw, const [
      'doctor_name',
      'doctor_full_name',
      'doctor_fio',
      'doctor',
    ]);
    if (single != '—') out.add(single);
    final doctorObj = raw['doctor'];
    if (doctorObj is Map) {
      final m = Map<String, dynamic>.from(doctorObj);
      final name = _pick(m, const ['full_name', 'doctor_name', 'name', 'fio']);
      if (name != '—') out.add(name);
    }

    final listCandidates = <dynamic>[
      raw['doctors'],
      raw['doctor_list'],
      raw['doctor_names'],
      raw['doctor_fios'],
      raw['doctors_list'],
    ];
    for (final c in listCandidates) {
      if (c is List) {
        for (final item in c) {
          if (item is String && item.trim().isNotEmpty) out.add(item.trim());
          if (item is Map) {
            final m = Map<String, dynamic>.from(item);
            final name = _pick(m, const [
              'full_name',
              'doctor_name',
              'name',
              'fio',
            ]);
            if (name != '—') out.add(name);
          }
        }
      }
      if (c is String && c.trim().isNotEmpty) {
        final normalized = c.replaceAll(';', ',');
        for (final part in normalized.split(',')) {
          final p = part.trim();
          if (p.isNotEmpty) out.add(p);
        }
      }
    }
    return out.toList(growable: false);
  }

  static List<HistoryPresentationRecord> _extractPresentations(
    Map<String, dynamic> raw,
  ) {
    final candidates = <dynamic>[
      raw['talked_about_drugs'],
      raw['presentations'],
      raw['presentation_list'],
      raw['visit_presentations'],
      raw['drugs'],
      raw['items'],
      raw['products'],
    ];

    List<dynamic>? list;
    for (final c in candidates) {
      if (c is List && c.isNotEmpty) {
        list = c;
        break;
      }
    }
    if (list == null || list.isEmpty) {
      return const <HistoryPresentationRecord>[];
    }

    final result = <HistoryPresentationRecord>[];
    for (final item in list) {
      if (item is! Map) continue;
      final m = Map<String, dynamic>.from(item);
      final name = _pick(m, const ['drug_name', 'name', 'title']);
      final manufacturer = _pick(m, const [
        'manufacturer',
        'producer_name',
        'producer',
        'company',
        'drug_manufacturer',
        'manufacturer_name',
      ]);
      final status = _statusKey(
        '${m['status'] ?? m['result'] ?? m['prescribe_status'] ?? m['familiarity_status'] ?? m['familiarity_status_name'] ?? (m['is_familiar'] == true ? 'completed' : '') ?? (m['prescribes'] == true ? 'completed' : '')}',
      );
      final exactStatusLabel = _firstNonEmptyString([
        m['familiarity_status_name'],
        m['prescribe_status_name'],
        m['status_name'],
        m['result_name'],
      ]);
      result.add(
        HistoryPresentationRecord(
          name: name,
          manufacturer: manufacturer,
          statusKey: status,
          rawStatusLabel: exactStatusLabel == '—' ? null : exactStatusLabel,
        ),
      );
    }
    return result;
  }

  static List<HistoryStockItemRecord> _extractStockItems(
    Map<String, dynamic> raw,
  ) {
    final candidates = <dynamic>[
      raw['stock_items'],
      raw['items'],
      raw['drugs'],
      raw['products'],
    ];
    List<dynamic>? list;
    for (final c in candidates) {
      if (c is List && c.isNotEmpty) {
        list = c;
        break;
      }
    }
    if (list == null || list.isEmpty) return const <HistoryStockItemRecord>[];

    final result = <HistoryStockItemRecord>[];
    for (final item in list) {
      if (item is! Map) continue;
      final m = Map<String, dynamic>.from(item);
      result.add(
        HistoryStockItemRecord(
          name: _pick(m, const ['drug_name', 'name', 'title']),
          serialNumber: _pick(m, const [
            'serial_number',
            'series',
            'series_number',
            'serial_no',
          ]),
          quantity: _toInt(m['package'] ?? m['quantity'] ?? m['qty']) ?? 1,
        ),
      );
    }
    return result;
  }

  static List<HistoryOrderItemRecord> _extractOrderItems(
    Map<String, dynamic> raw,
  ) {
    final candidates = <dynamic>[raw['drugs'], raw['items'], raw['products']];
    List<dynamic>? list;
    for (final candidate in candidates) {
      if (candidate is List && candidate.isNotEmpty) {
        list = candidate;
        break;
      }
    }
    if (list == null) return const <HistoryOrderItemRecord>[];

    final result = <HistoryOrderItemRecord>[];
    for (final item in list) {
      if (item is! Map) continue;
      final map = Map<String, dynamic>.from(item);
      final quantity =
          _toInt(map['package'] ?? map['quantity'] ?? map['qty']) ?? 1;
      final directTotal = _toDouble(
        map['total_sum'] ?? map['sum'] ?? map['amount'],
      );
      final salePrice = _toDouble(map['sale_price'] ?? map['price']) ?? 0;
      result.add(
        HistoryOrderItemRecord(
          name: _pick(map, const ['drug_name', 'name', 'title']),
          quantity: quantity,
          serialNumber: _pick(map, const [
            'serial_no',
            'serial_number',
            'series',
            'series_number',
          ]),
          total: directTotal ?? salePrice * quantity,
        ),
      );
    }
    return result;
  }

  static double? _extractItemsTotal(Map<String, dynamic> raw) {
    final candidates = <dynamic>[
      raw['stock_items'],
      raw['items'],
      raw['drugs'],
      raw['products'],
    ];
    for (final c in candidates) {
      if (c is! List || c.isEmpty) continue;
      double sum = 0;
      var hasAny = false;
      for (final item in c) {
        if (item is! Map) continue;
        final m = Map<String, dynamic>.from(item);
        final direct = _toDouble(m['total'] ?? m['sum'] ?? m['amount']);
        if (direct != null) {
          sum += direct;
          hasAny = true;
          continue;
        }
        final price = _toDouble(
          m['price'] ?? m['sale_price'] ?? m['base_price'],
        );
        final qty = _toDouble(m['package'] ?? m['quantity'] ?? m['qty']) ?? 1;
        if (price != null) {
          sum += price * qty;
          hasAny = true;
        }
      }
      if (hasAny) return sum;
    }
    return null;
  }

  static String _formatDate(DateTime? dt) {
    if (dt == null) return '—';
    final dd = dt.day.toString().padLeft(2, '0');
    final mm = dt.month.toString().padLeft(2, '0');
    final yyyy = dt.year.toString();
    return '$dd.$mm.$yyyy';
  }

  static String _formatDateTime(DateTime? dt) {
    if (dt == null) return '—';
    final dd = dt.day.toString().padLeft(2, '0');
    final mm = dt.month.toString().padLeft(2, '0');
    final yyyy = dt.year.toString();
    final hh = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '$dd.$mm.$yyyy, $hh:$min';
  }

  static String _statusKey(String status) {
    final s = status.toLowerCase();
    if (s == '2' || s == '3') return 'completed';
    if (s == '0' || s == '1') return 'planned';
    if (s.contains('провед')) return 'completed';
    if (s.contains('ознакомлен') || s.contains('выписывает')) {
      if (s.contains('не выписывает')) return 'familiar_not_prescribes';
      return 'completed';
    }
    if (s.contains('не знаком') || s.contains('not_familiar')) {
      return 'cancelled';
    }
    if (s.contains('коммент') || s.contains('other')) return 'planned';
    if (s.contains('заплан')) return 'planned';
    switch (s) {
      case 'completed':
      case 'done':
      case 'success':
      case 'проведено':
      case 'проведен':
      case 'familiar_prescribes':
        return 'completed';
      case 'familiar_not_prescribes':
        return 'familiar_not_prescribes';
      case 'planned':
      case 'in_progress':
      case 'new':
      case 'новая заявка':
      case 'запланировано':
        return 'planned';
      case 'cancelled':
      case 'rejected':
      case 'not_familiar':
        return 'cancelled';
      default:
        return 'planned';
    }
  }

  static DateTime? _firstDate(List<dynamic> values) {
    for (final v in values) {
      if (v == null) continue;
      final dt = _parseDate('$v');
      if (dt != null) return dt;
    }
    return null;
  }

  static DateTime? _parseDate(String raw) {
    final s = raw.trim();
    if (s.isEmpty || s == 'null') return null;
    final dt = DateTime.tryParse(s);
    if (dt != null) return dt;
    final m = RegExp(
      r'^(\d{1,2})\.(\d{1,2})\.(\d{4})(?:[,\s]+(\d{1,2}):(\d{2})(?::(\d{2}))?)?$',
    ).firstMatch(s);
    if (m == null) return null;
    final day = int.tryParse(m.group(1)!);
    final month = int.tryParse(m.group(2)!);
    final year = int.tryParse(m.group(3)!);
    final hour = int.tryParse(m.group(4) ?? '0') ?? 0;
    final minute = int.tryParse(m.group(5) ?? '0') ?? 0;
    final second = int.tryParse(m.group(6) ?? '0') ?? 0;
    if (day == null || month == null || year == null) return null;
    return DateTime(year, month, day, hour, minute, second);
  }

  static String _firstNonEmptyString(List<dynamic> values) {
    for (final v in values) {
      if (v == null) continue;
      final s = '$v'.trim();
      if (s.isNotEmpty && s != 'null') return s;
    }
    return '—';
  }

  static String _asLower(dynamic value) =>
      '${value ?? ''}'.trim().toLowerCase();

  static int? _buyerTypeFrom(Map<String, dynamic> raw) {
    final direct = _toInt(raw['buyer_type'] ?? raw['client_type']);
    if (direct != null) return direct;
    final isWholesaler = _toBool(raw['is_wholesaler']);
    if (isWholesaler == null) return null;
    return isWholesaler ? 1 : 0;
  }

  static int? _toInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse('$value');
  }

  static double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is num) return value.toDouble();
    return double.tryParse('$value');
  }

  static bool? _toBool(dynamic value) {
    if (value == null) return null;
    if (value is bool) return value;
    if (value is num) return value != 0;
    final s = '$value'.trim().toLowerCase();
    if (s == 'true' || s == '1') return true;
    if (s == 'false' || s == '0') return false;
    return null;
  }
}

class HistoryPresentationRecord {
  final String name;
  final String manufacturer;
  final String statusKey;
  final String? rawStatusLabel;

  const HistoryPresentationRecord({
    required this.name,
    required this.manufacturer,
    required this.statusKey,
    this.rawStatusLabel,
  });

  String get statusLabel {
    if (rawStatusLabel != null && rawStatusLabel!.trim().isNotEmpty) {
      return rawStatusLabel!.trim();
    }
    switch (statusKey) {
      case 'completed':
        return 'Ознакомлен, выписывает';
      case 'familiar_not_prescribes':
        return 'Ознакомлен, не выписывает';
      case 'planned':
        return 'Комментарий';
      case 'cancelled':
        return 'Не знаком';
      default:
        return '—';
    }
  }

  ColorSpec get statusColor {
    final raw = rawStatusLabel?.toLowerCase() ?? '';
    if (raw.contains('не знаком')) {
      return const ColorSpec(bgHex: 0xFFFCE7E7, fgHex: 0xFFE35D5B);
    }
    if (raw.contains('не выписывает')) {
      return const ColorSpec(bgHex: 0xFFFAF1DF, fgHex: 0xFFC89B3C);
    }
    if (raw.contains('ознаком') || raw.contains('выписывает')) {
      return const ColorSpec(bgHex: 0xFFE4F6EE, fgHex: 0xFF55B98A);
    }
    if (raw.contains('коммент')) {
      return const ColorSpec(bgHex: 0xFFEFF2F7, fgHex: 0xFF7A848A);
    }
    switch (statusKey) {
      case 'completed':
        return const ColorSpec(bgHex: 0xFFE4F6EE, fgHex: 0xFF55B98A);
      case 'familiar_not_prescribes':
        return const ColorSpec(bgHex: 0xFFFAF1DF, fgHex: 0xFFC89B3C);
      case 'planned':
        return const ColorSpec(bgHex: 0xFFEFF2F7, fgHex: 0xFF7A848A);
      case 'cancelled':
        return const ColorSpec(bgHex: 0xFFFCE7E7, fgHex: 0xFFE35D5B);
      default:
        return const ColorSpec(bgHex: 0xFFEFF2F7, fgHex: 0xFF7A848A);
    }
  }
}

class HistoryStockItemRecord {
  final String name;
  final String serialNumber;
  final int quantity;

  const HistoryStockItemRecord({
    required this.name,
    required this.serialNumber,
    required this.quantity,
  });
}

class HistoryOrderItemRecord {
  final String name;
  final int quantity;
  final String serialNumber;
  final double total;

  const HistoryOrderItemRecord({
    required this.name,
    required this.quantity,
    required this.serialNumber,
    required this.total,
  });
}

class ColorSpec {
  final int bgHex;
  final int fgHex;

  const ColorSpec({required this.bgHex, required this.fgHex});
}

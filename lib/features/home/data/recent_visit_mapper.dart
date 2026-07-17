import 'dart:convert';

import '../../../core/models/local_visit.dart';
import '../domain/entities/recent_visit.dart';

class RecentVisitMapper {
  const RecentVisitMapper._();

  static List<RecentVisit> fromLocalVisits(List<LocalVisit> visits) =>
      fromRows(visits.map((visit) => visit.toMap()).toList(growable: false));

  static List<RecentVisit> fromRows(List<Map<String, dynamic>> rows) {
    final dedup = <String, Map<String, dynamic>>{};
    for (final source in rows) {
      final row = Map<String, dynamic>.from(source);
      final remoteId = _safeString(row['remote_id']);
      final type = _safeString(row['visit_type'], fallback: 'lpu');
      final created = _safeString(
        row['created_at'] ?? row['visit_date'] ?? row['date'],
      );
      final key = remoteId.isNotEmpty
          ? '${remoteId}_$type'
          : '${type}_$created';
      final previous = dedup[key];
      if (previous == null ||
          _parseDate(created).isAfter(
            _parseDate(
              _safeString(
                previous['created_at'] ??
                    previous['visit_date'] ??
                    previous['date'],
              ),
            ),
          )) {
        dedup[key] = row;
      }
    }

    final uniqueRows = dedup.values.toList()
      ..sort((a, b) {
        final ad = _parseDate(
          _safeString(a['date'] ?? a['visit_date'] ?? a['created_at']),
        );
        final bd = _parseDate(
          _safeString(b['date'] ?? b['visit_date'] ?? b['created_at']),
        );
        return bd.compareTo(ad);
      });
    return uniqueRows.take(10).map(_fromRow).toList(growable: false);
  }

  static RecentVisit _fromRow(Map<String, dynamic> row) {
    final date = _parseDate(
      _safeString(row['date'] ?? row['visit_date'] ?? row['created_at']),
    );
    final rawMap = _decodeMap(row['raw_json']);
    var id = _safeString(row['remote_id'] ?? row['visit_id']);
    if (id.isEmpty) {
      final pushed = _decode(row['last_push_response_json']);
      if (pushed is num || pushed is String) {
        id = _safeString(pushed);
      } else if (pushed is Map) {
        id = _safeString(pushed['id'] ?? pushed['visit_id']);
      }
    }

    final orgTypeId = _toInt(
      row['organization_type_id'] ??
          row['type_id'] ??
          rawMap['organization_type_id'] ??
          rawMap['type_id'],
    );
    final orgType = _safeString(
      row['organization_type'] ??
          row['org_type'] ??
          rawMap['organization_type'] ??
          rawMap['org_type'],
    ).toLowerCase();
    final visitType = _safeString(
      row['visit_type'] ??
          row['type'] ??
          rawMap['visit_type'] ??
          rawMap['type'],
      fallback: 'lpu',
    ).toLowerCase();

    final type = _resolveType(orgTypeId, orgType, visitType);
    final statusRaw = _safeString(
      row['status_name'] ??
          row['status'] ??
          row['visit_status'] ??
          rawMap['status_name'] ??
          rawMap['status'] ??
          rawMap['visit_status'],
    ).toLowerCase();
    final complete = _safeString(rawMap['complete']).toLowerCase();
    final statusKey = _statusKey(
      (complete == 'true' || complete == '1') ? 'completed' : statusRaw,
    );

    return RecentVisit(
      id: id,
      name: _safeString(row['organization_name'] ?? row['org_name']),
      dateDay: date.millisecondsSinceEpoch == 0 ? null : date.day,
      dateMonthIdx: date.millisecondsSinceEpoch == 0 ? null : date.month,
      timeLabel: date.millisecondsSinceEpoch == 0
          ? ''
          : '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}',
      statusKey: statusKey,
      type: type,
      subType: visitType == 'circle' ? 'circle' : '',
      pharmacistsFio: _safeString(
        rawMap['pharmacists_fio'] ??
            rawMap['pharmacists'] ??
            rawMap['pharmacist_names'],
        fallback: '—',
      ),
      participantsCount:
          _toInt(rawMap['participants_count'] ?? rawMap['participants']) ?? 0,
      firstDrugName: _firstDrugName(rawMap),
    );
  }

  static String _resolveType(int? orgTypeId, String orgType, String visitType) {
    if (visitType == '4' ||
        visitType == '3' ||
        visitType == 'stock' ||
        visitType == 'remnant') {
      return 'stock';
    }
    if (orgTypeId == 1 ||
        orgType.contains('pharm') ||
        orgType.contains('аптек') ||
        orgType == 'pharmacy') {
      return 'pharmacy';
    }
    if (orgTypeId != null || orgType.isNotEmpty) return 'lpu';
    if (visitType == '1' ||
        visitType == 'order' ||
        visitType == 'circle' ||
        visitType == 'pharmacy' ||
        visitType == 'apteka' ||
        visitType == 'аптека') {
      return 'pharmacy';
    }
    return 'lpu';
  }

  static String _firstDrugName(Map<String, dynamic> rawMap) {
    final items = rawMap['items'] ?? rawMap['drugs'] ?? rawMap['order_items'];
    if (items is! List || items.isEmpty || items.first is! Map) return '';
    final first = Map<String, dynamic>.from(items.first as Map);
    return _safeString(first['drug_name'] ?? first['name'] ?? first['title']);
  }

  static String _statusKey(String raw) {
    if (raw.contains('completed') ||
        raw.contains('done') ||
        raw.contains('провед')) {
      return 'completed';
    }
    if (raw.contains('cancel') || raw.contains('отмен')) return 'cancelled';
    if (raw.contains('process') ||
        raw.contains('in_progress') ||
        raw.contains('progress')) {
      return 'in_progress';
    }
    if (raw == '1') return 'completed';
    return 'planned';
  }

  static dynamic _decode(Object? value) {
    if (value is! String || value.isEmpty) return null;
    try {
      return jsonDecode(value);
    } catch (_) {
      return null;
    }
  }

  static Map<String, dynamic> _decodeMap(Object? value) {
    final decoded = _decode(value);
    return decoded is Map
        ? Map<String, dynamic>.from(decoded)
        : const <String, dynamic>{};
  }

  static DateTime _parseDate(String source) {
    if (source.isEmpty) return DateTime.fromMillisecondsSinceEpoch(0);
    final direct = DateTime.tryParse(source);
    if (direct != null) return direct;
    final match = RegExp(
      r'^(\d{1,2})\.(\d{1,2})\.(\d{4})(?:[,\s]+(\d{1,2}):(\d{2})(?::(\d{2}))?)?$',
    ).firstMatch(source.trim());
    if (match == null) return DateTime.fromMillisecondsSinceEpoch(0);
    final day = int.tryParse(match.group(1)!);
    final month = int.tryParse(match.group(2)!);
    final year = int.tryParse(match.group(3)!);
    if (day == null || month == null || year == null) {
      return DateTime.fromMillisecondsSinceEpoch(0);
    }
    return DateTime(
      year,
      month,
      day,
      int.tryParse(match.group(4) ?? '0') ?? 0,
      int.tryParse(match.group(5) ?? '0') ?? 0,
      int.tryParse(match.group(6) ?? '0') ?? 0,
    );
  }

  static String _safeString(Object? value, {String fallback = ''}) {
    if (value == null) return fallback;
    final result = value.toString();
    return result.isEmpty || result == 'null' ? fallback : result;
  }

  static int? _toInt(Object? value) {
    if (value is num) return value.toInt();
    return int.tryParse('$value');
  }
}

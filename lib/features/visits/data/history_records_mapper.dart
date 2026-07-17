import '../models/history_records.dart';

class HistoryRecordsMapper {
  const HistoryRecordsMapper._();

  static List<HistoryVisitRecord> fromRows(
    List<Map<String, dynamic>> rows,
  ) {
    final merged = <String, HistoryVisitRecord>{};
    for (final row in rows) {
      final record = HistoryVisitRecord.fromVisitMap(row);
      final key = record.id != '—' && record.id.trim().isNotEmpty
          ? '${record.id}_${record.type}_${record.subType}'
          : '${record.type}_${record.orgId}_${record.dateTime}';
      final previous = merged[key];
      if (previous == null || _score(record) >= _score(previous)) {
        merged[key] = record;
      }
    }

    final values = merged.values.toList();
    values.sort((a, b) => _parseDate(b).compareTo(_parseDate(a)));
    return values;
  }

  static int _score(HistoryVisitRecord visit) {
    var score = 0;
    if (visit.status == 'completed') score += 6;
    if (visit.dateTime != '—') score += 4;
    if (visit.doctor != '—') score += 3;
    if (visit.presentations.isNotEmpty) score += 5;
    if (visit.stockItems.isNotEmpty) score += 5;
    if (visit.orderTotal > 0) score += 6;
    if (visit.serialNumber.isNotEmpty) score += 2;
    if (visit.type == 'stock' || visit.type == 'pharmacy') score++;
    return score;
  }

  static DateTime _parseDate(HistoryVisitRecord record) {
    final match = RegExp(
      r'^(\d{2})\.(\d{2})\.(\d{4}),\s*(\d{2}):(\d{2})$',
    ).firstMatch(record.dateTime.trim());
    if (match == null) return DateTime.fromMillisecondsSinceEpoch(0);
    return DateTime(
      int.tryParse(match.group(3) ?? '') ?? 1970,
      int.tryParse(match.group(2) ?? '') ?? 1,
      int.tryParse(match.group(1) ?? '') ?? 1,
      int.tryParse(match.group(4) ?? '') ?? 0,
      int.tryParse(match.group(5) ?? '') ?? 0,
    );
  }
}

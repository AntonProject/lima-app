import '../entities/planned_visit_record.dart';

class MergePlannedVisits {
  const MergePlannedVisits();

  List<PlannedVisitRecord> call({
    required List<PlannedVisitRecord> planned,
    required List<PlannedVisitRecord> local,
  }) {
    final merged = <String, PlannedVisitRecord>{};
    final serverSignatures = <String>{};
    final localKeysBySignature = <String, String>{};

    for (final record in planned) {
      final key = record.remoteId == null
          ? 'l_${record.localId}'
          : 'r_${record.remoteId}';
      final signature = _signature(record);
      if (record.remoteId != null) {
        serverSignatures.add(signature);
      } else {
        localKeysBySignature[signature] = key;
      }
      merged[key] = record;
    }

    for (final record in local) {
      final key = record.remoteId == null
          ? 'l_${record.localId}'
          : 'r_${record.remoteId}';
      merged[key] = record;
    }

    for (final entry in localKeysBySignature.entries) {
      if (serverSignatures.contains(entry.key)) merged.remove(entry.value);
    }

    final result = merged.values.toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    return result;
  }

  static String _signature(PlannedVisitRecord record) {
    final date = record.date;
    return '${record.organisationId ?? 0}_${date.year}-${date.month}-${date.day}';
  }
}

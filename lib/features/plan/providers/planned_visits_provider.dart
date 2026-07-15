import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/models.dart';
import '../../visits/data/visits_repository.dart';

class PlannedVisitsNotifier extends StateNotifier<List<PlannedVisit>> {
  final VisitsRepository _repo;

  PlannedVisitsNotifier(this._repo) : super(const []) {
    load();
  }

  // Composite signature for matching a locally-created plan against its
  // server-synced twin: same organisation + same calendar day. Used to drop
  // un-stamped local duplicates once the server row for the same plan arrives
  // (the push response sometimes omits the remote id, leaving the local row
  // un-stamped — without this, a second "ghost" card appears after restart).
  static String _planSignature(int? orgId, DateTime date) =>
      '${orgId ?? 0}_${date.year}-${date.month}-${date.day}';

  Future<void> load() async {
    final merged = <String, PlannedVisit>{};
    // Signatures of server-stamped planned rows (have a remote_id).
    final serverSignatures = <String>{};
    // Local-keyed entries we may need to drop if a server twin exists.
    final localKeyToSignature = <String, String>{};

    // Load synced planned visits from local DB
    try {
      final dbRows = await _repo.getPlannedVisits();
      for (final row in dbRows) {
        final remoteId = (row['remote_id'] as num?)?.toInt();
        final localId = (row['id'] as num?)?.toInt();
        if (localId == null) continue;
        final key = remoteId != null ? 'r_$remoteId' : 'l_$localId';
        final visitDate =
            DateTime.tryParse('${row['visit_date'] ?? ''}') ?? DateTime.now();
        final orgId = (row['org_id'] as num?)?.toInt();
        final signature = _planSignature(orgId, visitDate);
        if (remoteId != null) {
          serverSignatures.add(signature);
        } else {
          localKeyToSignature[key] = signature;
        }
        merged[key] = PlannedVisit(
          id: remoteId ?? localId,
          organisationName: '${row['org_name'] ?? ''}',
          organisationId: (row['org_id'] as num?)?.toInt(),
          organisationType: (row['org_type'] ?? 'lpu') == 'pharmacy'
              ? OrgType.pharmacy
              : OrgType.lpu,
          doctorName: (row['doctor_name'] as String?)?.isNotEmpty == true
              ? row['doctor_name'] as String
              : null,
          assignedBy: row['assigned_by'] as String? ?? '',
          city: row['city'] as String?,
          district: row['district'] as String?,
          date: visitDate,
          status: VisitStatus.planned,
          visitFormat: row['visit_format'] as String?,
        );
      }
    } catch (_) {}

    // Local DB visits (created by this user on this device)
    try {
      final localRows = await _repo.getVisits();
      for (final row in localRows) {
        final localId = (row['id'] as num?)?.toInt();
        if (localId == null) continue;
        final status = '${row['status'] ?? 'planned'}'.toLowerCase();
        if (status == 'completed') continue;
        final remoteId = (row['remote_id'] as num?)?.toInt();
        final createdRaw = '${row['created_at'] ?? ''}';
        final created = DateTime.tryParse(createdRaw);
        if (created == null) continue;
        final visitType = '${row['visit_type'] ?? 'lpu'}'.toLowerCase();
        final orgName = '${row['org_name'] ?? ''}'.trim();
        if (orgName.isEmpty) continue;
        final key = remoteId != null ? 'r_$remoteId' : 'l_$localId';
        merged[key] = PlannedVisit(
          id: remoteId ?? localId,
          organisationName: orgName,
          organisationId: (row['org_id'] as num?)?.toInt(),
          organisationType:
              (visitType == 'pharmacy' ||
                  visitType == 'order' ||
                  visitType == 'circle')
              ? OrgType.pharmacy
              : OrgType.lpu,
          doctorName: '${row['doctor_name'] ?? ''}'.trim().isEmpty
              ? null
              : '${row['doctor_name']}'.trim(),
          assignedBy: 'Локально',
          city: null,
          date: created,
          status: status == 'completed'
              ? VisitStatus.completed
              : VisitStatus.planned,
        );
      }
    } catch (_) {}

    // Drop un-stamped local planned rows whose server twin (same org + day)
    // is already present, so a failed remote-id stamp doesn't surface a
    // doctorless/wrong-type duplicate card after the next pull/restart.
    localKeyToSignature.forEach((key, signature) {
      if (serverSignatures.contains(signature)) {
        merged.remove(key);
      }
    });

    final list = merged.values.toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    state = list;
  }

  void addPlannedVisit(PlannedVisit visit) {
    state = [...state, visit];
  }
}

final plannedVisitsProvider =
    StateNotifierProvider<PlannedVisitsNotifier, List<PlannedVisit>>((ref) {
      return PlannedVisitsNotifier(ref.watch(visitsRepositoryProvider));
    });

/// A visit, as stored in the local `visits` table. Field set mirrors the
/// SQLite schema in local_database.dart (including offline-first sync
/// bookkeeping — is_synced/sync_failed/push_attempts/next_retry_at, and the
/// last push request/response for diagnostics).
class LocalVisit {
  final int? id;
  final int? remoteId;
  final int orgId;
  final String orgName;
  final int? doctorId;
  final String? doctorName;
  final String visitType; // 'lpu' | 'order' | 'stock' | 'circle'
  final String status; // 'planned' | 'completed'
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isSynced;
  final String? rawJson;

  /// True once the push loop has given up on this visit (server rejected it,
  /// or all retry attempts were exhausted). Parked visits stay in the queue
  /// table but are excluded from automatic pushes — see
  /// LocalDatabase.markVisitPushFailedPermanently.
  final bool syncFailed;

  /// Number of failed push attempts so far. Reset to 0 by retryFailedVisit.
  final int pushAttempts;

  /// Backoff: the push loop skips this visit until this time, if set.
  final DateTime? nextRetryAt;

  final String? medicalRepName;
  final String? lastPushRequestJson;
  final String? lastPushResponseJson;

  const LocalVisit({
    this.id,
    this.remoteId,
    required this.orgId,
    required this.orgName,
    this.doctorId,
    this.doctorName,
    this.visitType = 'lpu',
    this.status = 'planned',
    this.notes,
    required this.createdAt,
    required this.updatedAt,
    this.isSynced = false,
    this.rawJson,
    this.syncFailed = false,
    this.pushAttempts = 0,
    this.nextRetryAt,
    this.medicalRepName,
    this.lastPushRequestJson,
    this.lastPushResponseJson,
  });

  LocalVisit copyWith({
    int? id,
    int? remoteId,
    int? orgId,
    String? orgName,
    int? doctorId,
    String? doctorName,
    String? visitType,
    String? status,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isSynced,
    String? rawJson,
    bool? syncFailed,
    int? pushAttempts,
    DateTime? nextRetryAt,
    String? medicalRepName,
    String? lastPushRequestJson,
    String? lastPushResponseJson,
  }) {
    return LocalVisit(
      id: id ?? this.id,
      remoteId: remoteId ?? this.remoteId,
      orgId: orgId ?? this.orgId,
      orgName: orgName ?? this.orgName,
      doctorId: doctorId ?? this.doctorId,
      doctorName: doctorName ?? this.doctorName,
      visitType: visitType ?? this.visitType,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isSynced: isSynced ?? this.isSynced,
      rawJson: rawJson ?? this.rawJson,
      syncFailed: syncFailed ?? this.syncFailed,
      pushAttempts: pushAttempts ?? this.pushAttempts,
      nextRetryAt: nextRetryAt ?? this.nextRetryAt,
      medicalRepName: medicalRepName ?? this.medicalRepName,
      lastPushRequestJson: lastPushRequestJson ?? this.lastPushRequestJson,
      lastPushResponseJson: lastPushResponseJson ?? this.lastPushResponseJson,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      if (remoteId != null) 'remote_id': remoteId,
      'org_id': orgId,
      'org_name': orgName,
      if (doctorId != null) 'doctor_id': doctorId,
      if (doctorName != null) 'doctor_name': doctorName,
      'visit_type': visitType,
      'status': status,
      if (notes != null) 'notes': notes,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'is_synced': isSynced ? 1 : 0,
      if (rawJson != null) 'raw_json': rawJson,
      'sync_failed': syncFailed ? 1 : 0,
      'push_attempts': pushAttempts,
      if (nextRetryAt != null)
        'next_retry_at': nextRetryAt!.toIso8601String(),
      if (medicalRepName != null) 'medical_rep_name': medicalRepName,
      if (lastPushRequestJson != null)
        'last_push_request_json': lastPushRequestJson,
      if (lastPushResponseJson != null)
        'last_push_response_json': lastPushResponseJson,
    };
  }

  factory LocalVisit.fromMap(Map<String, dynamic> map) {
    return LocalVisit(
      id: map['id'] as int?,
      remoteId: map['remote_id'] as int?,
      orgId: map['org_id'] as int,
      orgName: map['org_name'] as String,
      doctorId: map['doctor_id'] as int?,
      doctorName: map['doctor_name'] as String?,
      visitType: map['visit_type'] as String? ?? 'lpu',
      status: map['status'] as String? ?? 'planned',
      notes: map['notes'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      isSynced: (map['is_synced'] as int? ?? 0) == 1,
      rawJson: map['raw_json'] as String?,
      syncFailed: (map['sync_failed'] as int? ?? 0) == 1,
      pushAttempts: (map['push_attempts'] as num?)?.toInt() ?? 0,
      nextRetryAt: map['next_retry_at'] == null
          ? null
          : DateTime.tryParse(map['next_retry_at'] as String),
      medicalRepName: map['medical_rep_name'] as String?,
      lastPushRequestJson: map['last_push_request_json'] as String?,
      lastPushResponseJson: map['last_push_response_json'] as String?,
    );
  }
}

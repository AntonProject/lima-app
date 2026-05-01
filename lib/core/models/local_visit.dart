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
    );
  }
}

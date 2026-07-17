class PendingDoctorRecord {
  final int? id;
  final String fullName;
  final String? createdAt;

  const PendingDoctorRecord({this.id, required this.fullName, this.createdAt});

  factory PendingDoctorRecord.fromMap(Map<String, dynamic> row) {
    return PendingDoctorRecord(
      id: _toInt(row['id']),
      fullName: row['full_name']?.toString() ?? '',
      createdAt: row['created_at']?.toString(),
    );
  }
}

class PendingOrganisationUpdateRecord {
  final int? id;
  final String name;

  const PendingOrganisationUpdateRecord({this.id, required this.name});

  factory PendingOrganisationUpdateRecord.fromMap(Map<String, dynamic> row) {
    return PendingOrganisationUpdateRecord(
      id: _toInt(row['id']),
      name: row['name']?.toString() ?? '',
    );
  }
}

class SyncLocalTotals {
  final int organizations;
  final int lpu;
  final int pharmacy;
  final int distributor;
  final int doctors;
  final int visits;
  final int drugs;
  final int materials;

  const SyncLocalTotals({
    this.organizations = 0,
    this.lpu = 0,
    this.pharmacy = 0,
    this.distributor = 0,
    this.doctors = 0,
    this.visits = 0,
    this.drugs = 0,
    this.materials = 0,
  });

  factory SyncLocalTotals.fromMap(Map<String, int> values) {
    return SyncLocalTotals(
      organizations: values['organizations'] ?? 0,
      lpu: values['lpu'] ?? 0,
      pharmacy: values['pharmacy'] ?? 0,
      distributor: values['distributor'] ?? 0,
      doctors: values['doctors'] ?? 0,
      visits: values['visits'] ?? 0,
      drugs: values['drugs'] ?? 0,
      materials: values['materials'] ?? 0,
    );
  }
}

int? _toInt(Object? value) {
  if (value is num) return value.toInt();
  return int.tryParse('$value');
}

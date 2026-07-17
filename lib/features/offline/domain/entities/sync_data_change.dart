enum SyncDataTable {
  organisations,
  doctors,
  doctorOrganisations,
  drugs,
  drugMaterials,
  visits,
  plannedVisits,
  pendingDoctors,
  pendingOrganisationUpdates,
  other,
}

class SyncDataChange {
  final Set<SyncDataTable> tables;

  const SyncDataChange(this.tables);

  bool containsAny(Iterable<SyncDataTable> expected) =>
      tables.any(expected.toSet().contains);

  factory SyncDataChange.fromStorageTables(Iterable<String> tables) {
    return SyncDataChange(tables.map(_mapTable).toSet());
  }

  static SyncDataTable _mapTable(String table) {
    switch (table) {
      case 'organisations':
        return SyncDataTable.organisations;
      case 'doctors':
        return SyncDataTable.doctors;
      case 'doctor_organisations':
        return SyncDataTable.doctorOrganisations;
      case 'drugs':
        return SyncDataTable.drugs;
      case 'drug_materials':
        return SyncDataTable.drugMaterials;
      case 'visits':
        return SyncDataTable.visits;
      case 'planned_visits':
        return SyncDataTable.plannedVisits;
      case 'pending_doctors':
        return SyncDataTable.pendingDoctors;
      case 'pending_org_updates':
        return SyncDataTable.pendingOrganisationUpdates;
      default:
        return SyncDataTable.other;
    }
  }
}

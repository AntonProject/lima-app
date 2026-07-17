import '../../../../core/models/models.dart';

/// Data-independent representation of a planned/local visit row.
///
/// [localId] and [remoteId] are kept separately because a locally created
/// plan can exist before the server assigns its id. The presentation model
/// only needs the resolved [id].
class PlannedVisitRecord {
  final int localId;
  final int? remoteId;
  final String organisationName;
  final int? organisationId;
  final String organisationType;
  final String? doctorName;
  final String assignedBy;
  final String? city;
  final String? district;
  final DateTime date;
  final VisitStatus status;
  final String? visitFormat;

  const PlannedVisitRecord({
    required this.localId,
    this.remoteId,
    required this.organisationName,
    this.organisationId,
    required this.organisationType,
    this.doctorName,
    required this.assignedBy,
    this.city,
    this.district,
    required this.date,
    required this.status,
    this.visitFormat,
  });

  int get id => remoteId ?? localId;

  PlannedVisit toModel() => PlannedVisit(
    id: id,
    organisationName: organisationName,
    organisationId: organisationId,
    organisationType: organisationType == 'pharmacy'
        ? OrgType.pharmacy
        : OrgType.lpu,
    doctorName: doctorName,
    assignedBy: assignedBy,
    city: city,
    district: district,
    date: date,
    status: status,
    visitFormat: visitFormat,
  );
}

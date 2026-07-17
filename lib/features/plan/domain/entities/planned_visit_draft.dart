class VisitFormatOption {
  final int id;
  final String name;

  const VisitFormatOption({required this.id, required this.name});
}

class PlannedVisitDraft {
  final int organisationId;
  final String organisationName;
  final String organisationType;
  final int? doctorId;
  final List<int> doctorIds;
  final String? doctorName;
  final String assignedBy;
  final String? city;
  final String? district;
  final DateTime visitDate;
  final String comment;
  final String visitFormat;
  final int visitFormatId;

  const PlannedVisitDraft({
    required this.organisationId,
    required this.organisationName,
    required this.organisationType,
    required this.doctorId,
    required this.doctorIds,
    required this.doctorName,
    required this.assignedBy,
    required this.city,
    required this.district,
    required this.visitDate,
    required this.comment,
    required this.visitFormat,
    required this.visitFormatId,
  });
}

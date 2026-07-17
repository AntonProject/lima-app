import '../../plan/domain/entities/planned_visit_draft.dart';

class PlannedVisitMapper {
  const PlannedVisitMapper._();

  static Map<String, dynamic> toLocalRow(PlannedVisitDraft draft) => {
    'org_id': draft.organisationId,
    'org_name': draft.organisationName,
    'org_type': draft.organisationType,
    'doctor_id': draft.doctorId,
    'doctor_name': draft.doctorName,
    'assigned_by': draft.assignedBy,
    'city': draft.city ?? '',
    'district': draft.district ?? '',
    'visit_date': draft.visitDate.toIso8601String(),
    'status': 'planned',
    'comment': draft.comment,
    'visit_format': draft.visitFormat,
  };
}

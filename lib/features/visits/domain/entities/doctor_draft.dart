class DoctorDraft {
  final int organizationId;
  final String fullName;
  final String specialty;
  final int specializationId;
  final String? phone;
  final String? hobby;
  final String? interests;
  final String? birthday;

  const DoctorDraft({
    required this.organizationId,
    required this.fullName,
    required this.specialty,
    required this.specializationId,
    required this.phone,
    required this.hobby,
    required this.interests,
    required this.birthday,
  });
}

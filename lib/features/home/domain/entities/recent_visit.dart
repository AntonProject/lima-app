class RecentVisit {
  final String id;
  final String name;
  final int? dateDay;
  final int? dateMonthIdx;
  final String timeLabel;
  final String statusKey;
  final String type;
  final String subType;
  final String pharmacistsFio;
  final int participantsCount;
  final String firstDrugName;

  const RecentVisit({
    required this.id,
    required this.name,
    this.dateDay,
    this.dateMonthIdx,
    required this.timeLabel,
    required this.statusKey,
    required this.type,
    required this.subType,
    required this.pharmacistsFio,
    required this.participantsCount,
    this.firstDrugName = '',
  });
}

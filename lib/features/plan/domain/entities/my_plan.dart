class MyPlanProgress {
  final int year;
  final int totalPlanCount;
  final int totalFactCount;
  final double totalPlanSum;
  final double totalFactSum;
  final double? completionPercentCount;
  final double? completionPercentSum;
  final List<MyPlanDrugProgress> drugs;

  const MyPlanProgress({
    required this.year,
    required this.totalPlanCount,
    required this.totalFactCount,
    required this.totalPlanSum,
    required this.totalFactSum,
    required this.completionPercentCount,
    required this.completionPercentSum,
    required this.drugs,
  });

  bool get hasPlan => drugs.isNotEmpty;

  MyPlanActiveTask? activeTask(DateTime date) {
    if (drugs.isEmpty) return null;

    final monthNodes = drugs
        .map(
          (drug) =>
              drug.monthFor(date) ?? MyPlanMonthProgress.empty(date.month),
        )
        .toList(growable: false);

    var index = -1;
    for (var i = 0; i < drugs.length; i++) {
      final month = monthNodes[i];
      if (month.planCount > 0 &&
          (month.completionPercentCount == null ||
              month.completionPercentCount! < 100)) {
        index = i;
        break;
      }
    }

    if (index < 0) {
      for (var i = 0; i < drugs.length; i++) {
        final percent = monthNodes[i].completionPercentCount;
        if (percent == null || percent < 100) {
          index = i;
          break;
        }
      }
    }

    if (index < 0) index = 0;
    return MyPlanActiveTask(
      index: index,
      total: drugs.length,
      drug: drugs[index],
      month: monthNodes[index],
    );
  }
}

class MyPlanDrugProgress {
  final int drugBindingId;
  final String drugName;
  final String producerName;
  final double basePrice;
  final int planCount;
  final int factCount;
  final double planSum;
  final double factSum;
  final double? completionPercentCount;
  final double? completionPercentSum;
  final List<MyPlanMonthProgress> months;

  const MyPlanDrugProgress({
    required this.drugBindingId,
    required this.drugName,
    required this.producerName,
    required this.basePrice,
    required this.planCount,
    required this.factCount,
    required this.planSum,
    required this.factSum,
    required this.completionPercentCount,
    required this.completionPercentSum,
    required this.months,
  });

  MyPlanMonthProgress? monthFor(DateTime date) {
    if (months.length == 12) {
      final sorted = [...months]..sort((a, b) => a.month.compareTo(b.month));
      return sorted[date.month - 1];
    }

    for (final month in months) {
      if (month.month == date.month) return month;
    }
    for (final month in months) {
      if (month.month == date.month - 1) return month;
    }
    return null;
  }
}

class MyPlanMonthProgress {
  final int month;
  final String monthName;
  final int planCount;
  final int factCount;
  final double planSum;
  final double factSum;
  final double? completionPercentCount;
  final double? completionPercentSum;

  const MyPlanMonthProgress({
    required this.month,
    required this.monthName,
    required this.planCount,
    required this.factCount,
    required this.planSum,
    required this.factSum,
    required this.completionPercentCount,
    required this.completionPercentSum,
  });

  const MyPlanMonthProgress.empty(int month)
    : this(
        month: month,
        monthName: '',
        planCount: 0,
        factCount: 0,
        planSum: 0,
        factSum: 0,
        completionPercentCount: null,
        completionPercentSum: null,
      );
}

class MyPlanActiveTask {
  final int index;
  final int total;
  final MyPlanDrugProgress drug;
  final MyPlanMonthProgress month;

  const MyPlanActiveTask({
    required this.index,
    required this.total,
    required this.drug,
    required this.month,
  });
}

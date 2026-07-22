import '../domain/entities/my_plan.dart';

class MyPlanMapper {
  const MyPlanMapper._();

  static MyPlanProgress fromJson(Map<String, dynamic> json) {
    final drugs = _list(json['drugs'])
        .map(_drugFromJson)
        .whereType<MyPlanDrugProgress>()
        .toList(growable: false);

    return MyPlanProgress(
      year: _int(json['year']),
      totalPlanCount: _int(json['total_plan_count']),
      totalFactCount: _int(json['total_fact_count']),
      totalPlanSum: _double(json['total_plan_sum']),
      totalFactSum: _double(json['total_fact_sum']),
      completionPercentCount: _nullableDouble(
        json['completion_percent_count'] ?? json['completion_percent'],
      ),
      completionPercentSum: _nullableDouble(json['completion_percent_sum']),
      drugs: drugs,
    );
  }

  static Map<String, dynamic> toJson(MyPlanProgress plan) {
    return <String, dynamic>{
      'year': plan.year,
      'total_plan_count': plan.totalPlanCount,
      'total_fact_count': plan.totalFactCount,
      'total_plan_sum': plan.totalPlanSum,
      'total_fact_sum': plan.totalFactSum,
      'completion_percent_count': plan.completionPercentCount,
      'completion_percent_sum': plan.completionPercentSum,
      'drugs': plan.drugs.map(_drugToJson).toList(growable: false),
    };
  }

  static MyPlanDrugProgress? _drugFromJson(dynamic value) {
    final json = _map(value);
    if (json == null) return null;
    return MyPlanDrugProgress(
      drugBindingId: _int(json['drug_binding_id']),
      drugName: json['drug_name']?.toString().trim() ?? '',
      producerName: json['producer_name']?.toString().trim() ?? '',
      basePrice: _double(json['base_price']),
      planCount: _int(json['plan_count']),
      factCount: _int(json['fact_count']),
      planSum: _double(json['plan_sum']),
      factSum: _double(json['fact_sum']),
      completionPercentCount: _nullableDouble(
        json['completion_percent_count'] ?? json['completion_percent'],
      ),
      completionPercentSum: _nullableDouble(json['completion_percent_sum']),
      months: _list(json['months'])
          .map(_monthFromJson)
          .whereType<MyPlanMonthProgress>()
          .toList(growable: false),
    );
  }

  static MyPlanMonthProgress? _monthFromJson(dynamic value) {
    final json = _map(value);
    if (json == null) return null;
    return MyPlanMonthProgress(
      month: _int(json['month']),
      monthName: json['month_name']?.toString().trim() ?? '',
      planCount: _int(json['plan_count']),
      factCount: _int(json['fact_count']),
      planSum: _double(json['plan_sum']),
      factSum: _double(json['fact_sum']),
      completionPercentCount: _nullableDouble(
        json['completion_percent_count'] ?? json['completion_percent'],
      ),
      completionPercentSum: _nullableDouble(json['completion_percent_sum']),
    );
  }

  static Map<String, dynamic> _drugToJson(MyPlanDrugProgress drug) {
    return <String, dynamic>{
      'drug_binding_id': drug.drugBindingId,
      'drug_name': drug.drugName,
      'producer_name': drug.producerName,
      'base_price': drug.basePrice,
      'plan_count': drug.planCount,
      'fact_count': drug.factCount,
      'plan_sum': drug.planSum,
      'fact_sum': drug.factSum,
      'completion_percent_count': drug.completionPercentCount,
      'completion_percent_sum': drug.completionPercentSum,
      'months': drug.months.map(_monthToJson).toList(growable: false),
    };
  }

  static Map<String, dynamic> _monthToJson(MyPlanMonthProgress month) {
    return <String, dynamic>{
      'month': month.month,
      'month_name': month.monthName,
      'plan_count': month.planCount,
      'fact_count': month.factCount,
      'plan_sum': month.planSum,
      'fact_sum': month.factSum,
      'completion_percent_count': month.completionPercentCount,
      'completion_percent_sum': month.completionPercentSum,
    };
  }

  static List<dynamic> _list(dynamic value) => value is List ? value : const [];

  static Map<String, dynamic>? _map(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return null;
  }

  static int _int(dynamic value) {
    if (value is num) return value.round();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static double _double(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  static double? _nullableDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }
}

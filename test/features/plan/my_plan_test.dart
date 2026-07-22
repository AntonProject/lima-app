import 'package:flutter_test/flutter_test.dart';
import 'package:lima/features/plan/data/my_plan_mapper.dart';
import 'package:lima/features/plan/domain/entities/my_plan.dart';
import 'package:lima/features/plan/domain/repositories/my_plan_repository.dart';
import 'package:lima/features/plan/presentation/view_models/my_plan_view_model.dart';

void main() {
  test('maps the planning API count and sum percentages', () {
    final plan = MyPlanMapper.fromJson({
      'year': 2026,
      'total_plan_count': 142128,
      'total_fact_count': 71,
      'total_plan_sum': 3691876105,
      'total_fact_sum': 4771200,
      'completion_percent_count': 0.05,
      'completion_percent_sum': 0.13,
      'drugs': [
        {
          'drug_binding_id': 5,
          'drug_name': 'Аккорд',
          'producer_name': 'TEMUR MED',
          'plan_count': 145,
          'fact_count': 0,
          'completion_percent_count': 0,
          'months': [
            {
              'month': 7,
              'plan_count': 7,
              'fact_count': 0,
              'completion_percent_count': null,
            },
          ],
        },
      ],
    });

    expect(plan.year, 2026);
    expect(plan.totalPlanCount, 142128);
    expect(plan.completionPercentCount, 0.05);
    expect(plan.completionPercentSum, 0.13);
    expect(plan.drugs.single.months.single.completionPercentCount, isNull);
  });

  test('selects a full month list positionally for either month base', () {
    final months = List.generate(
      12,
      (index) => _month(month: 11 - index, plan: 11 - index),
    );
    final drug = _drug(id: 1, months: months);

    final july = drug.monthFor(DateTime(2026, 7, 1));

    expect(july?.month, 6);
    expect(july?.planCount, 6);
  });

  test('prefers a one-based month value for an incomplete month list', () {
    final drug = _drug(
      id: 1,
      months: [_month(month: 6, plan: 60), _month(month: 7, plan: 70)],
    );

    expect(drug.monthFor(DateTime(2026, 7, 1))?.planCount, 70);
  });

  test('active task prefers an unfinished drug with a monthly plan', () {
    final noMonthlyPlan = _drug(
      id: 1,
      months: [_month(month: 7, plan: 0, percent: null)],
    );
    final active = _drug(
      id: 2,
      months: [_month(month: 7, plan: 12, percent: 20)],
    );
    final plan = _plan(drugs: [noMonthlyPlan, active]);

    final task = plan.activeTask(DateTime(2026, 7, 1));

    expect(task?.drug.drugBindingId, 2);
    expect(task?.index, 1);
    expect(task?.total, 2);
  });

  test('keeps a cached plan visible when refresh fails', () async {
    final cached = _plan(drugs: [_drug(id: 1)]);
    final viewModel = MyPlanViewModel(
      _FakeMyPlanRepository(
        cached: cached,
        refreshError: StateError('offline'),
      ),
      2026,
    );
    addTearDown(viewModel.dispose);

    await viewModel.load();

    expect(viewModel.state.plan, same(cached));
    expect(viewModel.state.isLoading, isFalse);
    expect(viewModel.state.isRefreshing, isFalse);
    expect(viewModel.state.error, contains('offline'));
  });
}

MyPlanProgress _plan({List<MyPlanDrugProgress> drugs = const []}) {
  return MyPlanProgress(
    year: 2026,
    totalPlanCount: 0,
    totalFactCount: 0,
    totalPlanSum: 0,
    totalFactSum: 0,
    completionPercentCount: null,
    completionPercentSum: null,
    drugs: drugs,
  );
}

MyPlanDrugProgress _drug({
  required int id,
  List<MyPlanMonthProgress> months = const [],
}) {
  return MyPlanDrugProgress(
    drugBindingId: id,
    drugName: 'Drug $id',
    producerName: 'Producer',
    basePrice: 0,
    planCount: 0,
    factCount: 0,
    planSum: 0,
    factSum: 0,
    completionPercentCount: null,
    completionPercentSum: null,
    months: months,
  );
}

MyPlanMonthProgress _month({
  required int month,
  required int plan,
  double? percent,
}) {
  return MyPlanMonthProgress(
    month: month,
    monthName: '',
    planCount: plan,
    factCount: 0,
    planSum: 0,
    factSum: 0,
    completionPercentCount: percent,
    completionPercentSum: percent,
  );
}

class _FakeMyPlanRepository implements MyPlanRepository {
  final MyPlanProgress? cached;
  final Object? refreshError;

  const _FakeMyPlanRepository({this.cached, this.refreshError});

  @override
  Future<MyPlanProgress?> getCachedPlan(int year) async => cached;

  @override
  Future<MyPlanProgress> refreshPlan(int year) async {
    final error = refreshError;
    if (error != null) throw error;
    return cached ?? _plan();
  }
}

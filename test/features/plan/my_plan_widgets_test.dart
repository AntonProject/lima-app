import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lima/features/plan/domain/entities/my_plan.dart';
import 'package:lima/features/plan/widgets/my_plan_widgets.dart';
import 'package:lima/features/plan/widgets/plan_taskbar.dart';
import 'package:lima/core/widgets/app_widgets.dart';

void main() {
  final plan = _samplePlan();

  testWidgets('taskbar renders its collapsed and expanded mobile states', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _TestApp(
        child: PlanTaskbar(
          plan: plan,
          expanded: false,
          pullOffset: 0,
          onHintTap: () {},
        ),
      ),
    );

    expect(find.textContaining('pull down'), findsOneWidget);
    expect(find.text('Аккорд раствор для инфузий 50 мл'), findsNothing);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(
      _TestApp(
        child: PlanTaskbar(
          plan: plan,
          expanded: true,
          pullOffset: 0,
          onHintTap: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Аккорд раствор для инфузий 50 мл'), findsOneWidget);
    expect(find.text('1 of 1'), findsOneWidget);
    expect(find.textContaining('View all'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('active task card opens the annual plan when tapped', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    var taps = 0;
    await tester.pumpWidget(
      _TestApp(
        child: PlanTaskbar(
          plan: plan,
          expanded: true,
          pullOffset: 0,
          onHintTap: () => taps++,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(AppTapScale), findsOneWidget);
    await tester.tap(find.byType(AppTapScale));
    await tester.pump(const Duration(milliseconds: 220));

    expect(taps, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('annual plan and expanded month grid fit a mobile viewport', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _TestApp(
        child: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                MyPlanSummaryCard(plan: plan),
                const SizedBox(height: 12),
                MyPlanDrugCard(
                  drug: plan.drugs.single,
                  expanded: true,
                  onToggle: () {},
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Plan completion'), findsOneWidget);
    expect(find.text('January'), findsOneWidget);
    expect(find.text('December'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('year selector shows the current year and its neighbours', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _TestApp(
        child: MyPlanYearSelector(
          selectedYear: DateTime.now().year,
          onSelected: (_) {},
        ),
      ),
    );

    final currentYear = DateTime.now().year;
    expect(find.text('${currentYear - 1}'), findsOneWidget);
    expect(find.text('$currentYear'), findsOneWidget);
    expect(find.text('${currentYear + 1}'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('year selector keeps longer year lists horizontally scrollable', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _TestApp(
        child: MyPlanYearSelector(
          selectedYear: 2026,
          availableYears: List.generate(8, (index) => 2023 + index),
          onSelected: (_) {},
        ),
      ),
    );

    expect(find.text('2023'), findsOneWidget);
    expect(find.text('2030'), findsOneWidget);
    expect(find.byType(SingleChildScrollView), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _TestApp extends StatelessWidget {
  final Widget child;

  const _TestApp({required this.child});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(locale: const Locale('en'), home: child);
  }
}

MyPlanProgress _samplePlan() {
  final months = List.generate(
    12,
    (index) => MyPlanMonthProgress(
      month: index + 1,
      monthName: '',
      planCount: index == DateTime.now().month - 1 ? 7 : index + 1,
      factCount: 0,
      planSum: 100,
      factSum: 0,
      completionPercentCount: 0,
      completionPercentSum: 0,
    ),
  );
  final drug = MyPlanDrugProgress(
    drugBindingId: 5,
    drugName: 'Аккорд раствор для инфузий 50 мл',
    producerName: 'TEMUR MED',
    basePrice: 100,
    planCount: 145,
    factCount: 0,
    planSum: 14500,
    factSum: 0,
    completionPercentCount: 0,
    completionPercentSum: 0,
    months: months,
  );
  return MyPlanProgress(
    year: 2026,
    totalPlanCount: 142128,
    totalFactCount: 71,
    totalPlanSum: 3691876105,
    totalFactSum: 4771200,
    completionPercentCount: 0.05,
    completionPercentSum: 0.13,
    drugs: [drug],
  );
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/i18n/app_i18n.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/my_plan_provider.dart';
import '../widgets/my_plan_widgets.dart';

class MyPlanScreen extends ConsumerStatefulWidget {
  const MyPlanScreen({super.key});

  @override
  ConsumerState<MyPlanScreen> createState() => _MyPlanScreenState();
}

class _MyPlanScreenState extends ConsumerState<MyPlanScreen> {
  late int _selectedYear;
  final Set<int> _expandedDrugs = <int>{};

  @override
  void initState() {
    super.initState();
    _selectedYear = DateTime.now().year;
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(myPlanProvider(_selectedYear));
    final plan = state.plan;

    return Scaffold(
      backgroundColor: AppColors.primaryBg,
      appBar: AppBar(
        toolbarHeight: 76,
        leadingWidth: 56,
        backgroundColor: AppColors.secondaryBg,
        surfaceTintColor: Colors.transparent,
        shadowColor: const Color(0x14000000),
        elevation: 2,
        scrolledUnderElevation: 2,
        leading: IconButton(
          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/home');
            }
          },
          icon: Icon(AppIcons.back, size: 23),
        ),
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              context.l10n.t('myPlan'),
              style: GoogleFonts.manrope(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.primaryText,
              ),
            ),
            Text(
              context.l10n.t('planAndFactForYear'),
              style: GoogleFonts.manrope(
                fontSize: 13,
                color: const Color(0xFF9EABC4),
              ),
            ),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () => ref
            .read(myPlanProvider(_selectedYear).notifier)
            .load(refreshOnly: true),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 32),
          children: [
            MyPlanYearSelector(
              selectedYear: _selectedYear,
              onSelected: (year) {
                if (year == _selectedYear) return;
                setState(() {
                  _selectedYear = year;
                  _expandedDrugs.clear();
                });
              },
            ),
            if (state.isRefreshing)
              const LinearProgressIndicator(minHeight: 2)
            else
              const SizedBox(height: 2),
            if (state.isLoading && plan == null)
              const SizedBox(
                height: 280,
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              )
            else if (plan == null)
              SizedBox(
                height: 280,
                child: _PlanLoadError(
                  onRetry: () =>
                      ref.read(myPlanProvider(_selectedYear).notifier).load(),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                child: Column(
                  children: [
                    MyPlanSummaryCard(plan: plan),
                    if (plan.drugs.isEmpty)
                      const MyPlanEmptyState()
                    else ...[
                      const SizedBox(height: 14),
                      for (final drug in plan.drugs) ...[
                        MyPlanDrugCard(
                          drug: drug,
                          expanded: _expandedDrugs.contains(drug.drugBindingId),
                          onToggle: () {
                            setState(() {
                              if (!_expandedDrugs.remove(drug.drugBindingId)) {
                                _expandedDrugs.add(drug.drugBindingId);
                              }
                            });
                          },
                        ),
                        const SizedBox(height: 10),
                      ],
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PlanLoadError extends StatelessWidget {
  final VoidCallback onRetry;

  const _PlanLoadError({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(AppIcons.clipboard, size: 40, color: AppColors.hintText),
            const SizedBox(height: 16),
            Text(
              context.l10n.t('planLoadFailed'),
              textAlign: TextAlign.center,
              style: GoogleFonts.manrope(color: AppColors.secondaryText),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: 160,
              child: ElevatedButton(
                onPressed: onRetry,
                child: Text(context.l10n.t('retry')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

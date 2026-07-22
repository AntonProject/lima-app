import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/i18n/app_i18n.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_widgets.dart';
import '../domain/entities/my_plan.dart';
import 'plan_progress_widgets.dart';

class MyPlanYearSelector extends StatelessWidget {
  final int selectedYear;
  final ValueChanged<int> onSelected;
  final List<int>? availableYears;

  const MyPlanYearSelector({
    super.key,
    required this.selectedYear,
    required this.onSelected,
    this.availableYears,
  });

  @override
  Widget build(BuildContext context) {
    final currentYear = DateTime.now().year;
    final years =
        (availableYears ?? [currentYear - 1, currentYear, currentYear + 1])
            .toSet()
            .toList()
          ..sort();
    return SizedBox(
      height: 62,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < years.length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                _YearButton(
                  year: years[i],
                  selected: years[i] == selectedYear,
                  onTap: () => onSelected(years[i]),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _YearButton extends StatelessWidget {
  final int year;
  final bool selected;
  final VoidCallback onTap;

  const _YearButton({
    required this.year,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AppTapScale(
      onTap: onTap,
      pressedScale: 0.96,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 68,
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
          ),
        ),
        child: Text(
          '$year',
          style: GoogleFonts.manrope(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : const Color(0xFF60708D),
          ),
        ),
      ),
    );
  }
}

class MyPlanSummaryCard extends StatelessWidget {
  final MyPlanProgress plan;

  const MyPlanSummaryCard({super.key, required this.plan});

  @override
  Widget build(BuildContext context) {
    final percent = plan.completionPercentCount;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: shadowSm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  context.l10n.t('planCompletion'),
                  style: GoogleFonts.manrope(
                    fontSize: 14,
                    color: const Color(0xFF60708D),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                planPercentLabel(percent),
                style: GoogleFonts.manrope(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: planProgressColor(percent),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          PlanProgressBar(value: percent),
          const SizedBox(height: 14),
          _SummaryRow(
            label: context.l10n.t('packages'),
            value:
                '${formatPlanInt(context, plan.totalFactCount)} / '
                '${formatPlanInt(context, plan.totalPlanCount)}',
          ),
          const SizedBox(height: 6),
          _SummaryRow(
            label: context.l10n.t('sum'),
            value:
                '${formatPlanMoney(context, plan.totalFactSum)} / '
                '${formatPlanMoney(context, plan.totalPlanSum)}',
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;

  const _SummaryRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.manrope(
            fontSize: 14,
            color: const Color(0xFF60708D),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: GoogleFonts.manrope(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.primaryText,
            ),
          ),
        ),
      ],
    );
  }
}

class MyPlanDrugCard extends StatelessWidget {
  final MyPlanDrugProgress drug;
  final bool expanded;
  final VoidCallback onToggle;

  const MyPlanDrugCard({
    super.key,
    required this.drug,
    required this.expanded,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final percent = drug.completionPercentCount;
    return AppTapScale(
      onTap: onToggle,
      pressedScale: 0.99,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: shadowSm,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        drug.drugName.isEmpty
                            ? context.l10n.t('drug')
                            : drug.drugName,
                        style: GoogleFonts.manrope(
                          fontSize: 14,
                          height: 1.25,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primaryText,
                        ),
                      ),
                      if (drug.producerName.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          drug.producerName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.manrope(
                            fontSize: 11,
                            color: const Color(0xFF9EABC4),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  planPercentLabel(percent),
                  style: GoogleFonts.manrope(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: planProgressColor(percent),
                  ),
                ),
                const SizedBox(width: 6),
                Icon(
                  expanded ? AppIcons.chevronDown : AppIcons.chevronRight,
                  size: 18,
                  color: const Color(0xFF9EABC4),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Text(
                    '${formatPlanInt(context, drug.factCount)} / '
                    '${formatPlanInt(context, drug.planCount)} '
                    '${context.l10n.t('planPcsShort')}',
                    style: GoogleFonts.manrope(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primaryText,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${formatPlanMoney(context, drug.factSum)} / '
                    '${formatPlanMoney(context, drug.planSum)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.right,
                    style: GoogleFonts.manrope(
                      fontSize: 11,
                      color: const Color(0xFF9EABC4),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            PlanProgressBar(value: percent, height: 5),
            AnimatedSize(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: expanded
                  ? _PlanMonthsGrid(months: drug.months)
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlanMonthsGrid extends StatelessWidget {
  final List<MyPlanMonthProgress> months;

  const _PlanMonthsGrid({required this.months});

  @override
  Widget build(BuildContext context) {
    final sorted = [...months]..sort((a, b) => a.month.compareTo(b.month));
    final zeroBased = sorted.any((month) => month.month == 0);
    return Column(
      children: [
        const SizedBox(height: 12),
        const Divider(height: 1, color: AppColors.divider),
        const SizedBox(height: 10),
        LayoutBuilder(
          builder: (context, constraints) {
            const gap = 8.0;
            final width = (constraints.maxWidth - gap * 2) / 3;
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [
                for (var i = 0; i < sorted.length; i++)
                  SizedBox(
                    width: width,
                    height: 64,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: AppColors.primaryBg,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              localizedPlanMonth(
                                context,
                                sorted.length == 12
                                    ? i + 1
                                    : sorted[i].month + (zeroBased ? 1 : 0),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.manrope(
                                fontSize: 11,
                                color: const Color(0xFF60708D),
                              ),
                            ),
                            const Spacer(),
                            Text(
                              '${formatPlanInt(context, sorted[i].factCount)}/'
                              '${formatPlanInt(context, sorted[i].planCount)}',
                              style: GoogleFonts.manrope(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primaryText,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class MyPlanEmptyState extends StatelessWidget {
  const MyPlanEmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 76),
      child: Column(
        children: [
          Icon(AppIcons.clipboard, size: 40, color: const Color(0xFF9EABC4)),
          const SizedBox(height: 18),
          Text(
            context.l10n.t('noPlanDataForYear'),
            textAlign: TextAlign.center,
            style: GoogleFonts.manrope(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF60708D),
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/i18n/app_i18n.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_widgets.dart';
import '../domain/entities/my_plan.dart';
import 'plan_progress_widgets.dart';

class PlanTaskbar extends StatelessWidget {
  final MyPlanProgress plan;
  final bool expanded;
  final double pullOffset;
  final VoidCallback onHintTap;

  const PlanTaskbar({
    super.key,
    required this.plan,
    required this.expanded,
    required this.pullOffset,
    required this.onHintTap,
  });

  @override
  Widget build(BuildContext context) {
    final task = plan.activeTask(DateTime.now());
    if (task == null) return const SizedBox.shrink();

    return AnimatedSize(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: Transform.translate(
        offset: Offset(0, pullOffset),
        child: expanded
            ? _ExpandedTaskbar(task: task, onHintTap: onHintTap)
            : _CollapsedTaskbar(onTap: onHintTap),
      ),
    );
  }
}

class _CollapsedTaskbar extends StatelessWidget {
  final VoidCallback onTap;

  const _CollapsedTaskbar({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.primaryBg,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 42,
          child: Center(
            child: Text(
              '↓ ${context.l10n.t('pullToRevealPlan')} ↓',
              textAlign: TextAlign.center,
              style: GoogleFonts.manrope(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF9EABC4),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ExpandedTaskbar extends StatelessWidget {
  final MyPlanActiveTask task;
  final VoidCallback onHintTap;

  const _ExpandedTaskbar({required this.task, required this.onHintTap});

  @override
  Widget build(BuildContext context) {
    final percent = task.month.completionPercentCount;
    return Column(
      children: [
        Container(
          color: AppColors.primary,
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: context.l10n.t('activeTask'),
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          TextSpan(
                            text:
                                ' · ${localizedPlanMonth(context, DateTime.now().month)}',
                          ),
                        ],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.manrope(
                        fontSize: 12,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${task.index + 1} ${context.l10n.t('planOf')} ${task.total}',
                    style: GoogleFonts.manrope(
                      fontSize: 11,
                      color: Colors.white.withValues(alpha: 0.75),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              AppTapScale(
                onTap: onHintTap,
                pressedScale: 0.98,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              task.drug.drugName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.manrope(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primaryText,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            planPercentLabel(percent),
                            style: GoogleFonts.manrope(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: planProgressColor(percent),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Text(
                        '${formatPlanInt(context, task.month.factCount)} / '
                        '${formatPlanInt(context, task.month.planCount)} '
                        '${context.l10n.t('planPcsShort')}',
                        style: GoogleFonts.manrope(
                          fontSize: 11,
                          color: const Color(0xFF9EABC4),
                        ),
                      ),
                      const SizedBox(height: 8),
                      PlanProgressBar(value: percent, height: 5),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        Material(
          color: AppColors.primaryBg,
          child: InkWell(
            onTap: onHintTap,
            child: SizedBox(
              height: 42,
              child: Center(
                child: Text(
                  '↓ ${context.l10n.t('viewAllPlan')} ↓',
                  style: GoogleFonts.manrope(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF9EABC4),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

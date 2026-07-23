import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/i18n/app_i18n.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_widgets.dart';
import '../domain/entities/my_plan.dart';
import 'plan_progress_widgets.dart';

/// Compatibility composition used by widget previews and tests.
///
/// On the home screen [PlanTaskbarPanel] is rendered inside the blue sliver
/// app bar while [PlanTaskbarHint] remains directly below it.
class PlanTaskbar extends StatelessWidget {
  final MyPlanProgress plan;
  final bool expanded;
  final VoidCallback onHintTap;

  const PlanTaskbar({
    super.key,
    required this.plan,
    required this.expanded,
    required this.onHintTap,
  });

  @override
  Widget build(BuildContext context) {
    final task = plan.activeTask(DateTime.now());
    if (task == null) return const SizedBox.shrink();

    return Column(
      children: [
        if (expanded)
          Container(
            color: AppColors.primary,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: PlanTaskbarPanel(task: task, onTap: onHintTap),
          ),
        PlanTaskbarHint(expanded: expanded, onTap: onHintTap),
      ],
    );
  }
}

/// Active-plan content that belongs to the blue home sliver app bar.
class PlanTaskbarPanel extends StatelessWidget {
  static const double height = 112;

  final MyPlanActiveTask task;
  final VoidCallback onTap;

  const PlanTaskbarPanel({super.key, required this.task, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final percent = task.month.completionPercentCount;

    return SizedBox(
      height: height,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(0, 8, 0, 10),
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
            Expanded(
              child: AppTapScale(
                onTap: onTap,
                pressedScale: 0.98,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(12, 9, 12, 8),
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
                      const SizedBox(height: 4),
                      Text(
                        '${formatPlanInt(context, task.month.factCount)} / '
                        '${formatPlanInt(context, task.month.planCount)} '
                        '${context.l10n.t('planPcsShort')}',
                        style: GoogleFonts.manrope(
                          fontSize: 11,
                          color: const Color(0xFF9EABC4),
                        ),
                      ),
                      const Spacer(),
                      PlanProgressBar(value: percent, height: 5),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Stationary action label directly below the home sliver app bar.
class PlanTaskbarHint extends StatelessWidget {
  final bool expanded;
  final VoidCallback onTap;

  const PlanTaskbarHint({
    super.key,
    required this.expanded,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.primaryBg,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 42,
          child: Center(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              switchInCurve: Curves.easeOut,
              switchOutCurve: Curves.easeIn,
              child: Text(
                expanded
                    ? '↓ ${context.l10n.t('viewAllPlan')} ↓'
                    : '↓ ${context.l10n.t('pullToRevealPlan')} ↓',
                key: ValueKey(expanded),
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
      ),
    );
  }
}

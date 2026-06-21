import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/i18n/app_i18n.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_widgets.dart';

class LpuCompleteScreen extends StatelessWidget {
  const LpuCompleteScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final startTime = DateTime.now().subtract(const Duration(minutes: 23));
    final endTime = DateTime.now();
    final duration = endTime.difference(startTime);

    return Scaffold(
      backgroundColor: AppColors.primaryBg,
      body: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              color: AppColors.secondaryBg,
              boxShadow: shadowSm,
            ),
            padding: EdgeInsets.fromLTRB(
                12, MediaQuery.of(context).padding.top + 8, 12, 10),
            child: Row(
              children: [
                AppTapScale(
                  pressedScale: 0.9,
                  onTap: () =>
                      context.canPop() ? context.pop() : context.go('/visits'),
                  child: const Icon(Icons.close_rounded,
                      color: AppColors.primaryText, size: 22),
                ),
                const SizedBox(width: 10),
                Text(
                  context.l10n.t('visitDone'),
                  style: GoogleFonts.manrope(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primaryText,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(12, 20, 12, 20),
              children: [
                Center(
                  child: Container(
                    width: 68,
                    height: 68,
                    decoration: BoxDecoration(
                      color: AppColors.success,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.success.withValues(alpha: 0.25),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.check_rounded,
                        color: Colors.white, size: 36),
                  ),
                ),
                const SizedBox(height: 14),
                Center(
                  child: Text(
                    context.l10n.t('visitDoneSuccess'),
                    style: GoogleFonts.manrope(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primaryText,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Center(
                  child: Text(
                    context.l10n.t('dataSavedInSystem'),
                    style: GoogleFonts.manrope(
                      fontSize: 13,
                      color: AppColors.secondaryText,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.secondaryBg,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: shadowSm,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  child: Column(
                    children: [
                      _SummaryRow(
                        icon: Icons.access_time_rounded,
                        label: context.l10n.t('visitStart'),
                        value:
                            '${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}',
                      ),
                      const Divider(height: 1, thickness: 0.5, color: AppColors.divider),
                      _SummaryRow(
                        icon: Icons.check_circle_outline_rounded,
                        label: context.l10n.t('visitEnd'),
                        value:
                            '${endTime.hour.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')}',
                      ),
                      const Divider(height: 1, thickness: 0.5, color: AppColors.divider),
                      _SummaryRow(
                        icon: Icons.timer_outlined,
                        label: context.l10n.t('duration'),
                        value: '${duration.inMinutes} ${context.l10n.t('minutesShort')}',
                      ),
                      const Divider(height: 1, thickness: 0.5, color: AppColors.divider),
                      _SummaryRow(
                        icon: Icons.medication_outlined,
                        label: context.l10n.t('drugsShown'),
                        value: '3',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                AppTapScale(
                  pressedScale: 0.97,
                  onTap: () => context.go('/visits'),
                  child: ElevatedButton(
                    onPressed: null,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 44),
                      disabledBackgroundColor: AppColors.primary,
                      disabledForegroundColor: Colors.white,
                    ),
                    child: Text(context.l10n.t('toVisits')),
                  ),
                ),
                const SizedBox(height: 8),
                AppTapScale(
                  pressedScale: 0.97,
                  onTap: () => context.go('/visits'),
                  child: OutlinedButton(
                    onPressed: null,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 44),
                      disabledForegroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.primary),
                    ),
                    child: Text(context.l10n.t('newVisit')),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _SummaryRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: AppColors.iconBgBlue,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: AppColors.primary, size: 15),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.manrope(
                fontSize: 13,
                color: AppColors.secondaryText,
              ),
            ),
          ),
          Text(
            value,
            style: GoogleFonts.manrope(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.primaryText,
            ),
          ),
        ],
      ),
    );
  }
}

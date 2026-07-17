import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/i18n/app_i18n.dart';
import '../../../core/models/models.dart';
import '../../../core/theme/app_theme.dart';

class PlanVisitCard extends StatelessWidget {
  final PlannedVisit visit;
  final VoidCallback onTap;

  const PlanVisitCard({super.key, required this.visit, required this.onTap});

  String _formatAddress(BuildContext context) {
    final city = (visit.city ?? '').trim();
    final district = (visit.district ?? '').trim();
    if (city.isEmpty && district.isEmpty) return '';
    if (city.isEmpty) return district;
    final cityShort = context.l10n.t('cityShort');
    if (district.isEmpty) return '$cityShort $city';
    return '$cityShort $city, $district';
  }

  @override
  Widget build(BuildContext context) {
    final isCompleted = visit.status == VisitStatus.completed;
    final statusText = isCompleted
        ? context.l10n.t('conducted')
        : context.l10n.t('planned');
    final statusBg = isCompleted
        ? const Color(0xFFE6F7EE)
        : const Color(0xFFFCEFD9);
    final statusFg = isCompleted
        ? const Color(0xFF1F8A4C)
        : const Color(0xFFB46A1B);
    final doctorName = (visit.doctorName ?? '').trim();
    final address = _formatAddress(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.secondaryBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border, width: 0.5),
            boxShadow: shadowSm,
          ),
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      visit.organisationName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.manrope(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaryText,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      doctorName.isEmpty
                          ? context.l10n.t('doctorNotAssigned')
                          : doctorName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.manrope(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        fontStyle: doctorName.isEmpty
                            ? FontStyle.italic
                            : FontStyle.normal,
                        color: doctorName.isEmpty
                            ? AppColors.hintText
                            : AppColors.primary,
                      ),
                    ),
                    if (visit.assignedBy.trim().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        visit.assignedBy,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.manrope(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: AppColors.secondaryText,
                        ),
                      ),
                    ],
                    if (address.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        address,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.manrope(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: AppColors.hintText,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: statusBg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      statusText,
                      style: GoogleFonts.manrope(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: statusFg,
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  const Icon(
                    Icons.chevron_right_rounded,
                    size: 22,
                    color: AppColors.hintText,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lima/core/i18n/app_i18n.dart';
import 'package:lima/core/theme/app_theme.dart';

void showDoctorDetailDialog(
  BuildContext context, {
  required String name,
  required String specialty,
  required String category,
  required String lastVisit,
  int? orgId,
  String? orgName,
  int? doctorId,
}) {
  showModalBottomSheet(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _DoctorDetailSheet(
      name: name, specialty: specialty, category: category,
      lastVisit: lastVisit, orgId: orgId, orgName: orgName, doctorId: doctorId,
    ),
  );
}

class _DoctorDetailSheet extends StatelessWidget {
  final String name, specialty, category, lastVisit;
  final int? orgId, doctorId;
  final String? orgName;

  const _DoctorDetailSheet({
    required this.name, required this.specialty,
    required this.category, required this.lastVisit,
    this.orgId, this.doctorId, this.orgName,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.secondaryBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(
          16, 16, 16, MediaQuery.of(context).padding.bottom + 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 36, height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2)),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: Text(name,
                    style: GoogleFonts.manrope(
                        fontSize: 18, fontWeight: FontWeight.w700,
                        color: AppColors.primaryText),
                    maxLines: 2, overflow: TextOverflow.ellipsis),
              ),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                      color: AppColors.primaryBg,
                      borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.close_rounded,
                      color: AppColors.secondaryText, size: 20),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Divider(height: 1, thickness: 0.5, color: AppColors.divider),
          const SizedBox(height: 14),
          Container(
            decoration: BoxDecoration(
              color: AppColors.primaryBg,
              borderRadius: BorderRadius.circular(14),
            ),
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                _InfoLine(context.l10n.t('specialty'), specialty),
                const SizedBox(height: 10),
                _InfoLine(context.l10n.t('category'), category),
                const SizedBox(height: 10),
                _InfoLine(context.l10n.t('lastVisit'), lastVisit),
              ],
            ),
          ),
          const SizedBox(height: 20),
          if (orgId != null && doctorId != null)
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                context.push(Uri(
                  path: '/visits/lpu/detail/$orgId/doctors/$doctorId/detailing',
                  queryParameters: {
                    'doctorName': name,
                    'orgName': orgName ?? '',
                  },
                ).toString());
              },
              icon: const Icon(Icons.play_circle_outline_rounded, size: 18, color: Colors.white),
              label: Text(context.l10n.t('startVisit'),
                  style: GoogleFonts.manrope(
                      fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 52),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            )
          else
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 52),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: Text(context.l10n.t('close'),
                  style: GoogleFonts.manrope(
                      fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
            ),
        ],
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  final String label, value;
  const _InfoLine(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 130,
          child: Text(label,
              style: GoogleFonts.manrope(
                  fontSize: 13, color: AppColors.secondaryText)),
        ),
        Expanded(
          child: Text(value,
              style: GoogleFonts.manrope(
                  fontSize: 13, fontWeight: FontWeight.w600,
                  color: AppColors.primaryText),
              textAlign: TextAlign.right),
        ),
      ],
    );
  }
}

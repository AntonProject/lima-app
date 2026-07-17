import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/i18n/app_i18n.dart';
import '../../../core/theme/app_theme.dart';
import '../domain/entities/visit_interaction.dart';

class LpuDetailingCompletionDialog extends StatelessWidget {
  final int organizationId;
  final String organizationName;
  final String organizationAddress;
  final String doctorName;
  final int doctorCount;
  final List<String> selectedDrugs;
  final DrugStatus? firstStatus;

  const LpuDetailingCompletionDialog({
    super.key,
    required this.organizationId,
    required this.organizationName,
    required this.organizationAddress,
    required this.doctorName,
    required this.doctorCount,
    required this.selectedDrugs,
    required this.firstStatus,
  });

  @override
  Widget build(BuildContext context) {
    final isGroup = doctorCount > 1;
    final doctorsLabel = isGroup
        ? context.l10n.t('doctorsWord')
        : context.l10n.t('doctorWord');
    final subtitle = isGroup
        ? context.l10n.t('groupPresentation')
        : context.l10n.t('presentation11');
    final firstDrug = selectedDrugs.isEmpty
        ? context.l10n.t('noDrugsSelected')
        : selectedDrugs.first;
    final firstStatusText = switch (firstStatus) {
      DrugStatus.familiarPrescribes => context.l10n.t('familiarPrescribes'),
      DrugStatus.familiarNotPrescribes => context.l10n.t(
        'familiarNotPrescribes',
      ),
      DrugStatus.unfamiliar => context.l10n.t('notFamiliar'),
      DrugStatus.other => context.l10n.t('comment'),
      _ => null,
    };
    final firstStatusColor = switch (firstStatus) {
      DrugStatus.familiarPrescribes => const Color(0xFF55B98A),
      DrugStatus.familiarNotPrescribes => const Color(0xFFC89B3C),
      DrugStatus.unfamiliar => const Color(0xFFE35D5B),
      DrugStatus.other => AppColors.secondaryText,
      _ => AppColors.secondaryText,
    };
    final firstStatusBg = switch (firstStatus) {
      DrugStatus.familiarPrescribes => const Color(0xFFE4F6EE),
      DrugStatus.familiarNotPrescribes => const Color(0xFFFAF1DF),
      DrugStatus.unfamiliar => const Color(0xFFFCE7E7),
      DrugStatus.other => const Color(0xFFEFF2F7),
      _ => const Color(0xFFEFF2F7),
    };

    return PopScope(
      canPop: false,
      child: Dialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: const BoxDecoration(
                    color: Color(0xFFDDF8EC),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: const BoxDecoration(
                        color: Color(0xFF55C796),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        LucideIcons.check,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                context.l10n.t('visitDone'),
                textAlign: TextAlign.center,
                style: GoogleFonts.manrope(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primaryText,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: GoogleFonts.manrope(
                  fontSize: 13,
                  color: AppColors.secondaryText,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 14),
              const Divider(height: 1, color: AppColors.divider),
              _dialogRow(context.l10n.t('organization'), organizationName),
              if (organizationAddress.isNotEmpty) ...[
                const Divider(height: 1, color: AppColors.divider),
                _dialogRow(context.l10n.t('address'), organizationAddress),
              ],
              const Divider(height: 1, color: AppColors.divider),
              _dialogRow(doctorsLabel, doctorName),
              const Divider(height: 1, color: AppColors.divider),
              const SizedBox(height: 10),
              Text(
                context.l10n.t(
                  'drugsN',
                  args: {'count': '${selectedDrugs.length}'},
                ),
                style: GoogleFonts.manrope(
                  fontSize: 13,
                  color: AppColors.secondaryText,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.divider),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        firstDrug,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.manrope(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: AppColors.primaryText,
                        ),
                      ),
                    ),
                    if (firstStatusText != null)
                      Container(
                        margin: const EdgeInsets.only(left: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: firstStatusBg,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          firstStatusText,
                          style: GoogleFonts.manrope(
                            fontSize: 11,
                            color: firstStatusColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  context.go(
                    Uri(
                      path: '/visits/lpu/detail/$organizationId',
                      queryParameters: {'name': organizationName},
                    ).toString(),
                  );
                },
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 44),
                ),
                child: Text(context.l10n.t('toOrganization')),
              ),
              const SizedBox(height: 10),
              OutlinedButton(
                onPressed: () {
                  Navigator.pop(context);
                  context.go(
                    '/home?refresh=${DateTime.now().millisecondsSinceEpoch}',
                  );
                },
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 44),
                ),
                child: Text(context.l10n.t('toHome')),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dialogRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 84,
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              softWrap: false,
              style: GoogleFonts.manrope(
                fontSize: 12,
                color: AppColors.secondaryText,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.manrope(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.primaryText,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

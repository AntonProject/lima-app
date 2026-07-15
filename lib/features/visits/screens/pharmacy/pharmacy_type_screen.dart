import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lima/features/visits/dialogs/payment_type_dialog.dart';
import 'package:lima/features/visits/data/visits_repository.dart';
import 'package:lima/features/auth/providers/auth_provider.dart';
import '../../../../core/i18n/app_i18n.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_widgets.dart';

class PharmacyTypeScreen extends ConsumerWidget {
  final int pharmacyId;
  final String pharmacyName;

  const PharmacyTypeScreen({
    super.key,
    required this.pharmacyId,
    required this.pharmacyName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
              12,
              MediaQuery.of(context).padding.top + 8,
              12,
              10,
            ),
            child: Row(
              children: [
                AppTapScale(
                  pressedScale: 0.9,
                  onTap: () {
                    if (context.canPop()) {
                      context.pop();
                      return;
                    }
                    context.go(
                      Uri(
                        path: '/visits/pharmacy/detail/$pharmacyId',
                        queryParameters: {'name': pharmacyName},
                      ).toString(),
                    );
                  },
                  child: const Icon(
                    Icons.arrow_back_rounded,
                    color: AppColors.primaryText,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.l10n.t('visitType'),
                        style: GoogleFonts.manrope(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primaryText,
                        ),
                      ),
                      Text(
                        pharmacyName,
                        style: GoogleFonts.manrope(
                          fontSize: 12,
                          color: AppColors.secondaryText,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 20),
              children: [
                Text(
                  context.l10n.t('selectVisitType'),
                  style: GoogleFonts.manrope(
                    fontSize: 13,
                    color: AppColors.secondaryText,
                  ),
                ),
                const SizedBox(height: 12),

                _VisitTypeCard(
                  icon: Icons.shopping_cart_rounded,
                  label: context.l10n.t('bron'),
                  description: context.l10n.t('bronDesc'),
                  bgColor: AppColors.iconBgBlue,
                  iconColor: AppColors.primary,
                  onTap: () async {
                    var allowWholesale = true;
                    try {
                      final companyId = ref.read(authProvider).user?.companyId;
                      allowWholesale = await ref
                          .read(visitsRepositoryProvider)
                          .supportsWholesaleOrders(companyId: companyId);
                    } catch (_) {
                      allowWholesale = true;
                    }
                    if (!context.mounted) return;
                    final payment = await showPaymentTypeDialog(
                      context,
                      allowWholesale: allowWholesale,
                    );
                    if (payment == null || !context.mounted) return;
                    context.push(
                      Uri(
                        path: '/visits/pharmacy/detail/$pharmacyId/type/order',
                        queryParameters: {
                          'name': pharmacyName,
                          'prepayment': '${payment.prepayment}',
                          'buyerType': '${payment.buyerType}',
                        },
                      ).toString(),
                    );
                  },
                ),
                const SizedBox(height: 8),

                _VisitTypeCard(
                  icon: Icons.inventory_2_rounded,
                  label: context.l10n.t('removeStockTitle'),
                  description: context.l10n.t('stockCheckDesc'),
                  bgColor: AppColors.iconBgOrange,
                  iconColor: AppColors.accent,
                  onTap: () => context.push(
                    Uri(
                      path: '/visits/pharmacy/detail/$pharmacyId/type/stock',
                      queryParameters: {'name': pharmacyName},
                    ).toString(),
                  ),
                ),
                const SizedBox(height: 8),

                _VisitTypeCard(
                  icon: Icons.groups_rounded,
                  label: context.l10n.t('pharmCircle'),
                  description: context.l10n.t('pharmCircleDesc'),
                  bgColor: AppColors.iconBgGreen,
                  iconColor: AppColors.success,
                  onTap: () => context.push(
                    Uri(
                      path: '/visits/pharmacy/detail/$pharmacyId/type/circle',
                      queryParameters: {'name': pharmacyName},
                    ).toString(),
                  ),
                ),
                const SizedBox(height: 16),

                HintBox(text: context.l10n.t('bronNote')),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _VisitTypeCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String description;
  final Color bgColor;
  final Color iconColor;
  final VoidCallback onTap;

  const _VisitTypeCard({
    required this.icon,
    required this.label,
    required this.description,
    required this.bgColor,
    required this.iconColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AppTapScale(
      pressedScale: 0.95,
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.secondaryBg,
          borderRadius: BorderRadius.circular(12),
          boxShadow: shadowSm,
        ),
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.manrope(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primaryText,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: GoogleFonts.manrope(
                      fontSize: 12,
                      color: AppColors.secondaryText,
                    ),
                    maxLines: 2,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.hintText,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lima/core/i18n/app_i18n.dart';
import 'package:lima/core/theme/app_theme.dart';

class PaymentTermsSelection {
  final int prepayment; // 100 or 0
  final int buyerType; // 0 retail, 1 wholesale

  const PaymentTermsSelection({
    required this.prepayment,
    required this.buyerType,
  });
}

Future<PaymentTermsSelection?> showPaymentTypeDialog(
  BuildContext context, {
  bool allowWholesale = true,
}) {
  return showModalBottomSheet(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _PaymentTypeSheet(allowWholesale: allowWholesale),
  );
}

class _PaymentTypeSheet extends StatefulWidget {
  final bool allowWholesale;

  const _PaymentTypeSheet({required this.allowWholesale});

  @override
  State<_PaymentTypeSheet> createState() => _PaymentTypeSheetState();
}

class _PaymentTypeSheetState extends State<_PaymentTypeSheet> {
  int _prepayment = 100; // 100 or 0
  int _buyerType = 0; // 0=retail, 1=wholesale

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.secondaryBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        MediaQuery.of(context).padding.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: Text(
                  context.l10n.t('paymentTerms'),
                  style: GoogleFonts.manrope(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryText,
                  ),
                ),
              ),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.primaryBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.close_rounded,
                    color: AppColors.secondaryText,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            context.l10n.t('prepayment'),
            style: GoogleFonts.manrope(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.secondaryText,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [100, 0].map((pct) {
              final active = _prepayment == pct;
              return Padding(
                padding: const EdgeInsets.only(right: 10),
                child: GestureDetector(
                  onTap: () => setState(() => _prepayment = pct),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: active
                          ? AppColors.iconBgBlue
                          : AppColors.primaryBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: active ? AppColors.primary : AppColors.border,
                        width: active ? 2 : 1,
                      ),
                    ),
                    child: Text(
                      '$pct%',
                      style: GoogleFonts.manrope(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: active
                            ? AppColors.primary
                            : AppColors.secondaryText,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
          Text(
            context.l10n.t('buyerType'),
            style: GoogleFonts.manrope(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.secondaryText,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: AppColors.primaryBg,
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.all(4),
            child: Row(
              children: [
                Expanded(
                  child: _TypeBtn(
                    context.l10n.t('retail'),
                    0,
                    _buyerType,
                    enabled: true,
                    onTap: () => setState(() => _buyerType = 0),
                  ),
                ),
                Expanded(
                  child: _TypeBtn(
                    context.l10n.t('wholesale'),
                    1,
                    _buyerType,
                    enabled: widget.allowWholesale,
                    onTap: () => setState(() => _buyerType = 1),
                  ),
                ),
              ],
            ),
          ),
          if (!widget.allowWholesale) ...[
            const SizedBox(height: 10),
            Text(
              'Оптовый тип покупателя недоступен для вашей компании',
              style: GoogleFonts.manrope(
                fontSize: 12,
                color: AppColors.hintText,
              ),
            ),
          ],
          const SizedBox(height: 20),
          Text(
            context.l10n.t('contract'),
            style: GoogleFonts.manrope(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.secondaryText,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            context.l10n.t('noContracts'),
            style: GoogleFonts.manrope(fontSize: 13, color: AppColors.hintText),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => Navigator.pop(
              context,
              PaymentTermsSelection(
                prepayment: _prepayment,
                buyerType: _buyerType,
              ),
            ),
            style:
                ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ).copyWith(
                  backgroundColor: WidgetStateProperty.resolveWith((states) {
                    if (states.contains(WidgetState.disabled)) {
                      return AppColors.border;
                    }
                    return AppColors.primary;
                  }),
                  foregroundColor: WidgetStateProperty.all(Colors.white),
                ),
            child: Text(
              context.l10n.t('continue'),
              style: GoogleFonts.manrope(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TypeBtn extends StatelessWidget {
  final String label;
  final int index, current;
  final bool enabled;
  final VoidCallback onTap;

  const _TypeBtn(
    this.label,
    this.index,
    this.current, {
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final active = index == current;
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Opacity(
        opacity: enabled ? 1 : 0.5,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: active ? AppColors.iconBgBlue : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: active
                ? Border.all(color: AppColors.primary, width: 1)
                : null,
          ),
          child: Center(
            child: Text(
              label,
              style: GoogleFonts.manrope(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: active ? AppColors.primary : AppColors.secondaryText,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

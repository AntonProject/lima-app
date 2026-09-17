import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lima/core/models/client_contract.dart';
import 'package:lima/core/i18n/app_i18n.dart';
import 'package:lima/core/models/order_term_option.dart';
import 'package:lima/core/theme/app_theme.dart';

class PaymentTermsSelection {
  final int prepayment;
  final int buyerType;
  final OrderTermOption? pricingTerms;
  final ClientContract? contract;

  const PaymentTermsSelection({
    required this.prepayment,
    required this.buyerType,
    this.pricingTerms,
    this.contract,
  });

  int? get contractId => contract?.id;
}

Future<PaymentTermsSelection?> showPaymentTypeDialog(
  BuildContext context, {
  List<OrderTermOption> terms = const [],
  bool? prepaymentEnabled,
  List<ClientContract> contracts = const [],
  int? selectedContractId,
  int? initialPrepayment,
  int? initialBuyerType,
  bool? allowWholesale,
}) {
  return showModalBottomSheet(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _PaymentTypeSheet(
      terms: terms,
      prepaymentEnabled: prepaymentEnabled,
      contracts: contracts,
      selectedContractId: selectedContractId,
      initialPrepayment: initialPrepayment,
      initialBuyerType: initialBuyerType,
      allowWholesale: allowWholesale,
    ),
  );
}

class _PaymentTypeSheet extends StatefulWidget {
  final List<OrderTermOption> terms;
  final bool? prepaymentEnabled;
  final List<ClientContract> contracts;
  final int? selectedContractId;
  final int? initialPrepayment;
  final int? initialBuyerType;
  final bool? allowWholesale;

  const _PaymentTypeSheet({
    required this.terms,
    required this.prepaymentEnabled,
    required this.contracts,
    required this.selectedContractId,
    required this.initialPrepayment,
    required this.initialBuyerType,
    required this.allowWholesale,
  });

  @override
  State<_PaymentTypeSheet> createState() => _PaymentTypeSheetState();
}

class _PaymentTypeSheetState extends State<_PaymentTypeSheet> {
  int? _prepayment;
  int? _buyerType;
  int? _contractId;

  @override
  void initState() {
    super.initState();
    _prepayment = widget.initialPrepayment;
    _buyerType = widget.initialBuyerType;
    _contractId = widget.selectedContractId;
    _syncBuyerType();
  }

  /// Keeps the buyer type consistent with the chosen prepayment, and picks it
  /// outright when the terms leave only one option — an unavoidable choice is
  /// not a choice, and leaving it unselected blocks "Продолжить" for no reason.
  void _syncBuyerType() {
    if (_effectivePrepayment == null) {
      _buyerType = null;
      return;
    }
    final current = _buyerType;
    if (current != null && _supportsBuyer(current)) return;
    final supported = const [
      0,
      1,
    ].where(_supportsBuyer).toList(growable: false);
    _buyerType = supported.length == 1 ? supported.single : null;
  }

  List<OrderTermOption> get _availableTerms {
    if (widget.allowWholesale == false) {
      return widget.terms.where((term) => !term.wholesaler).toList();
    }
    return widget.terms;
  }

  List<int> get _prepayments {
    final values = _availableTerms
        .map((term) => term.prepaymentPercent)
        .toSet();
    final result = values.toList()..sort((a, b) => b.compareTo(a));
    if (widget.prepaymentEnabled != true && result.length > 1) {
      return const [];
    }
    return result;
  }

  int? get _effectivePrepayment {
    if (widget.prepaymentEnabled != true && _prepayments.length == 1) {
      return _prepayments.single;
    }
    return _prepayment;
  }

  bool _supportsBuyer(int buyerType) {
    final prepayment = _effectivePrepayment;
    if (prepayment == null) return false;
    return _availableTerms.any(
      (term) =>
          term.prepaymentPercent == prepayment &&
          term.supportsBuyer(buyerType == 1),
    );
  }

  OrderTermOption? get _selectedPricingTerms {
    final prepayment = _effectivePrepayment;
    final buyerType = _buyerType;
    if (prepayment == null || buyerType == null) return null;
    final matches = _availableTerms
        .where(
          (term) =>
              term.prepaymentPercent == prepayment &&
              term.supportsBuyer(buyerType == 1),
        )
        .toList(growable: false);
    return matches.length == 1 ? matches.single : null;
  }

  bool get _canContinue => _selectedPricingTerms != null;

  ClientContract? get _selectedContract {
    final id = _contractId;
    if (id == null) return null;
    for (final contract in widget.contracts) {
      if (contract.id == id) return contract;
    }
    return null;
  }

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
          if (widget.prepaymentEnabled == true || _prepayments.length > 1) ...[
            Text(
              context.l10n.t('prepayment'),
              style: GoogleFonts.manrope(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.secondaryText,
              ),
            ),
            const SizedBox(height: 10),
            if (_prepayments.isEmpty)
              _UnavailableText(context.l10n.t('noContracts'))
            else
              Row(
                children: _prepayments.map((pct) {
                  final active = _effectivePrepayment == pct;
                  return Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: GestureDetector(
                      onTap: () => setState(() {
                        _prepayment = pct;
                        _syncBuyerType();
                      }),
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
                            color: active
                                ? AppColors.primary
                                : AppColors.border,
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
          ],
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
                    enabled: _supportsBuyer(0),
                    onTap: () => setState(() => _buyerType = 0),
                  ),
                ),
                Expanded(
                  child: _TypeBtn(
                    context.l10n.t('wholesale'),
                    1,
                    _buyerType,
                    enabled: _supportsBuyer(1),
                    onTap: () => setState(() => _buyerType = 1),
                  ),
                ),
              ],
            ),
          ),
          if (_effectivePrepayment == null || !_supportsBuyer(1)) ...[
            const SizedBox(height: 10),
            Text(
              // Both buyer chips are disabled until a prepayment is picked, so
              // blaming the company for it would point at the wrong cause.
              context.l10n.t(
                _effectivePrepayment == null
                    ? 'selectPrepaymentFirst'
                    : 'wholesaleUnavailable',
              ),
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
          if (widget.contracts.isEmpty)
            Text(
              context.l10n.t('noContracts'),
              style: GoogleFonts.manrope(
                fontSize: 13,
                color: AppColors.hintText,
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _ContractChip(
                  label: context.l10n.t('noContracts'),
                  selected: _contractId == null,
                  onTap: () => setState(() => _contractId = null),
                ),
                ...widget.contracts.map(
                  (contract) => _ContractChip(
                    label: contract.name.isNotEmpty
                        ? contract.name
                        : (contract.number ?? '№ ${contract.id}'),
                    selected: _contractId == contract.id,
                    onTap: () => setState(() => _contractId = contract.id),
                  ),
                ),
              ],
            ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _canContinue
                ? () => Navigator.pop(
                    context,
                    PaymentTermsSelection(
                      prepayment: _effectivePrepayment!,
                      buyerType: _buyerType!,
                      pricingTerms: _selectedPricingTerms,
                      contract: _selectedContract,
                    ),
                  )
                : null,
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
  final int index;
  final int? current;
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

class _UnavailableText extends StatelessWidget {
  final String text;

  const _UnavailableText(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: GoogleFonts.manrope(fontSize: 13, color: AppColors.hintText),
    );
  }
}

class _ContractChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ContractChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.iconBgBlue : AppColors.primaryBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
            width: selected ? 2 : 1,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.manrope(
            fontSize: 13,
            color: selected ? AppColors.primary : AppColors.secondaryText,
          ),
        ),
      ),
    );
  }
}

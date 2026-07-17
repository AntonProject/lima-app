import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lima/core/i18n/app_i18n.dart';
import 'package:lima/features/visits/domain/entities/pharmacy_order.dart';
import 'package:lima/features/visits/providers/pharmacy_order_provider.dart';
import 'package:lima/features/visits/presentation/view_models/pharmacy_order_view_model.dart';
import 'package:lima/core/theme/app_theme.dart';
import 'package:lima/core/widgets/app_widgets.dart';
import 'package:lima/features/auth/providers/auth_provider.dart';
import 'package:lima/core/providers/connectivity_provider.dart';

import '../../../../core/models/models.dart';

part '../../widgets/pharmacy_order_widgets.dart';

class PharmacyOrderScreen extends ConsumerStatefulWidget {
  final int pharmacyId;
  final String pharmacyName;

  const PharmacyOrderScreen({
    super.key,
    required this.pharmacyId,
    this.pharmacyName = '',
  });

  @override
  ConsumerState<PharmacyOrderScreen> createState() =>
      _PharmacyOrderScreenState();
}

class _PharmacyOrderScreenState extends ConsumerState<PharmacyOrderScreen> {
  PharmacyOrderViewModelConfig? _orderConfig;
  bool _paramsApplied = false;
  int _prepayment = 100;
  int _buyerType = 0; // 0 retail, 1 wholesale

  PharmacyOrderViewState get _orderState {
    final config = _orderConfig;
    if (config == null) return const PharmacyOrderViewState();
    return ref.read(pharmacyOrderViewModelProvider(config));
  }

  PharmacyOrderViewModel get _orderViewModel {
    final config = _orderConfig;
    assert(config != null);
    return ref.read(pharmacyOrderViewModelProvider(config!).notifier);
  }

  List<Drug> get _drugs => _orderState.drugs.values.toList(growable: false);

  int get _selectedCount => _orderState.selectedIds.length;
  bool get _hasInvalidSelectedQty => _orderState.hasInvalidQuantities;
  double get _selectedTotal => _orderState.total;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_paramsApplied) return;
    final params = GoRouterState.of(context).uri.queryParameters;
    _prepayment = int.tryParse(params['prepayment'] ?? '') ?? 100;
    _buyerType = int.tryParse(params['buyerType'] ?? '') ?? 0;
    _orderConfig = PharmacyOrderViewModelConfig(
      pharmacyId: widget.pharmacyId,
      organizationName: widget.pharmacyName,
      fromCart: false,
      checkoutCartId: null,
      prepaymentPercent: _prepayment,
      buyerType: _buyerType,
      initialQuantities: const {},
      initialDrugs: const {},
      cartItems: const [],
    );
    _paramsApplied = true;
  }

  Future<void> _openQtyDialog(Drug drug) async {
    final initial = _orderState.quantities[drug.id] ?? 0;
    final result = await showAppSheet<int>(
      context,
      useRootNavigator: true,
      backgroundColor: AppColors.secondaryBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _QtyDialog(
        drug: drug,
        initialQty: initial,
        formatExpiry: _formatExpiryMonthYear,
      ),
    );
    if (result == null || !mounted) return;
    _orderViewModel.setQuantity(drug.id, result);
  }

  Future<void> _continueToBron() async {
    if (_orderState.isConfirming) return;
    _orderViewModel.setConfirming(true);
    try {
      final linesResult = _orderViewModel.buildSelectedLines();
      if (linesResult.lines.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.l10n.t('noDrugsSelected'))),
          );
        }
        return;
      }

      final isOffline = ref.read(isOfflineProvider);
      final isWholesaler = _buyerType == 1;
      PharmacyOrderPricingPreview? pricingPreview;
      if (!isOffline) {
        final user = ref.read(authProvider).user;
        try {
          pricingPreview = await _orderViewModel.calculateSelectedPricing(
            companyId: user?.companyId,
          );
        } catch (_) {
          pricingPreview = null;
        }
        if (pricingPreview == null) {
          if (!mounted) return;
          final buyerLabel = isWholesaler
              ? context.l10n.t('wholesale')
              : context.l10n.t('retail');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                context.l10n.t(
                  'noPriceMatrix',
                  args: {'prepay': '$_prepayment', 'buyer': buyerLabel},
                ),
              ),
            ),
          );
          return;
        }
      }

      final selectedLines = pricingPreview?.lines ?? linesResult.lines;
      final routeLines = selectedLines
          .map((line) {
            final drug = _drugs.firstWhere(
              (item) => item.currentStockId == line.incomeDetailingId,
              orElse: () => _drugs.firstWhere(
                (item) => item.id == line.drugId,
                orElse: () => Drug(
                  id: line.drugId,
                  name: line.drugName,
                  manufacturer: '',
                  price: line.salePrice,
                ),
              ),
            );
            return PharmacyOrderRouteLine(
              id: drug.id,
              name: drug.name,
              manufacturer: drug.manufacturer,
              price: line.salePrice,
              serialNumber: line.serialNumber,
              expiryDate: line.expiryDate,
              mainStock: drug.mainStock,
              stock: drug.stock,
              remainsStock: drug.remainsStock,
              currentStockId: line.incomeDetailingId,
              bindingDrugId: line.drugId,
              quantity: line.quantity,
            );
          })
          .toList(growable: false);
      final pricingTerms = pricingPreview?.terms;

      if (!mounted) return;
      context.push(
        Uri(
          path: '/visits/pharmacy/detail/${widget.pharmacyId}/type/bron',
          queryParameters: {'name': widget.pharmacyName},
        ).toString(),
        extra: PharmacyOrderRouteData(
          lines: routeLines,
          prepaymentPercent: _prepayment,
          buyerType: _buyerType,
          pricingTerms: pricingTerms,
        ),
      );
    } finally {
      _orderViewModel.setConfirming(false);
    }
  }

  String _formatExpiryMonthYear(String? raw) {
    if (raw == null || raw.isEmpty) return '—';
    final dt = DateTime.tryParse(raw);
    if (dt == null) {
      final m = RegExp(r'^(\d{2})\.(\d{4})$').firstMatch(raw.trim());
      if (m != null) return '${m.group(1)}.${m.group(2)}';
      return raw;
    }
    final mm = dt.month.toString().padLeft(2, '0');
    return '$mm.${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final config = _orderConfig;
    if (config == null) {
      return const Scaffold(
        backgroundColor: AppColors.primaryBg,
        body: Center(child: CircularProgressIndicator()),
      );
    }
    final orderState = ref.watch(pharmacyOrderViewModelProvider(config));
    final drugs = orderState.drugs.values.toList(growable: false);
    final filtered = drugs
        .where(
          (d) => d.name.toLowerCase().contains(orderState.query.toLowerCase()),
        )
        .toList();

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
              16,
              MediaQuery.of(context).padding.top + 8,
              16,
              0,
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => context.pop(),
                      child: const Icon(
                        Icons.arrow_back_rounded,
                        color: AppColors.primaryText,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.l10n.t('bronCheckout'),
                            style: GoogleFonts.manrope(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primaryText,
                            ),
                          ),
                          if (widget.pharmacyName.isNotEmpty)
                            Text(
                              widget.pharmacyName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.manrope(
                                fontSize: 12,
                                color: AppColors.secondaryText,
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 40),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  onChanged: _orderViewModel.setQuery,
                  decoration: InputDecoration(
                    hintText: context.l10n.t('searchDrugs'),
                    prefixIcon: Icon(
                      Icons.search_rounded,
                      color: AppColors.hintText,
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
          Expanded(
            child: orderState.isLoading
                ? const Center(child: CircularProgressIndicator())
                : filtered.isEmpty
                ? EmptyState(
                    icon: Icons.search_off_rounded,
                    title: context.l10n.t('nothingFound'),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                    itemCount: filtered.length,
                    itemBuilder: (_, i) {
                      final drug = filtered[i];
                      final qty = orderState.quantities[drug.id] ?? 0;
                      return _DrugCard(
                        drug: drug,
                        selectedQty: qty,
                        isOverStock: orderState.isOverStock(drug.id),
                        onTap: () => _openQtyDialog(drug),
                      );
                    },
                  ),
          ),
        ],
      ),
      bottomNavigationBar: _selectedCount == 0
          ? null
          : Container(
              decoration: BoxDecoration(
                color: AppColors.secondaryBg,
                boxShadow: shadowMd,
              ),
              padding: EdgeInsets.fromLTRB(
                16,
                10,
                16,
                MediaQuery.of(context).padding.bottom + 10,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.l10n.t('totalColon'),
                          style: GoogleFonts.manrope(
                            fontSize: 12,
                            color: AppColors.secondaryText,
                          ),
                        ),
                        Text(
                          formatUzs(_selectedTotal),
                          style: GoogleFonts.manrope(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primaryText,
                          ),
                        ),
                        Text(
                          '$_prepayment% · ${_buyerType == 1 ? context.l10n.t('wholesale') : context.l10n.t('retail')}',
                          style: GoogleFonts.manrope(
                            fontSize: 12,
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed:
                          _hasInvalidSelectedQty || orderState.isConfirming
                          ? null
                          : _continueToBron,
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 52),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (orderState.isConfirming) ...[
                            const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                          Text(
                            orderState.isConfirming
                                ? context.l10n.t('preparingOrder')
                                : context.l10n.t('placeBron'),
                            style: GoogleFonts.manrope(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (!orderState.isConfirming) ...[
                            const SizedBox(width: 8),
                            const Icon(Icons.arrow_forward_rounded, size: 18),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

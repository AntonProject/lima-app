import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lima/core/i18n/app_i18n.dart';
import 'package:lima/core/db/local_database.dart';
import 'package:lima/core/network/remote_api_service.dart';
import 'package:lima/core/theme/app_theme.dart';
import 'package:lima/core/widgets/app_widgets.dart';
import 'package:lima/features/auth/providers/auth_provider.dart';
import 'package:lima/core/providers/connectivity_provider.dart';

import '../../../../core/models/models.dart';

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
  List<Drug> _drugs = [];
  final Map<int, int> _selectedQtyByDrugId = {};
  bool _loading = true;
  bool _paramsApplied = false;
  String _query = '';
  int _prepayment = 100;
  int _buyerType = 0; // 0 retail, 1 wholesale
  bool _confirming = false;

  List<Drug> get _filtered => _drugs
      .where((d) => d.name.toLowerCase().contains(_query.toLowerCase()))
      .toList();

  int get _selectedCount =>
      _selectedQtyByDrugId.values.where((q) => q > 0).length;
  bool get _hasInvalidSelectedQty => _selectedQtyByDrugId.entries.any((e) {
    final drug = _drugs.cast<Drug?>().firstWhere(
      (d) => d?.id == e.key,
      orElse: () => null,
    );
    return drug != null && _isOverStock(drug, e.value);
  });

  double get _selectedTotal {
    var total = 0.0;
    for (final d in _drugs) {
      final q = _selectedQtyByDrugId[d.id] ?? 0;
      if (q > 0) total += d.price * q;
    }
    return total;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadDrugs());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_paramsApplied) return;
    final params = GoRouterState.of(context).uri.queryParameters;
    _prepayment = int.tryParse(params['prepayment'] ?? '') ?? 100;
    _buyerType = int.tryParse(params['buyerType'] ?? '') ?? 0;
    _paramsApplied = true;
  }

  Future<void> _loadDrugs() async {
    final db = ref.read(localDatabaseProvider);
    final rows = await db.getDrugs();
    final loaded = rows
        .map(Drug.fromJson)
        // For pharmacy order flow backend needs stock-level identity.
        // Without it visits can be created with order_status=0 and empty drugs.
        .where((d) => d.currentStockId != null && d.bindingDrugId != null)
        .toList();

    if (!mounted) return;
    setState(() {
      _drugs = loaded;
      _loading = false;
    });
  }

  Future<void> _openQtyDialog(Drug drug) async {
    final initial = _selectedQtyByDrugId[drug.id] ?? 0;
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
    setState(() => _selectedQtyByDrugId[drug.id] = result);
  }

  Future<void> _continueToBron() async {
    if (_confirming) return;
    setState(() => _confirming = true);
    try {
      final selected = _selectedQtyByDrugId.entries
          .where((e) => e.value > 0)
          .map((e) => '${e.key}:${e.value}')
          .join(';');
      final selectedDetails = _selectedQtyByDrugId.entries
          .where((e) => e.value > 0)
          .map((e) {
            final drug = _drugs.firstWhere(
              (d) => d.id == e.key,
              orElse: () => Drug(
                id: e.key,
                name: context.l10n.t('drugHash', args: {'id': '${e.key}'}),
                manufacturer: '',
                price: 0,
              ),
            );
            return <String, dynamic>{
              'id': drug.id,
              'name': drug.name,
              'manufacturer': drug.manufacturer,
              'price': drug.price,
              'serial_number': drug.serialNumber,
              'expiry_date': drug.expiryDate,
              'main_stock': drug.mainStock,
              'stock': drug.stock,
              'remains_stock': drug.remainsStock,
              'current_stock_id': drug.currentStockId,
              'binding_drug_id': drug.bindingDrugId,
              'package': e.value,
              'quantity': e.value,
              'sale_price': drug.price,
              'sale_price_without_nds': _priceWithoutNds(drug.price),
            };
          })
          .toList();

      final isOffline = ref.read(isOfflineProvider);
      final isWholesaler = _buyerType == 1;
      Map<String, dynamic>? pricingDraft;
      if (!isOffline) {
        final user = ref.read(authProvider).user;
        final orderDrugs = selectedDetails
            .map(
              (item) => <String, dynamic>{
                'income_detailing_id': item['current_stock_id'],
                'drug_id': item['binding_drug_id'] ?? item['id'],
                'package': item['quantity'] ?? item['package'],
                'sale_price': item['price'],
              },
            )
            .toList();
        try {
          pricingDraft = await ref
              .read(remoteApiServiceProvider)
              .prepareOrderVisitDraft(
                prepaymentPercent: _prepayment,
                isWholesaler: isWholesaler,
                companyId: user?.companyId,
                orderTotal: _selectedTotal,
                drugs: orderDrugs,
              );
        } catch (_) {
          pricingDraft = null;
        }
        if (pricingDraft == null) {
          if (!mounted) return;
          final buyerLabel = isWholesaler ? context.l10n.t('wholesale') : context.l10n.t('retail');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                context.l10n.t('noPriceMatrix', args: {'prepay': '$_prepayment', 'buyer': buyerLabel}),
              ),
            ),
          );
          return;
        }
        final pricedRows =
            (pricingDraft['drugs'] as List?)
                ?.whereType<Map>()
                .map((e) => Map<String, dynamic>.from(e))
                .toList() ??
            const <Map<String, dynamic>>[];
        final byIncomeDetailingId = <int, Map<String, dynamic>>{};
        for (final row in pricedRows) {
          final incomeDetailingId =
              (row['income_detailing_id'] as num?)?.toInt() ??
              (row['current_stock_id'] as num?)?.toInt();
          if (incomeDetailingId != null) {
            byIncomeDetailingId[incomeDetailingId] = row;
          }
        }
        for (final item in selectedDetails) {
          final currentStockId = (item['current_stock_id'] as num?)?.toInt();
          if (currentStockId == null) continue;
          final priced = byIncomeDetailingId[currentStockId];
          if (priced == null) continue;
          item['price'] =
              ((priced['sale_price'] as num?) ?? item['price'] ?? 0).toDouble();
          item['sale_price'] = item['price'];
          item['sale_price_without_nds'] =
              ((priced['sale_price_without_nds'] as num?) ??
                      item['sale_price_without_nds'] ??
                      0)
                  .toDouble();
          if (priced['margin_percent'] != null) {
            item['margin_percent'] = priced['margin_percent'];
          }
        }
      }

      if (!mounted) return;
      context.push(
        Uri(
          path: '/visits/pharmacy/detail/${widget.pharmacyId}/type/bron',
          queryParameters: {
            'name': widget.pharmacyName,
            'items': selected,
            'items_data': jsonEncode(selectedDetails),
            'prepayment': '$_prepayment',
            'buyerType': '$_buyerType',
            if (pricingDraft?['company_id'] != null)
              'companyId': '${pricingDraft!['company_id']}',
            if (pricingDraft?['payment_variant_id'] != null)
              'paymentVariantId': '${pricingDraft!['payment_variant_id']}',
            if (pricingDraft?['margin_id'] != null)
              'marginId': '${pricingDraft!['margin_id']}',
            if (pricingDraft?['margin_percent'] != null)
              'marginPercent': '${pricingDraft!['margin_percent']}',
          },
        ).toString(),
      );
    } finally {
      if (mounted) {
        setState(() => _confirming = false);
      }
    }
  }

  int _availableStock(Drug drug) => drug.remainsStock ?? drug.stock ?? 0;

  bool _isOverStock(Drug drug, int qty) => qty > _availableStock(drug);

  double _priceWithoutNds(double value) {
    return double.parse((value / 1.12).toStringAsFixed(2));
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
                  onChanged: (v) => setState(() => _query = v),
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
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _filtered.isEmpty
                ? EmptyState(
                    icon: Icons.search_off_rounded,
                    title: context.l10n.t('nothingFound'),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                    itemCount: _filtered.length,
                    itemBuilder: (_, i) {
                      final drug = _filtered[i];
                      final qty = _selectedQtyByDrugId[drug.id] ?? 0;
                      return _DrugCard(
                        drug: drug,
                        selectedQty: qty,
                        isOverStock: _isOverStock(drug, qty),
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
                          _hasInvalidSelectedQty || _confirming
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
                          if (_confirming) ...[
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
                            _confirming
                                ? context.l10n.t('preparingOrder')
                                : context.l10n.t('placeBron'),
                            style: GoogleFonts.manrope(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (!_confirming) ...[
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

class _DrugCard extends StatelessWidget {
  final Drug drug;
  final int selectedQty;
  final bool isOverStock;
  final VoidCallback onTap;

  const _DrugCard({
    required this.drug,
    required this.selectedQty,
    required this.isOverStock,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: selectedQty > 0
                ? const Color(0xFFF2F6FF)
                : AppColors.secondaryBg,
            borderRadius: BorderRadius.circular(14),
            boxShadow: shadowSm,
            border: Border.all(
              color: isOverStock
                  ? AppColors.error
                  : selectedQty > 0
                  ? AppColors.primary
                  : Colors.transparent,
              width: selectedQty > 0 ? 1.5 : 0,
            ),
          ),
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    margin: const EdgeInsets.only(top: 2),
                    decoration: BoxDecoration(
                      color: AppColors.iconBgBlue,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.medication_rounded,
                      color: AppColors.primary,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          drug.name,
                          style: GoogleFonts.manrope(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primaryText,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          context.l10n.t('manufacturerColon', args: {'value': drug.manufacturer.isNotEmpty ? drug.manufacturer : '—'}),
                          style: GoogleFonts.manrope(
                            fontSize: 12,
                            color: AppColors.secondaryText,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          context.l10n.t('serialColon', args: {'value': drug.serialNumber?.isNotEmpty == true ? drug.serialNumber! : '—'}),
                          style: GoogleFonts.manrope(
                            fontSize: 12,
                            color: AppColors.secondaryText,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          context.l10n.t('expiryColon', args: {'value': drug.expiryDate?.isNotEmpty == true ? drug.expiryDate! : '—'}),
                          style: GoogleFonts.manrope(
                            fontSize: 12,
                            color: AppColors.secondaryText,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          context.l10n.t('mainStockColon', args: {'value': '${drug.mainStock ?? drug.stock ?? 0}'}),
                          style: GoogleFonts.manrope(
                            fontSize: 12,
                            color: AppColors.secondaryText,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          context.l10n.t('remainsColon', args: {'value': '${drug.remainsStock ?? drug.stock ?? 0}'}),
                          style: GoogleFonts.manrope(
                            fontSize: 12,
                            color: AppColors.secondaryText,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (selectedQty > 0)
                    Container(
                      margin: const EdgeInsets.only(left: 8, top: 2),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: isOverStock
                            ? AppColors.error
                            : AppColors.primary,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '$selectedQty',
                        style: GoogleFonts.manrope(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              const Divider(height: 1, color: AppColors.divider),
              const SizedBox(height: 8),
              Text(
                formatUzs(drug.price),
                style: GoogleFonts.manrope(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QtyBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final Color? iconColor;

  const _QtyBtn({required this.icon, this.onTap, this.iconColor});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 54,
        height: 52,
        decoration: BoxDecoration(
          color: AppColors.primaryBg,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          icon,
          size: 30,
          color: onTap == null
              ? AppColors.hintText
              : (iconColor ?? AppColors.primaryText),
        ),
      ),
    );
  }
}

Widget _qtyDialogLine(
  String label,
  String value, {
  int labelFlex = 1,
  int valueFlex = 1,
  int maxLines = 2,
  bool showDivider = false,
  Color? valueColor,
  FontWeight valueWeight = FontWeight.w600,
}) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: labelFlex,
              child: Text(
                '$label:',
                style: GoogleFonts.manrope(
                  fontSize: 13,
                  color: AppColors.secondaryText,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: valueFlex,
              child: Text(
                value,
                textAlign: TextAlign.right,
                style: GoogleFonts.manrope(
                  fontSize: 13,
                  fontWeight: valueWeight,
                  color: valueColor ?? AppColors.primaryText,
                ),
                maxLines: maxLines,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        if (showDivider) ...[
          const SizedBox(height: 6),
          const Divider(height: 1, color: AppColors.divider),
        ],
      ],
    ),
  );
}

/// Quantity-selection sheet content for the Бронь flow. Its own
/// [StatefulWidget] so [TextEditingController] follows the normal
/// State.dispose() lifecycle instead of being manually disposed right after
/// the enclosing bottom sheet's Navigator.pop() — the sheet's close
/// animation can still hold the field mounted for a few frames after pop()
/// resolves, and disposing the controller mid-animation crashed the app.
class _QtyDialog extends StatefulWidget {
  final Drug drug;
  final int initialQty;
  final String Function(String?) formatExpiry;

  const _QtyDialog({
    required this.drug,
    required this.initialQty,
    required this.formatExpiry,
  });

  @override
  State<_QtyDialog> createState() => _QtyDialogState();
}

class _QtyDialogState extends State<_QtyDialog> {
  late final TextEditingController _qtyCtrl;
  late int _qty;

  int get _available => widget.drug.remainsStock ?? widget.drug.stock ?? 0;

  @override
  void initState() {
    super.initState();
    _qty = widget.initialQty > 0 ? widget.initialQty : 0;
    _qtyCtrl = TextEditingController(text: '$_qty');
  }

  @override
  void dispose() {
    _qtyCtrl.dispose();
    super.dispose();
  }

  void _setQty(int next) {
    setState(() {
      _qty = next < 0 ? 0 : next;
      _qtyCtrl.text = '$_qty';
    });
  }

  @override
  Widget build(BuildContext context) {
    final drug = widget.drug;
    final mainStock = drug.mainStock ?? drug.stock ?? 0;
    final available = _available;
    final isOverStock = _qty > available;
    final canIncrease = _qty < available;
    final counterColor = isOverStock
        ? AppColors.error
        : const Color(0xFFE49351);

    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom +
              MediaQuery.of(context).padding.bottom +
              12,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      context.l10n.t('selectQuantity'),
                      style: GoogleFonts.manrope(
                        fontSize: 18,
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
                        size: 20,
                        color: AppColors.secondaryText,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.divider),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
              child: Column(
                children: [
                  _qtyDialogLine(
                    context.l10n.t('drug'),
                    drug.name,
                    valueFlex: 2,
                    maxLines: 3,
                    showDivider: true,
                  ),
                  _qtyDialogLine(
                    context.l10n.t('manufacturer'),
                    drug.manufacturer.isNotEmpty ? drug.manufacturer : '—',
                    showDivider: true,
                  ),
                  _qtyDialogLine(
                    context.l10n.t('expiryDate'),
                    widget.formatExpiry(drug.expiryDate),
                    showDivider: true,
                  ),
                  _qtyDialogLine(
                    context.l10n.t('serialNumber'),
                    drug.serialNumber?.isNotEmpty == true
                        ? drug.serialNumber!
                        : '—',
                    showDivider: true,
                  ),
                  _qtyDialogLine(
                    context.l10n.t('mainStock'),
                    context.l10n.t('pcsN', args: {'n': '$mainStock'}),
                    showDivider: true,
                  ),
                  _qtyDialogLine(
                    context.l10n.t('remains'),
                    context.l10n.t('pcsN', args: {'n': '$available'}),
                    showDivider: true,
                  ),
                  _qtyDialogLine(
                    context.l10n.t('price'),
                    formatUzs(drug.price),
                    valueColor: AppColors.primary,
                    valueWeight: FontWeight.w700,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  _QtyBtn(
                    icon: Icons.remove_rounded,
                    iconColor: const Color(0xFFE49351),
                    onTap: () => _setQty(_qty > 1 ? _qty - 1 : 0),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Container(
                      height: 52,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: counterColor, width: 2),
                      ),
                      child: Center(
                        child: TextField(
                          controller: _qtyCtrl,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(5),
                          ],
                          textAlign: TextAlign.center,
                          style: GoogleFonts.manrope(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: counterColor,
                          ),
                          decoration: const InputDecoration(
                            isCollapsed: true,
                            filled: false,
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                          ),
                          // Select-all on tap so typing replaces the "0"
                          // instead of appending to it ("0" → "36", not
                          // "036").
                          onTap: () {
                            _qtyCtrl.selection = TextSelection(
                              baseOffset: 0,
                              extentOffset: _qtyCtrl.text.length,
                            );
                          },
                          onChanged: (v) => setState(() {
                            _qty = v.isEmpty ? 0 : (int.tryParse(v) ?? 0);
                          }),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  _QtyBtn(
                    icon: Icons.add_rounded,
                    iconColor: const Color(0xFF2AA65A),
                    onTap: canIncrease ? () => _setQty(_qty + 1) : null,
                  ),
                ],
              ),
            ),
            if (isOverStock) ...[
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  context.l10n.t('availableN', args: {'n': '$available'}),
                  textAlign: TextAlign.center,
                  style: GoogleFonts.manrope(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.error,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                height: 58,
                decoration: BoxDecoration(
                  color: const Color(0xFFE77834),
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Row(
                  children: [
                    Text(
                      context.l10n.t('totalColon'),
                      style: GoogleFonts.manrope(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      formatUzs(drug.price * _qty),
                      style: GoogleFonts.manrope(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Divider(height: 1, color: AppColors.divider),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ElevatedButton(
                onPressed: _qty <= 0 || isOverStock
                    ? null
                    : () => Navigator.pop(context, _qty),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  context.l10n.t('confirm'),
                  style: GoogleFonts.manrope(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
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

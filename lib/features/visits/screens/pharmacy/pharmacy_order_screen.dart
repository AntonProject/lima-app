import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lima/core/db/local_database.dart';
import 'package:lima/core/theme/app_theme.dart';
import 'package:lima/core/widgets/app_widgets.dart';

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
  ConsumerState<PharmacyOrderScreen> createState() => _PharmacyOrderScreenState();
}

class _PharmacyOrderScreenState extends ConsumerState<PharmacyOrderScreen> {
  List<Drug> _drugs = [];
  final Map<int, int> _mainStockByDrugId = {};
  final Map<int, int> _selectedQtyByDrugId = {};
  bool _loading = true;
  bool _paramsApplied = false;
  String _query = '';
  int _prepayment = 100;
  int _buyerType = 0; // 0 retail, 1 wholesale

  List<Drug> get _filtered => _drugs
      .where((d) => d.name.toLowerCase().contains(_query.toLowerCase()))
      .toList();

  int get _selectedCount => _selectedQtyByDrugId.values.where((q) => q > 0).length;

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
    // Populate _mainStockByDrugId from local DB
    final rows = await db.getDrugs();
    for (final row in rows) {
      final id = (row['id'] as num?)?.toInt();
      final stock = (row['stock'] as num?)?.toInt();
      if (id != null && stock != null) _mainStockByDrugId[id] = stock;
    }
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
    var qtyStr = initial > 0 ? initial.toString() : '0';
    final mainStock = _mainStockByDrugId[drug.id] ?? (drug.stock ?? 0);
    final remains = drug.stock ?? 0;
    final result = await showModalBottomSheet<int>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: AppColors.secondaryBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (_, setModal) {
          final qty = int.tryParse(qtyStr) ?? 0;
          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).padding.bottom + 12),
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
                          'Выберите количество',
                          style: GoogleFonts.manrope(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primaryText,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.pop(ctx),
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: AppColors.primaryBg,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.close_rounded, size: 20, color: AppColors.secondaryText),
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
                      _line(
                        'Препарат',
                        drug.name,
                        valueFlex: 2,
                        maxLines: 3,
                        showDivider: true,
                      ),
                      _line(
                        'Производитель',
                        drug.manufacturer.isNotEmpty ? drug.manufacturer : '—',
                        showDivider: true,
                      ),
                      _line(
                        'Срок годности',
                        _formatExpiryMonthYear(drug.expiryDate),
                        showDivider: true,
                      ),
                      _line(
                        'Серийный номер',
                        drug.serialNumber?.isNotEmpty == true ? drug.serialNumber! : '—',
                        showDivider: true,
                      ),
                      _line('На основном складе', '$mainStock шт.', showDivider: true),
                      _line('Остаток', '$remains шт.', showDivider: true),
                      _line(
                        'Цена',
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
                        onTap: () => setModal(() {
                          final cur = int.tryParse(qtyStr) ?? 0;
                          qtyStr = (cur > 1 ? cur - 1 : 0).toString();
                        }),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Container(
                          height: 52,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFE49351), width: 2),
                          ),
                          child: Center(
                            child: Text(
                              qtyStr,
                              style: GoogleFonts.manrope(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFFE49351),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      _QtyBtn(
                        icon: Icons.add_rounded,
                        iconColor: const Color(0xFF2AA65A),
                        onTap: () => setModal(() {
                          final cur = int.tryParse(qtyStr) ?? 0;
                          qtyStr = (cur + 1).toString();
                        }),
                      ),
                    ],
                  ),
                ),
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
                          'Итого:',
                          style: GoogleFonts.manrope(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          formatUzs(drug.price * qty),
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
                    onPressed: qty <= 0 ? null : () => Navigator.pop(ctx, qty),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 52),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: Text(
                      'Подтвердить',
                      style: GoogleFonts.manrope(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
    if (result == null || !mounted) return;
    setState(() => _selectedQtyByDrugId[drug.id] = result);
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

  Widget _line(
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
                  style: GoogleFonts.manrope(fontSize: 13, color: AppColors.secondaryText),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryBg,
      body: Column(
        children: [
          Container(
            decoration: BoxDecoration(color: AppColors.secondaryBg, boxShadow: shadowSm),
            padding: EdgeInsets.fromLTRB(16, MediaQuery.of(context).padding.top + 8, 16, 0),
            child: Column(
              children: [
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => context.pop(),
                      child: const Icon(Icons.arrow_back_rounded, color: AppColors.primaryText, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Оформление брони',
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
                              style: GoogleFonts.manrope(fontSize: 12, color: AppColors.secondaryText),
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
                  decoration: const InputDecoration(
                    hintText: 'Поиск препаратов...',
                    prefixIcon: Icon(Icons.search_rounded, color: AppColors.hintText, size: 20),
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
                    ? const EmptyState(icon: Icons.search_off_rounded, title: 'Ничего не найдено')
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                        itemCount: _filtered.length,
                        itemBuilder: (_, i) {
                          final drug = _filtered[i];
                          final qty = _selectedQtyByDrugId[drug.id] ?? 0;
                          return _DrugCard(
                            drug: drug,
                            selectedQty: qty,
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
              decoration: BoxDecoration(color: AppColors.secondaryBg, boxShadow: shadowMd),
              padding: EdgeInsets.fromLTRB(16, 10, 16, MediaQuery.of(context).padding.bottom + 10),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Итого:',
                          style: GoogleFonts.manrope(fontSize: 12, color: AppColors.secondaryText),
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
                          '$_prepayment% · ${_buyerType == 1 ? 'Опт' : 'Розница'}',
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
                      onPressed: () {
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
                                  name: 'Препарат #${e.key}',
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
                                'stock': drug.stock,
                                'current_stock_id': drug.currentStockId,
                                'binding_drug_id': drug.bindingDrugId,
                              };
                            })
                            .toList();
                        context.push(
                          Uri(
                            path: '/visits/pharmacy/detail/${widget.pharmacyId}/type/bron',
                            queryParameters: {
                              'name': widget.pharmacyName,
                              'items': selected,
                              'items_data': jsonEncode(selectedDetails),
                              'prepayment': '$_prepayment',
                              'buyerType': '$_buyerType',
                            },
                          ).toString(),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 52),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Оформить бронь',
                            style: GoogleFonts.manrope(fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.arrow_forward_rounded, size: 18),
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
  final VoidCallback onTap;

  const _DrugCard({
    required this.drug,
    required this.selectedQty,
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
            color: selectedQty > 0 ? const Color(0xFFF2F6FF) : AppColors.secondaryBg,
            borderRadius: BorderRadius.circular(14),
            boxShadow: shadowSm,
            border: Border.all(
              color: selectedQty > 0 ? AppColors.primary : Colors.transparent,
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
                    child: const Icon(Icons.medication_rounded, color: AppColors.primary, size: 18),
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
                          'Производитель: ${drug.manufacturer.isNotEmpty ? drug.manufacturer : '—'}',
                          style: GoogleFonts.manrope(fontSize: 12, color: AppColors.secondaryText),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Серийный номер: ${drug.serialNumber?.isNotEmpty == true ? drug.serialNumber : '—'}',
                          style: GoogleFonts.manrope(fontSize: 12, color: AppColors.secondaryText),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Срок годности: ${drug.expiryDate?.isNotEmpty == true ? drug.expiryDate : '—'}',
                          style: GoogleFonts.manrope(fontSize: 12, color: AppColors.secondaryText),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'На основном складе: ${drug.stock ?? 0} шт.',
                          style: GoogleFonts.manrope(fontSize: 12, color: AppColors.secondaryText),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Остаток: ${drug.stock ?? 0} шт.',
                          style: GoogleFonts.manrope(fontSize: 12, color: AppColors.secondaryText),
                        ),
                      ],
                    ),
                  ),
                  if (selectedQty > 0)
                    Container(
                      margin: const EdgeInsets.only(left: 8, top: 2),
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
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

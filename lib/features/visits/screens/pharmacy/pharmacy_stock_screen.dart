import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:convert';
import 'package:lima/core/i18n/app_i18n.dart';
import 'package:lima/core/db/local_database.dart';
import 'package:lima/core/models/local_visit.dart';
import 'package:lima/core/network/remote_api_service.dart';
import 'package:lima/core/providers/connectivity_provider.dart';
import 'package:lima/core/providers/dashboard_counts_provider.dart';
import 'package:lima/core/theme/app_theme.dart';
import 'package:lima/core/widgets/app_widgets.dart';
import 'package:lima/features/auth/providers/auth_provider.dart';

import '../../../../core/models/models.dart';

class PharmacyStockScreen extends ConsumerStatefulWidget {
  final int pharmacyId;
  final String pharmacyName;

  const PharmacyStockScreen({
    super.key,
    required this.pharmacyId,
    this.pharmacyName = '',
  });

  @override
  ConsumerState<PharmacyStockScreen> createState() =>
      _PharmacyStockScreenState();
}

class _PharmacyStockScreenState extends ConsumerState<PharmacyStockScreen> {
  final Map<int, int> _qtyByDrugId = {};
  List<Drug> _drugs = [];
  bool _loading = true;
  String _query = '';
  bool _actionLocked = false;
  int get _selectedCount => _qtyByDrugId.values.fold<int>(0, (a, b) => a + b);
  bool get _hasInvalidSelectedQty => _qtyByDrugId.entries.any((e) {
    final drug = _drugs.cast<Drug?>().firstWhere(
      (d) => d?.id == e.key,
      orElse: () => null,
    );
    return drug != null && _isOverStock(drug, e.value);
  });

  List<Drug> get _filtered => _drugs
      .where((d) => d.name.toLowerCase().contains(_query.toLowerCase()))
      .toList();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadDrugs());
  }

  Future<void> _loadDrugs() async {
    final db = ref.read(localDatabaseProvider);
    final rows = await db.getDrugs();
    final loaded = rows.map(Drug.fromJson).toList();
    if (!mounted) return;
    setState(() {
      _drugs = loaded;
      _loading = false;
    });
  }

  Future<void> _openQtyDialog(Drug drug) async {
    final initial = _qtyByDrugId[drug.id] ?? 0;
    final available = _availableStock(drug);
    final result = await showAppSheet<int>(
      context,
      useRootNavigator: true,
      backgroundColor: AppColors.secondaryBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _StockQtyDialog(
        drug: drug,
        initialQty: initial,
        available: available,
      ),
    );
    if (result == null || !mounted) return;
    setState(() => _qtyByDrugId[drug.id] = result);
  }

  int _availableStock(Drug drug) => drug.remainsStock ?? drug.stock ?? 0;

  bool _isOverStock(Drug drug, int qty) => qty > _availableStock(drug);

  Future<void> _openConfirmScreen() async {
    if (_actionLocked) return;
    final selected = <int, Drug>{
      for (final e in _qtyByDrugId.entries)
        if (e.value > 0 && _drugs.any((d) => d.id == e.key))
          e.key: _drugs.firstWhere((d) => d.id == e.key),
    };
    if (selected.isEmpty || _hasInvalidSelectedQty) return;
    final result = await Navigator.of(context).push<_StockSubmitPayload>(
      MaterialPageRoute(
        builder: (_) => _StockConfirmScreen(
          pharmacyName: widget.pharmacyName,
          qtyByDrugId: Map<int, int>.from(_qtyByDrugId),
          drugsById: selected,
        ),
      ),
    );
    if (result == null || !mounted) return;
    setState(
      () => _qtyByDrugId
        ..clear()
        ..addAll(result.qtyByDrugId),
    );
    await _submitStock(result);
  }

  Future<void> _submitStock(_StockSubmitPayload payload) async {
    if (_actionLocked) return;
    final hasInvalidQty = payload.qtyByDrugId.entries.any((e) {
      final drug = payload.drugsById[e.key];
      return drug != null && _isOverStock(drug, e.value);
    });
    if (hasInvalidQty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.t('qtyExceedsStock'))),
        );
      }
      return;
    }
    setState(() => _actionLocked = true);
    final now = DateTime.now().toIso8601String();
    final stockItemsPayload = payload.qtyByDrugId.entries
        .where((e) => e.value > 0 && payload.drugsById.containsKey(e.key))
        .map((e) {
          final d = payload.drugsById[e.key]!;
          return <String, dynamic>{
            'drug_id': d.id,
            'drug_name': d.name,
            'manufacturer': d.manufacturer,
            'serial_number': d.serialNumber ?? '',
            'expiry_date': d.expiryDate ?? '',
            'quantity': e.value,
            'stock': d.stock ?? 0,
          };
        })
        .toList();
    final drugsPayload = payload.qtyByDrugId.entries
        .where((e) => e.value > 0 && payload.drugsById.containsKey(e.key))
        .map((e) {
          final d = payload.drugsById[e.key]!;
          return <String, dynamic>{
            'income_detailing_id': d.currentStockId,
            'drug_id': d.bindingDrugId ?? d.id,
            'package': e.value,
            'sale_price': d.price,
            'sale_price_without_nds': _priceWithoutNds(d.price),
            'serial_no': d.serialNumber,
            'expire_date': d.expiryDate,
          };
        })
        .toList();
    int? localId;
    try {
      final rawVisitJson = jsonEncode({
        'organization_id': widget.pharmacyId,
        'organization_name': widget.pharmacyName,
        'visit_type': 4,
        'status': 'completed',
        'comment': payload.comment.trim(),
        'stock_items': stockItemsPayload,
        // Swagger VisitRequest uses DrugRequest[] for stock/remnant visits.
        'drugs': drugsPayload,
        'start_date': now,
        'end_date': now,
      });
      localId = await ref.read(localDatabaseProvider).insertVisit({
        'remote_id': null,
        'org_id': widget.pharmacyId,
        'org_name': widget.pharmacyName,
        'doctor_id': null,
        'doctor_name': null,
        'visit_type': 'stock',
        'status': 'completed',
        'notes': payload.comment.trim(),
        'medical_rep_name': ref.read(authProvider).user?.fullName,
        'created_at': now,
        'updated_at': now,
        'raw_json': rawVisitJson,
      });
      ref.invalidate(dashboardCountsProvider);
      final isOffline = ref.read(isOfflineProvider);
      if (!isOffline) {
        try {
          final createdAt = DateTime.tryParse(now) ?? DateTime.now();
          final pushResult = await ref
              .read(remoteApiServiceProvider)
              .pushUnsyncedVisitDebug(
                LocalVisit(
                  id: localId,
                  remoteId: null,
                  orgId: widget.pharmacyId,
                  orgName: widget.pharmacyName,
                  visitType: 'stock',
                  status: 'completed',
                  notes: payload.comment.trim(),
                  createdAt: createdAt,
                  updatedAt: createdAt,
                  isSynced: false,
                  rawJson: rawVisitJson,
                ),
              );
          await ref.read(localDatabaseProvider).markSynced([localId]);
          final responseObj = pushResult['response'];
          final remoteId = switch (responseObj) {
            int v => v,
            String s => int.tryParse(s),
            Map<String, dynamic> m =>
              (m['id'] as num?)?.toInt() ??
                  (m['visit_id'] as num?)?.toInt() ??
                  (m['data'] is Map<String, dynamic>
                      ? ((m['data']['id'] as num?)?.toInt() ??
                            (m['data']['visit_id'] as num?)?.toInt())
                      : null),
            _ => null,
          };
          if (remoteId != null) {
            await ref
                .read(localDatabaseProvider)
                .updateVisitRemoteId(localVisitId: localId, remoteId: remoteId);
            try {
              final remoteRow = await ref
                  .read(remoteApiServiceProvider)
                  .getVisitHistoryRemnantById(remoteId);
              if (remoteRow != null) {
                final serverRaw = remoteRow['raw_json'];
                var mergedRaw = <String, dynamic>{};
                if (serverRaw is String && serverRaw.isNotEmpty) {
                  final decoded = jsonDecode(serverRaw);
                  if (decoded is Map) {
                    mergedRaw = Map<String, dynamic>.from(decoded);
                  }
                } else {
                  mergedRaw = Map<String, dynamic>.from(remoteRow);
                }
                mergedRaw.putIfAbsent('stock_items', () => stockItemsPayload);
                final serverDrugs = mergedRaw['drugs'];
                if ((serverDrugs is! List || serverDrugs.isEmpty) &&
                    drugsPayload.isNotEmpty) {
                  mergedRaw['drugs'] = drugsPayload;
                }
                await ref
                    .read(localDatabaseProvider)
                    .updateVisitRawJson(
                      localVisitId: localId,
                      rawJson: jsonEncode(mergedRaw),
                    );
              }
            } catch (_) {}
          }
          await ref
              .read(localDatabaseProvider)
              .setVisitPushPayload(
                visitId: localId,
                requestJson: jsonEncode(pushResult['request']),
                responseJson: jsonEncode(pushResult['response']),
              );
        } catch (e) {
          await ref
              .read(localDatabaseProvider)
              .setVisitPushPayload(
                visitId: localId,
                responseJson: jsonEncode({'error': '$e'}),
              );
        }
      }
    } catch (_) {}
    if (ref.read(isOfflineProvider)) {
      pulseOfflineBanner(ref);
    }
    if (!mounted) return;
    await _showSuccessDialog();
  }

  double _priceWithoutNds(double value) {
    return double.parse((value / 1.12).toStringAsFixed(2));
  }

  Future<void> _showSuccessDialog() async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PopScope(
        canPop: false,
        child: Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 20),
          child: Container(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 76,
                  height: 76,
                  decoration: const BoxDecoration(
                    color: Color(0xFFE5F8EE),
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.check_rounded,
                      color: AppColors.success,
                      size: 48,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  context.l10n.t('stockRemoved'),
                  textAlign: TextAlign.center,
                  style: GoogleFonts.manrope(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryText,
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    context.pushReplacement(
                      Uri(
                        path: '/visits/pharmacy/detail/${widget.pharmacyId}',
                        queryParameters: {'name': widget.pharmacyName},
                      ).toString(),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    context.l10n.t('goToCompany'),
                    style: GoogleFonts.manrope(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                OutlinedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    context.go(
                      '/home?refresh=${DateTime.now().millisecondsSinceEpoch}',
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    context.l10n.t('toHome'),
                    style: GoogleFonts.manrope(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
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
            decoration: BoxDecoration(
              color: AppColors.secondaryBg,
              boxShadow: shadowSm,
            ),
            padding: EdgeInsets.fromLTRB(
              16,
              MediaQuery.of(context).padding.top + 8,
              16,
              12,
            ),
            child: Row(
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
                        context.l10n.t('removeStockTitle'),
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
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: TextFormField(
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
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                : _filtered.isEmpty
                ? EmptyState(
                    icon: Icons.search_off_rounded,
                    title: context.l10n.t('nothingFound'),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    itemCount: _filtered.length,
                    itemBuilder: (_, i) {
                      final drug = _filtered[i];
                      final qty = _qtyByDrugId[drug.id];
                      final isOverStock =
                          qty != null && _isOverStock(drug, qty);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: GestureDetector(
                          onTap: () => _openQtyDialog(drug),
                          child: Container(
                            decoration: BoxDecoration(
                              color: AppColors.secondaryBg,
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: shadowSm,
                            ),
                            padding: const EdgeInsets.all(14),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
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
                                      const SizedBox(height: 6),
                                      const Divider(
                                        height: 1,
                                        color: AppColors.divider,
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        context.l10n.t('priceColon', args: {'value': formatUzs(drug.price)}),
                                        style: GoogleFonts.manrope(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (qty != null && qty > 0) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isOverStock
                                          ? const Color(0xFFFFE8E8)
                                          : AppColors.iconBgBlue,
                                      borderRadius: BorderRadius.circular(8),
                                      border: isOverStock
                                          ? Border.all(color: AppColors.error)
                                          : null,
                                    ),
                                    child: Text(
                                      '$qty',
                                      style: GoogleFonts.manrope(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: isOverStock
                                            ? AppColors.error
                                            : AppColors.primary,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      bottomNavigationBar: _selectedCount > 0
          ? Container(
              decoration: BoxDecoration(
                color: AppColors.secondaryBg,
                boxShadow: shadowMd,
              ),
              padding: EdgeInsets.fromLTRB(
                16,
                8,
                16,
                MediaQuery.of(context).padding.bottom + 8,
              ),
              child: ElevatedButton(
                onPressed: _hasInvalidSelectedQty ? null : _openConfirmScreen,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  context.l10n.t('continue'),
                  style: GoogleFonts.manrope(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            )
          : null,
    );
  }
}

class _StockSubmitPayload {
  final Map<int, int> qtyByDrugId;
  final Map<int, Drug> drugsById;
  final String comment;

  const _StockSubmitPayload({
    required this.qtyByDrugId,
    required this.drugsById,
    required this.comment,
  });
}

class _StockConfirmScreen extends StatefulWidget {
  final String pharmacyName;
  final Map<int, int> qtyByDrugId;
  final Map<int, Drug> drugsById;

  const _StockConfirmScreen({
    required this.pharmacyName,
    required this.qtyByDrugId,
    required this.drugsById,
  });

  @override
  State<_StockConfirmScreen> createState() => _StockConfirmScreenState();
}

class _StockConfirmScreenState extends State<_StockConfirmScreen> {
  late final Map<int, int> _qtyByDrugId = Map<int, int>.from(
    widget.qtyByDrugId,
  );
  final _commentCtrl = TextEditingController();

  int get _itemsCount => _qtyByDrugId.values.fold<int>(0, (a, b) => a + b);
  List<int> get _ids =>
      _qtyByDrugId.keys.where((id) => (_qtyByDrugId[id] ?? 0) > 0).toList();
  bool get _hasInvalidQty => _ids.any((id) {
    final drug = widget.drugsById[id];
    if (drug == null) return false;
    return _isOverStock(drug, _qtyByDrugId[id] ?? 0);
  });

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
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
              12,
            ),
            child: Row(
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
                Text(
                  context.l10n.t('stockRests'),
                  style: GoogleFonts.manrope(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryText,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
              children: [
                for (final id in _ids) ...[
                  _stockItemCard(id),
                  const SizedBox(height: 10),
                ],
                Text(
                  context.l10n.t('comment'),
                  style: GoogleFonts.manrope(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _commentCtrl,
                  maxLines: 3,
                  decoration: InputDecoration(hintText: context.l10n.t('comment')),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.secondaryBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Text(
                        context.l10n.t('quantityColon'),
                        style: GoogleFonts.manrope(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        context.l10n.t('pcsN', args: {'n': '$_itemsCount'}),
                        style: GoogleFonts.manrope(
                          fontSize: 16,
                          color: AppColors.primaryText,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppColors.secondaryBg,
          boxShadow: shadowMd,
        ),
        padding: EdgeInsets.fromLTRB(
          16,
          8,
          16,
          MediaQuery.of(context).padding.bottom + 8,
        ),
        child: ElevatedButton(
          onPressed: _ids.isEmpty || _hasInvalidQty
              ? null
              : () => Navigator.pop(
                  context,
                  _StockSubmitPayload(
                    qtyByDrugId: _qtyByDrugId,
                    drugsById: widget.drugsById,
                    comment: _commentCtrl.text.trim(),
                  ),
                ),
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(double.infinity, 52),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          child: Text(
            context.l10n.t('removeStock'),
            style: GoogleFonts.manrope(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _stockItemCard(int id) {
    final drug = widget.drugsById[id]!;
    final qty = _qtyByDrugId[id] ?? 0;
    final isOverStock = _isOverStock(drug, qty);
    return Container(
      decoration: BoxDecoration(
        color: AppColors.secondaryBg,
        borderRadius: BorderRadius.circular(12),
        border: isOverStock ? Border.all(color: AppColors.error) : null,
      ),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  drug.name,
                  style: GoogleFonts.manrope(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  drug.serialNumber?.isNotEmpty == true
                      ? drug.serialNumber!
                      : '—',
                  style: GoogleFonts.manrope(
                    fontSize: 14,
                    color: AppColors.secondaryText,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isOverStock ? AppColors.error : const Color(0xFFE9A165),
              ),
            ),
            child: Text(
              '$qty',
              style: GoogleFonts.manrope(
                fontSize: 16,
                color: isOverStock ? AppColors.error : const Color(0xFFE9A165),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => _editQty(id),
            child: _iconSquare(
              Icons.edit_outlined,
              color: const Color(0xFF7A8899),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => setState(() => _qtyByDrugId.remove(id)),
            child: _iconSquare(
              Icons.delete_outline_rounded,
              color: const Color(0xFFE05B57),
            ),
          ),
        ],
      ),
    );
  }

  Widget _iconSquare(IconData icon, {required Color color}) {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: AppColors.primaryBg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, color: color, size: 18),
    );
  }

  Future<void> _editQty(int id) async {
    final drug = widget.drugsById[id]!;
    final available = _availableStock(drug);
    final initial = _qtyByDrugId[id] ?? 1;
    final result = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: AppColors.secondaryBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => _StockEditQtyDialog(
        initialQty: initial,
        available: available,
      ),
    );
    if (result == null) return;
    setState(() {
      if (result <= 0) {
        _qtyByDrugId.remove(id);
      } else {
        _qtyByDrugId[id] = result;
      }
    });
  }

  int _availableStock(Drug drug) => drug.remainsStock ?? drug.stock ?? 0;

  bool _isOverStock(Drug drug, int qty) => qty > _availableStock(drug);
}

Widget _stockQtyLine(String label, String value) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
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
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: GoogleFonts.manrope(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.primaryText,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    ),
  );
}

/// Quantity sheet for "Снятие остатков". Own [StatefulWidget] so the qty
/// [TextEditingController] follows State.dispose() instead of a manual
/// dispose right after Navigator.pop() — see _QtyDialog in
/// pharmacy_order_screen.dart for why that crashed the app. Keeps the
/// existing on-screen [_NumKeypad] alongside a real TextField so both the
/// device keyboard and the tap-keypad work.
class _StockQtyDialog extends StatefulWidget {
  final Drug drug;
  final int initialQty;
  final int available;

  const _StockQtyDialog({
    required this.drug,
    required this.initialQty,
    required this.available,
  });

  @override
  State<_StockQtyDialog> createState() => _StockQtyDialogState();
}

class _StockQtyDialogState extends State<_StockQtyDialog> {
  late final TextEditingController _qtyCtrl;
  late int _qty;

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

  void _onKey(String key) {
    setState(() {
      var qtyStr = '$_qty';
      if (key == 'C') {
        qtyStr = '0';
      } else if (key == '←') {
        qtyStr = qtyStr.length <= 1
            ? '0'
            : qtyStr.substring(0, qtyStr.length - 1);
      } else {
        qtyStr = qtyStr == '0' ? key : qtyStr + key;
      }
      _qty = int.tryParse(qtyStr) ?? 0;
      _qtyCtrl.text = '$_qty';
    });
  }

  @override
  Widget build(BuildContext context) {
    final drug = widget.drug;
    final available = widget.available;
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
                  _stockQtyLine(context.l10n.t('drug'), drug.name),
                  _stockQtyLine(
                    context.l10n.t('manufacturer'),
                    drug.manufacturer.isNotEmpty ? drug.manufacturer : '—',
                  ),
                  _stockQtyLine(
                    context.l10n.t('expiryDate'),
                    drug.expiryDate?.isNotEmpty == true
                        ? drug.expiryDate!
                        : '—',
                  ),
                  _stockQtyLine(
                    context.l10n.t('serialNumber'),
                    drug.serialNumber?.isNotEmpty == true
                        ? drug.serialNumber!
                        : '—',
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
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _NumKeypad(onKey: _onKey),
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

/// Compact quantity-edit sheet used by _StockConfirmScreen. Own
/// [StatefulWidget] for the same reason as [_StockQtyDialog] — see its
/// doc comment.
class _StockEditQtyDialog extends StatefulWidget {
  final int initialQty;
  final int available;

  const _StockEditQtyDialog({required this.initialQty, required this.available});

  @override
  State<_StockEditQtyDialog> createState() => _StockEditQtyDialogState();
}

class _StockEditQtyDialogState extends State<_StockEditQtyDialog> {
  late final TextEditingController _qtyCtrl;
  late int _qty;

  @override
  void initState() {
    super.initState();
    _qty = widget.initialQty;
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

  void _onKey(String key) {
    setState(() {
      var qtyStr = '$_qty';
      if (key == 'C') {
        qtyStr = '0';
      } else if (key == '←') {
        qtyStr = qtyStr.length <= 1
            ? '0'
            : qtyStr.substring(0, qtyStr.length - 1);
      } else {
        qtyStr = qtyStr == '0' ? key : qtyStr + key;
      }
      _qty = int.tryParse(qtyStr) ?? 0;
      _qtyCtrl.text = '$_qty';
    });
  }

  @override
  Widget build(BuildContext context) {
    final available = widget.available;
    final isOverStock = _qty > available;
    final canIncrease = _qty < available;
    final counterColor = isOverStock
        ? AppColors.error
        : const Color(0xFFE9A165);

    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        MediaQuery.of(context).padding.bottom + 12,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            context.l10n.t('quantity'),
            style: GoogleFonts.manrope(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _QtyBtn(
                icon: Icons.remove_rounded,
                onTap: () => _setQty(_qty > 1 ? _qty - 1 : 0),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  height: 46,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: counterColor, width: 1.5),
                  ),
                  child: TextField(
                    controller: _qtyCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(5),
                    ],
                    textAlign: TextAlign.center,
                    style: GoogleFonts.manrope(
                      fontSize: 20,
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
              const SizedBox(width: 10),
              _QtyBtn(
                icon: Icons.add_rounded,
                onTap: canIncrease ? () => _setQty(_qty + 1) : null,
              ),
            ],
          ),
          if (isOverStock) ...[
            const SizedBox(height: 6),
            Text(
              context.l10n.t('availableN', args: {'n': '$available'}),
              style: GoogleFonts.manrope(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.error,
              ),
            ),
          ],
          const SizedBox(height: 10),
          _NumKeypad(onKey: _onKey),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: _qty <= 0 || isOverStock
                ? null
                : () => Navigator.pop(context, _qty),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              context.l10n.t('saved'),
              style: GoogleFonts.manrope(fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _NumKeypad extends StatelessWidget {
  final void Function(String key) onKey;

  const _NumKeypad({required this.onKey});

  @override
  Widget build(BuildContext context) {
    const keys = ['1', '2', '3', '4', '5', '6', '7', '8', '9', 'C', '0', '←'];
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 2.4,
      children: keys.map((k) {
        final isAction = k == 'C' || k == '←';
        return GestureDetector(
          onTap: () => onKey(k),
          child: Container(
            decoration: BoxDecoration(
              color: isAction ? const Color(0xFFEEF0F3) : AppColors.primaryBg,
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: Text(
              k,
              style: GoogleFonts.manrope(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: isAction
                    ? AppColors.secondaryText
                    : AppColors.primaryText,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _QtyBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const _QtyBtn({required this.icon, this.onTap});

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
          size: 28,
          color: onTap == null ? AppColors.hintText : AppColors.primaryText,
        ),
      ),
    );
  }
}

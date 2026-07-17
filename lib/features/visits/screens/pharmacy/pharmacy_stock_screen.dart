import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lima/core/i18n/app_i18n.dart';
import 'package:lima/features/visits/domain/entities/completed_visit.dart';
import 'package:lima/features/visits/providers/pharmacy_stock_provider.dart';
import 'package:lima/features/visits/widgets/pharmacy_stock_widgets.dart';
import 'package:lima/features/visits/providers/visit_write_provider.dart';
import 'package:lima/core/providers/connectivity_provider.dart';
import 'package:lima/core/providers/dashboard_counts_provider.dart';
import 'package:lima/core/theme/app_theme.dart';
import 'package:lima/core/widgets/app_widgets.dart';
import 'package:lima/core/utils/swallowed.dart';
import 'package:lima/features/auth/providers/auth_provider.dart';

import '../../../../core/models/models.dart';

part '../../widgets/pharmacy_stock_screen_widgets.dart';

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
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => ref.read(pharmacyStockViewModelProvider.notifier).load(),
    );
  }

  Future<void> _openQtyDialog(Drug drug) async {
    final viewState = ref.read(pharmacyStockViewModelProvider);
    final initial = viewState.quantities[drug.id] ?? 0;
    final available = viewState.availableStock(drug);
    final result = await showAppSheet<int>(
      context,
      useRootNavigator: true,
      backgroundColor: AppColors.secondaryBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => PharmacyStockQtyDialog(
        drug: drug,
        initialQty: initial,
        available: available,
      ),
    );
    if (result == null || !mounted) return;
    ref
        .read(pharmacyStockViewModelProvider.notifier)
        .setQuantity(drug.id, result);
  }

  int _availableStock(Drug drug) => drug.remainsStock ?? drug.stock ?? 0;

  bool _isOverStock(Drug drug, int qty) => qty > _availableStock(drug);

  Future<void> _openConfirmScreen() async {
    final viewState = ref.read(pharmacyStockViewModelProvider);
    if (viewState.isActionLocked) return;
    final selected = <int, Drug>{
      for (final e in viewState.quantities.entries)
        if (e.value > 0 && viewState.drugs.any((d) => d.id == e.key))
          e.key: viewState.drugs.firstWhere((d) => d.id == e.key),
    };
    if (selected.isEmpty || viewState.hasInvalidSelectedQty) return;
    final result = await Navigator.of(context).push<PharmacyStockSubmitPayload>(
      MaterialPageRoute(
        builder: (_) => PharmacyStockConfirmScreen(
          pharmacyName: widget.pharmacyName,
          qtyByDrugId: Map<int, int>.from(viewState.quantities),
          drugsById: selected,
        ),
      ),
    );
    if (result == null || !mounted) return;
    ref
        .read(pharmacyStockViewModelProvider.notifier)
        .replaceQuantities(result.qtyByDrugId);
    await _submitStock(result);
  }

  Future<void> _submitStock(PharmacyStockSubmitPayload payload) async {
    final viewModel = ref.read(pharmacyStockViewModelProvider.notifier);
    if (ref.read(pharmacyStockViewModelProvider).isActionLocked) return;
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
    viewModel.lockAction();
    final now = DateTime.now().toIso8601String();
    final stockItemsPayload = payload.qtyByDrugId.entries
        .where((e) => e.value > 0 && payload.drugsById.containsKey(e.key))
        .map((e) {
          final d = payload.drugsById[e.key]!;
          return StockItemRecord(
            drugId: d.id,
            drugName: d.name,
            manufacturer: d.manufacturer,
            serialNumber: d.serialNumber ?? '',
            expiryDate: d.expiryDate ?? '',
            quantity: e.value,
            stock: d.stock ?? 0,
          );
        })
        .toList(growable: false);
    final drugsPayload = payload.qtyByDrugId.entries
        .where((e) => e.value > 0 && payload.drugsById.containsKey(e.key))
        .map((e) {
          final d = payload.drugsById[e.key]!;
          return StockDrugRecord(
            incomeDetailingId: d.currentStockId,
            drugId: d.bindingDrugId ?? d.id,
            package: e.value,
            salePrice: d.price,
            salePriceWithoutNds: _priceWithoutNds(d.price),
            serialNumber: d.serialNumber,
            expiryDate: d.expiryDate,
          );
        })
        .toList(growable: false);
    try {
      await ref
          .read(visitWriteRepositoryProvider)
          .complete(
            CompletedVisitDraft(
              organizationId: widget.pharmacyId,
              organizationName: widget.pharmacyName,
              doctorId: null,
              doctorName: null,
              localVisitType: 'stock',
              notes: payload.comment.trim(),
              medicalRepName: ref.read(authProvider).user?.fullName,
              createdAt: DateTime.tryParse(now) ?? DateTime.now(),
              updatedAt: DateTime.tryParse(now) ?? DateTime.now(),
              payload: StockCompletedVisitPayload(
                stockItems: List.unmodifiable(stockItemsPayload),
                drugs: List.unmodifiable(drugsPayload),
              ),
            ),
            tryRemote: !ref.read(isOfflineProvider),
          );
      ref.invalidate(dashboardCountsProvider);
      // The repository keeps a failed remote write queued for retry.
    } catch (error) {
      logSwallowed(error, 'PharmacyStockScreen.saveVisit');
    }
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
  Widget build(BuildContext context) => _buildScreen(context);
}

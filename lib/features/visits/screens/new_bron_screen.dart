import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lima/core/i18n/app_i18n.dart';
import 'package:lima/features/visits/domain/entities/pharmacy_order.dart';
import 'package:lima/features/visits/presentation/view_models/pharmacy_order_view_model.dart';
import 'package:lima/features/visits/providers/pharmacy_order_provider.dart';
import 'package:lima/core/models/models.dart';
import 'package:lima/core/providers/app_collections_provider.dart';
import 'package:lima/core/providers/connectivity_provider.dart';
import 'package:lima/core/providers/dashboard_counts_provider.dart';
import 'package:lima/core/services/specification_export_service.dart';
import 'package:lima/core/theme/app_theme.dart';
import 'package:lima/core/widgets/app_widgets.dart';
import 'package:lima/features/auth/providers/auth_provider.dart';
import 'package:lima/features/visits/providers/visits_hub_provider.dart';

part '../widgets/new_bron_screen_widgets.dart';

class NewBronScreen extends ConsumerStatefulWidget {
  final int pharmacyId;
  final String pharmacyName;
  final PharmacyOrderRouteData routeData;

  const NewBronScreen({
    super.key,
    required this.pharmacyId,
    required this.pharmacyName,
    required this.routeData,
  });

  @override
  ConsumerState<NewBronScreen> createState() => _NewBronScreenState();
}

class _NewBronScreenState extends ConsumerState<NewBronScreen> {
  final TextEditingController _commentCtrl = TextEditingController();

  int _prepayment = 100;
  int _buyerType = 0;
  int? _companyId;
  int? _paymentVariantId;
  int? _marginId;
  int? _marginPercent;
  int? _checkoutCartId;
  bool _fromCart = false;
  bool _paramsLoaded = false;
  PharmacyOrderViewModelConfig? _orderConfig;
  final _specExport = SpecificationExportService();

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_paramsLoaded) return;
    final routeData = widget.routeData;
    _prepayment = routeData.prepaymentPercent;
    _buyerType = routeData.buyerType;
    _checkoutCartId = routeData.cartId;
    _companyId = routeData.pricingTerms?.companyId;
    _paymentVariantId = routeData.pricingTerms?.paymentVariantId;
    _marginId = routeData.pricingTerms?.marginId;
    _marginPercent = routeData.pricingTerms?.marginPercent;
    _fromCart = routeData.fromCart;
    final initialQuantities = <int, int>{};
    final initialDrugs = <int, Drug>{};
    for (final line in routeData.lines) {
      if (line.quantity <= 0) continue;
      initialQuantities[line.id] = line.quantity;
      initialDrugs[line.id] = Drug(
        id: line.id,
        name: line.name,
        manufacturer: line.manufacturer,
        price: line.price,
        serialNumber: line.serialNumber,
        expiryDate: line.expiryDate,
        mainStock: line.mainStock,
        stock: line.stock,
        remainsStock: line.remainsStock,
        currentStockId: line.currentStockId,
        bindingDrugId: line.bindingDrugId,
      );
    }
    _paramsLoaded = true;
    _orderConfig = PharmacyOrderViewModelConfig(
      pharmacyId: widget.pharmacyId,
      organizationName: widget.pharmacyName,
      fromCart: _fromCart,
      checkoutCartId: _checkoutCartId,
      prepaymentPercent: _prepayment,
      buyerType: _buyerType,
      selectedCompanyId: _companyId,
      paymentVariantId: _paymentVariantId,
      marginId: _marginId,
      marginPercent: _marginPercent,
      initialQuantities: Map.unmodifiable(initialQuantities),
      initialDrugs: Map.unmodifiable(initialDrugs),
      cartItems: List.unmodifiable(ref.read(appCollectionsProvider).cartItems),
    );
  }

  PharmacyOrderViewState get _orderState {
    final config = _orderConfig;
    if (config == null) return const PharmacyOrderViewState();
    return ref.read(pharmacyOrderViewModelProvider(config));
  }

  PharmacyOrderViewModel get _orderViewModel {
    final config = _orderConfig;
    if (config == null) {
      throw StateError('Pharmacy order view model is not initialized');
    }
    return ref.read(pharmacyOrderViewModelProvider(config).notifier);
  }

  Map<int, Drug> get _drugById => _orderState.drugs;
  Map<int, int> get _qtyByDrugId => _orderState.quantities;
  List<int> get _ids => _orderState.selectedIds;
  bool get _hasInvalidQuantities => _orderState.hasInvalidQuantities;
  double get _total => _orderState.total;
  bool get _actionLocked => _orderState.isActionLocked;

  Future<void> _saveToCart() async {
    if (_actionLocked) return;
    if (_hasInvalidQuantities) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.t('qtyExceedsStock'))),
      );
      return;
    }
    _orderViewModel.setActionLocked(true);
    final notifier = ref.read(appCollectionsProvider.notifier);
    var savedCount = 0;
    for (final id in _ids) {
      final qty = _qtyByDrugId[id] ?? 0;
      if (qty <= 0) continue;
      final drug = _drugById[id];
      if (drug == null) continue;
      await notifier.addToCart(
        drug,
        quantity: qty,
        pharmacyId: widget.pharmacyId,
        pharmacyName: widget.pharmacyName,
        prepaymentPercent: _prepayment,
        buyerType: _buyerType,
      );
      savedCount++;
    }
    if (savedCount == 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.t('loadingDrugData'))),
        );
      }
      _orderViewModel.setActionLocked(false);
      return;
    }
    if (!mounted) return;
    await _showResultDialog(
      title: context.l10n.t('orderAddedToCart'),
      subtitle: context.l10n.t('orderSavedInCart'),
      badge: context.l10n.t('orderAvailable12h'),
    );
  }

  Future<void> _sendOrder() async {
    if (_actionLocked || _orderState.submission.isBusy) return;
    if (_hasInvalidQuantities) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.t('qtyExceedsStock'))),
      );
      return;
    }

    final user = ref.read(authProvider).user;
    if (user == null || user.id <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.t('cannotIdentifyUser'))),
      );
      return;
    }

    try {
      final org = await ref
          .read(organisationsDirectoryRepositoryProvider)
          .getModelById(widget.pharmacyId);
      if (!mounted) return;
      final result = await _orderViewModel.submitOrder(
        PharmacyOrderSubmitContext(
          orderUserId: user.id,
          medicalRepName: user.fullName,
          userCompanyId: user.companyId,
          organizationInn: org?.inn == null ? null : _parseInt(org!.inn),
          isOffline: ref.read(isOfflineProvider),
          comment: _commentCtrl.text.trim(),
        ),
      );
      if (!mounted) return;

      switch (result.status) {
        case PharmacyOrderSubmissionStatus.invalidLines:
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.l10n.t('loadingDrugData'))),
          );
          return;
        case PharmacyOrderSubmissionStatus.noPriceMatrix:
          final buyerLabel = _buyerType == 1
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
        case PharmacyOrderSubmissionStatus.failed:
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                context.l10n.t(
                  'orderFailedError',
                  args: {'error': result.message ?? 'unknown'},
                ),
              ),
            ),
          );
          return;
        case PharmacyOrderSubmissionStatus.rejected:
          ref.invalidate(dashboardCountsProvider);
          await _showResultDialog(
            title: context.l10n.t('orderNotSent'),
            subtitle:
                '${result.message ?? context.l10n.t('serverRejectedOrder')}. '
                '${context.l10n.t('orderSavedLocallyRetry')}',
            success: false,
            stayOnPageOnClose: true,
          );
          return;
        case PharmacyOrderSubmissionStatus.sent:
        case PharmacyOrderSubmissionStatus.queued:
          break;
        case PharmacyOrderSubmissionStatus.idle:
        case PharmacyOrderSubmissionStatus.loading:
          return;
      }

      if (!mounted) return;
      if (result.skippedInvalidItems > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.l10n.t(
                'skippedNoStockN',
                args: {'count': '${result.skippedInvalidItems}'},
              ),
            ),
          ),
        );
      }
      if (_fromCart) {
        unawaited(
          ref
              .read(appCollectionsProvider.notifier)
              .clearCartGroup(
                pharmacyId: widget.pharmacyId,
                pharmacyName: widget.pharmacyName,
                cartId: _checkoutCartId,
                prepaymentPercent: _prepayment,
                buyerType: _buyerType,
              )
              .catchError((_) {}),
        );
      }
      ref.invalidate(dashboardCountsProvider);
      if (ref.read(isOfflineProvider)) pulseOfflineBanner(ref);
      unawaited(
        ref.read(authProvider.notifier).refreshProfile().catchError((_) {}),
      );
      if (!mounted) return;
      await _showResultDialog(
        title: result.status == PharmacyOrderSubmissionStatus.sent
            ? context.l10n.t('orderPlaced')
            : context.l10n.t('orderSaved'),
        subtitle: result.status == PharmacyOrderSubmissionStatus.sent
            ? context.l10n.t('orderSentToOperator')
            : result.remoteError
            ? context.l10n.t('orderQueuedSyncFail')
            : context.l10n.t('orderWillSendOnSync'),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.l10n.t('orderFailedError', args: {'error': '$error'}),
          ),
        ),
      );
    }
  }

  int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString().replaceAll(RegExp(r'\D'), ''));
  }

  bool _isLineOverStock(int id) => _orderState.isOverStock(id);

  bool _canIncreaseQty(int id) => _orderState.canIncrease(id);

  @override
  Widget build(BuildContext context) {
    final config = _orderConfig;
    if (config == null) return const SizedBox.shrink();
    final orderState = ref.watch(pharmacyOrderViewModelProvider(config));
    final actionBusy = _actionLocked || orderState.submission.isBusy;
    final itemsCount = orderState.selectedIds.fold<int>(
      0,
      (sum, id) => sum + (_qtyByDrugId[id] ?? 0),
    );
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
                AppTapScale(
                  onTap: () {
                    if (context.canPop()) {
                      context.pop();
                    } else if (_fromCart) {
                      context.go('/basket');
                    } else {
                      context.go(
                        Uri(
                          path:
                              '/visits/pharmacy/detail/${widget.pharmacyId}/type',
                          queryParameters: {'name': widget.pharmacyName},
                        ).toString(),
                      );
                    }
                  },
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
                        _fromCart
                            ? context.l10n.t('orderCheckout')
                            : context.l10n.t('bronCheckout'),
                        style: GoogleFonts.manrope(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primaryText,
                        ),
                      ),
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
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
              children: [
                _orderDetailsCard(itemsCount),
                const SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.secondaryBg,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: shadowSm,
                  ),
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    children: [
                      _pair(context.l10n.t('prepaymentColon'), '$_prepayment%'),
                      const Divider(color: AppColors.divider, height: 16),
                      _pair(
                        context.l10n.t('buyerTypeColon'),
                        _buyerType == 1
                            ? context.l10n.t('wholesale')
                            : context.l10n.t('retail'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.secondaryBg,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: shadowSm,
                  ),
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.l10n.t('comment'),
                        style: GoogleFonts.manrope(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _commentCtrl,
                        maxLines: 3,
                        decoration: InputDecoration(
                          hintText: context.l10n.t('enterComment'),
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
          8,
          8,
          8,
          MediaQuery.of(context).padding.bottom + 8,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFE6894A),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Text(
                    context.l10n.t('toPayColon'),
                    style: GoogleFonts.manrope(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    formatUzs(_total),
                    style: GoogleFonts.manrope(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: _ids.isEmpty || actionBusy || _hasInvalidQuantities
                  ? null
                  : _sendOrder,
              icon: actionBusy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.check_rounded),
              label: Text(
                actionBusy
                    ? context.l10n.t('placingOrder')
                    : context.l10n.t('sendOrderToOperator'),
                style: GoogleFonts.manrope(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
            if (!_fromCart) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _ids.isEmpty || actionBusy || _hasInvalidQuantities
                    ? null
                    : _saveToCart,
                icon: const Icon(
                  Icons.shopping_cart_rounded,
                  color: Color(0xFF2C9E63),
                ),
                label: Text(
                  context.l10n.t('saveToCart'),
                  style: GoogleFonts.manrope(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF2C9E63),
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                  side: const BorderSide(color: Color(0xFFAEDFC6)),
                  backgroundColor: const Color(0xFFEFFAF4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _ids.isEmpty || actionBusy || _hasInvalidQuantities
                  ? null
                  : _showSpecFormatDialog,
              icon: const Icon(Icons.file_download_outlined),
              label: Text(
                context.l10n.t('downloadSpec'),
                style: GoogleFonts.manrope(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

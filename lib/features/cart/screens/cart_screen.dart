import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lima/core/i18n/app_i18n.dart';
import 'package:lima/core/providers/app_collections_provider.dart';
import 'package:lima/core/providers/connectivity_provider.dart';
import 'package:lima/core/theme/app_theme.dart';
import 'package:lima/core/widgets/app_widgets.dart';
import 'package:lima/features/cart/providers/cart_view_provider.dart';
import 'package:lima/features/cart/presentation/view_models/cart_view_model.dart';
import 'package:lima/features/visits/domain/entities/pharmacy_order.dart';

part '../widgets/cart_screen_widgets.dart';

class CartScreen extends ConsumerStatefulWidget {
  const CartScreen({super.key});

  @override
  ConsumerState<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends ConsumerState<CartScreen> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(appCollectionsProvider.notifier).clearExpiredCartItems();
    });
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appCollectionsProvider);
    final viewState = ref.watch(cartViewModelProvider);
    final notifier = ref.read(appCollectionsProvider.notifier);
    final groups = _cartGroups(state.cartItems);

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
              AppUi.screenHorizontal,
              MediaQuery.of(context).padding.top + 8,
              AppUi.screenHorizontal,
              12,
            ),
            child: Row(
              children: [
                AppTapScale(
                  onTap: () => context.pop(),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.primaryBg,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.arrow_back_rounded,
                      color: AppColors.primaryText,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  context.l10n.t('cart'),
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
            child: state.cartItems.isEmpty
                ? Center(
                    child: Text(
                      context.l10n.t('cartEmpty'),
                      style: GoogleFonts.manrope(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.secondaryText,
                      ),
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 20),
                    children: [
                      ...groups.map(
                        (group) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _cartGroupCard(
                            context,
                            ref,
                            notifier,
                            viewState,
                            group,
                          ),
                        ),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          color: AppColors.secondaryBg,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.divider),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        child: Column(
                          children: [
                            _summaryRow(
                              context.l10n.t('totalOrders'),
                              '${groups.length}',
                            ),
                            const Divider(height: 10, color: AppColors.divider),
                            _summaryRow(
                              context.l10n.t('totalItems'),
                              '${state.cartCount}',
                            ),
                            const Divider(height: 10, color: AppColors.divider),
                            _summaryRow(
                              context.l10n.t('totalAmount'),
                              formatUzs(state.cartTotal),
                              valueColor: AppColors.primary,
                              keyWeight: FontWeight.w700,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
      bottomNavigationBar: const _CartBottomNav(),
    );
  }

  Widget _cartGroupCard(
    BuildContext context,
    WidgetRef ref,
    AppCollectionsNotifier notifier,
    CartViewState viewState,
    _CartGroup group,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.secondaryBg,
        borderRadius: BorderRadius.circular(AppUi.cardRadius),
        border: Border.all(color: AppColors.divider),
        boxShadow: shadowSm,
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                context.l10n.t(
                  'orderN',
                  args: {'n': _orderIdFromDate(group.addedAt)},
                ),
                style: GoogleFonts.manrope(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primaryText,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3DB),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _remainingLabel(context, group.addedAt),
                  style: GoogleFonts.manrope(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFFE3A335),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            group.pharmacyName,
            style: GoogleFonts.manrope(
              fontSize: 14,
              color: AppColors.secondaryText,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            context.l10n.t(
              'prepaymentBullet',
              args: {
                'percent': '${group.prepaymentPercent}',
                'buyer': group.buyerType == 1
                    ? context.l10n.t('wholesale')
                    : context.l10n.t('retail'),
              },
            ),
            style: GoogleFonts.manrope(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.secondaryText,
            ),
          ),
          const SizedBox(height: 8),
          const Divider(height: 1, color: AppColors.divider),
          const SizedBox(height: 8),
          ...group.items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _cartItemRow(context, notifier, item, group),
            ),
          ),
          const Divider(height: 1, color: AppColors.divider),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.l10n.t('totalColon'),
                      style: GoogleFonts.manrope(
                        fontSize: 14,
                        color: AppColors.secondaryText,
                      ),
                    ),
                    Text(
                      formatUzs(group.total),
                      style: GoogleFonts.manrope(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 102,
                child: AppTapScale(
                  pressedScale: 0.97,
                  onTap: () => notifier.clearCartGroup(
                    pharmacyId: group.pharmacyId,
                    pharmacyName: group.pharmacyName,
                    cartId: group.cartId,
                    prepaymentPercent: group.prepaymentPercent,
                    buyerType: group.buyerType,
                  ),
                  child: OutlinedButton(
                    onPressed: null,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(
                        double.infinity,
                        AppUi.buttonHeight,
                      ),
                      disabledForegroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppUi.buttonRadius),
                      ),
                    ),
                    child: Text(
                      context.l10n.t('delete'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.manrope(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 116,
                child: AppTapScale(
                  pressedScale: 0.97,
                  onTap: viewState.checkingOutKey == group.identityKey
                      ? null
                      : () => _checkoutGroup(context, ref, group),
                  child: ElevatedButton(
                    onPressed: null,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(
                        double.infinity,
                        AppUi.buttonHeight,
                      ),
                      disabledBackgroundColor: AppColors.primary,
                      disabledForegroundColor: Colors.white,
                      elevation: 1,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppUi.buttonRadius),
                      ),
                    ),
                    child: viewState.checkingOutKey == group.identityKey
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            context.l10n.t('checkout'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.manrope(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _cartItemRow(
    BuildContext context,
    AppCollectionsNotifier notifier,
    CartItemSnapshot item,
    _CartGroup group,
  ) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      decoration: BoxDecoration(
        color: AppColors.secondaryBg,
        borderRadius: BorderRadius.circular(AppUi.buttonRadius),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.manrope(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primaryText,
                  ),
                ),
                Text(
                  item.manufacturer.isEmpty ? '—' : item.manufacturer,
                  style: GoogleFonts.manrope(
                    fontSize: 12,
                    color: AppColors.secondaryText,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            context.l10n.t('pcsN', args: {'n': '${item.quantity}'}),
            style: GoogleFonts.manrope(
              fontSize: 13,
              color: AppColors.secondaryText,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            formatUzs(item.total),
            style: GoogleFonts.manrope(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.primaryText,
            ),
          ),
          const SizedBox(width: 6),
          AppTapScale(
            onTap: () => notifier.updateCartQuantity(
              item.drugId,
              0,
              pharmacyId: item.pharmacyId,
              cartId: item.cartId,
              prepaymentPercent: group.prepaymentPercent,
              buyerType: group.buyerType,
            ),
            child: const Icon(
              Icons.delete_rounded,
              color: AppColors.error,
              size: 20,
            ),
          ),
        ],
      ),
    );
  }

  void _checkoutGroup(BuildContext context, WidgetRef ref, _CartGroup group) {
    final pharmacyId = group.pharmacyId;
    if (pharmacyId == null || pharmacyId <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.t('couldNotDeterminePharmacy'))),
      );
      return;
    }
    final cartViewModel = ref.read(cartViewModelProvider.notifier);
    if (!cartViewModel.beginCheckout(group.identityKey)) return;
    final routeData = PharmacyOrderRouteData(
      lines: group.items
          .map(
            (item) => PharmacyOrderRouteLine(
              id: item.drugId,
              name: item.name,
              manufacturer: item.manufacturer,
              price: item.price,
              serialNumber: item.serialNumber,
              expiryDate: item.expiryDate,
              stock: item.stock,
              currentStockId: item.currentStockId,
              bindingDrugId: item.bindingDrugId,
              quantity: item.quantity,
            ),
          )
          .toList(growable: false),
      prepaymentPercent: group.prepaymentPercent,
      buyerType: group.buyerType,
      cartId: group.cartId,
      fromCart: true,
    );
    if (ref.read(isOfflineProvider)) {
      pulseOfflineBanner(ref);
    }
    try {
      context.go(
        Uri(
          path: '/visits/pharmacy/detail/$pharmacyId/type/checkout',
          queryParameters: {'name': group.pharmacyName},
        ).toString(),
        extra: routeData,
      );
    } catch (e) {
      cartViewModel.clearCheckout();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.l10n.t('couldNotOpenCheckout', args: {'error': '$e'}),
          ),
        ),
      );
    }
  }

  Widget _summaryRow(
    String key,
    String value, {
    Color valueColor = AppColors.primaryText,
    FontWeight keyWeight = FontWeight.w400,
  }) {
    return Row(
      children: [
        Text(
          key,
          style: GoogleFonts.manrope(
            fontSize: 14,
            color: AppColors.secondaryText,
            fontWeight: keyWeight,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: GoogleFonts.manrope(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: valueColor,
          ),
        ),
      ],
    );
  }

  static String _orderIdFromDate(String? iso) {
    final dt = DateTime.tryParse(iso ?? '') ?? DateTime.now();
    final id = (dt.millisecondsSinceEpoch ~/ 1000) % 100000;
    return '$id';
  }

  String _remainingLabel(BuildContext context, String? iso) {
    if (iso == null || iso.isEmpty) {
      return context.l10n.t('hoursMinFormat', args: {'h': '12', 'm': '00'});
    }
    final created = DateTime.tryParse(iso);
    if (created == null) {
      return context.l10n.t('hoursMinFormat', args: {'h': '12', 'm': '00'});
    }
    final endsAt = created.add(const Duration(hours: 12));
    final left = endsAt.difference(DateTime.now());
    if (left.isNegative) {
      return context.l10n.t('hoursMinFormat', args: {'h': '00', 'm': '00'});
    }
    final h = left.inHours;
    final m = left.inMinutes % 60;
    final hh = h.toString().padLeft(2, '0');
    final mm = m.toString().padLeft(2, '0');
    return context.l10n.t('hoursMinFormat', args: {'h': hh, 'm': mm});
  }

  static List<_CartGroup> _cartGroups(List<CartItemSnapshot> items) {
    final byKey = <String, List<CartItemSnapshot>>{};
    for (final item in items) {
      final prepayment = item.prepaymentPercent ?? 100;
      final buyerType = item.buyerType ?? 0;
      final key = item.cartId != null
          ? 'server:${item.cartId}:$prepayment:$buyerType'
          : 'pharmacy:${item.pharmacyId ?? 0}:${item.pharmacyName ?? ''}:$prepayment:$buyerType';
      byKey.putIfAbsent(key, () => <CartItemSnapshot>[]).add(item);
    }
    final groups = byKey.values.map(_CartGroup.fromItems).toList();
    groups.sort((a, b) {
      final aDate = DateTime.tryParse(a.addedAt ?? '') ?? DateTime(1970);
      final bDate = DateTime.tryParse(b.addedAt ?? '') ?? DateTime(1970);
      return aDate.compareTo(bDate);
    });
    return groups;
  }
}

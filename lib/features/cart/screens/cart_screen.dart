import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lima/core/providers/app_collections_provider.dart';
import 'package:lima/core/providers/connectivity_provider.dart';
import 'package:lima/core/theme/app_theme.dart';
import 'package:lima/core/widgets/app_widgets.dart';

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
    final notifier = ref.read(appCollectionsProvider.notifier);

    final first = state.cartItems.isNotEmpty ? state.cartItems.first : null;
    final pharmacy = (first?.pharmacyName?.isNotEmpty == true)
        ? first!.pharmacyName!
        : 'Аптека';
    final timer = _remainingLabel(first?.addedAt);
    final orderId = _orderIdFromDate(first?.addedAt);

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
                  'Корзина',
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
                      'Корзина пуста',
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
                      Container(
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
                                  'Заказ #$orderId',
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
                                    timer,
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
                              pharmacy,
                              style: GoogleFonts.manrope(
                                fontSize: 14,
                                color: AppColors.secondaryText,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Divider(height: 1, color: AppColors.divider),
                            const SizedBox(height: 8),
                            ...state.cartItems.map(
                              (item) => Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Container(
                                  padding: const EdgeInsets.fromLTRB(
                                    10,
                                    8,
                                    10,
                                    8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.secondaryBg,
                                    borderRadius: BorderRadius.circular(
                                      AppUi.buttonRadius,
                                    ),
                                    border: Border.all(
                                      color: AppColors.divider,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
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
                                              item.manufacturer.isEmpty
                                                  ? '—'
                                                  : item.manufacturer,
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
                                        '${item.quantity} шт.',
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
                                        onTap: () => notifier
                                            .updateCartQuantity(item.drugId, 0),
                                        child: const Icon(
                                          Icons.delete_rounded,
                                          color: AppColors.error,
                                          size: 20,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const Divider(height: 1, color: AppColors.divider),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Итого:',
                                        style: GoogleFonts.manrope(
                                          fontSize: 14,
                                          color: AppColors.secondaryText,
                                        ),
                                      ),
                                      Text(
                                        formatUzs(state.cartTotal),
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
                                    onTap: notifier.clearCart,
                                    child: OutlinedButton(
                                      onPressed: null,
                                      style: OutlinedButton.styleFrom(
                                        minimumSize: const Size(
                                          double.infinity,
                                          AppUi.buttonHeight,
                                        ),
                                        disabledForegroundColor:
                                            AppColors.primary,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            AppUi.buttonRadius,
                                          ),
                                        ),
                                      ),
                                      child: Text(
                                        'Удалить',
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
                                    onTap: () {
                                      final first = state.cartItems.isNotEmpty
                                          ? state.cartItems.first
                                          : null;
                                      final pharmacyId = first?.pharmacyId;
                                      if (pharmacyId == null ||
                                          pharmacyId <= 0) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'Не удалось определить аптеку заказа',
                                            ),
                                          ),
                                        );
                                        return;
                                      }
                                      final items = state.cartItems
                                          .map(
                                            (e) => '${e.drugId}:${e.quantity}',
                                          )
                                          .join(';');
                                      if (ref.read(isOfflineProvider)) {
                                        pulseOfflineBanner(ref);
                                      }
                                      context.push(
                                        Uri(
                                          path:
                                              '/visits/pharmacy/detail/$pharmacyId/type/checkout',
                                          queryParameters: {
                                            'name': first?.pharmacyName ?? '',
                                            'items': items,
                                            'prepayment': '100',
                                            'buyerType': '0',
                                          },
                                        ).toString(),
                                      );
                                    },
                                    child: ElevatedButton(
                                      onPressed: null,
                                      style: ElevatedButton.styleFrom(
                                        minimumSize: const Size(
                                          double.infinity,
                                          AppUi.buttonHeight,
                                        ),
                                        disabledBackgroundColor:
                                            AppColors.primary,
                                        disabledForegroundColor: Colors.white,
                                        elevation: 1,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            AppUi.buttonRadius,
                                          ),
                                        ),
                                      ),
                                      child: Text(
                                        'Оформить',
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
                      ),
                      const SizedBox(height: 10),
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
                            _summaryRow('Всего заказов:', '1'),
                            const Divider(height: 10, color: AppColors.divider),
                            _summaryRow('Товаров:', '${state.cartCount}'),
                            const Divider(height: 10, color: AppColors.divider),
                            _summaryRow(
                              'Общая сумма:',
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

  static String _remainingLabel(String? iso) {
    if (iso == null || iso.isEmpty) return '12 ч 00 мин';
    final created = DateTime.tryParse(iso);
    if (created == null) return '12 ч 00 мин';
    final endsAt = created.add(const Duration(hours: 12));
    final left = endsAt.difference(DateTime.now());
    if (left.isNegative) return '00 ч 00 мин';
    final h = left.inHours;
    final m = left.inMinutes % 60;
    final hh = h.toString().padLeft(2, '0');
    final mm = m.toString().padLeft(2, '0');
    return '$hh ч $mm мин';
  }
}

class _CartBottomNav extends StatelessWidget {
  const _CartBottomNav();

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.secondaryBg,
        boxShadow: shadowSm,
        border: const Border(top: BorderSide(color: AppColors.divider)),
      ),
      padding: EdgeInsets.fromLTRB(8, 8, 8, bottomPad + 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _NavItem(
            icon: Icons.home_rounded,
            label: 'Главная',
            onTap: () => context.go('/home'),
          ),
          _NavItem(
            icon: Icons.calendar_month_rounded,
            label: 'План',
            onTap: () => context.go('/plan'),
          ),
          _NavItem(
            icon: Icons.place_rounded,
            label: 'Визиты',
            onTap: () => context.go('/visits'),
          ),
          _NavItem(
            icon: Icons.bookmark_rounded,
            label: 'База',
            onTap: () => context.go('/knowledge'),
          ),
          _NavItem(
            icon: Icons.person_rounded,
            label: 'Профиль',
            onTap: () => context.go('/profile'),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AppTapScale(
      onTap: onTap,
      child: SizedBox(
        width: 64,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 22, color: AppColors.hintText),
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.manrope(
                fontSize: 10,
                color: AppColors.hintText,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

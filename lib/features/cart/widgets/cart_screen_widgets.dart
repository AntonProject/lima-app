part of '../screens/cart_screen.dart';

class _CartGroup {
  final int? pharmacyId;
  final String pharmacyName;
  final String? addedAt;
  final int? cartId;
  final int prepaymentPercent;
  final int buyerType;
  final List<CartItemSnapshot> items;

  const _CartGroup({
    required this.pharmacyId,
    required this.pharmacyName,
    required this.addedAt,
    required this.cartId,
    required this.prepaymentPercent,
    required this.buyerType,
    required this.items,
  });

  String get identityKey =>
      '${cartId ?? 0}:${pharmacyId ?? 0}:$prepaymentPercent:$buyerType:$pharmacyName';

  int get count => items.fold(0, (sum, item) => sum + item.quantity);
  double get total => items.fold(0, (sum, item) => sum + item.total);
  String get buyerLabel => buyerType == 1 ? 'Опт' : 'Розница';

  factory _CartGroup.fromItems(List<CartItemSnapshot> items) {
    final first = items.first;
    return _CartGroup(
      pharmacyId: first.pharmacyId,
      pharmacyName: first.pharmacyName?.isNotEmpty == true
          ? first.pharmacyName!
          : 'Аптека',
      addedAt: first.addedAt,
      cartId: first.cartId,
      prepaymentPercent: first.prepaymentPercent ?? 100,
      buyerType: first.buyerType ?? 0,
      items: List.unmodifiable(items),
    );
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
            label: context.l10n.t('navHome'),
            onTap: () => context.go('/home'),
          ),
          _NavItem(
            icon: Icons.calendar_month_rounded,
            label: context.l10n.t('navPlan'),
            onTap: () => context.go('/plan'),
          ),
          _NavItem(
            icon: Icons.place_rounded,
            label: context.l10n.t('navVisits'),
            onTap: () => context.go('/visits'),
          ),
          _NavItem(
            icon: Icons.bookmark_rounded,
            label: context.l10n.t('navKnowledge'),
            onTap: () => context.go('/knowledge'),
          ),
          _NavItem(
            icon: Icons.person_rounded,
            label: context.l10n.t('navProfile'),
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

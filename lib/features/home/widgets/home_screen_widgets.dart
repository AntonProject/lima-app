part of '../screens/home_screen.dart';

/// Shared fixed height for the home activity / quick-action cards so both
/// rows line up. Content is single-line (counts, short labels) and ellipsized.
// 84 (not 82): the stacked title/value/subtitle text needs ~82px and font
// ascent/descent rounding pushed it 1px over, causing a RenderFlex overflow.
const double _homeCardHeight = 84;

class _ActivityCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final Color iconBg;
  final IconData icon;
  final Color iconColor;
  final VoidCallback? onTap;

  const _ActivityCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.iconBg,
    required this.icon,
    required this.iconColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AppTapScale(
      onTap: onTap,
      pressedScale: 0.95,
      child: Container(
        height: _homeCardHeight,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.secondaryBg,
          borderRadius: BorderRadius.circular(12),
          boxShadow: shadowSm,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Text block: title → value → subtitle stacked on the left.
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    // Nudge the title baseline up to the icon's top edge.
                    padding: const EdgeInsets.only(top: 1),
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.manrope(
                        fontSize: 11,
                        height: 1.25,
                        color: AppColors.secondaryText,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.manrope(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      height: 1.25,
                      color: AppColors.primaryText,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.manrope(
                      fontSize: 11,
                      height: 1.25,
                      color: AppColors.secondaryText,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Icon pinned to the top-right of the whole text block.
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: iconColor, size: 17),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Color iconBg;
  final IconData icon;
  final Color iconColor;
  final VoidCallback onTap;
  final int? badgeCount;

  const _QuickCard({
    required this.title,
    required this.subtitle,
    required this.iconBg,
    required this.icon,
    required this.iconColor,
    required this.onTap,
    this.badgeCount,
  });

  @override
  Widget build(BuildContext context) {
    return AppTapScale(
      onTap: onTap,
      pressedScale: 0.95,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.secondaryBg,
          borderRadius: BorderRadius.circular(12),
          boxShadow: shadowSm,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon (with optional badge) on the left.
            SizedBox(
              width: 36,
              height: 36,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: iconBg,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Icon(icon, color: iconColor, size: 20),
                  ),
                  if ((badgeCount ?? 0) > 0)
                    Positioned(
                      top: -4,
                      right: -4,
                      child: Container(
                        width: 16,
                        height: 16,
                        decoration: const BoxDecoration(
                          color: Color(0xFFEF3340),
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '${badgeCount!}',
                          style: GoogleFonts.manrope(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Title + subtitle aligned to the icon's top/bottom edges (with a
            // 2px inset), matching the profile stat cards.
            Expanded(
              child: SizedBox(
                height: 36,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.manrope(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          height: 1.0,
                          color: AppColors.primaryText,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        subtitle.isNotEmpty ? subtitle : '',
                        style: GoogleFonts.manrope(
                          fontSize: 11,
                          height: 1.0,
                          color: AppColors.secondaryText,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
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

class _VisitItem extends StatelessWidget {
  final String name;
  final String id;
  final String date;
  final String time;
  final String status;
  final String statusKey;
  final String type;
  final String subType;
  final String pharmacistsFio;
  final int participantsCount;
  final String firstDrugName;
  final VoidCallback onTap;

  const _VisitItem({
    required this.name,
    required this.id,
    required this.date,
    required this.time,
    required this.status,
    required this.statusKey,
    required this.type,
    required this.subType,
    required this.pharmacistsFio,
    required this.participantsCount,
    required this.onTap,
    this.firstDrugName = '',
  });

  @override
  Widget build(BuildContext context) {
    final isLpu = type == 'lpu';
    final isStock = type == 'stock';
    final isCircle = type == 'pharmacy' && subType == 'circle';
    final localizedStatus = switch (statusKey) {
      'completed' => context.l10n.t('conducted'),
      'in_progress' => context.l10n.t('visitStatusInProgress'),
      'cancelled' => context.l10n.t('cancelled'),
      _ => context.l10n.t('visitStatusPlanned'),
    };
    final (statusBg, statusFg) = switch (statusKey) {
      'completed' => (const Color(0xFFEFF2F7), const Color(0xFF77839A)),
      'in_progress' => (const Color(0xFFFAF1DF), const Color(0xFFC89B3C)),
      'cancelled' => (const Color(0xFFFCE7E7), const Color(0xFFE35D5B)),
      _ => (const Color(0xFFEAF0FF), AppColors.primary),
    };
    return AppTapScale(
      onTap: onTap,
      pressedScale: 0.95,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.secondaryBg,
          borderRadius: BorderRadius.circular(12),
          boxShadow: shadowSm,
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isLpu
                    ? AppColors.iconBgBlue
                    : (isStock
                          ? const Color(0xFFFFF3DB)
                          : isCircle
                          ? const Color(0xFFDDF5E6)
                          : AppColors.iconBgGreen),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                isLpu
                    ? AppIcons.company
                    : (isStock
                          ? AppIcons.package
                          : isCircle
                          ? AppIcons.add
                          : AppIcons.materials),
                color: isLpu
                    ? AppColors.primary
                    : (isStock
                          ? const Color(0xFFE3A335)
                          : isCircle
                          ? const Color(0xFF2AA65A)
                          : AppColors.success),
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name gets the full first line; the id + status badge move
                  // down to the date row so long names aren't truncated early.
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.manrope(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primaryText,
                    ),
                  ),
                  if (!isLpu && !isCircle && firstDrugName.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      firstDrugName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.manrope(
                        fontSize: 12,
                        color: AppColors.secondaryText,
                      ),
                    ),
                  ],
                  const SizedBox(height: 2),
                  if (isCircle && pharmacistsFio != '—')
                    Row(
                      children: [
                        Text(
                          '$date  ',
                          style: GoogleFonts.manrope(
                            fontSize: 12,
                            color: AppColors.secondaryText,
                          ),
                        ),
                        Icon(
                          AppIcons.users,
                          size: 13,
                          color: Color(0xFF2AA65A),
                        ),
                        const SizedBox(width: 3),
                        Expanded(
                          child: RichText(
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            text: TextSpan(
                              style: GoogleFonts.manrope(fontSize: 12),
                              children: [
                                TextSpan(
                                  text: pharmacistsFio,
                                  style: const TextStyle(
                                    color: Color(0xFF2AA65A),
                                  ),
                                ),
                                if (participantsCount > 0)
                                  TextSpan(
                                    text:
                                        ' (${context.l10n.t('participantsN', args: {'count': '$participantsCount'})})',
                                    style: const TextStyle(
                                      color: Color(0xFF8390A3),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    )
                  else
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '$date  $time',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.manrope(
                              fontSize: 12,
                              color: AppColors.secondaryText,
                            ),
                          ),
                        ),
                        if (id.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Text(
                            id,
                            style: GoogleFonts.manrope(
                              fontSize: 11,
                              color: AppColors.secondaryText,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: statusBg,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            localizedStatus,
                            style: GoogleFonts.manrope(
                              fontSize: 10,
                              color: statusFg,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            Icon(AppIcons.chevronRight, color: AppColors.hintText, size: 20),
          ],
        ),
      ),
    );
  }
}

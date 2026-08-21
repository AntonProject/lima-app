part of '../screens/home_screen.dart';

/// Shared fixed height for the home activity / quick-action cards so both
/// rows line up. Content is single-line (counts, short labels) and ellipsized.
// 84 (not 82): the stacked title/value/subtitle text needs ~82px and font
// ascent/descent rounding pushed it 1px over, causing a RenderFlex overflow.
const double _homeCardHeight = 84;

class _WorkdayCard extends ConsumerWidget {
  const _WorkdayCard();

  Future<void> _finishWorkday(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(workdayProvider.notifier).end();
    } catch (error) {
      if (!context.mounted) return;
      _showWorkdayError(
        context,
        error,
        fallback: context.l10n.t('workdayEndFailed'),
      );
    }
  }

  void _startWorkday(BuildContext context) {
    showAppSheet<void>(
      context,
      // The workday picker must sit above the persistent tab bar. The local
      // shell navigator renders the bar after its child, so use the root
      // navigator for this modal route.
      useRootNavigator: true,
      backgroundColor: AppColors.secondaryBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _WorkdayTypeSheet(hostContext: context),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(workdayProvider);
    final phase = state.workday.phase;
    final isStarting = state.action == WorkdayAction.starting;
    final isEnding = state.action == WorkdayAction.ending;
    final isNotStarted = phase == WorkdayPhase.notStarted;
    final isActive = phase == WorkdayPhase.active;
    final isCompleted = phase == WorkdayPhase.completed;

    final badgeColor = isNotStarted || isCompleted
        ? AppColors.secondaryText
        : AppColors.success;
    final badgeLabel = switch (phase) {
      WorkdayPhase.notStarted => context.l10n.t('workdayNotStarted'),
      WorkdayPhase.active => context.l10n.t('workday'),
      WorkdayPhase.completed => context.l10n.t('workdayCompleted'),
    };
    final title = switch (phase) {
      WorkdayPhase.notStarted => context.l10n.t('selectWorkdayType'),
      WorkdayPhase.active =>
        state.workday.dayTypeName ?? context.l10n.t('workday'),
      WorkdayPhase.completed => context.l10n.t('workdayCompleted'),
    };
    final time = _workdayTime(
      isCompleted ? state.workday.endTime : state.workday.startTime,
    );
    final subtitle = switch (phase) {
      WorkdayPhase.notStarted => context.l10n.t('tapToStartWorkday'),
      WorkdayPhase.active => context.l10n.t(
        'workdayStartedAt',
        args: {'time': time},
      ),
      WorkdayPhase.completed => context.l10n.t(
        'workdayEndedAt',
        args: {'time': time},
      ),
    };

    final card = Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isActive ? AppColors.primary : AppColors.border,
          width: isActive ? 1.5 : 1,
        ),
        boxShadow: shadowSm,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: badgeColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!isNotStarted) ...[
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: badgeColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                      ],
                      Text(
                        badgeLabel,
                        style: GoogleFonts.manrope(
                          color: badgeColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.manrope(
                    color: AppColors.primaryText,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.manrope(
                    color: AppColors.secondaryText,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          if (isNotStarted)
            Icon(AppIcons.chevronRight, size: 22, color: AppColors.hintText)
          else if (isActive)
            SizedBox(
              height: 36,
              child: FilledButton(
                onPressed: isEnding ? null : () => _finishWorkday(context, ref),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  backgroundColor: AppColors.error.withValues(alpha: 0.1),
                  foregroundColor: AppColors.error,
                  elevation: 0,
                  textStyle: GoogleFonts.manrope(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                child: isEnding
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.error,
                        ),
                      )
                    : Text(context.l10n.t('endWorkday')),
              ),
            ),
        ],
      ),
    );

    if (!isNotStarted) return card;
    return AppTapScale(
      onTap: isStarting ? null : () => _startWorkday(context),
      pressedScale: 0.98,
      child: card,
    );
  }
}

class _WorkdayTypeSheet extends ConsumerStatefulWidget {
  const _WorkdayTypeSheet({required this.hostContext});

  final BuildContext hostContext;

  @override
  ConsumerState<_WorkdayTypeSheet> createState() => _WorkdayTypeSheetState();
}

class _WorkdayTypeSheetState extends ConsumerState<_WorkdayTypeSheet> {
  WorkdayDayType? _selected;

  Future<void> _submit(WorkdayDayType? selected) async {
    if (selected == null) return;
    try {
      await ref.read(workdayProvider.notifier).start(dayType: selected);
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
    } catch (error) {
      if (!mounted) return;
      final hostContext = widget.hostContext;
      Navigator.of(context, rootNavigator: true).pop();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!hostContext.mounted) return;
        _showWorkdayError(
          hostContext,
          error,
          fallback: hostContext.l10n.t('workdayStartFailed'),
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(workdayProvider);
    final isStarting = state.action == WorkdayAction.starting;
    final selectedDayType = _selected;
    final bottom =
        MediaQuery.viewInsetsOf(context).bottom +
        MediaQuery.paddingOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 12, 16, bottom + 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: Text(
                  context.l10n.t('selectWorkdayType'),
                  style: GoogleFonts.manrope(
                    color: AppColors.primaryText,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              AppTapScale(
                pressedScale: 0.9,
                onTap: isStarting
                    ? null
                    : () => Navigator.of(context, rootNavigator: true).pop(),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppColors.primaryBg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.close_rounded,
                    size: 18,
                    color: AppColors.secondaryText,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: AppColors.divider),
          const SizedBox(height: 12),
          if (state.dayTypes.isEmpty && state.isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: CircularProgressIndicator(),
              ),
            )
          else
            ...state.dayTypes.map((dayType) {
              final isSelected = selectedDayType?.id == dayType.id;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: AppTapScale(
                  onTap: isStarting
                      ? null
                      : () => setState(() => _selected = dayType),
                  pressedScale: 0.98,
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 68),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 9,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.primary.withValues(alpha: 0.07)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? AppColors.primary
                            : AppColors.border,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            _dayTypeIcon(dayType.id),
                            color: _dayTypeColor(dayType.id),
                            size: 23,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                dayType.name,
                                style: GoogleFonts.manrope(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primaryText,
                                ),
                              ),
                              if (dayType.description.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  dayType.description,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.manrope(
                                    fontSize: 11.5,
                                    color: AppColors.secondaryText,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        if (isSelected)
                          Container(
                            width: 28,
                            height: 28,
                            alignment: Alignment.center,
                            decoration: const BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              AppIcons.check,
                              color: Colors.white,
                              size: 18,
                            ),
                          )
                        else
                          Icon(
                            AppIcons.chevronRight,
                            color: AppColors.hintText,
                            size: 18,
                          ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          const SizedBox(height: 2),
          const Divider(height: 1, color: AppColors.divider),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: selectedDayType == null || isStarting
                ? null
                : () => _submit(selectedDayType),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 50),
              disabledBackgroundColor: AppColors.primary.withValues(
                alpha: 0.55,
              ),
              disabledForegroundColor: Colors.white.withValues(alpha: 0.95),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              textStyle: GoogleFonts.manrope(
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            child: isStarting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(AppIcons.location, size: 20),
                      const SizedBox(width: 10),
                      Text(context.l10n.t('startWorkday')),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

void _showWorkdayError(
  BuildContext context,
  Object error, {
  required String fallback,
}) {
  final message = error is WorkdayActionException
      ? error.message ?? fallback
      : fallback;
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
    return;
  }

  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (context) => Positioned(
      top: MediaQuery.paddingOf(context).top + 12,
      left: 0,
      right: 0,
      child: IgnorePointer(
        child: Center(
          child: Material(
            color: Colors.transparent,
            child: TweenAnimationBuilder<double>(
              duration: const Duration(milliseconds: 180),
              tween: Tween(begin: 0, end: 1),
              curve: Curves.easeOutCubic,
              builder: (context, opacity, child) =>
                  Opacity(opacity: opacity, child: child),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.sizeOf(context).width * 0.8,
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: shadowLg,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        alignment: Alignment.center,
                        decoration: const BoxDecoration(
                          color: AppColors.error,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Flexible(
                        child: Text(
                          message,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.manrope(
                            color: AppColors.primaryText,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  overlay.insert(entry);
  Future<void>.delayed(const Duration(seconds: 4)).then((_) => entry.remove());
}

String _workdayTime(String? raw) {
  final value = raw == null ? null : DateTime.tryParse(raw);
  if (value == null) return '—';

  // The API returns a wall-clock value shifted by the user's UTC offset but
  // without an explicit offset. Use the device timezone instead of a fixed
  // Tashkent-only correction.
  final localValue = value.subtract(DateTime.now().timeZoneOffset);
  return '${localValue.hour.toString().padLeft(2, '0')}:${localValue.minute.toString().padLeft(2, '0')}';
}

IconData _dayTypeIcon(int id) => switch (id) {
  1 => AppIcons.location,
  2 => AppIcons.company,
  3 => AppIcons.pharmacy,
  _ => AppIcons.calendar,
};

Color _dayTypeColor(int id) => switch (id) {
  3 => AppColors.accent,
  _ => AppColors.primary,
};

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
      'pending' => context.l10n.t('orderPendingSync'),
      'sync_failed' => context.l10n.t('orderSyncFailed'),
      'in_progress' => context.l10n.t('visitStatusInProgress'),
      'cancelled' => context.l10n.t('cancelled'),
      _ => context.l10n.t('visitStatusPlanned'),
    };
    final (statusBg, statusFg) = switch (statusKey) {
      'completed' => (const Color(0xFFEFF2F7), const Color(0xFF77839A)),
      'pending' => (const Color(0xFFFFF4D6), const Color(0xFFB88700)),
      'sync_failed' => (const Color(0xFFFCE7E7), const Color(0xFFE35D5B)),
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

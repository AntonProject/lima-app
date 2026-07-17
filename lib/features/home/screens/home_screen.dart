import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/widgets/app_widgets.dart';
import 'package:lima/features/auth/providers/auth_provider.dart';
import 'package:lima/core/dialogs/feedback_dialog.dart';
import 'package:lima/core/providers/app_collections_provider.dart';
import 'package:lima/core/providers/connectivity_provider.dart';
import 'package:lima/core/providers/locale_provider.dart';
import 'package:lima/core/providers/dashboard_counts_provider.dart';
import 'package:lima/core/providers/sync_provider.dart';
import 'package:lima/core/services/in_app_notifications_service.dart';
import 'package:lima/features/offline/domain/entities/sync_data_change.dart';
import 'package:lima/features/home/domain/repositories/home_repository.dart';
import 'package:lima/features/home/presentation/view_models/home_recent_visits_view_model.dart';
import 'package:lima/features/home/providers/home_repository_provider.dart';
import 'package:lima/features/home/providers/home_recent_visits_provider.dart';
import 'package:lima/shell/nav_bar_layout.dart';
import 'package:lima/core/i18n/app_i18n.dart';
import 'package:lima/core/utils/swallowed.dart';

part '../widgets/home_screen_widgets.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  /// Loads recent visits from the local repository into the warm cache so the
  /// home screen renders instantly on first navigation after the splash.
  static Future<void> preload(HomeRepository repository) async {
    await HomeRecentVisitsViewModel.preload(repository);
  }

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with WidgetsBindingObserver {
  String? _lastRefreshToken;
  DateTime? _lastSyncSeenAt;
  StreamSubscription<SyncDataChange>? _dbChangesSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _dbChangesSub = ref.read(homeRepositoryProvider).changes.listen((change) {
      if (!mounted) return;
      if (change.containsAny(const [SyncDataTable.visits])) {
        ref.read(homeRecentVisitsProvider.notifier).load();
        ref.invalidate(dashboardCountsProvider);
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(appCollectionsProvider.notifier).clearExpiredCartItems();
    });
    ref.read(homeRecentVisitsProvider.notifier).load();
  }

  @override
  void dispose() {
    _dbChangesSub?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    String? token;
    try {
      token = GoRouterState.of(context).uri.queryParameters['refresh'];
    } catch (error) {
      logSwallowed(error, 'HomeScreen.routeRefreshToken');
    }
    if (token != null && token != _lastRefreshToken) {
      _lastRefreshToken = token;
      ref.invalidate(dashboardCountsProvider);
      ref.read(homeRecentVisitsProvider.notifier).load();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.invalidate(dashboardCountsProvider);
      ref.read(appCollectionsProvider.notifier).clearExpiredCartItems();
      ref.read(homeRecentVisitsProvider.notifier).load();
      if (!ref.read(isOfflineProvider)) {
        ref.read(syncProvider.notifier).reconcileInBackground();
      }
    }
  }

  PopupMenuItem<String> _langMenuItem(
    String value,
    String flag,
    String label,
    String current,
  ) {
    return PopupMenuItem<String>(
      value: value,
      child: Row(
        children: [
          Text(flag, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 10),
          Text(
            label,
            style: GoogleFonts.manrope(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppColors.primaryText,
            ),
          ),
          const Spacer(),
          if (current == value)
            Icon(AppIcons.check, size: 16, color: AppColors.primary),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('[HOME] build start');
    final user = ref.watch(authProvider).user;
    final recentVisitsState = ref.watch(homeRecentVisitsProvider);
    final recentVisits = recentVisitsState.visits;
    final syncState = ref.watch(syncProvider);
    final collections = ref.watch(appCollectionsProvider);
    final dashboardCounts = ref.watch(dashboardCountsProvider).valueOrNull;
    // A local-DB read failure means these counts are a fallback zero, not a
    // genuinely empty day — show "—" instead of a misleading "0".
    final dashboardCountsReliable = dashboardCounts?.isReliable ?? true;
    final locale = ref.watch(appLocaleProvider);
    final unreadNotifications =
        ref.watch(unreadNotificationsCountProvider).valueOrNull ?? 0;
    ref.listen<SyncState>(syncProvider, (prev, next) {
      final prevAt = prev?.lastSyncAt;
      final nextAt = next.lastSyncAt;
      if (nextAt == null) return;
      if (_lastSyncSeenAt != null &&
          nextAt.millisecondsSinceEpoch ==
              _lastSyncSeenAt!.millisecondsSinceEpoch) {
        return;
      }
      if (prevAt == null ||
          nextAt.millisecondsSinceEpoch != prevAt.millisecondsSinceEpoch) {
        _lastSyncSeenAt = nextAt;
        ref.invalidate(dashboardCountsProvider);
        ref.read(homeRecentVisitsProvider.notifier).load();
      }
    });
    debugPrint('[HOME] build, user=${user?.fullName}');

    return Scaffold(
      backgroundColor: AppColors.primaryBg,
      body: Column(
        children: [
          // ── Fixed Blue Header ───────────────────────────────────────────
          Container(
            decoration: const BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(20),
                bottomRight: Radius.circular(20),
              ),
            ),
            padding: EdgeInsets.fromLTRB(
              12,
              MediaQuery.of(context).padding.top + 10,
              12,
              8,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Image.asset(
                      'assets/images/lima_logo_2.png',
                      width: 44,
                      height: 44,
                    ),
                    Image.asset('assets/images/lima_text.png', height: 14),
                    const Spacer(),
                    Builder(
                      builder: (btnCtx) => AppTapScale(
                        onTap: () async {
                          final box = btnCtx.findRenderObject()! as RenderBox;
                          final overlay =
                              Navigator.of(
                                    btnCtx,
                                  ).overlay!.context.findRenderObject()!
                                  as RenderBox;
                          final pos = RelativeRect.fromRect(
                            Rect.fromPoints(
                              box.localToGlobal(
                                Offset(0, box.size.height + 4),
                                ancestor: overlay,
                              ),
                              box.localToGlobal(
                                Offset(box.size.width, box.size.height + 4),
                                ancestor: overlay,
                              ),
                            ),
                            Offset.zero & overlay.size,
                          );
                          final current = _localeCode(locale);
                          final selected = await showMenu<String>(
                            context: btnCtx,
                            position: pos,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            color: AppColors.secondaryBg,
                            elevation: 4,
                            items: [
                              _langMenuItem('ru', '🇷🇺', 'Русский', current),
                              _langMenuItem('en', '🇬🇧', 'English', current),
                              _langMenuItem(
                                'uz_latn',
                                '🇺🇿',
                                'O\'zbekcha',
                                current,
                              ),
                              _langMenuItem(
                                'uz_cyrl',
                                '🇺🇿',
                                'Ўзбекча',
                                current,
                              ),
                            ],
                          );
                          if (selected != null && mounted) {
                            await ref
                                .read(appLocaleProvider.notifier)
                                .setLocale(selected);
                          }
                        },
                        pressedScale: 0.93,
                        child: Container(
                          width: 44,
                          height: 36,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.3),
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(switch (_localeCode(locale)) {
                            'en' => '🇬🇧',
                            'uz_latn' || 'uz_cyrl' => '🇺🇿',
                            _ => '🇷🇺',
                          }, style: const TextStyle(fontSize: 18)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    AppTapScale(
                      onTap: () async {
                        await context.push('/notifications');
                        // Refresh the unread badge after returning.
                        ref.invalidate(unreadNotificationsCountProvider);
                      },
                      pressedScale: 0.93,
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.3),
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Stack(
                          clipBehavior: Clip.none,
                          alignment: Alignment.center,
                          children: [
                            Icon(AppIcons.bell, color: Colors.white, size: 19),
                            if (unreadNotifications > 0)
                              Positioned(
                                top: 6,
                                right: 7,
                                child: Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: AppColors.accent,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: AppColors.primary,
                                      width: 1,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.only(
                top: 10,
                bottom: LimaNavBarLayout.scrollBottomPadding(context),
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Activity section ───────────────────────────────────────
                      Text(
                        context.l10n.t('myActivityToday'),
                        style: GoogleFonts.manrope(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _ActivityCard(
                              title: context.l10n.t('visitsToday'),
                              value: dashboardCountsReliable
                                  ? '${dashboardCounts?.visitsTodayCount ?? 0}'
                                  : '—',
                              subtitle: dashboardCountsReliable
                                  ? context.l10n.t(
                                      'lpuStats',
                                      args: {
                                        'lpu':
                                            '${dashboardCounts?.lpuTodayCount ?? 0}',
                                        'pharmacy':
                                            '${dashboardCounts?.pharmacyTodayCount ?? 0}',
                                      },
                                    )
                                  : context.l10n.t('dataUnavailable'),
                              iconBg: AppColors.iconBgBlue,
                              icon: AppIcons.calendar,
                              iconColor: AppColors.primary,
                              onTap: () =>
                                  context.push('/visits/history?range=today'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _ActivityCard(
                              title: context.l10n.t('sales'),
                              value: formatUzs(
                                user?.salesAmount ?? 0,
                                short: true,
                              ),
                              subtitle: 'UZS ${context.l10n.t('forToday')}',
                              iconBg: AppColors.iconBgGreen,
                              icon: AppIcons.sales,
                              iconColor: AppColors.success,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // ── Quick actions ──────────────────────────────────────────
                      Text(
                        context.l10n.t('quickActions'),
                        style: GoogleFonts.manrope(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _QuickCard(
                              title: context.l10n.t('favoriteDoctors'),
                              subtitle: context.l10n.t('quickAccess'),
                              iconBg: AppColors.iconBgPurple,
                              icon: AppIcons.profile,
                              iconColor: AppColors.primary,
                              onTap: () => context.push('/profile/fav-doctors'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _QuickCard(
                              title: context.l10n.t('cart'),
                              subtitle: collections.cartCount > 0
                                  ? '${collections.cartCount} ${context.l10n.t('items')}'
                                  : '0 ${context.l10n.t('orders')}',
                              iconBg: AppColors.iconBgOrange,
                              icon: AppIcons.cart,
                              iconColor: AppColors.accent,
                              badgeCount: collections.cartCount > 0
                                  ? collections.cartCount
                                  : null,
                              onTap: () => context.push('/basket'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      AppTapScale(
                        onTap: () => context.go('/visits'),
                        pressedScale: 0.97,
                        child: ElevatedButton.icon(
                          onPressed: null,
                          icon: Icon(AppIcons.location, size: 16),
                          label: Text(context.l10n.t('startWork')),
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 44),
                            disabledBackgroundColor: AppColors.primary,
                            disabledForegroundColor: Colors.white,
                            textStyle: GoogleFonts.manrope(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      AppTapScale(
                        onTap: () => showFeedbackDialog(context),
                        pressedScale: 0.97,
                        child: OutlinedButton.icon(
                          onPressed: null,
                          icon: Icon(AppIcons.send, size: 18),
                          label: Text(context.l10n.t('feedback')),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 44),
                            backgroundColor: Colors.white,
                            disabledBackgroundColor: Colors.white,
                            disabledForegroundColor: AppColors.primary,
                            side: const BorderSide(color: AppColors.primary),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            textStyle: GoogleFonts.manrope(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // ── Recent visits ──────────────────────────────────────────
                      Row(
                        children: [
                          Text(
                            context.l10n.t('recentVisits'),
                            style: GoogleFonts.manrope(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.black,
                            ),
                          ),
                          const Spacer(),
                          GestureDetector(
                            onTap: () => context.push('/visits/history'),
                            child: Text(
                              context.l10n.t('viewAll'),
                              style: GoogleFonts.manrope(
                                fontSize: 12,
                                color: AppColors.primary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (recentVisits.isNotEmpty)
                        ...recentVisits.map(
                          (v) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _VisitItem(
                              name: v.name.isEmpty
                                  ? context.l10n.t('visit')
                                  : v.name,
                              id: v.id.isEmpty ? '' : '#${v.id}',
                              date: () {
                                if (v.dateDay == null ||
                                    v.dateMonthIdx == null) {
                                  return '';
                                }
                                final months = [
                                  context.l10n.t('monthJan'),
                                  context.l10n.t('monthFeb'),
                                  context.l10n.t('monthMar'),
                                  context.l10n.t('monthApr'),
                                  context.l10n.t('monthMay'),
                                  context.l10n.t('monthJun'),
                                  context.l10n.t('monthJul'),
                                  context.l10n.t('monthAug'),
                                  context.l10n.t('monthSep'),
                                  context.l10n.t('monthOct'),
                                  context.l10n.t('monthNov'),
                                  context.l10n.t('monthDec'),
                                ];
                                return '${v.dateDay} ${months[(v.dateMonthIdx! - 1).clamp(0, 11)]}';
                              }(),
                              time: v.timeLabel,
                              status: _l10nStatus(context, v.statusKey),
                              statusKey: v.statusKey,
                              type: v.type,
                              subType: v.subType,
                              pharmacistsFio: v.pharmacistsFio,
                              participantsCount: v.participantsCount,
                              firstDrugName: v.firstDrugName,
                              onTap: () => context.push(
                                Uri(
                                  path: '/visits/history',
                                  queryParameters: {
                                    if (v.id.isNotEmpty) 'visitId': v.id,
                                    'type': v.type,
                                    'openFirst': '1',
                                  },
                                ).toString(),
                              ),
                            ),
                          ),
                        )
                      else if (recentVisitsState.isLoading)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Center(
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      else
                        EmptyState(
                          icon: AppIcons.calendarX,
                          title: context.l10n.t('noVisitsPlanned'),
                        ),
                      const SizedBox(height: 12),
                      Text(
                        context.l10n.t('offlineAndSync'),
                        style: GoogleFonts.manrope(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: () => context.push('/sync'),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.secondaryBg,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: shadowSm,
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: syncState.unsyncedCount > 0
                                      ? const Color(0xFFFFF3E0)
                                      : AppColors.iconBgGreen,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  syncState.unsyncedCount > 0
                                      ? AppIcons.alert
                                      : AppIcons.cloud,
                                  color: syncState.unsyncedCount > 0
                                      ? AppColors.accent
                                      : AppColors.success,
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      context.l10n.t('offlineMode'),
                                      style: GoogleFonts.manrope(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.primaryText,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      syncState.unsyncedCount > 0
                                          ? context.l10n.t(
                                              'notSyncedShort',
                                              args: {
                                                'count':
                                                    '${syncState.unsyncedCount}',
                                              },
                                            )
                                          : context.l10n.t('syncedShort'),
                                      style: GoogleFonts.manrope(
                                        fontSize: 11,
                                        color: syncState.unsyncedCount > 0
                                            ? AppColors.accent
                                            : AppColors.success,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(
                                Icons.chevron_right_rounded,
                                color: AppColors.hintText,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _l10nStatus(BuildContext context, String key) {
  switch (key) {
    case 'completed':
      return context.l10n.t('conducted');
    case 'in_progress':
      return context.l10n.t('visitStatusInProgress');
    case 'cancelled':
      return context.l10n.t('cancelled');
    default:
      return context.l10n.t('visitStatusPlanned');
  }
}

String _localeCode(Locale locale) {
  if (locale.languageCode == 'uz' && locale.scriptCode == 'Cyrl') {
    return 'uz_cyrl';
  }
  if (locale.languageCode == 'uz') return 'uz_latn';
  return locale.languageCode;
}

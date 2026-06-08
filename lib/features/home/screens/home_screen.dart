import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_widgets.dart';
import 'package:lima/features/auth/providers/auth_provider.dart';
import 'package:lima/core/dialogs/feedback_dialog.dart';
import 'package:lima/core/providers/app_collections_provider.dart';
import 'package:lima/core/providers/connectivity_provider.dart';
import 'package:lima/core/providers/locale_provider.dart';
import 'package:lima/core/providers/dashboard_counts_provider.dart';
import 'package:lima/core/providers/sync_provider.dart';
import 'package:lima/core/db/local_database.dart';
import 'package:lima/shell/nav_bar_layout.dart';
import 'package:lima/core/i18n/app_i18n.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  /// Loads recent visits from the local DB into the static cache so the
  /// home screen renders instantly on first navigation after the splash.
  static Future<void> preload(LocalDatabase db) async {
    try {
      final dbRows = await db.getVisits().timeout(
        const Duration(seconds: 6),
        onTimeout: () => const <Map<String, dynamic>>[],
      );
      _HomeScreenState._cachedRecentVisits =
          _HomeScreenState._processVisitRows(dbRows);
    } catch (_) {
      // Best-effort prewarm — home will retry via its own _loadRecentVisits().
    }
  }

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with WidgetsBindingObserver {
  static List<_RecentVisitVm> _cachedRecentVisits = const [];

  bool _loadingRecent = false;
  bool _loadingRecentInFlight = false;
  List<_RecentVisitVm> _recentVisits = const [];
  String? _lastRefreshToken;
  DateTime? _lastSyncSeenAt;
  StreamSubscription<Set<String>>? _dbChangesSub;

  @override
  void initState() {
    super.initState();
    _recentVisits = _cachedRecentVisits;
    WidgetsBinding.instance.addObserver(this);
    _dbChangesSub = ref.read(localDatabaseProvider).changes.listen((tables) {
      if (!mounted) return;
      if (tables.contains('visits')) {
        _loadRecentVisits();
        ref.invalidate(dashboardCountsProvider);
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(appCollectionsProvider.notifier).clearExpiredCartItems();
    });
    _loadRecentVisits();
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
    } catch (_) {}
    if (token != null && token != _lastRefreshToken) {
      _lastRefreshToken = token;
      ref.invalidate(dashboardCountsProvider);
      _loadRecentVisits();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.invalidate(dashboardCountsProvider);
      ref.read(appCollectionsProvider.notifier).clearExpiredCartItems();
      _loadRecentVisits();
      if (!ref.read(isOfflineProvider)) {
        ref.read(syncProvider.notifier).reconcileInBackground();
      }
    }
  }

  Future<void> _loadRecentVisits() async {
    if (_loadingRecentInFlight) return;
    _loadingRecentInFlight = true;
    final shouldShowLoader = _recentVisits.isEmpty;
    if (shouldShowLoader && mounted) {
      setState(() => _loadingRecent = true);
    }
    try {
      final db = ref.read(localDatabaseProvider);
      final dbRows = await db.getVisits().timeout(
        const Duration(seconds: 6),
        onTimeout: () => const <Map<String, dynamic>>[],
      );
      final dbNext = _processVisitRows(dbRows);
      if (mounted) {
        setState(() {
          _recentVisits = dbNext;
          _cachedRecentVisits = dbNext;
          _loadingRecent = false;
        });
      }
    } finally {
      _loadingRecentInFlight = false;
      if (mounted && !shouldShowLoader) {
        setState(() => _loadingRecent = false);
      }
    }
  }

  static List<_RecentVisitVm> _processVisitRows(
    List<Map<String, dynamic>> dbRows,
  ) {
    final rows = dbRows.map((e) => Map<String, dynamic>.from(e)).toList();
    final dedup = <String, Map<String, dynamic>>{};
    for (final row in rows) {
      final rid = _safeStr(row['remote_id']);
      final type = _safeStr(row['visit_type'], fallback: 'lpu');
      final created = _safeStr(
        row['created_at'] ?? row['visit_date'] ?? row['date'],
      );
      final key = rid.isNotEmpty ? '${rid}_$type' : '${type}_$created';
      final prev = dedup[key];
      if (prev == null) {
        dedup[key] = row;
        continue;
      }
      final prevDt = _tryDate(
        _safeStr(prev['created_at'] ?? prev['visit_date'] ?? prev['date']),
      );
      final curDt = _tryDate(created);
      if (curDt.isAfter(prevDt)) {
        dedup[key] = row;
      }
    }
    final uniqueRows = dedup.values.toList();
    uniqueRows.sort((a, b) {
      final ad = _tryDate(
        (a['date'] ?? a['visit_date'] ?? a['created_at'])?.toString(),
      );
      final bd = _tryDate(
        (b['date'] ?? b['visit_date'] ?? b['created_at'])?.toString(),
      );
      return bd.compareTo(ad);
    });
    return uniqueRows.take(10).map(_RecentVisitVm.fromMap).toList();
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
            const Icon(LucideIcons.check, size: 16, color: AppColors.primary),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('[HOME] build start');
    final user = ref.watch(authProvider).user;
    final syncState = ref.watch(syncProvider);
    final collections = ref.watch(appCollectionsProvider);
    final dashboardCounts = ref.watch(dashboardCountsProvider).valueOrNull;
    final locale = ref.watch(appLocaleProvider);
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
        _loadRecentVisits();
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
                      width: 48,
                      height: 48,
                    ),
                    Image.asset(
                      'assets/images/lima_text.png',
                      height: 28,
                    ),
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
                          height: 36,
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(switch (_localeCode(locale)) {
                                'en' => '🇬🇧',
                                'uz_latn' || 'uz_cyrl' => '🇺🇿',
                                _ => '🇷🇺',
                              }, style: const TextStyle(fontSize: 14)),
                              const SizedBox(width: 4),
                              Text(
                                switch (_localeCode(locale)) {
                                  'uz_cyrl' => 'ЎЗ',
                                  'uz_latn' => 'UZ',
                                  _ => _localeCode(locale).toUpperCase(),
                                },
                                style: GoogleFonts.manrope(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(width: 2),
                              const Icon(
                                LucideIcons.chevronDown,
                                color: Colors.white,
                                size: 14,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    AppTapScale(
                      onTap: () => context.push('/notifications'),
                      pressedScale: 0.93,
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          LucideIcons.bell,
                          color: Colors.white,
                          size: 19,
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
                top: 12,
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
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primaryText,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _ActivityCard(
                              title: context.l10n.t('visitsToday'),
                              value:
                                  '${dashboardCounts?.visitsTodayCount ?? 0}',
                              subtitle: context.l10n.t(
                                'lpuStats',
                                args: {
                                  'lpu':
                                      '${dashboardCounts?.lpuTodayCount ?? 0}',
                                  'pharmacy':
                                      '${dashboardCounts?.pharmacyTodayCount ?? 0}',
                                },
                              ),
                              iconBg: AppColors.iconBgBlue,
                              icon: LucideIcons.calendarDays,
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
                              icon: LucideIcons.badgeDollarSign,
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
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primaryText,
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
                              icon: LucideIcons.user,
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
                              icon: LucideIcons.shoppingCart,
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
                          icon: const Icon(LucideIcons.mapPin, size: 16),
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
                      const SizedBox(height: 8),
                      AppTapScale(
                        onTap: () => showFeedbackDialog(context),
                        pressedScale: 0.97,
                        child: OutlinedButton.icon(
                          onPressed: null,
                          icon: const Icon(LucideIcons.send, size: 18),
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
                      const SizedBox(height: 16),

                      // ── Recent visits ──────────────────────────────────────────
                      Row(
                        children: [
                          Text(
                            context.l10n.t('recentVisits'),
                            style: GoogleFonts.manrope(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primaryText,
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
                      if (_recentVisits.isNotEmpty)
                        ..._recentVisits.map(
                          (v) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _VisitItem(
                              name: v.name,
                              id: v.id.isEmpty ? '' : '#${v.id}',
                              date: v.dateLabel,
                              time: v.timeLabel,
                              status: v.statusLabel,
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
                      else if (_loadingRecent)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Center(
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      else
                        const EmptyState(
                          icon: LucideIcons.calendarX2,
                          title: 'На эту дату визиты не запланированы',
                        ),
                      const SizedBox(height: 8),
                      Text(
                        context.l10n.t('offlineAndSync'),
                        style: GoogleFonts.manrope(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primaryText,
                        ),
                      ),
                      const SizedBox(height: 10),
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
                                      ? LucideIcons.circleAlert
                                      : LucideIcons.cloud,
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
                                        fontWeight: FontWeight.w800,
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

DateTime _tryDate(String? source) {
  if (source == null || source.isEmpty) {
    return DateTime.fromMillisecondsSinceEpoch(0);
  }
  final direct = DateTime.tryParse(source);
  if (direct != null) return direct;
  final m = RegExp(
    r'^(\d{1,2})\.(\d{1,2})\.(\d{4})(?:[,\s]+(\d{1,2}):(\d{2})(?::(\d{2}))?)?$',
  ).firstMatch(source.trim());
  if (m == null) return DateTime.fromMillisecondsSinceEpoch(0);
  final day = int.tryParse(m.group(1)!);
  final month = int.tryParse(m.group(2)!);
  final year = int.tryParse(m.group(3)!);
  final hour = int.tryParse(m.group(4) ?? '0') ?? 0;
  final minute = int.tryParse(m.group(5) ?? '0') ?? 0;
  final second = int.tryParse(m.group(6) ?? '0') ?? 0;
  if (day == null || month == null || year == null) {
    return DateTime.fromMillisecondsSinceEpoch(0);
  }
  return DateTime(year, month, day, hour, minute, second);
}

String _safeStr(Object? value, {String fallback = ''}) {
  if (value == null) return fallback;
  final s = value.toString();
  if (s.isEmpty || s == 'null') return fallback;
  return s;
}

class _RecentVisitVm {
  final String id;
  final String name;
  final String dateLabel;
  final String timeLabel;
  final String statusLabel;
  final String statusKey;
  final String type;
  final String subType;
  final String pharmacistsFio;
  final int participantsCount;
  final String firstDrugName;

  const _RecentVisitVm({
    required this.id,
    required this.name,
    required this.dateLabel,
    required this.timeLabel,
    required this.statusLabel,
    required this.statusKey,
    required this.type,
    required this.subType,
    required this.pharmacistsFio,
    required this.participantsCount,
    this.firstDrugName = '',
  });

  factory _RecentVisitVm.fromMap(Map<String, dynamic> row) {
    final dt = _tryDate(
      _safeStr(row['date'] ?? row['visit_date'] ?? row['created_at']),
    );
    String resolvedId = _safeStr(row['remote_id'] ?? row['visit_id']);
    final responseRaw = _safeStr(row['last_push_response_json']);
    if ((resolvedId.isEmpty || resolvedId == 'null') &&
        responseRaw.isNotEmpty) {
      try {
        final parsed = jsonDecode(responseRaw);
        if (parsed is int) {
          resolvedId = '$parsed';
        } else if (parsed is String && int.tryParse(parsed) != null) {
          resolvedId = parsed;
        } else if (parsed is Map) {
          final map = Map<String, dynamic>.from(parsed);
          final rid = map['id'] ?? map['visit_id'];
          resolvedId = _safeStr(rid, fallback: resolvedId);
        }
      } catch (_) {}
    }

    final rawJson = _safeStr(row['raw_json']);
    Map<String, dynamic> rawMap = const <String, dynamic>{};
    if (rawJson.isNotEmpty) {
      try {
        final parsed = jsonDecode(rawJson);
        if (parsed is Map) {
          rawMap = Map<String, dynamic>.from(parsed);
        }
      } catch (_) {}
    }
    final orgTypeId = int.tryParse(
      _safeStr(
        row['organization_type_id'] ??
            row['type_id'] ??
            rawMap['organization_type_id'] ??
            rawMap['type_id'],
      ),
    );
    final orgTypeRaw = _safeStr(
      row['organization_type'] ??
          row['org_type'] ??
          rawMap['organization_type'] ??
          rawMap['org_type'],
    ).toLowerCase();
    final visitTypeRaw = _safeStr(
      row['visit_type'] ??
          row['type'] ??
          rawMap['visit_type'] ??
          rawMap['type'],
      fallback: 'lpu',
    ).toLowerCase();
    final type = () {
      if (visitTypeRaw == '4' ||
          visitTypeRaw == '3' ||
          visitTypeRaw == 'stock' ||
          visitTypeRaw == 'remnant') {
        return 'stock';
      }
      if (orgTypeId == 1 ||
          orgTypeRaw.contains('pharm') ||
          orgTypeRaw.contains('аптек') ||
          orgTypeRaw == 'pharmacy') {
        return 'pharmacy';
      }
      if (orgTypeId != null || orgTypeRaw.isNotEmpty) return 'lpu';
      if (visitTypeRaw == '1' ||
          visitTypeRaw == 'order' ||
          visitTypeRaw == 'circle' ||
          visitTypeRaw == 'pharmacy' ||
          visitTypeRaw == 'apteka' ||
          visitTypeRaw == 'аптека') {
        return 'pharmacy';
      }
      return 'lpu';
    }();
    final subType = visitTypeRaw == 'circle' ? 'circle' : '';
    final pharmacistsFio = _safeStr(
      rawMap['pharmacists_fio'] ??
          rawMap['pharmacists'] ??
          rawMap['pharmacist_names'],
      fallback: '—',
    );
    final participantsCount =
        int.tryParse(
          _safeStr(rawMap['participants_count'] ?? rawMap['participants']),
        ) ??
        0;
    String firstDrugName = '';
    try {
      final itemsRaw =
          rawMap['items'] ?? rawMap['drugs'] ?? rawMap['order_items'];
      if (itemsRaw is List && itemsRaw.isNotEmpty) {
        final first = itemsRaw.first;
        if (first is Map) {
          firstDrugName = _safeStr(
            first['drug_name'] ?? first['name'] ?? first['title'],
          );
        }
      }
    } catch (_) {}

    final completeFlag = _safeStr(rawMap['complete']).toLowerCase();
    final statusRaw = _safeStr(
      row['status_name'] ??
          row['status'] ??
          row['visit_status'] ??
          rawMap['status_name'] ??
          rawMap['status'] ??
          rawMap['visit_status'],
    ).toLowerCase();
    final normalizedStatusRaw = (completeFlag == 'true' || completeFlag == '1')
        ? 'completed'
        : statusRaw;
    final statusKey = _statusKeyFromRaw(normalizedStatusRaw);
    return _RecentVisitVm(
      id: resolvedId,
      name: _safeStr(
        row['organization_name'] ?? row['org_name'],
        fallback: 'Визит',
      ),
      dateLabel: () {
        const months = [
          'янв',
          'фев',
          'мар',
          'апр',
          'май',
          'июн',
          'июл',
          'авг',
          'сен',
          'окт',
          'ноя',
          'дек',
        ];
        return '${dt.day} ${months[dt.month - 1]}';
      }(),
      timeLabel:
          '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}',
      statusLabel: _statusLabelFromKey(statusKey),
      statusKey: statusKey,
      type: type,
      subType: subType,
      pharmacistsFio: pharmacistsFio,
      participantsCount: participantsCount,
      firstDrugName: firstDrugName,
    );
  }

  static String _statusKeyFromRaw(String raw) {
    if (raw.contains('completed') ||
        raw.contains('done') ||
        raw.contains('провед')) {
      return 'completed';
    }
    if (raw.contains('cancel') || raw.contains('отмен')) {
      return 'cancelled';
    }
    if (raw.contains('process') ||
        raw.contains('in_progress') ||
        raw.contains('progress')) {
      return 'in_progress';
    }
    if (raw == '1') return 'completed';
    if (raw == '0') return 'planned';
    return 'planned';
  }

  static String _statusLabelFromKey(String key) {
    switch (key) {
      case 'completed':
        return 'Проведено';
      case 'in_progress':
        return 'В процессе';
      case 'cancelled':
        return 'Отменено';
      default:
        return 'План';
    }
  }
}

String _localeCode(Locale locale) {
  if (locale.languageCode == 'uz' && locale.scriptCode == 'Cyrl') {
    return 'uz_cyrl';
  }
  if (locale.languageCode == 'uz') return 'uz_latn';
  return locale.languageCode;
}

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
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.secondaryBg,
          borderRadius: BorderRadius.circular(12),
          boxShadow: shadowSm,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: GoogleFonts.manrope(
                      fontSize: 11,
                      color: AppColors.secondaryText,
                    ),
                  ),
                ),
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
            const SizedBox(height: 6),
            Text(
              value,
              style: GoogleFonts.manrope(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: AppColors.primaryText,
              ),
            ),
            Text(
              subtitle,
              style: GoogleFonts.manrope(
                fontSize: 11,
                color: AppColors.secondaryText,
              ),
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
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.secondaryBg,
          borderRadius: BorderRadius.circular(12),
          boxShadow: shadowSm,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: 40,
              height: 40,
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
            const SizedBox(height: 8),
            Text(
              title,
              style: GoogleFonts.manrope(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: AppColors.primaryText,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
            if (subtitle.isNotEmpty)
              Text(
                subtitle,
                style: GoogleFonts.manrope(
                  fontSize: 11,
                  color: AppColors.secondaryText,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
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
                    ? LucideIcons.building2
                    : (isStock
                          ? LucideIcons.packageCheck
                          : isCircle
                          ? LucideIcons.circlePlus
                          : LucideIcons.pill),
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
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.manrope(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primaryText,
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
                            fontWeight: FontWeight.w800,
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
                          status,
                          style: GoogleFonts.manrope(
                            fontSize: 10,
                            color: statusFg,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
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
                        const Icon(
                          LucideIcons.users,
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
                                    text: ' ($participantsCount чел.)',
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
                    Text(
                      '$date  $time',
                      style: GoogleFonts.manrope(
                        fontSize: 12,
                        color: AppColors.secondaryText,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            const Icon(
              LucideIcons.chevronRight,
              color: AppColors.hintText,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

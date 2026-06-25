import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lima/core/i18n/app_i18n.dart';
import 'package:lima/core/theme/app_theme.dart';
import 'package:lima/core/widgets/app_widgets.dart';
import 'package:lima/core/services/app_actions.dart';
import 'package:lima/core/dialogs/feedback_dialog.dart';
import 'package:lima/core/providers/app_collections_provider.dart';
import 'package:lima/core/providers/dashboard_counts_provider.dart';
import 'package:lima/core/providers/sync_provider.dart';
import 'package:lima/core/network/api_client.dart';
import 'package:lima/core/db/local_database.dart';
import 'package:lima/core/services/local_notifications_service.dart';
import 'package:lima/core/services/material_cache_service.dart';
import 'package:lima/core/models/models.dart';
import 'package:lima/features/auth/providers/auth_provider.dart';
import 'package:lima/shell/nav_bar_layout.dart';

/// Role label for the profile — the server's exact role name, with a single
/// localized fallback when the server sent nothing.
String _roleDisplay(BuildContext context, UserModel? user) {
  final name = user?.roleName?.trim() ?? '';
  return name.isNotEmpty ? name : context.l10n.t('roleMp');
}

String _formatUzPhone(String raw) {
  final digits = raw.replaceAll(RegExp(r'\D'), '');
  String local = digits;
  if (digits.startsWith('998')) {
    local = digits.substring(3);
  } else if (digits.startsWith('8') && digits.length == 12) {
    local = digits.substring(1);
  }
  if (local.length < 9) return raw;
  final d = local.substring(0, 9);
  return '+998 ${d.substring(0, 2)} ${d.substring(2, 5)} ${d.substring(5, 7)} ${d.substring(7, 9)}';
}

String _visitsLabel(BuildContext context, int count) =>
    context.l10n.pluralWord(count, 'visits');

String _doctorsLabel(BuildContext context, int count) =>
    context.l10n.pluralWord(count, 'doctors');

final favoriteDoctorsCountProvider = FutureProvider.autoDispose<int>((
  ref,
) async {
  final db = ref.watch(localDatabaseProvider);
  return db.getFavoriteDoctorsCount();
});

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    final collections = ref.watch(appCollectionsProvider);
    final counts = ref.watch(dashboardCountsProvider).valueOrNull;
    final favoriteDoctorsCount = ref
        .watch(favoriteDoctorsCountProvider)
        .maybeWhen(data: (value) => value, orElse: () => 0);
    final visitsCount = counts?.visitsTotalCount ?? user?.visitsCount ?? 0;
    final doctorsCount = favoriteDoctorsCount;
    ref.listen<SyncState>(syncProvider, (prev, next) {
      final prevAt = prev?.lastSyncAt;
      final nextAt = next.lastSyncAt;
      if (nextAt == null) return;
      if (prevAt == null ||
          nextAt.millisecondsSinceEpoch != prevAt.millisecondsSinceEpoch) {
        ref.invalidate(favoriteDoctorsCountProvider);
        ref.invalidate(dashboardCountsProvider);
      }
    });

    return Scaffold(
      backgroundColor: AppColors.primaryBg,
      body: ListView(
        padding: EdgeInsets.only(
          bottom: LimaNavBarLayout.scrollBottomPadding(context),
        ),
        children: [
          // ── Blue header ─────────────────────────────────────────────────
          Container(
            color: AppColors.primary,
            padding: EdgeInsets.fromLTRB(
              12,
              MediaQuery.of(context).padding.top + 12,
              12,
              0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Avatar + Name + Role + City in a row (left-aligned)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.25),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          user?.initials ?? '?',
                          style: GoogleFonts.manrope(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user?.fullName ?? '',
                            style: GoogleFonts.manrope(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _roleDisplay(context, user),
                            style: GoogleFonts.manrope(
                              fontSize: 13,
                              color: Colors.white.withValues(alpha: 0.85),
                            ),
                          ),
                          if (user?.city != null) ...[
                            const SizedBox(height: 3),
                            Row(
                              children: [
                                Icon(
                                  LucideIcons.mapPin,
                                  size: 13,
                                  color: Colors.white.withValues(alpha: 0.7),
                                ),
                                const SizedBox(width: 2),
                                Text(
                                  user!.city!,
                                  style: GoogleFonts.manrope(
                                    fontSize: 12,
                                    color: Colors.white.withValues(alpha: 0.7),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Stats inside blue header
                Row(
                  children: [
                    _HeaderStatCard(
                      icon: LucideIcons.mapPin,
                      value: '$visitsCount',
                      label: _visitsLabel(context, visitsCount),
                      onTap: () => context.push('/visits/history'),
                    ),
                    const SizedBox(width: 8),
                    _HeaderStatCard(
                      icon: LucideIcons.badgeDollarSign,
                      value: formatUzs(user?.salesAmount ?? 0, short: true),
                      label: context.l10n.t('sales'),
                    ),
                    const SizedBox(width: 8),
                    _HeaderStatCard(
                      icon: LucideIcons.user,
                      value: '$doctorsCount',
                      label: _doctorsLabel(context, doctorsCount),
                      onTap: () => context.push('/profile/fav-doctors'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // ── Contact info ─────────────────────────────────────────────────
          if (user?.phone != null || user?.company != null) ...[
            _SectionHeader(context.l10n.t('contactInfo')),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.secondaryBg,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: shadowSm,
                ),
                child: Column(
                  children: [
                    if (user?.phone != null)
                      _ContactRow(
                        icon: LucideIcons.phone,
                        label: context.l10n.t('phone'),
                        value: _formatUzPhone(user!.phone!),
                        isLink: true,
                        onTap: () => launchPhone(user.phone!),
                      ),
                    if (user?.phone != null && user?.company != null)
                      const Divider(
                        height: 1,
                        thickness: 0.5,
                        color: AppColors.divider,
                      ),
                    if (user?.company != null)
                      _ContactRow(
                        icon: LucideIcons.building2,
                        label: context.l10n.t('company'),
                        value: user!.company!,
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],

          // ── Quick actions ────────────────────────────────────────────────
          _SectionHeader(context.l10n.t('quickActions')),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.secondaryBg,
                borderRadius: BorderRadius.circular(16),
                boxShadow: shadowSm,
              ),
              child: Column(
                children: [
                  _ActionTile(
                    icon: LucideIcons.history,
                    label: context.l10n.t('visitHistory'),
                    iconBg: AppColors.iconBgBlue,
                    iconColor: AppColors.primary,
                    onTap: () => context.push('/visits/history'),
                  ),
                  _divider,
                  _ActionTile(
                    icon: LucideIcons.calendarDays,
                    label: context.l10n.t('visitPlan'),
                    iconBg: AppColors.iconBgBlue,
                    iconColor: AppColors.primary,
                    onTap: () => context.go('/plan'),
                  ),
                  _divider,
                  _ActionTile(
                    icon: LucideIcons.user,
                    label: context.l10n.t('favDoctors'),
                    iconBg: AppColors.iconBgBlue,
                    iconColor: AppColors.primary,
                    onTap: () => context.push('/profile/fav-doctors'),
                  ),
                  _divider,
                  _ActionTile(
                    icon: LucideIcons.cross,
                    label: context.l10n.t('favPharmacies'),
                    iconBg: AppColors.iconBgBlue,
                    iconColor: AppColors.primary,
                    onTap: () => context.push('/profile/fav-pharmacies'),
                  ),
                  _divider,
                  _ActionTile(
                    icon: LucideIcons.bookOpen,
                    label: context.l10n.t('knowledge'),
                    iconBg: AppColors.iconBgBlue,
                    iconColor: AppColors.primary,
                    onTap: () => context.go('/knowledge'),
                  ),
                  _divider,
                  _ActionTile(
                    icon: LucideIcons.shoppingCart,
                    label: context.l10n.t('cart'),
                    subtitle: collections.cartCount > 0
                        ? '${collections.cartCount} ${context.l10n.t('orders')}'
                        : null,
                    iconBg: AppColors.iconBgBlue,
                    iconColor: AppColors.primary,
                    onTap: () => context.push('/basket'),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // ── Settings ─────────────────────────────────────────────────────
          _SectionHeader(context.l10n.t('settings')),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.secondaryBg,
                borderRadius: BorderRadius.circular(16),
                boxShadow: shadowSm,
              ),
              child: Column(
                children: [
                  const _NotificationTile(),
                  _divider,
                  _ActionTile(
                    icon: LucideIcons.trash2,
                    label: context.l10n.t('clearCache'),
                    iconBg: AppColors.iconBgOrange,
                    iconColor: AppColors.accent,
                    onTap: () async {
                      await ref
                          .read(appCollectionsProvider.notifier)
                          .clearCart();
                      final db = ref.read(localDatabaseProvider);
                      final apiClient = ref.read(apiClientProvider);
                      final cacheService = MaterialCacheService(
                        dio: apiClient.dio,
                        authToken: apiClient.token,
                      );
                      await cacheService.clearCache(db);
                      await db.db.delete('cached_stats');
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(context.l10n.t('cacheCleared')),
                          ),
                        );
                      }
                    },
                  ),
                  _divider,
                  _ActionTile(
                    icon: LucideIcons.userMinus,
                    label: context.l10n.t('deleteAccount'),
                    iconBg: const Color(0xFFFFEEEE),
                    iconColor: AppColors.error,
                    onTap: () => _confirmDeleteAccount(context, ref, user),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // ── Support ─────────────────────────────────────────────────────
          _SectionHeader(context.l10n.t('support')),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.secondaryBg,
                borderRadius: BorderRadius.circular(16),
                boxShadow: shadowSm,
              ),
              child: Column(
                children: [
                  _ActionTile(
                    icon: LucideIcons.send,
                    label: context.l10n.t('feedback'),
                    iconBg: AppColors.iconBgBlue,
                    iconColor: AppColors.primary,
                    onTap: () => showFeedbackDialog(context),
                  ),
                  _divider,
                  _ActionTile(
                    icon: LucideIcons.headset,
                    label: context.l10n.t('techSupport'),
                    iconBg: AppColors.iconBgGreen,
                    iconColor: AppColors.success,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // ── Logout ───────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: AppTapScale(
              pressedScale: 0.97,
              onTap: () => ref.read(authProvider.notifier).logout(),
              child: Container(
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFEEEE),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      LucideIcons.logOut,
                      color: AppColors.error,
                      size: 17,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      context.l10n.t('logout'),
                      style: GoogleFonts.manrope(
                        color: AppColors.error,
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const _AppVersionLabel(),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

/// Account deletion for org-provisioned (B2B) accounts: the user cannot
/// self-delete, so we send a deletion request to LIMA support and sign out
/// locally. Satisfies App Store Guideline 5.1.1(v) for managed accounts.
Future<void> _confirmDeleteAccount(
  BuildContext context,
  WidgetRef ref,
  UserModel? user,
) async {
  final l10n = context.l10n;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(l10n.t('deleteAccountTitle')),
      content: Text(l10n.t('deleteAccountInfo')),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: Text(l10n.t('cancel')),
        ),
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          style: TextButton.styleFrom(foregroundColor: AppColors.error),
          child: Text(l10n.t('deleteAccountSend')),
        ),
      ],
    ),
  );
  if (confirmed != true) return;

  final body = StringBuffer()
    ..writeln('Account deletion request / Запрос на удаление аккаунта')
    ..writeln('---')
    ..writeln('User ID: ${user?.id ?? '-'}')
    ..writeln('Name: ${user?.fullName ?? '-'}')
    ..writeln('Phone: ${user?.phone ?? '-'}')
    ..writeln('Company: ${user?.company ?? '-'}');
  await launchEmailRequest(
    'info@lima.uz',
    subject: 'LIMA — account deletion request (ID ${user?.id ?? '-'})',
    body: body.toString(),
  );

  await ref.read(authProvider.notifier).logout();
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.l10n.t('deleteAccountRequested'))),
    );
  }
}

const _divider = Divider(
  height: 1,
  thickness: 0.5,
  color: AppColors.divider,
);

class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
      child: Text(
        text.toUpperCase(),
        style: GoogleFonts.manrope(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: AppColors.secondaryText,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

class _HeaderStatCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final VoidCallback? onTap;

  const _HeaderStatCard({
    required this.icon,
    required this.value,
    required this.label,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: AppTapScale(
        pressedScale: 0.93,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  color: Colors.white.withValues(alpha: 0.9),
                  size: 18,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                // Fixed to the icon height so the value/label hug the icon's
                // top/bottom edges, with 2px insets to pull them slightly in.
                child: SizedBox(
                  height: 36,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          value,
                          style: GoogleFonts.manrope(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            height: 1,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          softWrap: false,
                        ),
                        Text(
                          label,
                          style: GoogleFonts.manrope(
                            color: Colors.white.withValues(alpha: 0.75),
                            fontSize: 10,
                            height: 1,
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
      ),
    );
  }
}

class _ContactRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool isLink;
  final VoidCallback? onTap;

  const _ContactRow({
    required this.icon,
    required this.label,
    required this.value,
    this.isLink = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.iconBgBlue,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: AppColors.primary, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.manrope(
                      fontSize: 11,
                      color: AppColors.secondaryText,
                    ),
                  ),
                  Text(
                    value,
                    style: GoogleFonts.manrope(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: isLink ? AppColors.primary : AppColors.primaryText,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (isLink)
              const Icon(
                Icons.chevron_right,
                color: AppColors.hintText,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  final Color iconBg;
  final Color iconColor;
  final VoidCallback? onTap;

  const _ActionTile({
    required this.icon,
    required this.label,
    required this.iconBg,
    required this.iconColor,
    this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: iconBg,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: iconColor, size: 18),
      ),
      title: Text(
        label,
        style: GoogleFonts.manrope(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: AppColors.primaryText,
        ),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle!,
              style: GoogleFonts.manrope(
                fontSize: 12,
                color: AppColors.secondaryText,
              ),
            )
          : null,
      trailing: onTap != null
          ? const Icon(Icons.chevron_right, color: AppColors.hintText, size: 20)
          : null,
    );
  }
}

class _NotificationTile extends StatefulWidget {
  const _NotificationTile();

  @override
  State<_NotificationTile> createState() => _NotificationTileState();
}

class _NotificationTileState extends State<_NotificationTile> {
  bool _enabled = false;

  @override
  void initState() {
    super.initState();
    _loadPref();
  }

  Future<void> _loadPref() async {
    final prefs = await SharedPreferences.getInstance();
    final prefEnabled = prefs.getBool('notifications_enabled') ?? false;
    final status = await Permission.notification.status;
    final enabled = prefEnabled && status.isGranted;
    if (mounted) {
      setState(() => _enabled = enabled);
    }
    if (prefEnabled != enabled) {
      await prefs.setBool('notifications_enabled', enabled);
    }
  }

  Future<void> _toggle(bool value) async {
    if (value) {
      // Request OS authorization via the local-notifications plugin: this fires
      // the iOS system prompt on first use and registers the app with
      // UNUserNotificationCenter, so a "Notifications" row appears in Settings.
      // (permission_handler alone failed to create that row when the app had no
      // notification plugin configured, leaving the toggle at a dead-end.)
      final granted = await LocalNotificationsService.instance
          .requestPermission();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('notifications_enabled', granted);
      if (mounted) setState(() => _enabled = granted);
      final status = await Permission.notification.status;
      if (!granted &&
          (status.isPermanentlyDenied || status.isRestricted) &&
          mounted) {
        final openSettings = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(ctx.l10n.t('notifAccessTitle')),
            content: Text(ctx.l10n.t('notifPermDisabled')),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(ctx.l10n.t('cancel')),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(ctx.l10n.t('openSettings')),
              ),
            ],
          ),
        );
        if (openSettings == true) await openAppSettings();
      }
    } else {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('notifications_enabled', false);
      setState(() => _enabled = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: AppColors.iconBgBlue,
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(
          Icons.notifications_rounded,
          color: AppColors.primary,
          size: 18,
        ),
      ),
      title: Text(
        AppI18n.of(context).t('notifications'),
        style: GoogleFonts.manrope(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: AppColors.primaryText,
        ),
      ),
      trailing: Switch(
        value: _enabled,
        onChanged: _toggle,
        activeThumbColor: Colors.white,
        activeTrackColor: AppColors.primary,
      ),
    );
  }
}

class _AppVersionLabel extends StatefulWidget {
  const _AppVersionLabel();

  @override
  State<_AppVersionLabel> createState() => _AppVersionLabelState();
}

class _AppVersionLabelState extends State<_AppVersionLabel> {
  String _version = '';

  @override
  void initState() {
    super.initState();
    PackageInfo.fromPlatform()
        .then((info) {
          if (mounted) {
            setState(() => _version = '${info.version}+${info.buildNumber}');
          }
        })
        .catchError((_) {});
  }

  @override
  Widget build(BuildContext context) {
    if (_version.isEmpty) return const SizedBox.shrink();
    return Center(
      child: Text(
        'v$_version',
        style: GoogleFonts.manrope(fontSize: 12, color: AppColors.hintText),
      ),
    );
  }
}
